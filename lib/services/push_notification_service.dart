import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:leagueit/app_settings.dart';
import 'package:leagueit/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> leagueItFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    'FCM background message received: '
    '${message.messageId ?? '(no id)'}',
  );
  try {
    await _persistRemoteMessageToNotificationCenterBackground(message);
  } catch (error, stackTrace) {
    debugPrint('FCM background notification persist failed: $error');
    debugPrint('$stackTrace');
  }
}

const FlutterSecureStorage _fantasyNotificationStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accountName: 'leagueit_local_state'),
);
const String _fantasyNotificationEntriesStorageKeyPrefix =
    'fantasy.notifications.v1';
const Duration _fantasyNotificationRetentionWindow = Duration(days: 3);

String _fantasyNotificationUserScopeKey(String? uid) {
  final normalizedUid = uid?.trim() ?? '';
  return normalizedUid.isEmpty ? 'anonymous' : normalizedUid;
}

String _fantasyNotificationEntriesStorageKeyForUser(String? uid) =>
    '$_fantasyNotificationEntriesStorageKeyPrefix.${_fantasyNotificationUserScopeKey(uid)}';

class PushNotificationCenterEvent {
  const PushNotificationCenterEvent({
    required this.kind,
    required this.leagueId,
    required this.leagueName,
    required this.isSoccer,
    required this.round,
    required this.uid,
    required this.messageId,
  });

  final String kind;
  final String leagueId;
  final String leagueName;
  final bool isSoccer;
  final int? round;
  final String uid;
  final String messageId;
}

String _pushNotificationCenterKindForRemoteMessage(String type) {
  switch (type) {
    case 'fpts':
    case 'roster_lock_soon':
    case 'roster_lock':
    case 'roster_unlock':
    case 'trade_request':
    case 'draft_soon':
      return type;
    default:
      return type.isEmpty ? 'push' : type;
  }
}

String _normalizedPushFptsNotificationId({
  required String eventId,
  required String leagueId,
  required String round,
}) {
  final parts = eventId
      .split(':')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '';
  if (parts.first == 'fpts_pitcher' && parts.length >= 6) {
    return 'fpts_pitcher:${parts[1]}:${parts[3]}:${parts.sublist(4).join(':')}';
  }
  if (parts.first == 'fpts' && parts.length >= 5) {
    final playerId = parts.sublist(4).join(':');
    if (playerId.isEmpty) return '';
    return 'fpts:${parts[1]}:${parts[3]}:$playerId:push';
  }
  if (parts.first == 'fpts_goal' && parts.length >= 5) {
    final effectiveLeagueId = leagueId.isNotEmpty ? leagueId : parts[1];
    final effectiveRound = round.isNotEmpty ? round : '0';
    final playerId = parts.sublist(4).join(':');
    if (effectiveLeagueId.isEmpty || playerId.isEmpty) return '';
    return 'fpts:$effectiveLeagueId:$effectiveRound:$playerId:goal';
  }
  return '';
}

String _pushNotificationCenterEntryIdForRemoteMessage({
  required RemoteMessage message,
  required String type,
  required String leagueId,
  required String requestId,
  required String round,
  required String eventId,
}) {
  if (type == 'trade_request' && requestId.isNotEmpty) {
    return 'trade:$requestId';
  }
  if (type == 'roster_lock_soon' && eventId.isNotEmpty) {
    final parts = eventId
        .split(':')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 4 && parts.first == 'roster_lock_soon') {
      return 'lock_soon:${parts[1]}:${parts[2]}:${parts[3]}';
    }
  }
  if (type == 'roster_lock' && eventId.isNotEmpty) {
    final parts = eventId
        .split(':')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 4 && parts.first == 'roster_lock') {
      return 'lock:${parts[1]}:${parts[2]}';
    }
  }
  if (type == 'roster_unlock' && leagueId.isNotEmpty && round.isNotEmpty) {
    return 'unlock:$leagueId:$round';
  }
  if (type == 'fpts' && eventId.isNotEmpty) {
    final normalized = _normalizedPushFptsNotificationId(
      eventId: eventId,
      leagueId: leagueId,
      round: round,
    );
    if (normalized.isNotEmpty) return normalized;
  }
  if (eventId.isNotEmpty) {
    return 'push:$eventId';
  }
  final messageId = message.messageId?.trim() ?? '';
  if (messageId.isNotEmpty) return 'push:$messageId';
  return 'push:${DateTime.now().microsecondsSinceEpoch}';
}

String _uidForPushRemoteMessage(RemoteMessage message) {
  final explicitUid = '${message.data['uid'] ?? ''}'.trim();
  if (explicitUid.isNotEmpty) return explicitUid;
  final eventId = '${message.data['eventId'] ?? ''}'.trim();
  if (eventId.isEmpty) return '';
  final parts = eventId
      .split(':')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length >= 3 &&
      (parts.first == 'fpts' ||
          parts.first == 'fpts_pitcher' ||
          parts.first == 'fpts_goal')) {
    return parts[2];
  }
  return '';
}

PushNotificationCenterEvent _pushNotificationCenterEventForRemoteMessage(
  RemoteMessage message, {
  String? fallbackUid,
}) {
  final data = message.data;
  final type = '${data['type'] ?? ''}'.trim();
  final kind = _pushNotificationCenterKindForRemoteMessage(type);
  final leagueId = '${data['leagueId'] ?? ''}'.trim();
  final leagueName = '${data['leagueName'] ?? ''}'.trim();
  final round = int.tryParse('${data['round'] ?? ''}'.trim());
  final sport = '${data['sport'] ?? ''}'.trim().toLowerCase();
  final uid = _uidForPushRemoteMessage(message).trim();
  final effectiveUid = uid.isNotEmpty ? uid : (fallbackUid?.trim() ?? '');
  return PushNotificationCenterEvent(
    kind: kind,
    leagueId: leagueId,
    leagueName: leagueName,
    isSoccer: sport == 'soccer',
    round: round,
    uid: effectiveUid,
    messageId: message.messageId?.trim() ?? '',
  );
}

Map<String, dynamic>? _notificationCenterEntryForRemoteMessagePayload(
  RemoteMessage message,
) {
  final title =
      message.notification?.title?.trim() ??
      '${message.data['title'] ?? ''}'.trim();
  final body =
      message.notification?.body?.trim() ??
      '${message.data['body'] ?? ''}'.trim();
  if (title.isEmpty && body.isEmpty) return null;

  final data = message.data;
  final type = '${data['type'] ?? ''}'.trim();
  final leagueId = '${data['leagueId'] ?? ''}'.trim();
  final leagueName = '${data['leagueName'] ?? ''}'.trim();
  final requestId = '${data['requestId'] ?? ''}'.trim();
  final round = '${data['round'] ?? ''}'.trim();
  final sport = '${data['sport'] ?? ''}'.trim().toLowerCase();
  final eventId = '${data['eventId'] ?? ''}'.trim();
  final createdAt =
      message.sentTime?.toIso8601String() ?? DateTime.now().toIso8601String();

  return <String, dynamic>{
    'id': _pushNotificationCenterEntryIdForRemoteMessage(
      message: message,
      type: type,
      leagueId: leagueId,
      requestId: requestId,
      round: round,
      eventId: eventId,
    ),
    'kind': _pushNotificationCenterKindForRemoteMessage(type),
    'leagueId': leagueId,
    'leagueName': leagueName,
    'isSoccer': sport == 'soccer',
    'title': title.isEmpty ? 'LeagueIt' : title,
    'message': body,
    'createdAt': createdAt,
    'isRead': false,
  };
}

Future<List<Map<String, dynamic>>> _loadStoredNotificationEntryMaps(
  String key,
) async {
  final raw = await _fantasyNotificationStorage.read(key: key);
  if (raw == null || raw.trim().isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item.cast<Object?, Object?>()))
        .toList(growable: false);
  } catch (_) {
    return const <Map<String, dynamic>>[];
  }
}

List<Map<String, dynamic>> _trimStoredNotificationEntryMaps(
  List<Map<String, dynamic>> entries,
) {
  final now = DateTime.now();
  final cutoff = now.subtract(_fantasyNotificationRetentionWindow);
  final trimmed =
      entries.where((item) {
        final createdAt =
            DateTime.tryParse('${item['createdAt'] ?? ''}') ?? DateTime(1970);
        return !createdAt.isBefore(cutoff);
      }).toList()..sort((a, b) {
        final aCreatedAt =
            DateTime.tryParse('${a['createdAt'] ?? ''}') ?? DateTime(1970);
        final bCreatedAt =
            DateTime.tryParse('${b['createdAt'] ?? ''}') ?? DateTime(1970);
        return bCreatedAt.compareTo(aCreatedAt);
      });
  return trimmed;
}

Future<void> _persistRemoteMessageToNotificationCenterBackground(
  RemoteMessage message,
) async {
  final uid = _uidForPushRemoteMessage(message).trim();
  if (uid.isEmpty) return;
  final entry = _notificationCenterEntryForRemoteMessagePayload(message);
  if (entry == null) return;
  final key = _fantasyNotificationEntriesStorageKeyForUser(uid);
  final entries = await _loadStoredNotificationEntryMaps(key);
  final existingIds = entries
      .map((item) => '${item['id'] ?? ''}'.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (!existingIds.add('${entry['id'] ?? ''}'.trim())) {
    return;
  }
  final updatedEntries = _trimStoredNotificationEntryMaps([entry, ...entries]);
  await _fantasyNotificationStorage.write(
    key: key,
    value: jsonEncode(updatedEntries),
  );
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        'leagueit_general',
        'LeagueIt General',
        description: 'LeagueIt push and fantasy notifications',
        importance: Importance.max,
      );

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<PushNotificationCenterEvent>
  _notificationCenterEntriesController =
      StreamController<PushNotificationCenterEvent>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  bool _permissionRequested = false;
  String? _lastSyncedUid;

  Stream<PushNotificationCenterEvent> get notificationCenterEntriesChanged =>
      _notificationCenterEntriesController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    appSettings.addListener(_handleAppSettingsChanged);
    await _initializeLocalNotifications();
    await _syncPushEnabledPreference();
    if (kIsWeb) return;

    await _messaging.setAutoInitEnabled(true);
    FirebaseMessaging.onBackgroundMessage(
      leagueItFirebaseMessagingBackgroundHandler,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'FCM foreground message received: ${message.messageId ?? '(no id)'}',
      );
      unawaited(_persistRemoteMessageToNotificationCenter(message));
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(_showForegroundRemoteMessage(message));
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_persistRemoteMessageToNotificationCenter(message));
      _handleMessageOpened(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _persistRemoteMessageToNotificationCenter(initialMessage);
      _handleMessageOpened(initialMessage);
    }

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_syncCurrentToken(tokenOverride: token));
    });

    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((_) {
      unawaited(_handleAuthStateChanged());
    });

    await _handleAuthStateChanged();
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized || kIsWeb) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_generalChannel);
    await androidPlugin?.requestNotificationsPermission();
    _localNotificationsInitialized = true;
  }

  Future<void> _handleAuthStateChanged() async {
    final currentUser = _auth.currentUser;
    final previousUid = _lastSyncedUid;
    final currentUid = currentUser?.uid.trim();
    if (previousUid != null &&
        previousUid.isNotEmpty &&
        previousUid != currentUid) {
      await _removeTokenFromUser(previousUid);
    }
    _lastSyncedUid = currentUid;
    await _syncPushEnabledPreference();
    if (currentUser == null) return;

    final settings = await _ensurePermission();
    final status = settings.authorizationStatus;
    if (status != AuthorizationStatus.authorized &&
        status != AuthorizationStatus.provisional) {
      await _syncPermissionState(
        authorizationStatus: status.name,
        fcmToken: null,
        apnsToken: await _messaging.getAPNSToken(),
      );
      return;
    }

    await _syncCurrentToken();
  }

  void _handleAppSettingsChanged() {
    unawaited(_syncPushEnabledPreference());
  }

  Future<NotificationSettings> _ensurePermission() async {
    final current = await _messaging.getNotificationSettings();
    if (current.authorizationStatus != AuthorizationStatus.notDetermined ||
        _permissionRequested) {
      return current;
    }
    _permissionRequested = true;
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _syncCurrentToken({String? tokenOverride}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settings = await _messaging.getNotificationSettings();
    final token = tokenOverride ?? await _messaging.getToken();
    final apnsToken = await _messaging.getAPNSToken();
    await _syncPermissionState(
      authorizationStatus: settings.authorizationStatus.name,
      fcmToken: token,
      apnsToken: apnsToken,
    );
  }

  Future<void> _syncPermissionState({
    required String authorizationStatus,
    required String? fcmToken,
    required String? apnsToken,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final payload = <String, dynamic>{
      'notificationPermissionStatus': authorizationStatus,
      'notificationPlatform': defaultTargetPlatform.name,
      'pushEnabled': appSettings.pushEnabled,
      'pushTokenUpdatedAt': FieldValue.serverTimestamp(),
    };
    if ((fcmToken ?? '').trim().isNotEmpty) {
      payload['fcmTokens'] = FieldValue.arrayUnion([fcmToken!.trim()]);
      payload['lastFcmToken'] = fcmToken.trim();
    }
    if ((apnsToken ?? '').trim().isNotEmpty) {
      payload['apnsToken'] = apnsToken!.trim();
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(payload, SetOptions(merge: true));
    final normalizedToken = fcmToken?.trim() ?? '';
    if (normalizedToken.isNotEmpty) {
      await _removeTokenFromOtherUsers(
        currentUid: user.uid,
        fcmToken: normalizedToken,
      );
    }
  }

  Future<void> _syncPushEnabledPreference() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'pushEnabled': appSettings.pushEnabled,
      'pushPreferenceUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeTokenFromUser(String uid) async {
    final token = await _messaging.getToken();
    final normalizedToken = token?.trim() ?? '';
    if (normalizedToken.isEmpty) return;
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([normalizedToken]),
      'lastFcmToken': FieldValue.delete(),
      'pushTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeTokenFromOtherUsers({
    required String currentUid,
    required String fcmToken,
  }) async {
    final normalizedUid = currentUid.trim();
    final normalizedToken = fcmToken.trim();
    if (normalizedUid.isEmpty || normalizedToken.isEmpty) return;
    final docRef = _firestore.collection('users').doc(normalizedUid);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawTokens = data['fcmTokens'];
    final existingTokens = rawTokens is Iterable
        ? rawTokens
              .map((value) => '$value'.trim())
              .where((value) => value.isNotEmpty && value != normalizedToken)
              .toList(growable: false)
        : const <String>[];
    final cleanedTokens = <String>[
      ...LinkedHashSet<String>.from(existingTokens),
      normalizedToken,
    ];
    final lastToken = '${data['lastFcmToken'] ?? ''}'.trim();
    final tokensChanged =
        rawTokens is! Iterable ||
        cleanedTokens.length != rawTokens.length ||
        !cleanedTokens.every(
          rawTokens.cast<Object?>().map((e) => '$e'.trim()).contains,
        );
    if (!tokensChanged && lastToken == normalizedToken) {
      return;
    }
    await docRef.set({
      'fcmTokens': cleanedTokens,
      'lastFcmToken': normalizedToken,
      'pushTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title?.trim() ??
        '${message.data['title'] ?? ''}'.trim();
    final body =
        message.notification?.body?.trim() ??
        '${message.data['body'] ?? ''}'.trim();
    if (title.isEmpty && body.isEmpty) return;
    await showLocalNotification(
      tag:
          'remote:${message.messageId ?? DateTime.now().millisecondsSinceEpoch}',
      title: title.isEmpty ? 'LeagueIt' : title,
      body: body,
      data: {
        'type': '${message.data['type'] ?? ''}',
        'leagueId': '${message.data['leagueId'] ?? ''}',
        'requestId': '${message.data['requestId'] ?? ''}',
      },
    );
  }

  Future<void> _persistRemoteMessageToNotificationCenter(
    RemoteMessage message,
  ) async {
    final currentUser = _auth.currentUser;
    final uid =
        currentUser?.uid.trim() ??
        _lastSyncedUid?.trim() ??
        _uidForPushRemoteMessage(message).trim();
    if (uid.isEmpty) return;

    final entry = _notificationCenterEntryForRemoteMessagePayload(message);
    final event = _pushNotificationCenterEventForRemoteMessage(
      message,
      fallbackUid: uid,
    );
    if (entry == null) {
      _notificationCenterEntriesController.add(event);
      return;
    }

    final key = _fantasyNotificationEntriesStorageKeyForUser(uid);
    final entries = await _loadStoredNotificationEntryMaps(key);
    final existingIds = entries
        .map((item) => '${item['id'] ?? ''}'.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final inserted = existingIds.add('${entry['id'] ?? ''}'.trim());
    final updatedEntries = inserted
        ? _trimStoredNotificationEntryMaps([entry, ...entries])
        : _trimStoredNotificationEntryMaps(entries);

    await _fantasyNotificationStorage.write(
      key: key,
      value: jsonEncode(updatedEntries),
    );
    final unreadCount = updatedEntries
        .where((item) => item['isRead'] != true)
        .length;
    await syncAppIconBadgeCount(unreadCount);
    _notificationCenterEntriesController.add(event);
  }

  Future<void> showLocalNotification({
    required String tag,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (kIsWeb || !appSettings.pushEnabled) return;
    await _initializeLocalNotifications();
    await _localNotifications.show(
      id: _stableNotificationId(tag),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannel.id,
          _generalChannel.name,
          channelDescription: _generalChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data ?? const <String, String>{}),
    );
  }

  Future<void> syncAppIconBadgeCount(int count) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    await _initializeLocalNotifications();
    final badgeCount = count < 0 ? 0 : count;
    await _localNotifications.show(
      id: _stableNotificationId('badge_sync'),
      title: null,
      body: null,
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          presentBanner: false,
          presentList: false,
          badgeNumber: badgeCount,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          presentBanner: false,
          presentList: false,
          badgeNumber: badgeCount,
        ),
      ),
    );
  }

  int _stableNotificationId(String tag) => tag.hashCode & 0x7fffffff;

  void _handleMessageOpened(RemoteMessage message) {
    debugPrint(
      'FCM message opened: ${message.messageId ?? '(no id)'} '
      'data=${message.data}',
    );
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    debugPrint(
      'Local notification tapped: '
      '${response.payload ?? '(no payload)'}',
    );
  }

  Future<void> dispose() async {
    appSettings.removeListener(_handleAppSettingsChanged);
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _notificationCenterEntriesController.close();
  }
}

final PushNotificationService pushNotificationService =
    PushNotificationService();
