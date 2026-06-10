import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:leagueit/app_settings.dart';
import 'package:leagueit/auth/auth_controller.dart';
import 'package:leagueit/public_user_profile.dart';
import 'package:leagueit/services/api_service.dart';
import 'package:leagueit/services/league_service.dart';
import 'package:leagueit/services/push_notification_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

part 'widgets/custom_app_bar.dart';
part 'widgets/my_page_card.dart';
part 'widgets/side_menu.dart';
part 'widgets/card_switcher.dart';
part 'widgets/card_base.dart';
part 'widgets/shared_cards.dart';
part 'pages/simple_page.dart';
part 'pages/create_league_page.dart';
part 'pages/join_league_page.dart';
part 'pages/login_page.dart';
part 'pages/sign_up_page.dart';
part 'pages/faq_page.dart';
part 'pages/match_detail_page.dart';
part 'pages/roster_page.dart';
part 'pages/league_page.dart';
part 'pages/privacy_policy_page.dart';
part 'pages/profile_page.dart';
part 'pages/password_page.dart';
part 'pages/my_league_page.dart';
part 'pages/about_page.dart';
part 'pages/playbook_page.dart';
part 'pages/settings_page.dart';
part 'pages/draft_page.dart';
part 'pages/player_profile_page.dart';
part 'data/doc_player_meta.dart';
part 'pages/team_page.dart';
part 'pages/standings_page.dart';
part 'pages/schedule_page.dart';

final GlobalKey<LeagueItHomePageState> homeKey =
    GlobalKey<LeagueItHomePageState>();
const FlutterSecureStorage _profileAvatarStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accountName: 'leagueit_local_state'),
);
final ValueNotifier<String?> _profileAvatarPathNotifier =
    ValueNotifier<String?>(null);
final Map<String, ValueNotifier<String?>> _publicProfileAvatarUrlNotifiers = {};
bool _profileAvatarPathLoaded = false;
String _profileAvatarPathLoadedUid = '';
Future<void>? _profileAvatarPathLoadFuture;
int _profileAvatarPathLoadToken = 0;
final Map<String, Future<void>> _publicProfileAvatarUrlLoadFutures = {};
const String _localStateCacheDirectoryName = 'local_state_cache';
Future<Directory>? _localStateCacheDirectoryFuture;

Future<Directory> _ensureLocalStateCacheDirectory() {
  final inFlight = _localStateCacheDirectoryFuture;
  if (inFlight != null) return inFlight;
  final future = () async {
    final baseDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${baseDirectory.path}/$_localStateCacheDirectoryName',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }();
  _localStateCacheDirectoryFuture = future;
  return future;
}

String _localStateCacheFileName(String key) =>
    '${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}.json';

Future<File> _localStateCacheFile(String key) async {
  final directory = await _ensureLocalStateCacheDirectory();
  return File('${directory.path}/${_localStateCacheFileName(key)}');
}

Future<String?> _readLocalStateCache(String key) async {
  try {
    final file = await _localStateCacheFile(key);
    if (!await file.exists()) return null;
    final value = await file.readAsString();
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  } catch (error, stackTrace) {
    debugPrint('Local state cache read failed ($key): $error');
    debugPrint('$stackTrace');
    return null;
  }
}

Future<void> _writeLocalStateCache(String key, String value) async {
  final file = await _localStateCacheFile(key);
  await file.writeAsString(value, flush: true);
}

Future<String?> _readLocalStateCacheWithLegacySecureStorage({
  required String key,
  required FlutterSecureStorage legacyStorage,
}) async {
  final cached = await _readLocalStateCache(key);
  if (cached != null) return cached;
  try {
    final legacy = await legacyStorage.read(key: key);
    final normalized = legacy?.trim() ?? '';
    if (normalized.isEmpty) return null;
    await _writeLocalStateCache(key, normalized);
    unawaited(legacyStorage.delete(key: key));
    return normalized;
  } catch (error, stackTrace) {
    debugPrint('Legacy secure cache restore failed ($key): $error');
    debugPrint('$stackTrace');
    return null;
  }
}

// Hide placeholder league/match/standings data until real data is connected.
const bool kUseMockDataOutsideDraft = false;
const Duration _koreaTimeOffset = Duration(hours: 9);
final FilteringTextInputFormatter _passwordAsciiInputFormatter =
    FilteringTextInputFormatter.allow(RegExp(r'[\x21-\x7E]'));

bool _isAllowedPasswordValue(String value) {
  return RegExp(r'^[\x21-\x7E]*$').hasMatch(value);
}

class _LeagueItSurfacePalette {
  final bool isDark;
  final Color pageBackground;
  final Color cardBorder;
  final Color fieldFill;
  final Color ink;
  final Color mutedInk;
  final Color accent;
  final Color accentSoft;
  final Color gradientTop;
  final Color gradientBottom;
  final Color buttonDisabled;
  final Color tileSurface;
  final Color chipBorder;
  final Color popupSurfaceTop;
  final Color popupSurfaceBottom;
  final Color popupBorder;

  const _LeagueItSurfacePalette({
    required this.isDark,
    required this.pageBackground,
    required this.cardBorder,
    required this.fieldFill,
    required this.ink,
    required this.mutedInk,
    required this.accent,
    required this.accentSoft,
    required this.gradientTop,
    required this.gradientBottom,
    required this.buttonDisabled,
    required this.tileSurface,
    required this.chipBorder,
    required this.popupSurfaceTop,
    required this.popupSurfaceBottom,
    required this.popupBorder,
  });
}

_LeagueItSurfacePalette _leagueItSurfacePalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const _LeagueItSurfacePalette(
      isDark: true,
      pageBackground: Color(0xFF0F1110),
      cardBorder: Color(0xFF2A322D),
      fieldFill: Color(0xFF171B19),
      ink: Color(0xFFF5F7F2),
      mutedInk: Color(0xFFB1B7AF),
      accent: Color(0xFF54B37B),
      accentSoft: Color(0xFF183226),
      gradientTop: Color(0xFF151917),
      gradientBottom: Color(0xFF0F1311),
      buttonDisabled: Color(0xFF3C4741),
      tileSurface: Color(0xFF161A18),
      chipBorder: Color(0xFF29523D),
      popupSurfaceTop: Color(0xFF171B20),
      popupSurfaceBottom: Color(0xFF101418),
      popupBorder: Color(0xFF2A3440),
    );
  }
  return const _LeagueItSurfacePalette(
    isDark: false,
    pageBackground: Color(0xFFF7F7F2),
    cardBorder: Color(0xFFD8DDD2),
    fieldFill: Color(0xFFFFFFFC),
    ink: Color(0xFF1E1E1B),
    mutedInk: Color(0xFF6B6C66),
    accent: Color(0xFF245B45),
    accentSoft: Color(0xFFE4F0E9),
    gradientTop: Color(0xFFF5F7F0),
    gradientBottom: Color(0xFFFDFBF3),
    buttonDisabled: Color(0xFFBFC8BF),
    tileSurface: Color(0xFFFFFFFF),
    chipBorder: Color(0xFFCBE1D2),
    popupSurfaceTop: Color(0xFFFFFFFF),
    popupSurfaceBottom: Color(0xFFF7FAFF),
    popupBorder: Color(0xFFDDE7FF),
  );
}

bool _fantasyMatchupHasLiveOfficialGames(_FantasyMatchupView matchup) {
  if (!matchup.scoresReady) return false;
  return _fantasyRoundHasLiveOfficialGames(matchup.draft, matchup.round);
}

bool _fantasyRoundHasLiveOfficialGames(_JoinedDraft draft, int fantasyRound) {
  if (fantasyRound <= 0) return false;
  if (draft.isSoccer) {
    final rawFixtures = _fixtureAsList(_cachedKLeagueLeagueData?['fixtures']);
    if (rawFixtures.isEmpty) return false;
    final leagueRound = _mappedKLeagueRoundForFantasyRound(
      draft,
      fantasyRound,
      rawFixtures,
    );
    for (final raw in rawFixtures) {
      final map = _fixtureAsMap(raw);
      final league = _fixtureAsMap(map['league']);
      if (_roundNumber(_fixtureText(league['round'])) != leagueRound) {
        continue;
      }
      final fixture = _fixtureAsMap(map['fixture']);
      final status = _fixtureAsMap(fixture['status']);
      if (_isKLeagueLiveStatusShort(_fixtureText(status['short']))) {
        return true;
      }
    }
    return false;
  }

  final rawMatches = _fixtureAsList(_cachedKboLeagueData?['matches']);
  if (rawMatches.isEmpty) return false;
  final leagueRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  for (final raw in rawMatches) {
    final match = _fixtureAsMap(raw);
    final matchDate = DateTime.tryParse(_fixtureText(match['date']));
    if (matchDate == null) continue;
    if (_kboFantasyRoundForMatchDate(matchDate) != leagueRound) continue;
    if (_isKboLiveStatus(_fixtureText(match['status']))) {
      return true;
    }
  }
  return false;
}

class _AnimatedFantasyScoreText extends StatefulWidget {
  final double score;
  final int fractionDigits;
  final TextStyle style;
  final Color baseColor;
  final bool animateChanges;
  final TextAlign textAlign;

  const _AnimatedFantasyScoreText({
    super.key,
    required this.score,
    required this.fractionDigits,
    required this.style,
    required this.baseColor,
    required this.animateChanges,
    this.textAlign = TextAlign.center,
  });

  @override
  State<_AnimatedFantasyScoreText> createState() =>
      _AnimatedFantasyScoreTextState();
}

class _AnimatedFantasyScoreTextState extends State<_AnimatedFantasyScoreText>
    with SingleTickerProviderStateMixin {
  static const _highlightUp = Color(0xFF16A34A);
  static const _highlightDown = Color(0xFFE53935);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
    value: 1,
  );
  int _direction = 0;

  @override
  void didUpdateWidget(covariant _AnimatedFantasyScoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final delta = widget.score - oldWidget.score;
    if (delta.abs() < 0.0001) return;
    if (!widget.animateChanges) {
      _direction = 0;
      _controller.value = 1;
      return;
    }
    _direction = delta > 0 ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.score.toStringAsFixed(widget.fractionDigits);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final pulse = progress < 0.45
            ? Curves.easeOut.transform(progress / 0.45)
            : 1 - Curves.easeOut.transform((progress - 0.45) / 0.55);
        final scale = 1 + (pulse.clamp(0.0, 1.0) * 0.16);
        final highlight = _direction > 0 ? _highlightUp : _highlightDown;
        final color = _direction == 0 || !widget.animateChanges
            ? widget.baseColor
            : Color.lerp(
                highlight,
                widget.baseColor,
                Curves.easeOutCubic.transform(progress),
              )!;
        return Transform.scale(
          scale: scale,
          child: Text(
            label,
            maxLines: 1,
            textAlign: widget.textAlign,
            style: widget.style.copyWith(color: color),
          ),
        );
      },
    );
  }
}

class _AnimatedFantasyScorePair extends StatelessWidget {
  final String scoreIdentity;
  final double homeScore;
  final double awayScore;
  final int fractionDigits;
  final bool animateChanges;
  final TextStyle scoreStyle;
  final TextStyle separatorStyle;
  final Color baseColor;
  final String separator;

  const _AnimatedFantasyScorePair({
    required this.scoreIdentity,
    required this.homeScore,
    required this.awayScore,
    required this.fractionDigits,
    required this.animateChanges,
    required this.scoreStyle,
    required this.separatorStyle,
    required this.baseColor,
    this.separator = ':',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedFantasyScoreText(
          key: ValueKey('$scoreIdentity|home'),
          score: homeScore,
          fractionDigits: fractionDigits,
          style: scoreStyle,
          baseColor: baseColor,
          animateChanges: animateChanges,
          textAlign: TextAlign.right,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            separator,
            style: separatorStyle.copyWith(color: baseColor),
          ),
        ),
        _AnimatedFantasyScoreText(
          key: ValueKey('$scoreIdentity|away'),
          score: awayScore,
          fractionDigits: fractionDigits,
          style: scoreStyle,
          baseColor: baseColor,
          animateChanges: animateChanges,
          textAlign: TextAlign.left,
        ),
      ],
    );
  }
}

DateTime _toKst(DateTime value) => value.toUtc().add(_koreaTimeOffset);
DateTime _toUtcFromKst(DateTime value) => value.subtract(_koreaTimeOffset);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _activeProfileAvatarUid() =>
    FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

String _currentSignedInFantasyDisplayName() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '';
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  final emailPrefix = (user.email ?? '').split('@').first.trim();
  return emailPrefix;
}

String _normalizedFantasyIdentityText(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool _sameFantasyIdentity(String left, String right) {
  final normalizedLeft = _normalizedFantasyIdentityText(left);
  final normalizedRight = _normalizedFantasyIdentityText(right);
  return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
}

String _normalizedFantasyDisplayNameForUid(String uid, String fallback) {
  final normalizedUid = uid.trim();
  final normalizedFallback = fallback.trim();
  final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  if (normalizedUid.isEmpty || normalizedUid != currentUid) {
    return normalizedFallback;
  }
  final preferred = _currentSignedInFantasyDisplayName();
  return preferred.isNotEmpty ? preferred : normalizedFallback;
}

String _profileAvatarPathStorageKeyFor(String uid) =>
    'profile.avatar.path.v1.$uid';

Future<void> _ensureProfileAvatarPathLoaded({String? uid}) {
  final effectiveUid = (uid ?? _activeProfileAvatarUid()).trim();
  if (_profileAvatarPathLoaded && _profileAvatarPathLoadedUid == effectiveUid) {
    return Future<void>.value();
  }
  if (effectiveUid.isEmpty) {
    _profileAvatarPathNotifier.value = null;
    _profileAvatarPathLoaded = true;
    _profileAvatarPathLoadedUid = '';
    return Future<void>.value();
  }
  final inFlight = _profileAvatarPathLoadFuture;
  if (inFlight != null && _profileAvatarPathLoadedUid == effectiveUid) {
    return inFlight;
  }
  final token = ++_profileAvatarPathLoadToken;
  final storageKey = _profileAvatarPathStorageKeyFor(effectiveUid);
  final future = _profileAvatarStorage
      .read(key: storageKey)
      .then((storedPath) async {
        String? resolvedPath = storedPath;
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          final file = File(resolvedPath);
          if (!await file.exists()) {
            resolvedPath = null;
            await _profileAvatarStorage.delete(key: storageKey);
          }
        } else {
          resolvedPath = null;
        }
        if (token != _profileAvatarPathLoadToken) return;
        _profileAvatarPathNotifier.value = resolvedPath;
        _profileAvatarPathLoaded = true;
        _profileAvatarPathLoadedUid = effectiveUid;
      })
      .catchError((_) {
        if (token != _profileAvatarPathLoadToken) return;
        _profileAvatarPathNotifier.value = null;
        _profileAvatarPathLoaded = true;
        _profileAvatarPathLoadedUid = effectiveUid;
      })
      .whenComplete(() {
        if (token == _profileAvatarPathLoadToken) {
          _profileAvatarPathLoadFuture = null;
        }
      });
  _profileAvatarPathLoadFuture = future;
  return future;
}

Future<void> _persistProfileAvatarPath(String? path, {String? uid}) async {
  final effectiveUid = (uid ?? _activeProfileAvatarUid()).trim();
  final normalized = path?.trim() ?? '';
  if (effectiveUid.isEmpty) {
    _profileAvatarPathNotifier.value = null;
    _profileAvatarPathLoaded = true;
    _profileAvatarPathLoadedUid = '';
    return;
  }
  final storageKey = _profileAvatarPathStorageKeyFor(effectiveUid);
  if (normalized.isEmpty) {
    await _profileAvatarStorage.delete(key: storageKey);
    _profileAvatarPathNotifier.value = null;
    _profileAvatarPathLoaded = true;
    _profileAvatarPathLoadedUid = effectiveUid;
    return;
  }
  await _profileAvatarStorage.write(key: storageKey, value: normalized);
  _profileAvatarPathNotifier.value = normalized;
  _profileAvatarPathLoaded = true;
  _profileAvatarPathLoadedUid = effectiveUid;
}

Future<void> _deletePersistedProfileAvatarForUid(String uid) async {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) return;

  final storageKey = _profileAvatarPathStorageKeyFor(normalizedUid);
  try {
    final storedPath = await _profileAvatarStorage.read(key: storageKey);
    final normalizedPath = storedPath?.trim() ?? '';
    if (normalizedPath.isNotEmpty) {
      final file = File(normalizedPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  } catch (_) {
    // Ignore local avatar cleanup failures during account deletion.
  }

  try {
    await _profileAvatarStorage.delete(key: storageKey);
  } catch (_) {
    // Ignore secure storage cleanup failures during account deletion.
  }

  if (_profileAvatarPathLoadedUid == normalizedUid ||
      _activeProfileAvatarUid().isEmpty) {
    _profileAvatarPathNotifier.value = null;
    _profileAvatarPathLoaded = true;
    _profileAvatarPathLoadedUid = '';
  }
}

ValueNotifier<String?> _publicProfileAvatarUrlNotifierFor(String uid) {
  return _publicProfileAvatarUrlNotifiers.putIfAbsent(
    uid,
    () => ValueNotifier<String?>(null),
  );
}

void _cachePublicProfileAvatarUrl(String uid, String? url) {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) return;
  final normalizedUrl = url?.trim() ?? '';
  _publicProfileAvatarUrlNotifierFor(normalizedUid).value =
      normalizedUrl.isEmpty ? null : normalizedUrl;
}

void _clearPublicProfileAvatarUrlCache() {
  for (final notifier in _publicProfileAvatarUrlNotifiers.values) {
    notifier.value = null;
  }
  _publicProfileAvatarUrlLoadFutures.clear();
}

Future<void> _ensurePublicProfileAvatarUrlLoaded(
  String uid, {
  bool force = false,
}) {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) return Future<void>.value();

  final notifier = _publicProfileAvatarUrlNotifierFor(normalizedUid);
  if (!force && (notifier.value?.trim().isNotEmpty ?? false)) {
    return Future<void>.value();
  }

  final inFlight = _publicProfileAvatarUrlLoadFutures[normalizedUid];
  if (!force && inFlight != null) return inFlight;

  final future = FirebaseFirestore.instance
      .collection(kPublicUserProfilesCollection)
      .doc(normalizedUid)
      .get()
      .then((snapshot) async {
        final data = snapshot.data() ?? const <String, dynamic>{};
        var photoUrl = '${data['photoUrl'] ?? ''}'.trim();
        final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
        if (photoUrl.isEmpty && normalizedUid == currentUid) {
          photoUrl = FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
          if (photoUrl.isNotEmpty) {
            unawaited(
              syncCurrentUserPublicProfileFromAuth(
                FirebaseFirestore.instance,
                photoUrlOverride: photoUrl,
              ).catchError((error, stackTrace) {
                debugPrint(
                  'Current user public profile backfill failed '
                  '(uid=$normalizedUid): $error',
                );
                debugPrint('$stackTrace');
              }),
            );
          }
        }
        if (photoUrl.isEmpty && normalizedUid != currentUid) {
          try {
            final profile = await LeagueService.instance.getPublicUserProfile(
              normalizedUid,
            );
            photoUrl = '${profile?['photoUrl'] ?? ''}'.trim();
          } catch (error, stackTrace) {
            debugPrint(
              'Public profile avatar callable fallback failed '
              '(uid=$normalizedUid): $error',
            );
            debugPrint('$stackTrace');
          }
        }
        notifier.value = photoUrl.isEmpty ? null : photoUrl;
      })
      .catchError((error, stackTrace) {
        debugPrint(
          'Public profile avatar load failed (uid=$normalizedUid): $error',
        );
        debugPrint('$stackTrace');
        notifier.value = null;
      })
      .whenComplete(() {
        _publicProfileAvatarUrlLoadFutures.remove(normalizedUid);
      });

  _publicProfileAvatarUrlLoadFutures[normalizedUid] = future;
  return future;
}

String _kstMonthDayTimeLabel(DateTime value) {
  final kst = _toKst(value);
  return '${kst.month}/${kst.day} ${_twoDigits(kst.hour)}:${_twoDigits(kst.minute)}';
}

String _kstDotDateTimeLabel(DateTime value) {
  final kst = _toKst(value);
  return '${kst.year}.${_twoDigits(kst.month)}.${_twoDigits(kst.day)} '
      '${_twoDigits(kst.hour)}:${_twoDigits(kst.minute)}';
}

// ---------------------------------------------------------------------------
// Fantasy league (mock) data used across My League + Matchup details (League).
// Keep this centralized so ranks/standings stay consistent in the UI.
// ---------------------------------------------------------------------------

class _FantasyLeagueStanding {
  final String team;
  final int pts;
  const _FantasyLeagueStanding({required this.team, required this.pts});
}

class _HomeSearchSuggestion {
  final String name;
  final bool isSoccer;
  final _DocPlayerMeta meta;

  const _HomeSearchSuggestion({
    required this.name,
    required this.isSoccer,
    required this.meta,
  });
}

class _JoinedDraft {
  final String leagueId;
  final String leagueName;
  final DateTime when;
  final bool isSoccer;
  final int teamCount;
  final int roundCount;
  final int memberCount;
  final String inviteCode;
  final String ownerId;
  final List<_DraftOrderEntry> draftOrder;
  final bool fantasyReady;
  final List<_FantasyTeamState> fantasyTeams;
  final List<_FantasyScheduleMatchup> fantasySchedule;
  final List<List<_PlayerSlot?>> draftBoard;

  const _JoinedDraft({
    required this.leagueId,
    required this.leagueName,
    required this.when,
    required this.isSoccer,
    this.teamCount = 8,
    this.roundCount = 1,
    this.memberCount = 1,
    this.inviteCode = '',
    this.ownerId = '',
    this.draftOrder = const [],
    this.fantasyReady = false,
    this.fantasyTeams = const [],
    this.fantasySchedule = const [],
    this.draftBoard = const [],
  });

  Map<String, dynamic> toMap() => {
    'leagueId': leagueId,
    'leagueName': leagueName,
    'when': when.toIso8601String(),
    'isSoccer': isSoccer,
    'teamCount': teamCount,
    'roundCount': roundCount,
    'memberCount': memberCount,
    'inviteCode': inviteCode,
    'ownerId': ownerId,
    'draftOrder': draftOrder.map((entry) => entry.toMap()).toList(),
    'fantasyReady': fantasyReady,
    'fantasyTeams': fantasyTeams.map((team) => team.toMap()).toList(),
    'fantasySchedule': fantasySchedule
        .map((matchup) => matchup.toMap())
        .toList(),
    'draftBoard': _draftBoardToFirestoreRows(draftBoard),
  };
}

_JoinedDraft _joinedDraftFromJoinLeagueResponse(
  Map<String, dynamic> data, {
  required String fallbackCode,
}) {
  final draftTime = DateTime.tryParse('${data['draftDateTime'] ?? ''}');
  if (draftTime == null) {
    throw StateError('Draft 정보가 없는 리그입니다.');
  }

  return _JoinedDraft(
    leagueId: '${data['leagueId'] ?? ''}',
    leagueName: '${data['leagueName'] ?? 'My League'}',
    when: draftTime.toLocal(),
    isSoccer: '${data['sport'] ?? 'soccer'}' == 'soccer',
    teamCount: data['teamCount'] is int
        ? data['teamCount'] as int
        : int.tryParse('${data['teamCount'] ?? 8}') ?? 8,
    memberCount: data['memberCount'] is int
        ? data['memberCount'] as int
        : int.tryParse('${data['memberCount'] ?? 1}') ?? 1,
    inviteCode: '${data['inviteCode'] ?? fallbackCode}',
    ownerId: '${data['ownerId'] ?? ''}',
    draftOrder:
        (data['draftOrder'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => _DraftOrderEntry(
                uid: '${item['uid'] ?? ''}',
                displayName: '${item['displayName'] ?? 'Team'}',
                slot: item['slot'] is int
                    ? item['slot'] as int
                    : int.tryParse('${item['slot'] ?? 0}') ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.slot.compareTo(b.slot)),
  );
}

class _DraftOrderEntry {
  final String uid;
  final String displayName;
  final int slot;

  const _DraftOrderEntry({
    required this.uid,
    required this.displayName,
    required this.slot,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'slot': slot,
  };
}

class _FantasyTeamPlayer {
  final String name;
  final String position;
  final int score;
  final String club;
  final int number;
  final String playerId;

  const _FantasyTeamPlayer({
    required this.name,
    required this.position,
    required this.score,
    this.club = '',
    this.number = 0,
    this.playerId = '',
  });

  _PlayerSlot toPlayerSlot() => _PlayerSlot(
    name: name,
    score: score,
    position: position,
    club: club,
    number: number,
    playerId: playerId,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'position': position,
    'score': score,
    'club': club,
    'number': number,
    'playerId': playerId,
  };
}

class _KboFantasyRoundScoreState {
  final int round;
  final double bankedScore;
  final Map<String, double> starterBaselines;
  final DateTime updatedAt;
  final double? unlockedScoreSnapshot;
  final DateTime? unlockedAt;

  const _KboFantasyRoundScoreState({
    required this.round,
    required this.bankedScore,
    required this.starterBaselines,
    required this.updatedAt,
    this.unlockedScoreSnapshot,
    this.unlockedAt,
  });

  Map<String, dynamic> toMap() => {
    'round': round,
    'bankedScore': bankedScore,
    'starterBaselines': starterBaselines,
    'updatedAt': updatedAt.toIso8601String(),
    'unlockedScoreSnapshot': unlockedScoreSnapshot,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };
}

class _FantasyTeamState {
  final String uid;
  final String teamName;
  final List<_FantasyTeamPlayer> roster;
  final List<_FantasyTeamPlayer> starting;
  final List<_FantasyTeamPlayer> bench;
  final String? captainName;
  final String? viceCaptainName;
  final String? captainPlayerId;
  final String? viceCaptainPlayerId;
  final List<_KboFantasyRoundScoreState> kboRoundScoreStates;

  const _FantasyTeamState({
    required this.uid,
    required this.teamName,
    this.roster = const [],
    this.starting = const [],
    this.bench = const [],
    this.captainName,
    this.viceCaptainName,
    this.captainPlayerId,
    this.viceCaptainPlayerId,
    this.kboRoundScoreStates = const [],
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'teamName': teamName,
    'roster': roster.map((player) => player.toMap()).toList(),
    'starting': starting.map((player) => player.toMap()).toList(),
    'bench': bench.map((player) => player.toMap()).toList(),
    'captainName': captainName,
    'viceCaptainName': viceCaptainName,
    'captainPlayerId': captainPlayerId,
    'viceCaptainPlayerId': viceCaptainPlayerId,
    'kboRoundScoreStates': kboRoundScoreStates
        .map((state) => state.toMap())
        .toList(),
  };
}

bool _isBaseballHitterPosition(String position) {
  switch (position.trim().toUpperCase()) {
    case 'C':
    case 'IF':
    case 'OF':
    case 'DH':
      return true;
    default:
      return false;
  }
}

bool _isValidBaseballStartingLineup<T>(
  List<T> starting, {
  required String Function(T player) positionOf,
}) {
  if (starting.length != 10) return false;
  final pitchers = starting.where((p) => positionOf(p) == 'P').length;
  final catchers = starting.where((p) => positionOf(p) == 'C').length;
  final infielders = starting.where((p) => positionOf(p) == 'IF').length;
  final outfielders = starting.where((p) => positionOf(p) == 'OF').length;
  final designatedHitters = starting.where((p) => positionOf(p) == 'DH').length;
  final hitters = catchers + infielders + outfielders + designatedHitters;
  final extraHitters =
      (catchers - 1) + (infielders - 4) + (outfielders - 3) + designatedHitters;
  return pitchers == 1 &&
      catchers >= 1 &&
      infielders >= 4 &&
      outfielders >= 3 &&
      hitters == 9 &&
      extraHitters == 1;
}

List<T> _buildBaseballStartingFromRoster<T>(
  List<T> roster, {
  required String Function(T player) positionOf,
  required int Function(T player) scoreOf,
  required String Function(T player) identityOf,
}) {
  List<T> sortedPlayers(String position) {
    final players = roster.where((p) => positionOf(p) == position).toList();
    players.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    return players;
  }

  final catchers = sortedPlayers('C');
  final pitchers = sortedPlayers('P');
  final infielders = sortedPlayers('IF');
  final outfielders = sortedPlayers('OF');

  final starting = <T>[
    ...catchers.take(1),
    ...pitchers.take(1),
    ...infielders.take(4),
    ...outfielders.take(3),
  ];
  final usedIds = starting.map(identityOf).toSet();
  final dhCandidates =
      roster
          .where(
            (player) =>
                _isBaseballHitterPosition(positionOf(player)) &&
                !usedIds.contains(identityOf(player)),
          )
          .toList()
        ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
  if (dhCandidates.isNotEmpty) {
    starting.add(dhCandidates.first);
  }
  return starting;
}

_FantasyTeamState _normalizeBaseballFantasyTeam(_FantasyTeamState team) {
  if (_isValidBaseballStartingLineup(
    team.starting,
    positionOf: (player) => player.position,
  )) {
    return team;
  }

  final roster = team.roster.isNotEmpty
      ? team.roster
      : [...team.starting, ...team.bench];
  if (roster.isEmpty) return team;

  final starting = _buildBaseballStartingFromRoster(
    roster,
    positionOf: (player) => player.position,
    scoreOf: (player) => player.score,
    identityOf: (player) => _fantasyTeamPlayerIdentity(player),
  );
  if (starting.isEmpty) return team;

  final startingIds = starting.map(_fantasyTeamPlayerIdentity).toSet();
  final bench = roster
      .where(
        (player) => !startingIds.contains(_fantasyTeamPlayerIdentity(player)),
      )
      .toList();
  return _FantasyTeamState(
    uid: team.uid,
    teamName: team.teamName,
    roster: roster,
    starting: starting,
    bench: bench,
    captainName: team.captainName,
    viceCaptainName: team.viceCaptainName,
    captainPlayerId: team.captainPlayerId,
    viceCaptainPlayerId: team.viceCaptainPlayerId,
    kboRoundScoreStates: team.kboRoundScoreStates,
  );
}

class _FantasyTeamBranding {
  final IconData icon;
  final Color tint;
  static const Color defaultIconColor = Color(0xFF1E6B3A);

  const _FantasyTeamBranding({required this.icon, required this.tint});
}

const List<_FantasyTeamBranding> _fantasyTeamBrandings = [
  _FantasyTeamBranding(icon: Icons.shield_outlined, tint: Color(0xFFD7F8E0)),
  _FantasyTeamBranding(
    icon: Icons.workspace_premium_outlined,
    tint: Color(0xFFECFFB8),
  ),
  _FantasyTeamBranding(
    icon: Icons.military_tech_outlined,
    tint: Color(0xFFFFE2BE),
  ),
  _FantasyTeamBranding(
    icon: Icons.flag_circle_outlined,
    tint: Color(0xFFDDEBFF),
  ),
  _FantasyTeamBranding(icon: Icons.stars_outlined, tint: Color(0xFFF7DDF7)),
  _FantasyTeamBranding(
    icon: Icons.emoji_events_outlined,
    tint: Color(0xFFFFF0C4),
  ),
  _FantasyTeamBranding(
    icon: Icons.health_and_safety_outlined,
    tint: Color(0xFFE3F4FF),
  ),
  _FantasyTeamBranding(icon: Icons.verified_outlined, tint: Color(0xFFE4F7CF)),
];

int _stableSeedForBrand(String key) {
  var hash = 0;
  for (final c in key.codeUnits) {
    hash = 0x1fffffff & (hash + c);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= (hash >> 6);
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= (hash >> 11);
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash & 0x7fffffff;
}

_FantasyTeamBranding _fantasyTeamBrandingFor({
  required String uid,
  required String teamName,
}) {
  final seedKey = uid.isNotEmpty ? '$uid|$teamName' : teamName;
  final index = _stableSeedForBrand(seedKey) % _fantasyTeamBrandings.length;
  return _fantasyTeamBrandings[index];
}

class _FantasyTeamAvatar extends StatelessWidget {
  final String uid;
  final String teamName;
  final double size;
  final double iconSize;

  const _FantasyTeamAvatar({
    required this.uid,
    required this.teamName,
    required this.size,
    required this.iconSize,
  });

  bool get _isCurrentUsersTeam {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return currentUid.isNotEmpty && uid.trim() == currentUid;
  }

  @override
  Widget build(BuildContext context) {
    final branding = _fantasyTeamBrandingFor(uid: uid, teamName: teamName);
    unawaited(_ensureProfileAvatarPathLoaded());
    if (uid.trim().isNotEmpty) {
      unawaited(_ensurePublicProfileAvatarUrlLoaded(uid));
    }

    Widget fallbackAvatar() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: branding.tint,
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(
          branding.icon,
          size: iconSize,
          color: _FantasyTeamBranding.defaultIconColor,
        ),
      );
    }

    Widget publicAvatar(String? photoUrl) {
      final normalizedUrl = photoUrl?.trim() ?? '';
      if (normalizedUrl.isEmpty) {
        return fallbackAvatar();
      }
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          normalizedUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              'Fantasy avatar network load failed '
              '(uid=$uid, url=$normalizedUrl): $error',
            );
            if (stackTrace != null) {
              debugPrint('$stackTrace');
            }
            return fallbackAvatar();
          },
        ),
      );
    }

    if (!_isCurrentUsersTeam) {
      return ValueListenableBuilder<String?>(
        valueListenable: _publicProfileAvatarUrlNotifierFor(uid.trim()),
        builder: (context, photoUrl, _) => publicAvatar(photoUrl),
      );
    }

    return ValueListenableBuilder<String?>(
      valueListenable: _profileAvatarPathNotifier,
      builder: (context, avatarPath, _) {
        final normalizedPath = avatarPath?.trim() ?? '';
        if (normalizedPath.isEmpty) {
          final currentPhotoUrl =
              FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
          if (currentPhotoUrl.isNotEmpty) {
            return publicAvatar(currentPhotoUrl);
          }
          return ValueListenableBuilder<String?>(
            valueListenable: _publicProfileAvatarUrlNotifierFor(uid.trim()),
            builder: (context, photoUrl, _) => publicAvatar(photoUrl),
          );
        }
        final avatarFile = File(normalizedPath);
        if (!avatarFile.existsSync()) {
          final currentPhotoUrl =
              FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
          if (currentPhotoUrl.isNotEmpty) {
            return publicAvatar(currentPhotoUrl);
          }
          return ValueListenableBuilder<String?>(
            valueListenable: _publicProfileAvatarUrlNotifierFor(uid.trim()),
            builder: (context, photoUrl, _) => publicAvatar(photoUrl),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(avatarFile, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _FantasyScheduleMatchup {
  final int round;
  final String homeUid;
  final String homeTeam;
  final String awayUid;
  final String awayTeam;

  const _FantasyScheduleMatchup({
    required this.round,
    required this.homeUid,
    required this.homeTeam,
    required this.awayUid,
    required this.awayTeam,
  });

  Map<String, dynamic> toMap() => {
    'round': round,
    'homeUid': homeUid,
    'homeTeam': homeTeam,
    'awayUid': awayUid,
    'awayTeam': awayTeam,
  };
}

_JoinedDraft _joinedDraftWithRenamedFantasyIdentity(
  _JoinedDraft draft, {
  required String uid,
  required String teamName,
}) {
  final normalizedUid = uid.trim();
  final normalizedTeamName = teamName.trim();
  if (normalizedUid.isEmpty || normalizedTeamName.isEmpty) {
    return draft;
  }

  var changed = false;
  final updatedDraftOrder = draft.draftOrder.map((entry) {
    if (entry.uid != normalizedUid || entry.displayName == normalizedTeamName) {
      return entry;
    }
    changed = true;
    return _DraftOrderEntry(
      uid: entry.uid,
      displayName: normalizedTeamName,
      slot: entry.slot,
    );
  }).toList();

  final updatedFantasyTeams = draft.fantasyTeams.map((team) {
    if (team.uid != normalizedUid || team.teamName == normalizedTeamName) {
      return team;
    }
    changed = true;
    return _FantasyTeamState(
      uid: team.uid,
      teamName: normalizedTeamName,
      roster: team.roster,
      starting: team.starting,
      bench: team.bench,
      captainName: team.captainName,
      viceCaptainName: team.viceCaptainName,
      captainPlayerId: team.captainPlayerId,
      viceCaptainPlayerId: team.viceCaptainPlayerId,
      kboRoundScoreStates: team.kboRoundScoreStates,
    );
  }).toList();

  final updatedFantasySchedule = draft.fantasySchedule.map((matchup) {
    final homeChanged =
        matchup.homeUid == normalizedUid &&
        matchup.homeTeam != normalizedTeamName;
    final awayChanged =
        matchup.awayUid == normalizedUid &&
        matchup.awayTeam != normalizedTeamName;
    if (!homeChanged && !awayChanged) return matchup;
    changed = true;
    return _FantasyScheduleMatchup(
      round: matchup.round,
      homeUid: matchup.homeUid,
      homeTeam: homeChanged ? normalizedTeamName : matchup.homeTeam,
      awayUid: matchup.awayUid,
      awayTeam: awayChanged ? normalizedTeamName : matchup.awayTeam,
    );
  }).toList();

  if (!changed) return draft;

  return _JoinedDraft(
    leagueId: draft.leagueId,
    leagueName: draft.leagueName,
    when: draft.when,
    isSoccer: draft.isSoccer,
    teamCount: draft.teamCount,
    roundCount: draft.roundCount,
    memberCount: draft.memberCount,
    inviteCode: draft.inviteCode,
    ownerId: draft.ownerId,
    draftOrder: updatedDraftOrder,
    fantasyReady: draft.fantasyReady,
    fantasyTeams: updatedFantasyTeams,
    fantasySchedule: updatedFantasySchedule,
    draftBoard: draft.draftBoard,
  );
}

class _FantasyMatchupView {
  final _JoinedDraft draft;
  final int round;
  final _FantasyScheduleMatchup matchup;
  final _FantasyTeamState myTeam;
  final _FantasyTeamState opponent;
  final bool scoresReady;
  final double myScore;
  final double opponentScore;

  const _FantasyMatchupView({
    required this.draft,
    required this.round,
    required this.matchup,
    required this.myTeam,
    required this.opponent,
    required this.scoresReady,
    required this.myScore,
    required this.opponentScore,
  });
}

const Duration _draftPickDuration = Duration(seconds: 90);
const Duration _draftRetentionWindow = Duration(hours: 24);

int _draftRoundsForSport(bool isSoccer) => isSoccer ? 18 : 21;

Duration _draftTotalDuration({required bool isSoccer, required int teamCount}) {
  final safeTeamCount = teamCount <= 0 ? 8 : teamCount;
  return Duration(
    seconds:
        _draftPickDuration.inSeconds *
        _draftRoundsForSport(isSoccer) *
        safeTeamCount,
  );
}

DateTime _draftEndsAt(_JoinedDraft draft) {
  return draft.when.add(
    _draftTotalDuration(isSoccer: draft.isSoccer, teamCount: draft.teamCount),
  );
}

bool _isDraftCompletedAt(_JoinedDraft draft, DateTime now) {
  return !now.isBefore(_draftEndsAt(draft));
}

bool _isDraftExpiredAt(_JoinedDraft draft, DateTime now) {
  return !now.isBefore(draft.when.add(_draftRetentionWindow));
}

bool _isUnfilledDraftCanceledAt(_JoinedDraft draft, DateTime now) {
  if (draft.fantasyReady) return false;
  if (draft.teamCount <= 0) return false;
  if (draft.memberCount >= draft.teamCount) return false;
  return !now.isBefore(draft.when);
}

Duration _fantasyRoundInterval(bool isSoccer) =>
    isSoccer ? const Duration(days: 7) : const Duration(days: 1);

class _KboFantasyRoundWindow {
  final int round;
  final DateTime startKst;
  final DateTime endKst;

  const _KboFantasyRoundWindow({
    required this.round,
    required this.startKst,
    required this.endKst,
  });
}

const int _kboFantasyTotalRounds2026 = 24;

final List<_KboFantasyRoundWindow> _kboFantasyRoundWindows2026 =
    <_KboFantasyRoundWindow>[
      _KboFantasyRoundWindow(
        round: 1,
        startKst: DateTime(2026, 3, 28),
        endKst: DateTime(2026, 3, 29),
      ),
      _KboFantasyRoundWindow(
        round: 2,
        startKst: DateTime(2026, 3, 31),
        endKst: DateTime(2026, 4, 5),
      ),
      _KboFantasyRoundWindow(
        round: 3,
        startKst: DateTime(2026, 4, 7),
        endKst: DateTime(2026, 4, 12),
      ),
      _KboFantasyRoundWindow(
        round: 4,
        startKst: DateTime(2026, 4, 14),
        endKst: DateTime(2026, 4, 19),
      ),
      _KboFantasyRoundWindow(
        round: 5,
        startKst: DateTime(2026, 4, 21),
        endKst: DateTime(2026, 4, 26),
      ),
      _KboFantasyRoundWindow(
        round: 6,
        startKst: DateTime(2026, 4, 28),
        endKst: DateTime(2026, 5, 3),
      ),
      _KboFantasyRoundWindow(
        round: 7,
        startKst: DateTime(2026, 5, 5),
        endKst: DateTime(2026, 5, 10),
      ),
      _KboFantasyRoundWindow(
        round: 8,
        startKst: DateTime(2026, 5, 12),
        endKst: DateTime(2026, 5, 17),
      ),
      _KboFantasyRoundWindow(
        round: 9,
        startKst: DateTime(2026, 5, 19),
        endKst: DateTime(2026, 5, 24),
      ),
      _KboFantasyRoundWindow(
        round: 10,
        startKst: DateTime(2026, 5, 26),
        endKst: DateTime(2026, 5, 31),
      ),
      _KboFantasyRoundWindow(
        round: 11,
        startKst: DateTime(2026, 6, 2),
        endKst: DateTime(2026, 6, 7),
      ),
      _KboFantasyRoundWindow(
        round: 12,
        startKst: DateTime(2026, 6, 9),
        endKst: DateTime(2026, 6, 14),
      ),
      _KboFantasyRoundWindow(
        round: 13,
        startKst: DateTime(2026, 6, 16),
        endKst: DateTime(2026, 6, 21),
      ),
      _KboFantasyRoundWindow(
        round: 14,
        startKst: DateTime(2026, 6, 23),
        endKst: DateTime(2026, 6, 28),
      ),
      _KboFantasyRoundWindow(
        round: 15,
        startKst: DateTime(2026, 6, 30),
        endKst: DateTime(2026, 7, 5),
      ),
      _KboFantasyRoundWindow(
        round: 16,
        startKst: DateTime(2026, 7, 7),
        endKst: DateTime(2026, 7, 9),
      ),
      _KboFantasyRoundWindow(
        round: 17,
        startKst: DateTime(2026, 7, 16),
        endKst: DateTime(2026, 7, 19),
      ),
      _KboFantasyRoundWindow(
        round: 18,
        startKst: DateTime(2026, 7, 21),
        endKst: DateTime(2026, 7, 26),
      ),
      _KboFantasyRoundWindow(
        round: 19,
        startKst: DateTime(2026, 7, 28),
        endKst: DateTime(2026, 8, 2),
      ),
      _KboFantasyRoundWindow(
        round: 20,
        startKst: DateTime(2026, 8, 4),
        endKst: DateTime(2026, 8, 9),
      ),
      _KboFantasyRoundWindow(
        round: 21,
        startKst: DateTime(2026, 8, 11),
        endKst: DateTime(2026, 8, 16),
      ),
      _KboFantasyRoundWindow(
        round: 22,
        startKst: DateTime(2026, 8, 18),
        endKst: DateTime(2026, 8, 23),
      ),
      _KboFantasyRoundWindow(
        round: 23,
        startKst: DateTime(2026, 8, 25),
        endKst: DateTime(2026, 8, 30),
      ),
      _KboFantasyRoundWindow(
        round: 24,
        startKst: DateTime(2026, 9, 1),
        endKst: DateTime(2026, 9, 6),
      ),
    ];

DateTime _kstDayOnly(DateTime value) {
  final kst = _toKst(value);
  return DateTime(kst.year, kst.month, kst.day);
}

bool _kboFantasyRoundContainsDay(DateTime day, _KboFantasyRoundWindow window) {
  return !day.isBefore(window.startKst) && !day.isAfter(window.endKst);
}

int _anchorKboRoundForDraft(DateTime? draftAt) {
  final windows = _kboFantasyRoundWindows2026;
  if (windows.isEmpty || draftAt == null) return 1;

  final draftDay = _kstDayOnly(draftAt);
  if (draftDay.isBefore(windows.first.startKst)) return windows.first.round;

  for (final window in windows) {
    if (draftDay.isBefore(window.startKst)) {
      return window.round;
    }
    if (_kboFantasyRoundContainsDay(draftDay, window)) {
      return min(_kboFantasyTotalRounds2026, window.round + 1);
    }
  }

  return windows.last.round;
}

int _currentKboRoundAt(DateTime now) {
  final windows = _kboFantasyRoundWindows2026;
  if (windows.isEmpty) return 1;

  final nowDay = _kstDayOnly(now);
  if (nowDay.isBefore(windows.first.startKst)) return windows.first.round;

  var currentRound = windows.first.round;
  for (final window in windows) {
    if (nowDay.isBefore(window.startKst)) return currentRound;
    if (_kboFantasyRoundContainsDay(nowDay, window)) return window.round;
    currentRound = window.round;
  }

  return windows.last.round;
}

int _kboFantasyRoundCountForDraft(DateTime? draftAt) {
  final anchorRound = _anchorKboRoundForDraft(draftAt);
  return max(1, _kboFantasyTotalRounds2026 - anchorRound + 1);
}

int _mappedKboRoundForFantasyRound(_JoinedDraft draft, int fantasyRound) {
  final anchorRound = _anchorKboRoundForDraft(draft.when);
  return (anchorRound + fantasyRound - 1).clamp(1, _kboFantasyTotalRounds2026);
}

bool _kboFantasyRoundHasStarted(
  _JoinedDraft draft,
  int fantasyRound,
  DateTime now,
) {
  if (draft.isSoccer || fantasyRound <= 0) return false;
  final mappedRound = _mappedKboRoundForFantasyRound(draft, fantasyRound);
  final window = _kboFantasyRoundWindows2026
      .cast<_KboFantasyRoundWindow?>()
      .firstWhere((entry) => entry?.round == mappedRound, orElse: () => null);
  if (window == null) return false;
  final nowDay = _kstDayOnly(now);
  return !nowDay.isBefore(window.startKst);
}

int _defaultFantasyRoundCount({required bool isSoccer, DateTime? draftAt}) {
  if (isSoccer) {
    final cachedLeagueData = _cachedKLeagueLeagueData;
    final rawFixtures = _fixtureAsList(cachedLeagueData?['fixtures']);
    if (rawFixtures.isNotEmpty) {
      return _kLeagueFantasyRoundCountForDraft(draftAt, rawFixtures);
    }
    return _kLeagueFantasyTotalRounds2026;
  }
  return _kboFantasyRoundCountForDraft(draftAt);
}

int _currentFantasyRoundAt(_JoinedDraft draft, DateTime now) {
  final roundCount = max(1, draft.roundCount);
  if (now.isBefore(draft.when)) return 1;
  if (draft.isSoccer) {
    final cachedLeagueData = _cachedKLeagueLeagueData;
    if (cachedLeagueData != null) {
      final rawFixtures = _fixtureAsList(cachedLeagueData['fixtures']);
      final windows = _kLeagueRoundWindowsFromFixtures(rawFixtures);
      if (windows.isNotEmpty) {
        final anchorRound = _anchorKLeagueRoundForDraft(draft.when, windows);
        final currentRound = min(
          _currentKLeagueRoundAt(now, windows),
          _kLeagueFantasyMaxRound(windows),
        );
        final mappedRound = currentRound - anchorRound + 1;
        return mappedRound.clamp(1, roundCount);
      }
    }
  } else {
    final anchorRound = _anchorKboRoundForDraft(draft.when);
    final currentRound = _currentKboRoundAt(now);
    final mappedRound = currentRound - anchorRound + 1;
    return mappedRound.clamp(1, roundCount);
  }
  final interval = _fantasyRoundInterval(draft.isSoccer);
  final elapsed = now.difference(draft.when);
  final round = (elapsed.inSeconds ~/ interval.inSeconds) + 1;
  return round.clamp(1, roundCount);
}

class _KLeagueRoundWindow {
  final int round;
  final DateTime startUtc;
  final DateTime endUtc;

  const _KLeagueRoundWindow({
    required this.round,
    required this.startUtc,
    required this.endUtc,
  });
}

const int _kLeagueFantasyTotalRounds2026 = 33;
const Duration _kLeagueRoundAdvanceDelay = Duration(hours: 12);
const Duration _kLeagueFixtureDurationEstimate = Duration(hours: 2);

DateTime? _kLeagueFixtureEstimatedEndUtc(Map<String, dynamic> fixtureMap) {
  final fixture = _fixtureAsMap(fixtureMap['fixture']);
  final kickoff = DateTime.tryParse(_fixtureText(fixture['date']))?.toUtc();
  if (kickoff == null) return null;
  final status = _fixtureAsMap(fixture['status']);
  final elapsed = _readNullableInt(status['elapsed']) ?? 0;
  final estimatedMinutes = elapsed > 0
      ? max(120, elapsed)
      : _kLeagueFixtureDurationEstimate.inMinutes;
  return kickoff.add(Duration(minutes: estimatedMinutes));
}

DateTime _kLeagueRoundAdvanceUtc(_KLeagueRoundWindow window) =>
    window.endUtc.add(_kLeagueRoundAdvanceDelay);

List<_KLeagueRoundWindow> _kLeagueRoundWindowsFromFixtures(
  List<dynamic> rawFixtures,
) {
  final byRound = <int, ({DateTime startUtc, DateTime endUtc})>{};
  for (final raw in rawFixtures) {
    final map = _fixtureAsMap(raw);
    final league = _fixtureAsMap(map['league']);
    final round = _roundNumber(_fixtureText(league['round']));
    if (round <= 0) continue;
    final fixture = _fixtureAsMap(map['fixture']);
    final kickoff = DateTime.tryParse(_fixtureText(fixture['date']))?.toUtc();
    final estimatedEnd = _kLeagueFixtureEstimatedEndUtc(map);
    if (kickoff == null || estimatedEnd == null) continue;
    final existing = byRound[round];
    if (existing == null) {
      byRound[round] = (startUtc: kickoff, endUtc: estimatedEnd);
      continue;
    }
    byRound[round] = (
      startUtc: kickoff.isBefore(existing.startUtc)
          ? kickoff
          : existing.startUtc,
      endUtc: estimatedEnd.isAfter(existing.endUtc)
          ? estimatedEnd
          : existing.endUtc,
    );
  }

  final windows =
      byRound.entries
          .map(
            (entry) => _KLeagueRoundWindow(
              round: entry.key,
              startUtc: entry.value.startUtc,
              endUtc: entry.value.endUtc,
            ),
          )
          .toList()
        ..sort((a, b) => a.round.compareTo(b.round));
  return windows;
}

int _kLeagueFantasyMaxRound(List<_KLeagueRoundWindow> windows) {
  if (windows.isEmpty) return _kLeagueFantasyTotalRounds2026;
  return min(_kLeagueFantasyTotalRounds2026, windows.last.round);
}

bool _kLeagueRoundContainsInstant(
  DateTime instantUtc,
  _KLeagueRoundWindow window,
) {
  return !instantUtc.isBefore(window.startUtc) &&
      !instantUtc.isAfter(window.endUtc);
}

int _anchorKLeagueRoundForDraft(
  DateTime? draftAt,
  List<_KLeagueRoundWindow> windows,
) {
  if (windows.isEmpty || draftAt == null) return 1;
  final fantasyMaxRound = _kLeagueFantasyMaxRound(windows);
  final fantasyWindows = windows
      .where((window) => window.round <= fantasyMaxRound)
      .toList();
  if (fantasyWindows.isEmpty) return 1;

  final draftUtc = draftAt.toUtc();
  if (draftUtc.isBefore(fantasyWindows.first.startUtc)) {
    return fantasyWindows.first.round;
  }

  for (final window in fantasyWindows) {
    if (draftUtc.isBefore(window.startUtc)) {
      return window.round;
    }
    if (_kLeagueRoundContainsInstant(draftUtc, window)) {
      return min(fantasyMaxRound, window.round + 1);
    }
  }

  return fantasyWindows.last.round;
}

int _kLeagueFantasyRoundCountForDraft(
  DateTime? draftAt,
  List<dynamic> rawFixtures,
) {
  final windows = _kLeagueRoundWindowsFromFixtures(rawFixtures);
  final fantasyMaxRound = _kLeagueFantasyMaxRound(windows);
  final anchorRound = _anchorKLeagueRoundForDraft(draftAt, windows);
  return max(1, fantasyMaxRound - anchorRound + 1);
}

int _currentKLeagueRoundAt(DateTime now, List<_KLeagueRoundWindow> windows) {
  if (windows.isEmpty) return 1;
  final nowUtc = now.toUtc();
  if (nowUtc.isBefore(windows.first.startUtc)) return windows.first.round;
  for (final window in windows) {
    if (!nowUtc.isAfter(_kLeagueRoundAdvanceUtc(window))) {
      return window.round;
    }
  }
  return windows.last.round;
}

int _mappedKLeagueRoundForFantasyRound(
  _JoinedDraft draft,
  int fantasyRound,
  List<dynamic> rawFixtures,
) {
  final windows = _kLeagueRoundWindowsFromFixtures(rawFixtures);
  if (windows.isEmpty) return max(1, fantasyRound);
  final anchorRound = _anchorKLeagueRoundForDraft(draft.when, windows);
  final fantasyMaxRound = _kLeagueFantasyMaxRound(windows);
  final mappedRound = anchorRound + fantasyRound - 1;
  return mappedRound.clamp(windows.first.round, fantasyMaxRound);
}

const Duration _fantasySoccerScoreCacheTtl = Duration(seconds: 20);

class _FantasySoccerRoundScoreSnapshot {
  final String leagueId;
  final int round;
  final DateTime generatedAt;
  final bool finalized;
  final Map<String, double> basePlayerScores;
  final Map<String, double> displayedPlayerScores;
  final Map<String, double> teamScores;
  final Map<String, String?> captainNames;
  final Map<String, String?> viceCaptainNames;
  final Map<String, String?> captainPlayerIds;
  final Map<String, String?> viceCaptainPlayerIds;

  const _FantasySoccerRoundScoreSnapshot({
    required this.leagueId,
    required this.round,
    required this.generatedAt,
    required this.finalized,
    required this.basePlayerScores,
    required this.displayedPlayerScores,
    required this.teamScores,
    required this.captainNames,
    required this.viceCaptainNames,
    required this.captainPlayerIds,
    required this.viceCaptainPlayerIds,
  });
}

final Map<String, _FantasySoccerRoundScoreSnapshot>
_fantasySoccerRoundScoreCache = <String, _FantasySoccerRoundScoreSnapshot>{};
final Map<String, Future<_FantasySoccerRoundScoreSnapshot>>
_fantasySoccerRoundScoreInFlight =
    <String, Future<_FantasySoccerRoundScoreSnapshot>>{};
const FlutterSecureStorage _fantasySoccerRoundScoreStorage =
    FlutterSecureStorage(
      iOptions: IOSOptions(accountName: 'leagueit_local_state'),
    );
const String _fantasySoccerRoundScoreStorageKey =
    'fantasy_soccer_round_scores.v1';
const int _fantasySoccerRoundScoreStorageMaxEntries = 48;
Future<void>? _fantasySoccerRoundScoreRestoreFuture;

Map<String, dynamic> _fantasySoccerRoundScoreSnapshotToJson(
  _FantasySoccerRoundScoreSnapshot snapshot,
) => <String, dynamic>{
  'leagueId': snapshot.leagueId,
  'round': snapshot.round,
  'generatedAt': snapshot.generatedAt.toIso8601String(),
  'finalized': snapshot.finalized,
  'basePlayerScores': snapshot.basePlayerScores,
  'displayedPlayerScores': snapshot.displayedPlayerScores,
  'teamScores': snapshot.teamScores,
  'captainNames': snapshot.captainNames,
  'viceCaptainNames': snapshot.viceCaptainNames,
  'captainPlayerIds': snapshot.captainPlayerIds,
  'viceCaptainPlayerIds': snapshot.viceCaptainPlayerIds,
};

Map<String, double> _fantasySoccerDoubleMapFromJson(dynamic raw) {
  final source = _fixtureAsMap(raw);
  final result = <String, double>{};
  for (final entry in source.entries) {
    final value = (entry.value as num?)?.toDouble();
    if (value == null) continue;
    result[entry.key] = value;
  }
  return result;
}

Map<String, String?> _fantasySoccerNullableStringMapFromJson(dynamic raw) {
  final source = _fixtureAsMap(raw);
  final result = <String, String?>{};
  for (final entry in source.entries) {
    final value = '${entry.value ?? ''}'.trim();
    result[entry.key] = value.isEmpty ? null : value;
  }
  return result;
}

_FantasySoccerRoundScoreSnapshot? _fantasySoccerRoundScoreSnapshotFromJson(
  dynamic raw,
) {
  final json = _fixtureAsMap(raw);
  final leagueId = '${json['leagueId'] ?? ''}'.trim();
  final round = _readNullableInt(json['round']) ?? 0;
  final generatedAt = DateTime.tryParse('${json['generatedAt'] ?? ''}');
  if (leagueId.isEmpty || round <= 0 || generatedAt == null) return null;
  return _FantasySoccerRoundScoreSnapshot(
    leagueId: leagueId,
    round: round,
    generatedAt: generatedAt,
    finalized: json['finalized'] == true,
    basePlayerScores: _fantasySoccerDoubleMapFromJson(json['basePlayerScores']),
    displayedPlayerScores: _fantasySoccerDoubleMapFromJson(
      json['displayedPlayerScores'],
    ),
    teamScores: _fantasySoccerDoubleMapFromJson(json['teamScores']),
    captainNames: _fantasySoccerNullableStringMapFromJson(json['captainNames']),
    viceCaptainNames: _fantasySoccerNullableStringMapFromJson(
      json['viceCaptainNames'],
    ),
    captainPlayerIds: _fantasySoccerNullableStringMapFromJson(
      json['captainPlayerIds'],
    ),
    viceCaptainPlayerIds: _fantasySoccerNullableStringMapFromJson(
      json['viceCaptainPlayerIds'],
    ),
  );
}

Future<void> _restorePersistedFantasySoccerRoundScoreCache() {
  final inFlight = _fantasySoccerRoundScoreRestoreFuture;
  if (inFlight != null) return inFlight;
  final future =
      () async {
        try {
          final raw = await _readLocalStateCacheWithLegacySecureStorage(
            key: _fantasySoccerRoundScoreStorageKey,
            legacyStorage: _fantasySoccerRoundScoreStorage,
          );
          if (raw == null || raw.trim().isEmpty) return;
          final decoded = jsonDecode(raw);
          final entries = _fixtureAsMap(_fixtureAsMap(decoded)['entries']);
          for (final entry in entries.entries) {
            final snapshot = _fantasySoccerRoundScoreSnapshotFromJson(
              entry.value,
            );
            if (snapshot == null) continue;
            _fantasySoccerRoundScoreCache[entry.key] = snapshot;
          }
        } catch (error, stackTrace) {
          debugPrint(
            'restorePersistedFantasySoccerRoundScoreCache failed: $error',
          );
          debugPrint('$stackTrace');
        }
      }().whenComplete(() {
        _fantasySoccerRoundScoreRestoreFuture = null;
      });
  _fantasySoccerRoundScoreRestoreFuture = future;
  return future;
}

Future<void> _persistFantasySoccerRoundScoreCache() async {
  try {
    final entries = _fantasySoccerRoundScoreCache.entries.toList()
      ..sort((a, b) => b.value.generatedAt.compareTo(a.value.generatedAt));
    final payload = <String, dynamic>{
      'entries': <String, dynamic>{
        for (final entry in entries.take(
          _fantasySoccerRoundScoreStorageMaxEntries,
        ))
          entry.key: _fantasySoccerRoundScoreSnapshotToJson(entry.value),
      },
    };
    await _writeLocalStateCache(
      _fantasySoccerRoundScoreStorageKey,
      jsonEncode(payload),
    );
  } catch (error, stackTrace) {
    debugPrint('persistFantasySoccerRoundScoreCache failed: $error');
    debugPrint('$stackTrace');
  }
}

String _fantasyTeamIdentity({required String uid, required String teamName}) =>
    uid.trim().isNotEmpty ? uid.trim() : teamName.trim();

String _fantasyPlayerIdentity({
  required String name,
  String club = '',
  int number = 0,
  String playerId = '',
}) {
  final explicit = playerId.trim();
  if (explicit.isNotEmpty) return explicit;
  final canonicalClub = _canonicalKLeagueClub(_kLeagueDisplayTeamName(club));
  if (canonicalClub.isNotEmpty && number > 0) {
    return '$canonicalClub|$number|${name.trim()}';
  }
  return name.trim();
}

String _playerSlotIdentity(_PlayerSlot slot) => _fantasyPlayerIdentity(
  name: slot.name,
  club: slot.club,
  number: slot.number,
  playerId: slot.playerId,
);

String _fantasyTeamPlayerIdentity(_FantasyTeamPlayer player) =>
    _fantasyPlayerIdentity(
      name: player.name,
      club: player.club,
      number: player.number,
      playerId: player.playerId,
    );

String _fantasySoccerPlayerCacheKey({
  required String teamUid,
  required String teamName,
  required String playerName,
  String playerId = '',
}) =>
    '${_fantasyTeamIdentity(uid: teamUid, teamName: teamName)}|'
    '${_fantasyPlayerIdentity(name: playerName, playerId: playerId)}';

String _fantasySoccerRoundCacheKey(_JoinedDraft draft, int round) =>
    '${draft.leagueId}|$round';

String _normalizeFantasySoccerPosition(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'GK':
    case 'G':
      return 'GK';
    case 'DF':
    case 'D':
      return 'DF';
    case 'MF':
    case 'M':
      return 'MF';
    case 'FW':
    case 'F':
      return 'FW';
    default:
      return '';
  }
}

bool _isKLeagueFinalStatus(String short) {
  switch (short.trim().toUpperCase()) {
    case 'FT':
    case 'AET':
    case 'PEN':
      return true;
    default:
      return false;
  }
}

double _kLeagueGoalPoints(String position) {
  switch (position) {
    case 'GK':
      return 10;
    case 'DF':
      return 7;
    case 'MF':
      return 6;
    case 'FW':
      return 5;
    default:
      return 0;
  }
}

double _kLeagueAssistPoints(String position) {
  switch (position) {
    case 'GK':
      return 5;
    case 'DF':
    case 'MF':
    case 'FW':
      return 3;
    default:
      return 0;
  }
}

double _kLeagueCleanSheetPoints(String position) {
  switch (position) {
    case 'GK':
    case 'DF':
      return 3;
    default:
      return 0;
  }
}

Map<String, String> _kLeagueLineupClubLookup(List<dynamic> lineups) {
  final lookup = <String, String>{};
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    if (club.isEmpty) continue;
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      if (player.id.isNotEmpty) lookup[player.id] = club;
      lookup[player.originalName] = club;
      lookup[player.name] = club;
    }
  }
  return lookup;
}

Map<String, int> _kLeagueOwnGoalCounts(
  List<dynamic> events,
  Map<String, String> playerNames,
  Map<String, String> clubLookup,
) {
  final counts = <String, int>{};
  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    if (_fixtureText(event['type']) != 'Goal') continue;
    if (_fixtureText(event['detail']) != 'Own Goal') continue;
    final player = _fixtureAsMap(event['player']);
    final displayName = _eventPlayerDisplayName(player, playerNames);
    if (displayName.isEmpty) continue;
    final playerId = _fixtureText(player['id']);
    final directClub = clubLookup[playerId];
    final club = (directClub != null && directClub.trim().isNotEmpty)
        ? directClub
        : (clubLookup[displayName] ?? '');
    if (club.isEmpty) continue;
    final key = '$club|$displayName';
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

int _kLeagueEventMinuteValue(Map<String, dynamic> time) {
  final elapsed = _readNullableInt(time['elapsed']) ?? 0;
  final extra = _readNullableInt(time['extra']) ?? 0;
  return min(90, elapsed + extra);
}

int _kLeagueFixtureTotalMinutes(
  Map<String, dynamic> fixtureMeta,
  List<dynamic> events,
) {
  final status = _fixtureAsMap(fixtureMeta['status']);
  final elapsed = _readNullableInt(status['elapsed']) ?? 0;
  var total = max(90, min(90, elapsed));
  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    total = max(total, _kLeagueEventMinuteValue(_fixtureAsMap(event['time'])));
  }
  return min(90, max(90, total));
}

Map<String, String> _kLeagueLineupPositionLookup(List<dynamic> lineups) {
  final lookup = <String, String>{};
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      final normalized = _normalizeFantasySoccerPosition(player.position);
      if (normalized.isEmpty) continue;
      if (player.id.isNotEmpty) lookup[player.id] = normalized;
      lookup[player.originalName] = normalized;
      lookup[player.name] = normalized;
    }
  }
  return lookup;
}

String _kLeagueEventPlayerPosition(
  Map<String, dynamic> player,
  Map<String, String> playerNames,
  Map<String, String> positionLookup,
) {
  final id = _fixtureText(player['id']);
  if (id.isNotEmpty && positionLookup[id] != null) return positionLookup[id]!;
  final displayName = _eventPlayerDisplayName(player, playerNames);
  if (displayName.isNotEmpty && positionLookup[displayName] != null) {
    return positionLookup[displayName]!;
  }
  final originalName = _fixtureText(player['name']);
  return positionLookup[originalName] ?? '';
}

String _kLeagueRosterNameForClubNumber(String club, String number) {
  final jersey = int.tryParse(number.trim());
  if (jersey == null) return '';
  final canonicalClub = _canonicalKLeagueClub(club);
  for (final entry in _docRosterEntries) {
    if (entry.meta.number != jersey) continue;
    if (_canonicalKLeagueClub(entry.meta.club) == canonicalClub) {
      return entry.name;
    }
  }
  return '';
}

String _kLeagueScoreLookupKeyFromDetail(
  Map<String, dynamic> detail, {
  required String playerName,
  required String canonicalClub,
  required String number,
  Map<String, double>? scores,
}) {
  final lookup = scores ?? _kLeagueFantasyBaseScoresFromDetail(detail);
  final directKey = '$canonicalClub|$playerName';
  if (lookup.containsKey(directKey)) return directKey;

  final rosterName = _kLeagueRosterNameForClubNumber(canonicalClub, number);
  if (rosterName.isNotEmpty) {
    final rosterKey = '$canonicalClub|$rosterName';
    if (lookup.containsKey(rosterKey)) return rosterKey;
  }

  final lineups = _fixtureAsList(detail['lineups']);
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    if (club != canonicalClub) continue;
    for (final raw in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(raw, lineup: lineup);
      if (player == null) continue;
      if (player.number.trim() == number.trim()) {
        final key = '$canonicalClub|${player.name}';
        if (lookup.containsKey(key)) return key;
      }
    }
  }

  return directKey;
}

Map<String, double> _kLeagueFantasyBaseScoresFromDetail(
  Map<String, dynamic> detail,
) {
  return _kLeagueFantasyPlayerScoresFromDetail(detail).scores;
}

class _KLeagueDetailPlayerScoreBundle {
  final Map<String, double> scores;
  final Set<String> appearedKeys;

  const _KLeagueDetailPlayerScoreBundle({
    required this.scores,
    required this.appearedKeys,
  });
}

_KLeagueDetailPlayerScoreBundle _kLeagueFantasyPlayerScoresFromDetail(
  Map<String, dynamic> detail,
) {
  final detailFixture = _fixtureAsMap(detail['fixture']);
  final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
  final teams = _fixtureAsMap(detailFixture['teams']);
  final goals = _fixtureAsMap(detailFixture['goals']);
  final lineups = _fixtureAsList(detail['lineups']);
  final events = _fixtureAsList(detail['events']);
  final playerNames = _eventPlayerNameMap(lineups);
  final clubLookup = _kLeagueLineupClubLookup(lineups);
  final positionLookup = _kLeagueLineupPositionLookup(lineups);
  final ownGoalCounts = _kLeagueOwnGoalCounts(events, playerNames, clubLookup);
  final totalMinutes = _kLeagueFixtureTotalMinutes(fixtureMeta, events);

  final homeTeam = _fixtureAsMap(teams['home']);
  final awayTeam = _fixtureAsMap(teams['away']);
  final homeClub = _canonicalKLeagueClub(
    _kLeagueDisplayTeamName(_fixtureText(homeTeam['name'])),
  );
  final awayClub = _canonicalKLeagueClub(
    _kLeagueDisplayTeamName(_fixtureText(awayTeam['name'])),
  );
  final homeGoals = _readNullableInt(goals['home']) ?? 0;
  final awayGoals = _readNullableInt(goals['away']) ?? 0;
  final status = _fixtureAsMap(fixtureMeta['status']);
  final isFinal = _isKLeagueFinalStatus(_fixtureText(status['short']));

  final resultBonusByClub = <String, double>{};
  if (isFinal) {
    if (homeGoals > awayGoals) {
      resultBonusByClub[homeClub] = 3;
      resultBonusByClub[awayClub] = 0;
    } else if (homeGoals < awayGoals) {
      resultBonusByClub[homeClub] = 0;
      resultBonusByClub[awayClub] = 3;
    } else {
      resultBonusByClub[homeClub] = 1;
      resultBonusByClub[awayClub] = 1;
    }
  }

  final scores = <String, double>{};
  final appearedKeys = <String>{};
  final subOutMinuteByKey = <String, int>{};
  final subInMinuteByKey = <String, int>{};
  final statsMinutesByClubAndNumber = <String, int>{};
  final statsSubstituteByClubAndNumber = <String, bool>{};

  void addScore(String key, double value) {
    if (key.isEmpty) return;
    scores.update(key, (current) => current + value, ifAbsent: () => value);
  }

  String resolveClub(Map<String, dynamic> playerLike, String displayName) {
    final id = _fixtureText(playerLike['id']);
    final directClub = clubLookup[id];
    if (directClub != null && directClub.trim().isNotEmpty) {
      return directClub;
    }
    return clubLookup[displayName] ?? '';
  }

  for (final rawTeamBlock in _fixtureAsList(detail['players'])) {
    final teamBlock = _fixtureAsMap(rawTeamBlock);
    final team = _fixtureAsMap(teamBlock['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    for (final rawPlayerBlock in _fixtureAsList(teamBlock['players'])) {
      final playerBlock = _fixtureAsMap(rawPlayerBlock);
      final player = _fixtureAsMap(playerBlock['player']);
      final statsEntry = _fixtureAsMap(
        _fixtureAsList(playerBlock['statistics']).isNotEmpty
            ? _fixtureAsList(playerBlock['statistics']).first
            : const <String, dynamic>{},
      );
      final games = _fixtureAsMap(statsEntry['games']);
      final shirtNumber =
          _readNullableInt(games['number'])?.toString() ??
          _readNullableInt(player['number'])?.toString() ??
          _fixtureText(player['number']);
      if (shirtNumber.trim().isEmpty) continue;
      final key = '$club|$shirtNumber';
      final minutes = _readNullableInt(games['minutes']);
      if (minutes != null) {
        statsMinutesByClubAndNumber[key] = minutes;
      }
      if (games['substitute'] == true) {
        statsSubstituteByClubAndNumber[key] = true;
      }
    }
  }

  for (final raw in events) {
    final event = _fixtureAsMap(raw);
    final type = _fixtureText(event['type']);
    final detailText = _fixtureText(event['detail']);
    final player = _fixtureAsMap(event['player']);
    final assist = _fixtureAsMap(event['assist']);
    final minute = _kLeagueEventMinuteValue(_fixtureAsMap(event['time']));

    if (type == 'subst' || type == 'Subst') {
      final outName = _eventPlayerDisplayName(player, playerNames);
      final inName = _eventPlayerDisplayName(assist, playerNames);
      final outClub = resolveClub(player, outName);
      final inClub = resolveClub(assist, inName);
      if (outName.isNotEmpty && outClub.isNotEmpty) {
        subOutMinuteByKey['$outClub|$outName'] = minute;
      }
      if (inName.isNotEmpty && inClub.isNotEmpty) {
        subInMinuteByKey['$inClub|$inName'] = minute;
      }
      continue;
    }

    if (type == 'Goal') {
      final scorerName = _eventPlayerDisplayName(player, playerNames);
      final scorerClub = resolveClub(player, scorerName);
      if (detailText == 'Own Goal') {
        // Handled from lineup-based own-goal map below.
      } else if (detailText == 'Missed Penalty') {
        if (scorerName.isNotEmpty && scorerClub.isNotEmpty) {
          addScore('$scorerClub|$scorerName', -1);
        }
      } else if (scorerName.isNotEmpty && scorerClub.isNotEmpty) {
        final position = _kLeagueEventPlayerPosition(
          player,
          playerNames,
          positionLookup,
        );
        addScore('$scorerClub|$scorerName', _kLeagueGoalPoints(position));
      }

      final assistName = _eventPlayerDisplayName(assist, playerNames);
      final assistClub = resolveClub(assist, assistName);
      if (assistName.isNotEmpty && assistClub.isNotEmpty) {
        final assistPosition = _kLeagueEventPlayerPosition(
          assist,
          playerNames,
          positionLookup,
        );
        addScore(
          '$assistClub|$assistName',
          _kLeagueAssistPoints(assistPosition),
        );
      }
      continue;
    }

    if (type == 'Card') {
      final cardName = _eventPlayerDisplayName(player, playerNames);
      final cardClub = resolveClub(player, cardName);
      if (cardName.isEmpty || cardClub.isEmpty) continue;
      if (detailText.contains('Red')) {
        addScore('$cardClub|$cardName', -3);
      } else if (detailText.contains('Yellow')) {
        addScore('$cardClub|$cardName', -1);
      }
    }
  }

  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    final teamBonus = resultBonusByClub[club] ?? 0;
    final cleanSheetPoints =
        isFinal &&
            ((club == homeClub && awayGoals == 0) ||
                (club == awayClub && homeGoals == 0))
        ? 3.0
        : 0.0;

    for (final rawPlayer in _fixtureAsList(lineup['startXI'])) {
      final player = _lineupPlayerFromRaw(rawPlayer, lineup: lineup);
      if (player == null) continue;
      final key = '$club|${player.name}';
      final statsKey = '$club|${player.number}';
      final rawMinutes =
          statsMinutesByClubAndNumber[statsKey] ??
          (subOutMinuteByKey[key] ?? totalMinutes);
      final minutes = max(1, min(90, rawMinutes)).toDouble();
      final playerCleanSheetPoints = cleanSheetPoints > 0
          ? _kLeagueCleanSheetPoints(player.position)
          : 0.0;
      appearedKeys.add(key);
      addScore(
        key,
        minutes * 0.1 +
            teamBonus +
            playerCleanSheetPoints +
            (ownGoalCounts[key] ?? 0) * -2,
      );
    }

    for (final rawPlayer in _fixtureAsList(lineup['substitutes'])) {
      final player = _lineupPlayerFromRaw(rawPlayer, lineup: lineup);
      if (player == null) continue;
      final key = '$club|${player.name}';
      final enteredAt = subInMinuteByKey[key];
      final statsKey = '$club|${player.number}';
      final statsMinutes = statsMinutesByClubAndNumber[statsKey];
      final statsSubstitute = statsSubstituteByClubAndNumber[statsKey] == true;
      final hasAppearanceEvidence =
          enteredAt != null ||
          (statsMinutes != null && statsMinutes > 0) ||
          (statsSubstitute && (statsMinutes ?? 0) > 0);
      if (!hasAppearanceEvidence) {
        continue;
      }
      final rawMinutes =
          statsMinutes ?? max(0, totalMinutes - (enteredAt ?? totalMinutes));
      final minutes = max(1, min(90, rawMinutes)).toDouble();
      final playerCleanSheetPoints = cleanSheetPoints > 0
          ? _kLeagueCleanSheetPoints(player.position)
          : 0.0;
      appearedKeys.add(key);
      addScore(
        key,
        minutes * 0.1 +
            teamBonus +
            playerCleanSheetPoints +
            (ownGoalCounts[key] ?? 0) * -2,
      );
    }
  }

  final expandedScores = Map<String, double>.from(scores);
  for (final rawLineup in lineups) {
    final lineup = _fixtureAsMap(rawLineup);
    final team = _fixtureAsMap(lineup['team']);
    final club = _canonicalKLeagueClub(
      _kLeagueDisplayTeamName(_fixtureText(team['name'])),
    );
    for (final rawPlayer in [
      ..._fixtureAsList(lineup['startXI']),
      ..._fixtureAsList(lineup['substitutes']),
    ]) {
      final player = _lineupPlayerFromRaw(rawPlayer, lineup: lineup);
      if (player == null) continue;
      final key = '$club|${player.name}';
      final value = scores[key];
      if (value == null) continue;
      expandedScores[key] = value;
      if (appearedKeys.contains(key)) {
        appearedKeys.add(key);
      }
      if (player.originalName.trim().isNotEmpty) {
        expandedScores['$club|${player.originalName.trim()}'] = value;
        if (appearedKeys.contains(key)) {
          appearedKeys.add('$club|${player.originalName.trim()}');
        }
      }
      final rosterName = _kLeagueRosterNameForClubNumber(club, player.number);
      if (rosterName.isNotEmpty) {
        expandedScores['$club|$rosterName'] = value;
        if (appearedKeys.contains(key)) {
          appearedKeys.add('$club|$rosterName');
        }
      }
    }
  }

  return _KLeagueDetailPlayerScoreBundle(
    scores: expandedScores,
    appearedKeys: appearedKeys,
  );
}

String _kLeagueSeasonAptsKey({
  required String club,
  required String name,
  int? preferredNumber,
}) {
  final base = '${_canonicalKLeagueClub(club)}|${name.trim()}';
  if (preferredNumber != null && preferredNumber > 0) {
    return '$base|$preferredNumber';
  }
  return base;
}

Future<_FantasySoccerRoundScoreSnapshot>
_computeFantasySoccerRoundScoreSnapshot(
  _JoinedDraft draft,
  int round, {
  bool forceRefreshLiveData = false,
}) async {
  await _loadApiSoccerPlayers();
  final leagueData = await _loadCachedKLeagueLeagueData(
    forceRefresh: forceRefreshLiveData,
  );
  final rawFixtures = _fixtureAsList(leagueData['fixtures']);
  final mappedKLeagueRound = _mappedKLeagueRoundForFantasyRound(
    draft,
    round,
    rawFixtures,
  );
  final relevantFixtures = <Map<String, dynamic>>[];

  for (final raw in rawFixtures) {
    final map = _fixtureAsMap(raw);
    final league = _fixtureAsMap(map['league']);
    final fixtureRound = _roundNumber(_fixtureText(league['round']));
    if (fixtureRound != mappedKLeagueRound) continue;
    relevantFixtures.add(map);
  }

  var allFinal = relevantFixtures.isNotEmpty;
  final baseByClubAndPlayer = <String, double>{};
  for (final rawFixture in relevantFixtures) {
    final fixture = _fixtureAsMap(rawFixture['fixture']);
    final fixtureId = _readNullableInt(fixture['id']);
    if (fixtureId == null || fixtureId <= 0) {
      allFinal = false;
      continue;
    }
    try {
      final detail = await _loadCachedKLeagueFixtureDetail(
        fixtureId,
        forceRefresh: forceRefreshLiveData,
      );
      final detailFixture = _fixtureAsMap(detail['fixture']);
      final fixtureMeta = _fixtureAsMap(detailFixture['fixture']);
      final status = _fixtureAsMap(fixtureMeta['status']);
      if (!_isKLeagueFinalStatus(_fixtureText(status['short']))) {
        allFinal = false;
      }
      final scores = _kLeagueFantasyBaseScoresFromDetail(detail);
      scores.forEach(
        (key, score) => baseByClubAndPlayer.update(
          key,
          (value) => value + score,
          ifAbsent: () => score,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Fantasy soccer round score detail load failed '
        '(round=$mappedKLeagueRound, fixture=$fixtureId): $error',
      );
      debugPrint('$stackTrace');
      allFinal = false;
    }
  }

  final basePlayerScores = <String, double>{};
  final displayedPlayerScores = <String, double>{};
  final teamScores = <String, double>{};
  final captainNames = <String, String?>{};
  final viceCaptainNames = <String, String?>{};
  final captainPlayerIds = <String, String?>{};
  final viceCaptainPlayerIds = <String, String?>{};

  for (final team in draft.fantasyTeams) {
    final teamKey = _fantasyTeamIdentity(
      uid: team.uid,
      teamName: team.teamName,
    );
    double baseScoreFor(_FantasyTeamPlayer player) {
      final clubKey = _canonicalKLeagueClub(player.club);
      if (clubKey.isNotEmpty) {
        final direct = baseByClubAndPlayer['$clubKey|${player.name}'];
        if (direct != null) return direct;
        if (player.number > 0) {
          final rosterName = _kLeagueRosterNameForClubNumber(
            clubKey,
            '${player.number}',
          );
          if (rosterName.isNotEmpty) {
            final rosterScore = baseByClubAndPlayer['$clubKey|$rosterName'];
            if (rosterScore != null) return rosterScore;
          }
        }
      }
      final meta = _resolvePlayerMeta(player.name);
      return baseByClubAndPlayer['${_canonicalKLeagueClub(meta.club)}|${player.name}'] ??
          0;
    }

    final rankedStarters = [...team.starting]
      ..sort((a, b) {
        final scoreCompare = baseScoreFor(b).compareTo(baseScoreFor(a));
        if (scoreCompare != 0) return scoreCompare;
        return a.name.compareTo(b.name);
      });
    final startersById = <String, _FantasyTeamPlayer>{
      for (final player in team.starting)
        _fantasyTeamPlayerIdentity(player): player,
    };
    final captainPlayer =
        team.captainPlayerId != null &&
            startersById.containsKey(team.captainPlayerId)
        ? startersById[team.captainPlayerId]
        : (team.captainName == null
                  ? null
                  : team.starting.cast<_FantasyTeamPlayer?>().firstWhere(
                      (player) => player?.name == team.captainName,
                      orElse: () => null,
                    )) ??
              (rankedStarters.isEmpty ? null : rankedStarters.first);
    final captainId = captainPlayer == null
        ? null
        : _fantasyTeamPlayerIdentity(captainPlayer);
    final captain = captainPlayer?.name;
    final viceCaptainPlayer =
        team.viceCaptainPlayerId != null &&
            team.viceCaptainPlayerId != captainId &&
            startersById.containsKey(team.viceCaptainPlayerId)
        ? startersById[team.viceCaptainPlayerId]
        : (team.viceCaptainName == null
                  ? null
                  : team.starting.cast<_FantasyTeamPlayer?>().firstWhere(
                      (player) =>
                          player?.name == team.viceCaptainName &&
                          _fantasyTeamPlayerIdentity(player!) != captainId,
                      orElse: () => null,
                    )) ??
              rankedStarters.cast<_FantasyTeamPlayer?>().firstWhere(
                (player) =>
                    player != null &&
                    _fantasyTeamPlayerIdentity(player) != captainId,
                orElse: () => null,
              );
    captainNames[teamKey] = captain;
    viceCaptainNames[teamKey] = viceCaptainPlayer?.name;
    captainPlayerIds[teamKey] = captainId;
    viceCaptainPlayerIds[teamKey] = viceCaptainPlayer == null
        ? null
        : _fantasyTeamPlayerIdentity(viceCaptainPlayer);

    for (final player in team.roster) {
      final base = baseScoreFor(player);
      final displayed = _fantasyTeamPlayerIdentity(player) == captainId
          ? base * 2
          : base;
      final playerKey = _fantasySoccerPlayerCacheKey(
        teamUid: team.uid,
        teamName: team.teamName,
        playerName: player.name,
        playerId: player.playerId,
      );
      basePlayerScores[playerKey] = base;
      displayedPlayerScores[playerKey] = displayed;
    }

    teamScores[teamKey] = team.starting.fold<double>(
      0,
      (total, player) =>
          total +
          (displayedPlayerScores[_fantasySoccerPlayerCacheKey(
                teamUid: team.uid,
                teamName: team.teamName,
                playerName: player.name,
                playerId: player.playerId,
              )] ??
              0),
    );
  }

  if (relevantFixtures.isEmpty ||
      (teamScores.isNotEmpty &&
          teamScores.values.every((score) => score == 0))) {
    debugPrint(
      'fantasy soccer snapshot: league=${draft.leagueName} '
      'draftWhen=${draft.when.toIso8601String()} fantasyRound=$round '
      'mappedKLeagueRound=$mappedKLeagueRound fixtures=${relevantFixtures.length} '
      'baseScores=${baseByClubAndPlayer.length} teamScores=${teamScores.length}',
    );
  }

  return _FantasySoccerRoundScoreSnapshot(
    leagueId: draft.leagueId,
    round: round,
    generatedAt: DateTime.now(),
    finalized: allFinal,
    basePlayerScores: basePlayerScores,
    displayedPlayerScores: displayedPlayerScores,
    teamScores: teamScores,
    captainNames: captainNames,
    viceCaptainNames: viceCaptainNames,
    captainPlayerIds: captainPlayerIds,
    viceCaptainPlayerIds: viceCaptainPlayerIds,
  );
}

Future<_FantasySoccerRoundScoreSnapshot> _ensureFantasySoccerRoundScoreSnapshot(
  _JoinedDraft draft,
  int round, {
  bool force = false,
  bool forceRefreshLiveData = false,
}) {
  final cacheKey = _fantasySoccerRoundCacheKey(draft, round);
  final cached = _fantasySoccerRoundScoreCache[cacheKey];
  final now = DateTime.now();
  if (!force && cached != null) {
    final fresh =
        now.difference(cached.generatedAt) < _fantasySoccerScoreCacheTtl;
    if (cached.finalized || fresh) {
      return Future.value(cached);
    }
  }
  final inFlight = _fantasySoccerRoundScoreInFlight[cacheKey];
  if (inFlight != null) return inFlight;

  final future =
      _computeFantasySoccerRoundScoreSnapshot(
            draft,
            round,
            forceRefreshLiveData: forceRefreshLiveData,
          )
          .then((snapshot) {
            _fantasySoccerRoundScoreCache[cacheKey] = snapshot;
            return snapshot;
          })
          .whenComplete(() {
            _fantasySoccerRoundScoreInFlight.remove(cacheKey);
          });

  _fantasySoccerRoundScoreInFlight[cacheKey] = future;
  return future;
}

_FantasySoccerRoundScoreSnapshot? _fantasySoccerRoundScoreSnapshotFor(
  _JoinedDraft draft,
  int round,
) {
  return _fantasySoccerRoundScoreCache[_fantasySoccerRoundCacheKey(
    draft,
    round,
  )];
}

double _fantasySoccerBasePlayerRoundScore(
  _JoinedDraft draft,
  _FantasyTeamState team,
  String playerName,
  int round, {
  String playerId = '',
}) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return 0;
  return snapshot.basePlayerScores[_fantasySoccerPlayerCacheKey(
        teamUid: team.uid,
        teamName: team.teamName,
        playerName: playerName,
        playerId: playerId,
      )] ??
      0;
}

double _fantasySoccerDisplayedPlayerRoundScore(
  _JoinedDraft draft,
  _FantasyTeamState team,
  String playerName,
  int round, {
  String playerId = '',
}) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return 0;
  return snapshot.displayedPlayerScores[_fantasySoccerPlayerCacheKey(
        teamUid: team.uid,
        teamName: team.teamName,
        playerName: playerName,
        playerId: playerId,
      )] ??
      0;
}

String? _fantasySoccerCaptainName(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int round,
) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return null;
  return snapshot.captainNames[_fantasyTeamIdentity(
    uid: team.uid,
    teamName: team.teamName,
  )];
}

String? _fantasySoccerViceCaptainName(
  _JoinedDraft draft,
  _FantasyTeamState team,
  int round,
) {
  final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
  if (snapshot == null) return null;
  return snapshot.viceCaptainNames[_fantasyTeamIdentity(
    uid: team.uid,
    teamName: team.teamName,
  )];
}

_KboFantasyRoundScoreState? _kboRoundScoreStateForTeam(
  _FantasyTeamState team,
  int round,
) {
  for (final state in team.kboRoundScoreStates) {
    if (state.round == round) return state;
  }
  return null;
}

bool _isCaptainFantasyPlayerForTeam(
  _FantasyTeamState? team,
  _FantasyTeamPlayer player,
) {
  if (team == null) return false;
  final playerId = _fantasyTeamPlayerIdentity(player);
  if (team.captainPlayerId?.trim().isNotEmpty == true) {
    return team.captainPlayerId == playerId;
  }
  return team.captainName == player.name;
}

double _fantasyKboBasePlayerRoundScore(
  _FantasyTeamPlayer player, {
  required _JoinedDraft draft,
  required int round,
}) {
  if (!_kboFantasyRoundHasStarted(draft, round, DateTime.now())) {
    return 0.0;
  }
  final absoluteRound = _mappedKboRoundForFantasyRound(draft, round);
  final roundPoints = _cachedKboRoundPointsForPlayer(
    playerName: player.name,
    club: _normalizeKboDraftClub(player.club),
    preferredNumber: player.number,
    preferredPosition: player.position,
  );
  if (roundPoints == null) return 0.0;
  for (final entry in roundPoints) {
    if (entry.round == absoluteRound) {
      return entry.displayedPoints;
    }
  }
  return 0.0;
}

double _fantasyKboDisplayedPlayerRoundScore(
  _FantasyTeamPlayer player, {
  required _JoinedDraft draft,
  required int round,
  _FantasyTeamState? team,
}) {
  final base = _fantasyKboBasePlayerRoundScore(
    player,
    draft: draft,
    round: round,
  );
  return _isCaptainFantasyPlayerForTeam(team, player) ? base * 2 : base;
}

double _fantasyPlayerRoundScore(
  _FantasyTeamPlayer player,
  int round, {
  required bool isSoccer,
  _JoinedDraft? draft,
  _FantasyTeamState? team,
}) {
  if (isSoccer) {
    if (draft == null || team == null) return 0;
    return _fantasySoccerDisplayedPlayerRoundScore(
      draft,
      team,
      player.name,
      round,
      playerId: player.playerId,
    );
  }
  if (draft == null) return 0.0;
  return _fantasyKboDisplayedPlayerRoundScore(
    player,
    draft: draft,
    round: round,
    team: team,
  );
}

double _fantasyTeamRoundScore(
  _FantasyTeamState team,
  int round, {
  required bool isSoccer,
  _JoinedDraft? draft,
}) {
  if (isSoccer) {
    if (draft == null) return 0;
    final snapshot = _fantasySoccerRoundScoreSnapshotFor(draft, round);
    if (snapshot == null) return 0;
    return snapshot.teamScores[_fantasyTeamIdentity(
          uid: team.uid,
          teamName: team.teamName,
        )] ??
        0;
  }
  if (draft == null ||
      !_kboFantasyRoundHasStarted(draft, round, DateTime.now())) {
    return 0.0;
  }
  final unlockedSnapshot = _kboUnlockedRoundScoreSnapshotForTeam(
    team,
    draft: draft,
    round: round,
  );
  if (unlockedSnapshot != null) return unlockedSnapshot;
  final state = _kboRoundScoreStateForTeam(team, round);
  final baselines = state?.starterBaselines ?? const <String, double>{};
  final bankedScore = state?.bankedScore ?? 0.0;
  return bankedScore +
      team.starting.fold<double>(0.0, (total, player) {
        final current = _fantasyKboDisplayedPlayerRoundScore(
          player,
          draft: draft,
          round: round,
          team: team,
        );
        final baseline = baselines[_fantasyTeamPlayerIdentity(player)] ?? 0.0;
        return total + (current - baseline);
      });
}

String? _currentUserFantasyTeamName(_JoinedDraft draft) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  for (final team in draft.fantasyTeams) {
    if (team.uid == user.uid) {
      return _normalizedFantasyDisplayNameForUid(user.uid, team.teamName);
    }
  }

  for (final entry in draft.draftOrder) {
    if (entry.uid == user.uid) {
      return _normalizedFantasyDisplayNameForUid(user.uid, entry.displayName);
    }
  }

  final preferred = _currentSignedInFantasyDisplayName();
  if (preferred.isNotEmpty) return preferred;
  return null;
}

String? _currentUserFantasyUid() => FirebaseAuth.instance.currentUser?.uid;

_FantasyMatchupView? _currentFantasyMatchupForDraft(_JoinedDraft draft) {
  if (!draft.fantasyReady ||
      draft.fantasyTeams.isEmpty ||
      draft.fantasySchedule.isEmpty) {
    debugPrint(
      'currentFantasyMatchupForDraft: fantasy data missing '
      '(ready=${draft.fantasyReady}, teams=${draft.fantasyTeams.length}, schedule=${draft.fantasySchedule.length}) '
      'for ${draft.leagueName}',
    );
    return null;
  }
  final myUid = _currentUserFantasyUid();
  final myTeamName = _currentUserFantasyTeamName(draft);
  if ((myUid == null || myUid.isEmpty) &&
      (myTeamName == null || myTeamName.isEmpty)) {
    debugPrint(
      'currentFantasyMatchupForDraft: no current user identity for ${draft.leagueName}',
    );
    return null;
  }

  final round = _currentFantasyRoundAt(draft, DateTime.now());
  final roundMatchups = draft.fantasySchedule
      .where((item) => item.round == round)
      .toList(growable: false);
  final matchup = roundMatchups.firstWhere(
    (item) =>
        (((myUid != null && myUid.isNotEmpty) &&
            (item.homeUid == myUid || item.awayUid == myUid)) ||
        ((myTeamName != null && myTeamName.isNotEmpty) &&
            (_sameFantasyIdentity(item.homeTeam, myTeamName) ||
                _sameFantasyIdentity(item.awayTeam, myTeamName)))),
    orElse: () => const _FantasyScheduleMatchup(
      round: -1,
      homeUid: '',
      homeTeam: '',
      awayUid: '',
      awayTeam: '',
    ),
  );
  _FantasyTeamState? findTeam({String? uid, String? name}) {
    for (final team in draft.fantasyTeams) {
      if (uid != null && uid.isNotEmpty && team.uid == uid) return team;
      if (name != null &&
          name.isNotEmpty &&
          _sameFantasyIdentity(team.teamName, name)) {
        return team;
      }
    }
    return null;
  }

  if (matchup.round < 0) {
    final myTeam = findTeam(uid: myUid, name: myTeamName);
    if (myTeam != null && roundMatchups.isNotEmpty) {
      final scoresReady =
          !draft.isSoccer ||
          _fantasySoccerRoundScoreSnapshotFor(draft, round) != null;
      return _FantasyMatchupView(
        draft: draft,
        round: round,
        matchup: _FantasyScheduleMatchup(
          round: round,
          homeUid: myTeam.uid,
          homeTeam: myTeam.teamName,
          awayUid: '__bye__',
          awayTeam: 'BYE',
        ),
        myTeam: myTeam,
        opponent: const _FantasyTeamState(uid: '__bye__', teamName: 'BYE'),
        scoresReady: scoresReady,
        myScore: _fantasyTeamRoundScore(
          myTeam,
          round,
          isSoccer: draft.isSoccer,
          draft: draft,
        ),
        opponentScore: 0,
      );
    }
    debugPrint(
      'currentFantasyMatchupForDraft: no matchup found '
      '(round=$round, uid=$myUid, team=$myTeamName, roundMatchups=${roundMatchups.length}) '
      'for ${draft.leagueName}',
    );
    return null;
  }

  final homeTeam = findTeam(uid: matchup.homeUid, name: matchup.homeTeam);
  final awayTeam = findTeam(uid: matchup.awayUid, name: matchup.awayTeam);
  if (homeTeam == null || awayTeam == null) {
    debugPrint(
      'currentFantasyMatchupForDraft: team lookup failed '
      '(homeUid=${matchup.homeUid}, homeTeam=${matchup.homeTeam}, '
      'awayUid=${matchup.awayUid}, awayTeam=${matchup.awayTeam}) '
      'for ${draft.leagueName}',
    );
    return null;
  }

  final isHome =
      (myUid != null && myUid.isNotEmpty && matchup.homeUid == myUid) ||
      (myTeamName != null &&
          myTeamName.isNotEmpty &&
          _sameFantasyIdentity(matchup.homeTeam, myTeamName));
  final myTeam = isHome ? homeTeam : awayTeam;
  final opponent = isHome ? awayTeam : homeTeam;
  final scoresReady =
      !draft.isSoccer ||
      _fantasySoccerRoundScoreSnapshotFor(draft, round) != null;

  return _FantasyMatchupView(
    draft: draft,
    round: round,
    matchup: matchup,
    myTeam: myTeam,
    opponent: opponent,
    scoresReady: scoresReady,
    myScore: _fantasyTeamRoundScore(
      myTeam,
      round,
      isSoccer: draft.isSoccer,
      draft: draft,
    ),
    opponentScore: _fantasyTeamRoundScore(
      opponent,
      round,
      isSoccer: draft.isSoccer,
      draft: draft,
    ),
  );
}

List<_FantasyTeamPlayer> _parseFantasyTeamPlayers(
  dynamic raw, {
  required bool isSoccer,
}) {
  final list = raw as List<dynamic>? ?? const [];
  return list.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final name = '${map['name'] ?? ''}';
    final club = '${map['club'] ?? ''}'.trim();
    final number = map['number'] is int
        ? map['number'] as int
        : int.tryParse('${map['number'] ?? 0}') ?? 0;
    final fallbackMeta = isSoccer ? _resolvePlayerMeta(name) : null;
    final resolvedClub = club.isNotEmpty ? club : (fallbackMeta?.club ?? '');
    final resolvedNumber = number > 0 ? number : (fallbackMeta?.number ?? 0);
    return _FantasyTeamPlayer(
      name: name,
      position: '${map['position'] ?? ''}',
      score: map['score'] is int
          ? map['score'] as int
          : int.tryParse('${map['score'] ?? 0}') ?? 0,
      club: resolvedClub,
      number: resolvedNumber,
      playerId: _fantasyPlayerIdentity(
        name: name,
        club: resolvedClub,
        number: resolvedNumber,
        playerId: '${map['playerId'] ?? ''}',
      ),
    );
  }).toList();
}

List<_KboFantasyRoundScoreState> _parseKboRoundScoreStates(dynamic raw) {
  final list = raw as List<dynamic>? ?? const [];
  final parsed =
      list
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(
              item.cast<Object?, Object?>(),
            );
            final round = map['round'] is int
                ? map['round'] as int
                : int.tryParse('${map['round'] ?? 0}') ?? 0;
            if (round <= 0) return null;
            final rawBaselines = map['starterBaselines'] is Map
                ? map['starterBaselines'] as Map
                : null;
            final starterBaselines = <String, double>{};
            if (rawBaselines != null) {
              for (final entry in rawBaselines.entries) {
                final key = '${entry.key}'.trim();
                if (key.isEmpty) continue;
                starterBaselines[key] =
                    (entry.value as num?)?.toDouble() ??
                    double.tryParse('${entry.value}') ??
                    0.0;
              }
            }
            final updatedAt =
                DateTime.tryParse('${map['updatedAt'] ?? ''}') ??
                DateTime(1970);
            return _KboFantasyRoundScoreState(
              round: round,
              bankedScore:
                  (map['bankedScore'] as num?)?.toDouble() ??
                  double.tryParse('${map['bankedScore'] ?? ''}') ??
                  0.0,
              starterBaselines: starterBaselines,
              updatedAt: updatedAt,
              unlockedScoreSnapshot:
                  (map['unlockedScoreSnapshot'] as num?)?.toDouble() ??
                  double.tryParse('${map['unlockedScoreSnapshot'] ?? ''}'),
              unlockedAt: DateTime.tryParse('${map['unlockedAt'] ?? ''}'),
            );
          })
          .whereType<_KboFantasyRoundScoreState>()
          .toList()
        ..sort((a, b) => a.round.compareTo(b.round));
  return parsed;
}

bool _shouldFreezeUnlockedKboRoundScore(
  _JoinedDraft draft,
  int round, {
  DateTime? now,
}) {
  if (draft.isSoccer || round <= 0) return false;
  final currentTime = now ?? DateTime.now();
  if (!_kboFantasyRoundHasStarted(draft, round, currentTime)) return false;
  final lockState = _fantasyRosterLockStateForDraft(draft, now: currentTime);
  return lockState.phase == _FantasyRosterLockPhase.unlocked &&
      lockState.fantasyRound == round;
}

double? _kboUnlockedRoundScoreSnapshotForTeam(
  _FantasyTeamState team, {
  required _JoinedDraft draft,
  required int round,
  DateTime? now,
}) {
  if (!_shouldFreezeUnlockedKboRoundScore(draft, round, now: now)) {
    return null;
  }
  return _kboRoundScoreStateForTeam(team, round)?.unlockedScoreSnapshot;
}

List<_FantasyTeamState> _parseFantasyTeams(
  dynamic raw, {
  required bool isSoccer,
}) {
  final list = raw as List<dynamic>? ?? const [];
  return list.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final uid = '${map['uid'] ?? ''}';
    final captainName = '${map['captainName'] ?? ''}'.trim();
    final viceCaptainName = '${map['viceCaptainName'] ?? ''}'.trim();
    final captainPlayerId = '${map['captainPlayerId'] ?? ''}'.trim();
    final viceCaptainPlayerId = '${map['viceCaptainPlayerId'] ?? ''}'.trim();
    final team = _FantasyTeamState(
      uid: uid,
      teamName: _normalizedFantasyDisplayNameForUid(
        uid,
        '${map['teamName'] ?? 'Team'}',
      ),
      roster: _parseFantasyTeamPlayers(map['roster'], isSoccer: isSoccer),
      starting: _parseFantasyTeamPlayers(map['starting'], isSoccer: isSoccer),
      bench: _parseFantasyTeamPlayers(map['bench'], isSoccer: isSoccer),
      captainName: captainName.isEmpty ? null : captainName,
      viceCaptainName: viceCaptainName.isEmpty ? null : viceCaptainName,
      captainPlayerId: captainPlayerId.isEmpty ? null : captainPlayerId,
      viceCaptainPlayerId: viceCaptainPlayerId.isEmpty
          ? null
          : viceCaptainPlayerId,
      kboRoundScoreStates: _parseKboRoundScoreStates(
        map['kboRoundScoreStates'],
      ),
    );
    return isSoccer ? team : _normalizeBaseballFantasyTeam(team);
  }).toList();
}

List<_FantasyScheduleMatchup> _parseFantasySchedule(dynamic raw) {
  final list = raw as List<dynamic>? ?? const [];
  return list.whereType<Map>().map((item) {
    final map = Map<String, dynamic>.from(item);
    final homeUid = '${map['homeUid'] ?? ''}';
    final awayUid = '${map['awayUid'] ?? ''}';
    return _FantasyScheduleMatchup(
      round: map['round'] is int
          ? map['round'] as int
          : int.tryParse('${map['round'] ?? 0}') ?? 0,
      homeUid: homeUid,
      homeTeam: _normalizedFantasyDisplayNameForUid(
        homeUid,
        '${map['homeTeam'] ?? ''}',
      ),
      awayUid: awayUid,
      awayTeam: _normalizedFantasyDisplayNameForUid(
        awayUid,
        '${map['awayTeam'] ?? ''}',
      ),
    );
  }).toList()..sort((a, b) {
    final roundCompare = a.round.compareTo(b.round);
    if (roundCompare != 0) return roundCompare;
    return a.homeTeam.compareTo(b.homeTeam);
  });
}

List<List<_PlayerSlot?>> _parseDraftBoard(
  dynamic raw, {
  required bool isSoccer,
}) {
  final rows = raw as List<dynamic>? ?? const [];
  return rows.map<List<_PlayerSlot?>>((row) {
    final dynamic rawCells;
    if (row is Map) {
      rawCells = row['cells'];
    } else {
      rawCells = row;
    }
    final cells = rawCells as List<dynamic>? ?? const [];
    return cells.map<_PlayerSlot?>((cell) {
      if (cell is! Map) return null;
      final map = Map<String, dynamic>.from(cell);
      final name = '${map['name'] ?? ''}';
      if (name.isEmpty) return null;
      final club = '${map['club'] ?? ''}'.trim();
      final number = map['number'] is int
          ? map['number'] as int
          : int.tryParse('${map['number'] ?? 0}') ?? 0;
      final fallbackMeta = isSoccer ? _resolvePlayerMeta(name) : null;
      final resolvedClub = club.isNotEmpty ? club : (fallbackMeta?.club ?? '');
      final resolvedNumber = number > 0 ? number : (fallbackMeta?.number ?? 0);
      return _PlayerSlot(
        name: name,
        position: '${map['position'] ?? ''}',
        score: map['score'] is int
            ? map['score'] as int
            : int.tryParse('${map['score'] ?? 0}') ?? 0,
        club: resolvedClub,
        number: resolvedNumber,
        playerId: _fantasyPlayerIdentity(
          name: name,
          club: resolvedClub,
          number: resolvedNumber,
          playerId: '${map['playerId'] ?? ''}',
        ),
      );
    }).toList();
  }).toList();
}

List<Map<String, dynamic>> _draftBoardToFirestoreRows(
  List<List<_PlayerSlot?>> board,
) {
  return List<Map<String, dynamic>>.generate(board.length, (rowIndex) {
    return {
      'row': rowIndex,
      'cells': board[rowIndex]
          .map(
            (slot) => slot == null
                ? null
                : {
                    'name': slot.name,
                    'position': slot.position,
                    'score': slot.score,
                    'club': slot.club,
                    'number': slot.number,
                    'playerId': slot.playerId,
                  },
          )
          .toList(),
    };
  });
}

class _RecoveredFantasyPayload {
  final List<List<_PlayerSlot?>> board;
  final List<_FantasyTeamState> teams;
  final List<_FantasyScheduleMatchup> schedule;

  const _RecoveredFantasyPayload({
    required this.board,
    required this.teams,
    required this.schedule,
  });
}

const List<String> _kboDraftClubs = [
  'LG',
  'KIA',
  '삼성',
  '두산',
  '롯데',
  '한화',
  'KT',
  'SSG',
  'NC',
  '키움',
];

const String _kboDraftPlayerDirectoryAsset =
    'functions/kbo_players_season_2026.txt';

List<_PlayerSlot>? _kboDraftPlayerPoolCache;
Future<List<_PlayerSlot>>? _kboDraftPlayerPoolFuture;

String _normalizeKboDraftClub(String value) {
  switch (value.trim()) {
    case 'Samsung':
    case 'SAMSUNG':
      return '삼성';
    case 'Doosan':
    case 'DOOSAN':
      return '두산';
    case 'Lotte':
    case 'LOTTE':
      return '롯데';
    case 'Hanwha':
    case 'HANWHA':
      return '한화';
    case 'Kiwoom':
    case 'KIWOOM':
      return '키움';
    default:
      return value.trim();
  }
}

String? _normalizeKboDraftPosition(String value) {
  switch (value.trim()) {
    case 'Pitcher':
      return 'P';
    case 'Catcher':
      return 'C';
    case 'Outfielder':
    case 'Left Fielder':
    case 'Right Fielder':
    case 'Center Fielder':
      return 'OF';
    case 'Infielder':
    case 'First baseman':
    case 'Shortstop':
    case 'Second baseman':
    case 'Third baseman':
      return 'IF';
    default:
      return null;
  }
}

List<_PlayerSlot> _fallbackRecoveredBaseballPlayerPool() {
  final pool = <_PlayerSlot>[];
  for (final club in _kboDraftClubs) {
    for (int i = 1; i <= 12; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'P', number: i),
      );
    }
    for (int i = 1; i <= 8; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'IF', number: i),
      );
    }
    for (int i = 1; i <= 6; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'OF', number: i),
      );
    }
    for (int i = 1; i <= 3; i++) {
      pool.add(
        _makeRecoveredBaseballSlot(club: club, position: 'C', number: i),
      );
    }
  }
  return pool;
}

List<_PlayerSlot> _parseKboDraftPlayerPool(String raw) {
  final seen = <String>{};
  final pool = <_PlayerSlot>[];

  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final parts = line.split('|').map((part) => part.trim()).toList();
    if (parts.length < 5) continue;
    final englishName = parts[0];
    final koreanName = parts[1];
    final club = _normalizeKboDraftClub(parts[2]);
    final position = _normalizeKboDraftPosition(parts[3]);
    final number = int.tryParse(parts[4]) ?? 0;
    if (englishName.isEmpty || koreanName.isEmpty || position == null) {
      continue;
    }

    final displayName = koreanName;
    final dedupeKey = '$club|$displayName|$position|$number';
    if (!seen.add(dedupeKey)) continue;

    final scoreSeed = _stableSeedFromKey(dedupeKey);
    pool.add(
      _PlayerSlot(
        name: displayName,
        score: 5 + (scoreSeed % 6),
        position: position,
        club: club,
        number: number,
        playerId: dedupeKey,
      ),
    );
  }

  return pool;
}

Future<List<_PlayerSlot>> _loadKboDraftPlayerPool() {
  final cached = _kboDraftPlayerPoolCache;
  if (cached != null) return Future.value(cached);
  final inFlight = _kboDraftPlayerPoolFuture;
  if (inFlight != null) return inFlight;

  _kboDraftPlayerPoolFuture = rootBundle
      .loadString(_kboDraftPlayerDirectoryAsset)
      .then((raw) {
        final parsed = _parseKboDraftPlayerPool(raw);
        final resolved = parsed.isNotEmpty
            ? parsed
            : _fallbackRecoveredBaseballPlayerPool();
        _kboDraftPlayerPoolCache = resolved;
        return resolved;
      })
      .catchError((Object error) {
        debugPrint('Unable to load KBO draft player pool: $error');
        final fallback = _fallbackRecoveredBaseballPlayerPool();
        _kboDraftPlayerPoolCache = fallback;
        return fallback;
      });

  return _kboDraftPlayerPoolFuture!;
}

_PlayerSlot _makeRecoveredBaseballSlot({
  required String club,
  required String position,
  required int number,
}) {
  final scoreSeed = _stableSeedFromKey('$club|$position|$number');
  return _PlayerSlot(
    name: '$club $position$number',
    score: 5 + (scoreSeed % 6),
    position: position,
    club: club,
    number: number,
    playerId: '$club|$position|$number',
  );
}

List<_PlayerSlot> _buildRecoveredBaseballPlayerPool(
  Random random,
  List<_PlayerSlot> basePool,
) {
  final pool = List<_PlayerSlot>.from(basePool);
  pool.shuffle(random);
  return pool;
}

List<_FantasyTeamPlayer> _buildRecoveredSoccerStarting(
  List<_FantasyTeamPlayer> roster,
) {
  final gks = roster.where((p) => p.position == 'GK').toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  final dfs = roster.where((p) => p.position == 'DF').toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  final mfs = roster.where((p) => p.position == 'MF').toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  final fws = roster.where((p) => p.position == 'FW').toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  const formations = [
    (4, 4, 2),
    (4, 3, 3),
    (3, 4, 3),
    (4, 5, 1),
    (3, 5, 2),
    (5, 4, 1),
    (5, 2, 3),
  ];
  for (final (dfNeed, mfNeed, fwNeed) in formations) {
    if (gks.isEmpty ||
        dfs.length < dfNeed ||
        mfs.length < mfNeed ||
        fws.length < fwNeed) {
      continue;
    }
    return [
      gks.first,
      ...dfs.take(dfNeed),
      ...mfs.take(mfNeed),
      ...fws.take(fwNeed),
    ];
  }
  return roster.take(11).toList();
}

List<_FantasyTeamPlayer> _buildRecoveredBaseballStarting(
  List<_FantasyTeamPlayer> roster,
) {
  return _buildBaseballStartingFromRoster(
    roster,
    positionOf: (player) => player.position,
    scoreOf: (player) => player.score,
    identityOf: (player) => _fantasyTeamPlayerIdentity(player),
  );
}

Future<_RecoveredFantasyPayload> _recoverFantasyPayloadFromDraft(
  _JoinedDraft draft,
) async {
  final seedKey =
      'real|${draft.leagueName}|${draft.when.toIso8601String()}|${draft.teamCount}|${draft.isSoccer}';
  final random = Random(_stableSeedFromKey(seedKey));
  final rounds = _draftRoundsForSport(draft.isSoccer);
  final board = List.generate(
    rounds,
    (_) => List<_PlayerSlot?>.filled(draft.teamCount, null),
  );
  final playerPool = draft.isSoccer
      ? _buildPlayerPool(random)
      : _buildRecoveredBaseballPlayerPool(
          random,
          await _loadKboDraftPlayerPool(),
        );
  final minimums = draft.isSoccer
      ? const {'GK': 1, 'DF': 3, 'MF': 4, 'FW': 3}
      : const {'P': 1, 'IF': 4, 'OF': 3, 'C': 1};
  final draftOrderEntries = List<_DraftOrderEntry>.generate(draft.teamCount, (
    index,
  ) {
    if (index < draft.draftOrder.length) return draft.draftOrder[index];
    return _DraftOrderEntry(
      uid: '',
      displayName: 'Team ${index + 1}',
      slot: index + 1,
    );
  });

  bool isPicked(_PlayerSlot player) =>
      board.any((row) => row.any((slot) => slot?.name == player.name));

  Iterable<_PlayerSlot> availablePlayers() =>
      playerPool.where((player) => !isPicked(player));

  Map<String, int> teamPositionCounts(int teamIdx) {
    final counts = <String, int>{};
    for (int row = 0; row < rounds; row++) {
      final slot = board[row][teamIdx];
      if (slot == null) continue;
      counts.update(slot.position, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  int remainingEmptySlotsForTeam(int teamIdx) {
    int count = 0;
    for (int row = 0; row < rounds; row++) {
      if (board[row][teamIdx] == null) count++;
    }
    return count;
  }

  bool canStillMeetMinimumsAfterPick(int teamIdx, _PlayerSlot candidate) {
    final counts = teamPositionCounts(teamIdx);
    counts.update(candidate.position, (value) => value + 1, ifAbsent: () => 1);
    final remainingSlotsAfterPick = remainingEmptySlotsForTeam(teamIdx) - 1;
    int stillNeeded = 0;
    for (final entry in minimums.entries) {
      final have = counts[entry.key] ?? 0;
      stillNeeded += max(0, entry.value - have);
    }
    return stillNeeded <= remainingSlotsAfterPick;
  }

  List<_PlayerSlot> selectablePlayersForTeam(int teamIdx) {
    final available = availablePlayers().toList();
    final constrained = available
        .where((player) => canStillMeetMinimumsAfterPick(teamIdx, player))
        .toList();
    return constrained.isNotEmpty ? constrained : available;
  }

  _PlayerSlot? takeAvailablePlayerForPosition(String position) {
    final available = availablePlayers()
        .where((player) => player.position == position)
        .toList();
    if (available.isEmpty) return null;
    return available[random.nextInt(available.length)];
  }

  for (int index = 0; index < rounds * draft.teamCount; index++) {
    final row = index ~/ draft.teamCount;
    final col = index % draft.teamCount;
    final available = selectablePlayersForTeam(col);
    if (available.isEmpty) continue;
    board[row][col] = available[random.nextInt(available.length)];
  }

  for (int teamIdx = 0; teamIdx < draft.teamCount; teamIdx++) {
    final blankRows = <int>[];
    for (int row = 0; row < rounds; row++) {
      if (board[row][teamIdx] == null) blankRows.add(row);
    }
    if (blankRows.isEmpty) continue;

    final counts = teamPositionCounts(teamIdx);
    for (final entry in minimums.entries) {
      while ((counts[entry.key] ?? 0) < entry.value && blankRows.isNotEmpty) {
        final candidate = takeAvailablePlayerForPosition(entry.key);
        if (candidate == null) break;
        final row = blankRows.removeAt(0);
        board[row][teamIdx] = candidate;
        counts.update(
          candidate.position,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    while (blankRows.isNotEmpty) {
      final available = availablePlayers().toList();
      if (available.isEmpty) break;
      final row = blankRows.removeAt(0);
      board[row][teamIdx] = available[random.nextInt(available.length)];
    }
  }

  final teams = <_FantasyTeamState>[];
  for (int teamIdx = 0; teamIdx < draft.teamCount; teamIdx++) {
    final roster = <_FantasyTeamPlayer>[];
    for (int row = 0; row < rounds; row++) {
      final slot = board[row][teamIdx];
      if (slot == null) continue;
      roster.add(
        _FantasyTeamPlayer(
          name: slot.name,
          position: slot.position,
          score: slot.score,
          club: slot.club,
          number: slot.number,
          playerId: slot.playerId,
        ),
      );
    }
    final starting = draft.isSoccer
        ? _buildRecoveredSoccerStarting(roster)
        : _buildRecoveredBaseballStarting(roster);
    final startingIds = starting.map(_fantasyTeamPlayerIdentity).toSet();
    final bench = roster
        .where(
          (player) => !startingIds.contains(_fantasyTeamPlayerIdentity(player)),
        )
        .toList();
    final entry = draftOrderEntries[teamIdx];
    teams.add(
      _FantasyTeamState(
        uid: entry.uid,
        teamName: entry.displayName,
        roster: roster,
        starting: starting,
        bench: bench,
      ),
    );
  }

  final pairings = draftOrderEntries
      .map((entry) => (uid: entry.uid, name: entry.displayName))
      .toList();
  var rotation = [...pairings];
  final hasBye = rotation.length.isOdd;
  if (hasBye) {
    rotation = [...rotation, (uid: '__bye__', name: 'BYE')];
  }
  final baseRounds = <List<_FantasyScheduleMatchup>>[];
  final roundsPerCycle = rotation.length - 1;
  for (int round = 0; round < roundsPerCycle; round++) {
    final roundPairings = <_FantasyScheduleMatchup>[];
    for (int i = 0; i < rotation.length / 2; i++) {
      final home = rotation[i];
      final away = rotation[rotation.length - 1 - i];
      if (home.uid == '__bye__' || away.uid == '__bye__') continue;
      roundPairings.add(
        _FantasyScheduleMatchup(
          round: round + 1,
          homeUid: round.isEven ? home.uid : away.uid,
          homeTeam: round.isEven ? home.name : away.name,
          awayUid: round.isEven ? away.uid : home.uid,
          awayTeam: round.isEven ? away.name : home.name,
        ),
      );
    }
    baseRounds.add(roundPairings);
    rotation = [
      rotation.first,
      rotation.last,
      ...rotation.sublist(1, rotation.length - 1),
    ];
  }

  final schedule = <_FantasyScheduleMatchup>[];
  for (int round = 1; round <= max(1, draft.roundCount); round++) {
    final cycleIndex = (round - 1) % baseRounds.length;
    final cycleNumber = (round - 1) ~/ baseRounds.length;
    for (final matchup in baseRounds[cycleIndex]) {
      final flip = cycleNumber.isOdd;
      schedule.add(
        _FantasyScheduleMatchup(
          round: round,
          homeUid: flip ? matchup.awayUid : matchup.homeUid,
          homeTeam: flip ? matchup.awayTeam : matchup.homeTeam,
          awayUid: flip ? matchup.homeUid : matchup.awayUid,
          awayTeam: flip ? matchup.homeTeam : matchup.awayTeam,
        ),
      );
    }
  }

  return _RecoveredFantasyPayload(
    board: board,
    teams: teams,
    schedule: schedule,
  );
}

String _fantasyMyTeamName({required bool isSoccer}) =>
    isSoccer ? 'Blue Foxes' : 'Seoul Sluggers';

List<_FantasyLeagueStanding> _fantasyLeagueStandings({required bool isSoccer}) {
  // NOTE: This is mock data until we plug in a backend + real-time scoring.
  return isSoccer
      ? const [
          _FantasyLeagueStanding(team: 'Blue Foxes', pts: 38),
          _FantasyLeagueStanding(team: 'Red Bears', pts: 36),
          _FantasyLeagueStanding(team: 'White Tigers', pts: 34),
          _FantasyLeagueStanding(team: 'Green Hawks', pts: 32),
          _FantasyLeagueStanding(team: 'Sky Giants', pts: 29),
          _FantasyLeagueStanding(team: 'Orange Wolves', pts: 27),
          _FantasyLeagueStanding(team: 'Mint Dolphins', pts: 25),
          _FantasyLeagueStanding(team: 'Purple Knights', pts: 23),
          _FantasyLeagueStanding(team: 'Silver Sharks', pts: 20),
          _FantasyLeagueStanding(team: 'Golden Owls', pts: 18),
        ]
      : const [
          _FantasyLeagueStanding(team: 'Seoul Sluggers', pts: 52),
          _FantasyLeagueStanding(team: 'Busan Bombers', pts: 50),
          _FantasyLeagueStanding(team: 'Daegu Titans', pts: 48),
          _FantasyLeagueStanding(team: 'Incheon Waves', pts: 47),
          _FantasyLeagueStanding(team: 'Daejeon Rockets', pts: 45),
          _FantasyLeagueStanding(team: 'Suwon Knights', pts: 43),
          _FantasyLeagueStanding(team: 'Gwangju Sparks', pts: 40),
          _FantasyLeagueStanding(team: 'Jeju Mariners', pts: 38),
          _FantasyLeagueStanding(team: 'Ulsan Bulls', pts: 36),
          _FantasyLeagueStanding(team: 'Anyang Bears', pts: 34),
        ];
}

String _fantasyRankText({required bool isSoccer}) {
  final rows = _fantasyLeagueStandings(isSoccer: isSoccer);
  final myTeam = _fantasyMyTeamName(isSoccer: isSoccer);
  final idx = rows.indexWhere((r) => r.team == myTeam);
  final rank = idx < 0 ? '-' : '${idx + 1}위';
  return '$rank / ${rows.length}팀';
}

class LeagueItHomePage extends StatefulWidget {
  const LeagueItHomePage({super.key});

  @override
  State<LeagueItHomePage> createState() => LeagueItHomePageState();
}

class LeagueItHomePageState extends State<LeagueItHomePage>
    with TickerProviderStateMixin, RouteAware {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _launchController;
  late Animation<double> _launchOpacity;
  late Animation<double> _launchScale;
  late Animation<Offset> _launchSlide;
  bool _showLaunchIntro = false;
  static bool _didPlayLaunchIntro = false;
  late final TextEditingController _searchController;
  late final ScrollController _suggestionsScrollController;
  late Future<Map<String, dynamic>> _leagueFuture;
  late Future<Map<String, dynamic>> _kboLeagueFuture;

  bool _isMenuOpen = false;
  bool _isMyPageOpen = false;
  bool _isLoggedIn = false;
  String _lastAvatarCacheAuthUid = '';
  bool _hasSoccerLeague = false;
  bool _hasBaseballLeague = false;
  bool _frontLeagueIsSoccer = true;
  String? _selectedHomeSoccerLeagueId;
  String? _selectedHomeBaseballLeagueId;
  bool _suggestionsVisible = false;
  List<_HomeSearchSuggestion> _suggestions = [];
  DateTime? _draftTime;
  String? _draftLeagueName;
  Timer? _draftTimer;
  Timer? _kboLiveRefreshTimer;
  Future<void>? _visibleHomeKboRefreshFuture;
  DateTime? _lastVisibleHomeKboRefreshAt;
  bool _backgroundLiveRefreshSuspended = false;
  Duration _draftRemaining = Duration.zero;
  List<_JoinedDraft> _joinedDrafts = const [];
  final Set<String> _recoveringFantasyLeagueIds = <String>{};
  final Set<String> _cancelingUnfilledLeagueIds = <String>{};
  bool _isRefreshingFantasySoccerScores = false;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _incomingLeagueLinkSub;
  String? _pendingInviteCodeFromLink;
  String? _lastHandledLeagueLink;
  bool _isHandlingInviteCodeFromLink = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _joinedDraftsSub;
  final FlutterSecureStorage _localStateStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accountName: 'leagueit_local_state'),
  );
  static const String _kHasSoccerLeagueKey = 'home.has_soccer_league';
  static const String _kHasBaseballLeagueKey = 'home.has_baseball_league';
  static const String _kDraftTimeKey = 'home.draft_time';
  static const String _kDraftNameKey = 'home.draft_name';

  void setBackgroundLiveRefreshSuspended(bool suspended) {
    _backgroundLiveRefreshSuspended = suspended;
  }

  static const String _kFrontLeagueKey = 'home.front_is_soccer';
  static const String _kSelectedHomeSoccerLeagueKey =
      'home.selected_soccer_league';
  static const String _kSelectedHomeBaseballLeagueKey =
      'home.selected_baseball_league';
  static const String _kJoinedDraftsKey = 'home.joined_drafts.v1';
  final GlobalKey _homeTitleKey = GlobalKey();
  // Keep false in normal app flow. When true, login/league state is randomized
  // for UI demos and can look like "mock login".
  static const bool _demoRandomState = false;
  static const List<String> _demoLeagueNames = [
    'K League Masters',
    'Weekend Warriors',
    'Fantasy 12',
    'Sunday League',
  ];
  List<_HomeSearchSuggestion> _playerDirectory = const [];

  bool get isLoggedIn => _isLoggedIn;
  bool get hasSoccerLeague => _hasSoccerLeague;
  bool get hasBaseballLeague => _hasBaseballLeague;
  // Back-compat: treat "hasLeague" as soccer league for existing callers.
  bool get hasLeague => _hasSoccerLeague;
  List<_JoinedDraft> get joinedDrafts {
    final now = DateTime.now();
    final all =
        _joinedDrafts
            .where((draft) => !_isUnfilledDraftCanceledAt(draft, now))
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    return List.unmodifiable(all);
  }

  List<_JoinedDraft> get visibleDraftEntries {
    final now = DateTime.now();
    final visible = _activeJoinedDraftsAt(now)
      ..sort((a, b) => a.when.compareTo(b.when));
    return List.unmodifiable(visible);
  }

  _JoinedDraft? get primaryDraft {
    final now = DateTime.now();
    final visible = _activeJoinedDraftsAt(now);
    if (visible.isEmpty) return null;
    final upcoming = visible.where((d) => d.when.isAfter(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    if (upcoming.isNotEmpty) return upcoming.first;
    return visible.first;
  }

  _JoinedDraft? fantasyDraftForSport(bool isSoccer) {
    final candidates = _homeDraftOptionsForSport(isSoccer);
    return _preferredHomeDraftFromCandidates(
      candidates,
      selectedLeagueId: _selectedHomeLeagueIdForSport(isSoccer),
    );
  }

  _FantasyMatchupView? currentFantasyMatchupForSport(bool isSoccer) {
    final draft = fantasyDraftForSport(isSoccer);
    if (draft == null) return null;
    return _currentFantasyMatchupForDraft(draft);
  }

  List<_JoinedDraft> _homeDraftOptionsForSport(bool isSoccer) {
    final drafts =
        joinedDrafts
            .where(
              (draft) =>
                  draft.isSoccer == isSoccer &&
                  draft.fantasyReady &&
                  draft.fantasyTeams.isNotEmpty &&
                  draft.fantasySchedule.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    return List.unmodifiable(drafts);
  }

  List<_JoinedDraft> _activeJoinedDraftsAt(DateTime now) {
    return _joinedDrafts
        .where(
          (draft) =>
              !_isDraftExpiredAt(draft, now) &&
              !_isUnfilledDraftCanceledAt(draft, now),
        )
        .toList();
  }

  _JoinedDraft? _homeDraftForSportFrom(
    Iterable<_JoinedDraft> drafts,
    bool isSoccer, {
    String? selectedLeagueId,
  }) {
    final candidates =
        drafts
            .where(
              (draft) =>
                  draft.isSoccer == isSoccer &&
                  draft.fantasyReady &&
                  draft.fantasyTeams.isNotEmpty &&
                  draft.fantasySchedule.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    return _preferredHomeDraftFromCandidates(
      candidates,
      selectedLeagueId: selectedLeagueId,
    );
  }

  _JoinedDraft? _preferredHomeDraftFromCandidates(
    List<_JoinedDraft> candidates, {
    String? selectedLeagueId,
  }) {
    if (candidates.isEmpty) return null;
    final normalizedSelectedLeagueId = selectedLeagueId?.trim() ?? '';
    _JoinedDraft? selectedDraft;
    if (normalizedSelectedLeagueId.isNotEmpty) {
      for (final draft in candidates) {
        if (draft.leagueId == normalizedSelectedLeagueId) {
          selectedDraft = draft;
          break;
        }
      }
    }
    if (selectedDraft != null &&
        _currentFantasyMatchupForDraft(selectedDraft) != null) {
      return selectedDraft;
    }
    for (final draft in candidates) {
      if (_currentFantasyMatchupForDraft(draft) != null) {
        return draft;
      }
    }
    return selectedDraft ?? candidates.first;
  }

  Future<void> _refreshVisibleHomeKboRoundPoints({bool forceRefresh = false}) {
    final inFlight = _visibleHomeKboRefreshFuture;
    if (inFlight != null) return inFlight;

    final lastRanAt = _lastVisibleHomeKboRefreshAt;
    if (!forceRefresh &&
        lastRanAt != null &&
        DateTime.now().difference(lastRanAt) < const Duration(seconds: 5)) {
      return Future<void>.value();
    }

    final future =
        () async {
          final draft = fantasyDraftForSport(false);
          if (draft == null || draft.isSoccer) return;
          await _refreshVisibleHomeKboRoundPointsForDraft(
            draft,
            forceRefresh: forceRefresh,
          );
          _lastVisibleHomeKboRefreshAt = DateTime.now();
        }().whenComplete(() {
          _visibleHomeKboRefreshFuture = null;
        });
    _visibleHomeKboRefreshFuture = future;
    return future;
  }

  Future<void> _refreshVisibleHomeKboRoundPointsForDraft(
    _JoinedDraft draft, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final round = _currentFantasyRoundAt(draft, now);
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, round);
    if (!_kboFantasyRoundHasStarted(draft, round, now)) return;
    if (_shouldFreezeUnlockedKboRoundScore(draft, round, now: now)) {
      await _ensureUnlockedKboMatchupScoreSnapshotsForDraft(draft);
      return;
    }
    final matchup = _currentFantasyMatchupForDraft(draft);
    if (matchup == null) return;

    final slots = <String, _PlayerSlot>{};
    for (final team in [matchup.myTeam, matchup.opponent]) {
      for (final player in team.starting) {
        final slot = player.toPlayerSlot();
        slots[_playerSlotIdentity(slot)] = slot;
      }
    }
    if (slots.isEmpty) return;

    final visibleSlots = slots.values.toList(growable: false);
    const batchSize = 4;
    for (int index = 0; index < visibleSlots.length; index += batchSize) {
      final batch = visibleSlots.skip(index).take(batchSize);
      await Future.wait(
        batch.map(
          (slot) => _loadKboRoundPointsForPlayerShared(
            playerName: slot.name,
            club: _normalizeKboDraftClub(slot.club),
            preferredNumber: slot.number,
            preferredPosition: slot.position,
            forceRefresh: forceRefresh,
            targetRounds: <int>{absoluteRound},
            logFailures: false,
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  bool _isSameFantasyTeamState(_FantasyTeamState a, _FantasyTeamState b) {
    return (a.uid.isNotEmpty && b.uid.isNotEmpty && a.uid == b.uid) ||
        a.teamName == b.teamName;
  }

  _JoinedDraft _draftWithUpdatedFantasyTeamState(
    _JoinedDraft draft,
    _FantasyTeamState updatedTeam,
  ) {
    final updatedTeams = draft.fantasyTeams.map((team) {
      return _isSameFantasyTeamState(team, updatedTeam) ? updatedTeam : team;
    }).toList();
    return _JoinedDraft(
      leagueId: draft.leagueId,
      leagueName: draft.leagueName,
      when: draft.when,
      isSoccer: draft.isSoccer,
      teamCount: draft.teamCount,
      roundCount: draft.roundCount,
      memberCount: draft.memberCount,
      inviteCode: draft.inviteCode,
      ownerId: draft.ownerId,
      draftOrder: draft.draftOrder,
      fantasyReady: draft.fantasyReady,
      fantasyTeams: updatedTeams,
      fantasySchedule: draft.fantasySchedule,
      draftBoard: draft.draftBoard,
    );
  }

  Future<_JoinedDraft> _captureUnlockedKboMatchupScoreSnapshotsForDraft(
    _JoinedDraft draft,
  ) async {
    final now = DateTime.now();
    final round = _currentFantasyRoundAt(draft, now);
    final absoluteRound = _mappedKboRoundForFantasyRound(draft, round);
    if (!_shouldFreezeUnlockedKboRoundScore(draft, round, now: now)) {
      return draft;
    }

    final matchup = _currentFantasyMatchupForDraft(draft);
    if (matchup == null) return draft;

    final pendingTeams = [matchup.myTeam, matchup.opponent]
        .where(
          (team) =>
              _kboUnlockedRoundScoreSnapshotForTeam(
                team,
                draft: draft,
                round: round,
                now: now,
              ) ==
              null,
        )
        .toList();
    if (pendingTeams.isEmpty) return draft;

    await _loadCachedKboLeagueData();
    final slots = <String, _PlayerSlot>{};
    for (final team in pendingTeams) {
      for (final player in team.starting) {
        final slot = player.toPlayerSlot();
        slots[_playerSlotIdentity(slot)] = slot;
      }
    }
    const batchSize = 4;
    final values = slots.values.toList(growable: false);
    for (int index = 0; index < values.length; index += batchSize) {
      final batch = values.skip(index).take(batchSize);
      await Future.wait(
        batch.map(
          (slot) => _loadKboRoundPointsForPlayerShared(
            playerName: slot.name,
            club: _normalizeKboDraftClub(slot.club),
            preferredNumber: slot.number,
            preferredPosition: slot.position,
            targetRounds: <int>{absoluteRound},
            logFailures: false,
          ),
        ),
      );
    }

    final unlockedAt =
        _fantasyRosterLockStateForDraft(
          draft,
          now: now,
        ).unlocksAtUtc?.toUtc() ??
        now.toUtc();
    var updatedDraft = draft;
    for (final originalTeam in pendingTeams) {
      final team =
          updatedDraft.fantasyTeams.cast<_FantasyTeamState?>().firstWhere(
            (candidate) =>
                candidate != null &&
                _isSameFantasyTeamState(candidate, originalTeam),
            orElse: () => null,
          ) ??
          originalTeam;
      final existingState = _kboRoundScoreStateForTeam(team, round);
      final nextState = _KboFantasyRoundScoreState(
        round: round,
        bankedScore: existingState?.bankedScore ?? 0.0,
        starterBaselines: Map<String, double>.from(
          existingState?.starterBaselines ?? const <String, double>{},
        ),
        updatedAt: now.toUtc(),
        unlockedScoreSnapshot: _fantasyTeamRoundScore(
          team,
          round,
          isSoccer: false,
          draft: updatedDraft,
        ),
        unlockedAt: unlockedAt,
      );
      final updatedTeam = _FantasyTeamState(
        uid: team.uid,
        teamName: team.teamName,
        roster: team.roster,
        starting: team.starting,
        bench: team.bench,
        captainName: team.captainName,
        viceCaptainName: team.viceCaptainName,
        captainPlayerId: team.captainPlayerId,
        viceCaptainPlayerId: team.viceCaptainPlayerId,
        kboRoundScoreStates: [
          for (final state in team.kboRoundScoreStates)
            if (state.round != round) state,
          nextState,
        ]..sort((a, b) => a.round.compareTo(b.round)),
      );
      updatedDraft = _draftWithUpdatedFantasyTeamState(
        updatedDraft,
        updatedTeam,
      );
    }
    return updatedDraft;
  }

  Future<_JoinedDraft> _ensureUnlockedKboMatchupScoreSnapshotsForDraft(
    _JoinedDraft draft, {
    bool persist = true,
  }) async {
    final updatedDraft = await _captureUnlockedKboMatchupScoreSnapshotsForDraft(
      draft,
    );
    if (!persist || identical(updatedDraft, draft)) return updatedDraft;
    if (!mounted) return updatedDraft;
    setState(() {
      _upsertJoinedDraft(updatedDraft);
      _setPrimaryDraftFromJoinedDrafts();
    });
    await _saveLocalState();
    return updatedDraft;
  }

  String? _selectedHomeLeagueIdForSport(bool isSoccer) =>
      isSoccer ? _selectedHomeSoccerLeagueId : _selectedHomeBaseballLeagueId;

  void _setSelectedHomeLeagueIdForSport(bool isSoccer, String? leagueId) {
    setState(() {
      if (isSoccer) {
        _selectedHomeSoccerLeagueId = leagueId;
      } else {
        _selectedHomeBaseballLeagueId = leagueId;
      }
    });
    unawaited(_saveLocalState());
  }

  void _sanitizeSelectedHomeLeagues() {
    final soccerOptions = _homeDraftOptionsForSport(true);
    final baseballOptions = _homeDraftOptionsForSport(false);

    if (_selectedHomeSoccerLeagueId != null &&
        soccerOptions.every(
          (draft) => draft.leagueId != _selectedHomeSoccerLeagueId,
        )) {
      _selectedHomeSoccerLeagueId = soccerOptions.isEmpty
          ? null
          : soccerOptions.first.leagueId;
    } else if (_selectedHomeSoccerLeagueId == null &&
        soccerOptions.length == 1) {
      _selectedHomeSoccerLeagueId = soccerOptions.first.leagueId;
    }

    if (_selectedHomeBaseballLeagueId != null &&
        baseballOptions.every(
          (draft) => draft.leagueId != _selectedHomeBaseballLeagueId,
        )) {
      _selectedHomeBaseballLeagueId = baseballOptions.isEmpty
          ? null
          : baseballOptions.first.leagueId;
    } else if (_selectedHomeBaseballLeagueId == null &&
        baseballOptions.length == 1) {
      _selectedHomeBaseballLeagueId = baseballOptions.first.leagueId;
    }
  }

  Future<void> _refreshFantasySoccerScores({
    bool includeHistory = false,
    bool forceRefreshLiveData = false,
  }) async {
    if (_isRefreshingFantasySoccerScores) return;
    final soccerDrafts = _joinedDrafts
        .where(
          (draft) =>
              draft.isSoccer &&
              draft.fantasyReady &&
              draft.fantasyTeams.isNotEmpty &&
              draft.fantasySchedule.isNotEmpty,
        )
        .toList();
    if (soccerDrafts.isEmpty) return;

    _isRefreshingFantasySoccerScores = true;
    try {
      if (forceRefreshLiveData) {
        await _loadCachedKLeagueLeagueData(forceRefresh: true);
      }
      for (final draft in soccerDrafts) {
        final currentRound = _currentFantasyRoundAt(draft, DateTime.now());
        final rounds = includeHistory
            ? <int>[for (int round = 1; round <= currentRound; round++) round]
            : <int>[currentRound];
        for (final round in rounds) {
          await _ensureFantasySoccerRoundScoreSnapshot(
            draft,
            round,
            force: round == currentRound,
            forceRefreshLiveData: forceRefreshLiveData && round == currentRound,
          );
        }
      }
      unawaited(_persistFantasySoccerRoundScoreCache());
      if (!mounted) return;
      setState(() {});
    } catch (e, st) {
      debugPrint('refreshFantasySoccerScores failed: $e');
      debugPrint('$st');
    } finally {
      _isRefreshingFantasySoccerScores = false;
    }
  }

  String _userStateKey(String key) {
    final uid = authController.session?.accessToken ?? 'anonymous';
    return '$uid.$key';
  }

  String _userStateKeyForUid(String uid, String key) {
    final normalizedUid = uid.trim();
    final effectiveUid = normalizedUid.isEmpty ? 'anonymous' : normalizedUid;
    return '$effectiveUid.$key';
  }

  Future<void> _safeWriteLocalState({
    required String key,
    required String value,
  }) async {
    try {
      await _localStateStorage.write(key: key, value: value);
    } on PlatformException catch (e) {
      // iOS keychain can throw -25299("item already exists") on write.
      final code = e.code.toString();
      final raw = '${e.message} ${e.details}'.toLowerCase();
      final isDuplicate =
          code.contains('-25299') ||
          raw.contains('already exists') ||
          raw.contains('-25299') ||
          raw.contains('keychain');
      if (!isDuplicate) rethrow;

      await _localStateStorage.delete(key: key);
      await _localStateStorage.write(key: key, value: value);
    }
  }

  Future<void> _saveLocalState() async {
    if (!_isLoggedIn) return;
    await _safeWriteLocalState(
      key: _userStateKey(_kHasSoccerLeagueKey),
      value: _hasSoccerLeague ? '1' : '0',
    );
    await _safeWriteLocalState(
      key: _userStateKey(_kHasBaseballLeagueKey),
      value: _hasBaseballLeague ? '1' : '0',
    );
    await _safeWriteLocalState(
      key: _userStateKey(_kFrontLeagueKey),
      value: _frontLeagueIsSoccer ? '1' : '0',
    );
    if (_joinedDrafts.isEmpty) {
      await _localStateStorage.delete(key: _userStateKey(_kJoinedDraftsKey));
    } else {
      await _safeWriteLocalState(
        key: _userStateKey(_kJoinedDraftsKey),
        value: jsonEncode({
          'drafts': _joinedDrafts.map((draft) => draft.toMap()).toList(),
        }),
      );
    }
    if ((_selectedHomeSoccerLeagueId ?? '').isEmpty) {
      await _localStateStorage.delete(
        key: _userStateKey(_kSelectedHomeSoccerLeagueKey),
      );
    } else {
      await _safeWriteLocalState(
        key: _userStateKey(_kSelectedHomeSoccerLeagueKey),
        value: _selectedHomeSoccerLeagueId!,
      );
    }
    if ((_selectedHomeBaseballLeagueId ?? '').isEmpty) {
      await _localStateStorage.delete(
        key: _userStateKey(_kSelectedHomeBaseballLeagueKey),
      );
    } else {
      await _safeWriteLocalState(
        key: _userStateKey(_kSelectedHomeBaseballLeagueKey),
        value: _selectedHomeBaseballLeagueId!,
      );
    }
    if (_draftTime == null) {
      await _localStateStorage.delete(key: _userStateKey(_kDraftTimeKey));
      await _localStateStorage.delete(key: _userStateKey(_kDraftNameKey));
      return;
    }
    await _safeWriteLocalState(
      key: _userStateKey(_kDraftTimeKey),
      value: _draftTime!.toIso8601String(),
    );
    await _safeWriteLocalState(
      key: _userStateKey(_kDraftNameKey),
      value: _draftLeagueName ?? '',
    );
  }

  Future<void> _restoreLocalState() async {
    if (!_isLoggedIn) return;

    final soccerRaw = await _localStateStorage.read(
      key: _userStateKey(_kHasSoccerLeagueKey),
    );
    final baseballRaw = await _localStateStorage.read(
      key: _userStateKey(_kHasBaseballLeagueKey),
    );
    final frontRaw = await _localStateStorage.read(
      key: _userStateKey(_kFrontLeagueKey),
    );
    final joinedDraftsRaw = await _localStateStorage.read(
      key: _userStateKey(_kJoinedDraftsKey),
    );
    final selectedSoccerLeagueIdRaw = await _localStateStorage.read(
      key: _userStateKey(_kSelectedHomeSoccerLeagueKey),
    );
    final selectedBaseballLeagueIdRaw = await _localStateStorage.read(
      key: _userStateKey(_kSelectedHomeBaseballLeagueKey),
    );
    final draftTimeRaw = await _localStateStorage.read(
      key: _userStateKey(_kDraftTimeKey),
    );
    final draftNameRaw = await _localStateStorage.read(
      key: _userStateKey(_kDraftNameKey),
    );

    final bool hasSavedLeagueFlags = soccerRaw != null || baseballRaw != null;

    // Backward-compat default: if user is logged in and no prior local league
    // state exists, show soccer matchup card so the home does not look logged out.
    final bool soccer = hasSavedLeagueFlags ? soccerRaw == '1' : true;
    final bool baseball = hasSavedLeagueFlags ? baseballRaw == '1' : false;
    final bool frontSoccer = frontRaw == null
        ? _frontLeagueIsSoccer
        : frontRaw == '1';
    final DateTime? savedDraftTime = DateTime.tryParse(draftTimeRaw ?? '');
    final restoredDrafts = _restoreJoinedDraftsFromLocalJson(joinedDraftsRaw);
    final resolvedSoccer = restoredDrafts.any((draft) => draft.isSoccer)
        ? true
        : soccer;
    final resolvedBaseball = restoredDrafts.any((draft) => !draft.isSoccer)
        ? true
        : baseball;

    if (!mounted) return;
    setState(() {
      _joinedDrafts = restoredDrafts;
      _hasSoccerLeague = resolvedSoccer;
      _hasBaseballLeague = resolvedBaseball;
      _frontLeagueIsSoccer = frontSoccer;
      _selectedHomeSoccerLeagueId = selectedSoccerLeagueIdRaw;
      _selectedHomeBaseballLeagueId = selectedBaseballLeagueIdRaw;
      _draftTime = savedDraftTime;
      _draftLeagueName = savedDraftTime == null
          ? null
          : (draftNameRaw ?? 'My League');
      _sanitizeSelectedHomeLeagues();
    });
    _startDraftTimer();
    _listenJoinedDrafts();
    await _saveLocalState();
  }

  Future<void> clearPersistedLocalStateForUid(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    final keys = <String>[
      _kHasSoccerLeagueKey,
      _kHasBaseballLeagueKey,
      _kFrontLeagueKey,
      _kJoinedDraftsKey,
      _kSelectedHomeSoccerLeagueKey,
      _kSelectedHomeBaseballLeagueKey,
      _kDraftTimeKey,
      _kDraftNameKey,
    ];
    for (final key in keys) {
      await _localStateStorage.delete(
        key: _userStateKeyForUid(normalizedUid, key),
      );
    }
  }

  List<_JoinedDraft> _restoreJoinedDraftsFromLocalJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      final entries = _fixtureAsList(_fixtureAsMap(decoded)['drafts']);
      final result = <_JoinedDraft>[];
      for (final entry in entries) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final when = DateTime.tryParse('${map['when'] ?? ''}');
        if (when == null) continue;
        final isSoccer = map['isSoccer'] != false;
        result.add(
          _JoinedDraft(
            leagueId: '${map['leagueId'] ?? ''}',
            leagueName: '${map['leagueName'] ?? 'My League'}',
            when: when,
            isSoccer: isSoccer,
            teamCount: map['teamCount'] is int
                ? map['teamCount'] as int
                : int.tryParse('${map['teamCount'] ?? 8}') ?? 8,
            roundCount: map['roundCount'] is int
                ? map['roundCount'] as int
                : int.tryParse('${map['roundCount'] ?? 1}') ?? 1,
            memberCount: map['memberCount'] is int
                ? map['memberCount'] as int
                : int.tryParse('${map['memberCount'] ?? 1}') ?? 1,
            inviteCode: '${map['inviteCode'] ?? ''}',
            ownerId: '${map['ownerId'] ?? ''}',
            draftOrder: _parseDraftOrder(map['draftOrder']),
            fantasyReady: map['fantasyReady'] == true,
            fantasyTeams: _parseFantasyTeams(
              map['fantasyTeams'],
              isSoccer: isSoccer,
            ),
            fantasySchedule: _parseFantasySchedule(map['fantasySchedule']),
            draftBoard: _parseDraftBoard(map['draftBoard'], isSoccer: isSoccer),
          ),
        );
      }
      result.sort((a, b) => a.when.compareTo(b.when));
      return result;
    } catch (error, stackTrace) {
      debugPrint('restoreJoinedDraftsFromLocalJson failed: $error');
      debugPrint('$stackTrace');
      return const [];
    }
  }

  void updateLogin(bool value) {
    if (value) {
      if (mounted && _isLoggedIn != authController.isLoggedIn) {
        setState(() => _isLoggedIn = authController.isLoggedIn);
      }
      unawaited(_restoreLocalState());
      return;
    }
    if (!value) {
      unawaited(authController.signOut());
    }
  }

  void setHasLeague(bool value) {
    // Back-compat: sets soccer league.
    setState(() => _hasSoccerLeague = value);
    unawaited(_saveLocalState());
  }

  bool hasLeagueForSport(bool isSoccer) =>
      isSoccer ? _hasSoccerLeague : _hasBaseballLeague;

  void setHasLeagueForSport(bool isSoccer, bool value) {
    setState(() {
      if (isSoccer) {
        _hasSoccerLeague = value;
      } else {
        _hasBaseballLeague = value;
      }
    });
    unawaited(_saveLocalState());
  }

  void closePanels() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
  }

  void resetHomeUI() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
    _searchController.clear();
  }

  void setDraft(
    DateTime when,
    String name, {
    bool markLeague = true,
    bool isSoccer = true,
  }) {
    setState(() {
      _draftTime = when;
      _draftLeagueName = name;
      _upsertJoinedDraft(
        _JoinedDraft(
          leagueId: '',
          leagueName: name,
          when: when,
          isSoccer: isSoccer,
        ),
      );
      if (markLeague) {
        if (isSoccer) {
          _hasSoccerLeague = true;
        } else {
          _hasBaseballLeague = true;
        }
      }
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  void addOrUpdateJoinedDraft(_JoinedDraft draft) {
    setState(() {
      _upsertJoinedDraft(draft);
      _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
      _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
      _sanitizeSelectedHomeLeagues();
      _setPrimaryDraftFromJoinedDrafts();
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  void applyFantasyDisplayNameForUser({
    required String uid,
    required String teamName,
  }) {
    final normalizedUid = uid.trim();
    final normalizedTeamName = teamName.trim();
    if (normalizedUid.isEmpty || normalizedTeamName.isEmpty) return;

    setState(() {
      _joinedDrafts =
          _joinedDrafts
              .map(
                (draft) => _joinedDraftWithRenamedFantasyIdentity(
                  draft,
                  uid: normalizedUid,
                  teamName: normalizedTeamName,
                ),
              )
              .toList()
            ..sort((a, b) => a.when.compareTo(b.when));
      _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
      _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
      _sanitizeSelectedHomeLeagues();
      _setPrimaryDraftFromJoinedDrafts();
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  void _applyCurrentUserFantasyDisplayNameIfAvailable() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final teamName = _currentSignedInFantasyDisplayName();
    if (uid.isEmpty || teamName.isEmpty) return;
    applyFantasyDisplayNameForUser(uid: uid, teamName: teamName);
  }

  void _upsertJoinedDraft(_JoinedDraft draft) {
    final next = List<_JoinedDraft>.from(_joinedDrafts);
    final idx = next.indexWhere(
      (d) =>
          (draft.leagueId.isNotEmpty &&
              d.leagueId.isNotEmpty &&
              d.leagueId == draft.leagueId) ||
          (d.leagueName == draft.leagueName && d.isSoccer == draft.isSoccer),
    );
    if (idx >= 0) {
      next[idx] = draft;
    } else {
      next.add(draft);
    }
    next.sort((a, b) => a.when.compareTo(b.when));
    _joinedDrafts = next;
  }

  void removeJoinedDraftByLeagueId(String leagueId) {
    if (leagueId.isEmpty) return;

    final next = _joinedDrafts.where((d) => d.leagueId != leagueId).toList()
      ..sort((a, b) => a.when.compareTo(b.when));

    setState(() {
      _joinedDrafts = next;
      _hasSoccerLeague = next.any((d) => d.isSoccer);
      _hasBaseballLeague = next.any((d) => !d.isSoccer);
      _sanitizeSelectedHomeLeagues();
      _setPrimaryDraftFromJoinedDrafts();
    });
    _startDraftTimer();
    unawaited(_saveLocalState());
  }

  Future<void> _cleanupCanceledUnfilledDraft(_JoinedDraft draft) async {
    if (draft.leagueId.isEmpty) return;
    if (_cancelingUnfilledLeagueIds.contains(draft.leagueId)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || draft.ownerId != user.uid) return;

    _cancelingUnfilledLeagueIds.add(draft.leagueId);
    try {
      await LeagueService.instance.deleteLeague(draft.leagueId);
    } catch (e, st) {
      debugPrint(
        'cleanupCanceledUnfilledDraft failed for ${draft.leagueId}: $e',
      );
      debugPrint('$st');
    } finally {
      _cancelingUnfilledLeagueIds.remove(draft.leagueId);
    }
  }

  void _listenJoinedDrafts() {
    _joinedDraftsSub?.cancel();
    if (!_isLoggedIn) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _joinedDraftsSub = FirebaseFirestore.instance
        .collection('leagues')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.docs.any((doc) => _parseIsSoccerLeague(doc.data()))) {
              await _loadCachedKLeagueLeagueData();
            }
            final drafts = <_JoinedDraft>[];
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final when = _parseDraftDate(data);
              if (when == null) continue;
              final name = (data['name'] as String?)?.trim().isNotEmpty == true
                  ? (data['name'] as String).trim()
                  : 'My League';
              final isSoccer = _parseIsSoccerLeague(data);
              final members = List<String>.from(
                (data['members'] as List<dynamic>? ?? const []).map(
                  (e) => '$e',
                ),
              );
              final draft = _JoinedDraft(
                leagueId: doc.id,
                leagueName: name,
                when: when,
                isSoccer: isSoccer,
                teamCount: _parseTeamCount(data),
                roundCount: _parseRoundCount(data, isSoccer, when),
                memberCount: members.length,
                inviteCode: '${data['inviteCode'] ?? ''}',
                ownerId: '${data['ownerId'] ?? ''}',
                draftOrder: _parseDraftOrder(data['draftOrder']),
                fantasyReady: data['fantasyReady'] == true,
                fantasyTeams: _parseFantasyTeams(
                  data['fantasyTeams'],
                  isSoccer: isSoccer,
                ),
                fantasySchedule: _parseFantasySchedule(data['fantasySchedule']),
                draftBoard: _parseDraftBoard(
                  data['draftBoard'],
                  isSoccer: isSoccer,
                ),
              );
              drafts.add(draft);
            }
            final now = DateTime.now();
            final canceledUnfilledDrafts = drafts
                .where((draft) => _isUnfilledDraftCanceledAt(draft, now))
                .toList();
            final activeDrafts =
                drafts
                    .where((draft) => !_isUnfilledDraftCanceledAt(draft, now))
                    .toList()
                  ..sort((a, b) => a.when.compareTo(b.when));
            drafts.sort((a, b) => a.when.compareTo(b.when));
            if (activeDrafts.any((draft) => !draft.isSoccer)) {
              await _restorePersistedKLeaguePlayerRoundPointsCache();
              final visibleBaseballDraft = _homeDraftForSportFrom(
                activeDrafts,
                false,
                selectedLeagueId: _selectedHomeBaseballLeagueId,
              );
              if (visibleBaseballDraft != null) {
                final updatedVisibleBaseballDraft =
                    await _ensureUnlockedKboMatchupScoreSnapshotsForDraft(
                      visibleBaseballDraft,
                      persist: false,
                    );
                if (!identical(
                  updatedVisibleBaseballDraft,
                  visibleBaseballDraft,
                )) {
                  final index = activeDrafts.indexWhere(
                    (draft) =>
                        draft.leagueId == visibleBaseballDraft.leagueId &&
                        draft.isSoccer == visibleBaseballDraft.isSoccer,
                  );
                  if (index >= 0) {
                    activeDrafts[index] = updatedVisibleBaseballDraft;
                  }
                } else {
                  await _refreshVisibleHomeKboRoundPointsForDraft(
                    visibleBaseballDraft,
                  );
                }
              }
            }
            if (!mounted) return;
            setState(() {
              for (final draft in canceledUnfilledDrafts) {
                _draftSessionCache.remove(
                  _draftSessionKeyForJoinedDraft(draft),
                );
              }
              _joinedDrafts = activeDrafts;
              _hasSoccerLeague = activeDrafts.any((d) => d.isSoccer);
              _hasBaseballLeague = activeDrafts.any((d) => !d.isSoccer);
              _sanitizeSelectedHomeLeagues();
              _setPrimaryDraftFromJoinedDrafts();
            });
            unawaited(_refreshFantasySoccerScores());
            unawaited(_refreshVisibleHomeKboRoundPoints());
            for (final draft in canceledUnfilledDrafts) {
              unawaited(_cleanupCanceledUnfilledDraft(draft));
            }
            for (final draft in activeDrafts) {
              if (_shouldRecoverFantasyLeague(draft)) {
                unawaited(_recoverFantasyLeagueState(draft));
              }
            }
            _startDraftTimer();
            unawaited(_saveLocalState());
          },
          onError: (e, st) {
            debugPrint('watchMyDrafts error: $e');
            debugPrint('$st');
          },
        );
  }

  bool _shouldRecoverFantasyLeague(_JoinedDraft draft) {
    if (draft.leagueId.isEmpty) return false;
    if (draft.fantasyReady) return false;
    if (!_isDraftCompletedAt(draft, DateTime.now())) return false;
    return draft.draftOrder.length >= draft.teamCount && draft.teamCount > 1;
  }

  Future<void> _recoverFantasyLeagueState(_JoinedDraft draft) async {
    if (_recoveringFantasyLeagueIds.contains(draft.leagueId)) return;
    _recoveringFantasyLeagueIds.add(draft.leagueId);
    try {
      final payload = await _recoverFantasyPayloadFromDraft(draft);
      await LeagueService.instance.finalizeFantasyLeague(
        leagueId: draft.leagueId,
        draftBoard: _draftBoardToFirestoreRows(payload.board),
        fantasyTeams: payload.teams.map((team) => team.toMap()).toList(),
        fantasySchedule: payload.schedule
            .map((matchup) => matchup.toMap())
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _upsertJoinedDraft(
          _JoinedDraft(
            leagueId: draft.leagueId,
            leagueName: draft.leagueName,
            when: draft.when,
            isSoccer: draft.isSoccer,
            teamCount: draft.teamCount,
            roundCount: draft.roundCount,
            memberCount: draft.memberCount,
            inviteCode: draft.inviteCode,
            ownerId: draft.ownerId,
            draftOrder: draft.draftOrder,
            fantasyReady: true,
            fantasyTeams: payload.teams,
            fantasySchedule: payload.schedule,
            draftBoard: payload.board,
          ),
        );
        _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
        _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
        _sanitizeSelectedHomeLeagues();
        _setPrimaryDraftFromJoinedDrafts();
      });
      unawaited(_refreshFantasySoccerScores());
      _startDraftTimer();
    } catch (e, st) {
      debugPrint('recoverFantasyLeagueState failed for ${draft.leagueId}: $e');
      debugPrint('$st');
    } finally {
      _recoveringFantasyLeagueIds.remove(draft.leagueId);
    }
  }

  DateTime? _parseDraftDate(Map<String, dynamic> data) {
    final raw = data['draftDateTime'] ?? data['draftAt'] ?? data['draftTime'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  int _parseTeamCount(Map<String, dynamic> data) {
    final raw = data['teamCount'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 8;
    return 8;
  }

  int _parseRoundCount(
    Map<String, dynamic> data,
    bool isSoccer,
    DateTime? draftDate,
  ) {
    if (!isSoccer) {
      return _kboFantasyRoundCountForDraft(draftDate);
    }
    final cachedLeagueData = _cachedKLeagueLeagueData;
    final rawFixtures = _fixtureAsList(cachedLeagueData?['fixtures']);
    if (rawFixtures.isNotEmpty) {
      return _kLeagueFantasyRoundCountForDraft(draftDate, rawFixtures);
    }
    final raw = data['roundCount'];
    if (raw is int) return raw;
    if (raw is String) {
      return int.tryParse(raw) ?? _defaultFantasyRoundCount(isSoccer: true);
    }
    return _defaultFantasyRoundCount(isSoccer: true);
  }

  List<_DraftOrderEntry> _parseDraftOrder(dynamic raw) {
    final list = raw as List<dynamic>?;
    if (list == null || list.isEmpty) return const [];
    final result = <_DraftOrderEntry>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final uid = '${map['uid'] ?? ''}';
      result.add(
        _DraftOrderEntry(
          uid: uid,
          displayName: _normalizedFantasyDisplayNameForUid(
            uid,
            '${map['displayName'] ?? 'Team'}',
          ),
          slot: map['slot'] is int
              ? map['slot'] as int
              : int.tryParse('${map['slot'] ?? 0}') ?? 0,
        ),
      );
    }
    result.sort((a, b) => a.slot.compareTo(b.slot));
    return result;
  }

  bool _parseIsSoccerLeague(Map<String, dynamic> data) {
    final sport = (data['sport'] as String?)?.toLowerCase().trim();
    final name = (data['name'] as String?)?.toLowerCase().trim() ?? '';
    if (sport == null || sport.isEmpty) {
      if (name.contains('kbo') ||
          name.contains('baseball') ||
          name.contains('야구')) {
        return false;
      }
      return true;
    }
    return sport == 'soccer' ||
        sport == 'k league' ||
        sport == 'k-league' ||
        sport == 'kleague';
  }

  void _setPrimaryDraftFromJoinedDrafts() {
    final now = DateTime.now();
    final visible = _activeJoinedDraftsAt(now)
      ..sort((a, b) => a.when.compareTo(b.when));

    if (visible.isEmpty) {
      _draftTime = null;
      _draftLeagueName = null;
      _draftRemaining = Duration.zero;
      return;
    }
    final upcoming = visible.where((d) => d.when.isAfter(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));

    if (upcoming.isEmpty) {
      _draftTime = null;
      _draftLeagueName = null;
      _draftRemaining = Duration.zero;
      return;
    }

    _draftTime = upcoming.first.when;
    _draftLeagueName = upcoming.first.leagueName;
  }

  void _startDraftTimer() {
    _draftTimer?.cancel();
    if (_draftTime == null && _joinedDrafts.isEmpty) return;
    _tickDraft();
    _draftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickDraft();
    });
  }

  void _tickDraft() {
    final now = DateTime.now();
    if (!mounted) return;
    final canceledUnfilledDrafts = _joinedDrafts
        .where((draft) => _isUnfilledDraftCanceledAt(draft, now))
        .toList();
    final expiredDrafts = _joinedDrafts
        .where((draft) => _isDraftExpiredAt(draft, now))
        .toList();
    setState(() {
      if (canceledUnfilledDrafts.isNotEmpty) {
        final canceledIds = canceledUnfilledDrafts
            .map((draft) => draft.leagueId)
            .toSet();
        _joinedDrafts =
            _joinedDrafts
                .where((draft) => !canceledIds.contains(draft.leagueId))
                .toList()
              ..sort((a, b) => a.when.compareTo(b.when));
      }
      for (final draft in expiredDrafts) {
        _draftSessionCache.remove(_draftSessionKeyForJoinedDraft(draft));
      }
      _hasSoccerLeague = _joinedDrafts.any((d) => d.isSoccer);
      _hasBaseballLeague = _joinedDrafts.any((d) => !d.isSoccer);
      _sanitizeSelectedHomeLeagues();
      _setPrimaryDraftFromJoinedDrafts();
      if (_draftTime != null) {
        final remaining = _draftTime!.difference(now);
        _draftRemaining = remaining.isNegative ? Duration.zero : remaining;
      }
    });
    for (final draft in canceledUnfilledDrafts) {
      unawaited(_cleanupCanceledUnfilledDraft(draft));
    }
    if (canceledUnfilledDrafts.isNotEmpty) {
      unawaited(_saveLocalState());
    }
    if (_draftTime == null && _joinedDrafts.isEmpty) {
      _draftTimer?.cancel();
    }
  }

  void _applyDemoState() {
    final rand = Random();
    // 0: 로그아웃, 1: 로그인만(리그 없음), 2: 로그인+드래프트(리그 없음),
    // 3: 로그인+리그 보유(매치업만), 4: 로그인+리그+드래프트
    final scenario = rand.nextInt(5);
    switch (scenario) {
      case 0:
        setState(() {
          _isLoggedIn = false;
          _hasSoccerLeague = false;
          _hasBaseballLeague = false;
          _draftTime = null;
          _draftLeagueName = null;
        });
        _draftTimer?.cancel();
        return;
      case 1:
        setState(() {
          _isLoggedIn = true;
          _hasSoccerLeague = false;
          _hasBaseballLeague = false;
          _draftTime = null;
          _draftLeagueName = null;
        });
        return;
      case 2:
        {
          final now = DateTime.now();
          final when = now.add(
            Duration(minutes: 10 + rand.nextInt(60 * 24 * 3)),
          );
          final name = _demoLeagueNames[rand.nextInt(_demoLeagueNames.length)];
          setState(() {
            _isLoggedIn = true;
            _hasSoccerLeague = false;
            _hasBaseballLeague = false;
          });
          setDraft(when, name, markLeague: false, isSoccer: true);
          return;
        }
      case 3:
        setState(() {
          _isLoggedIn = true;
          _hasSoccerLeague = true;
          _hasBaseballLeague = false;
          _draftTime = null;
          _draftLeagueName = null;
        });
        return;
      case 4:
      default:
        {
          final now = DateTime.now();
          final when = now.add(
            Duration(minutes: 10 + rand.nextInt(60 * 24 * 3)),
          );
          final name = _demoLeagueNames[rand.nextInt(_demoLeagueNames.length)];
          setState(() {
            _isLoggedIn = true;
            _hasSoccerLeague = true;
            _hasBaseballLeague = false;
          });
          setDraft(when, name, isSoccer: true);
          return;
        }
    }
  }

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _suggestionsScrollController = ScrollController();
    _playerDirectory = _buildSoccerSearchDirectory();
    unawaited(_primeHomePlayerDirectory());
    unawaited(_ensureProfileAvatarPathLoaded());
    _leagueFuture = _loadCachedKLeagueLeagueData(forceRefresh: true);
    _kboLeagueFuture = _loadCachedKboLeagueData(forceRefresh: true);
    unawaited(
      _restorePersistedFantasySoccerRoundScoreCache().then((_) {
        if (!mounted) return;
        setState(() {});
      }),
    );
    unawaited(_restorePersistedKLeaguePlayerAptsCache());
    unawaited(
      _restorePersistedKLeaguePlayerRoundPointsCache().then((_) {
        if (!mounted) return;
        setState(() {});
      }),
    );
    unawaited(_refreshVisibleHomeKboRoundPoints());
    _kboLiveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_backgroundLiveRefreshSuspended) return;
      setState(() {
        _leagueFuture = _loadCachedKLeagueLeagueData(forceRefresh: true);
        _kboLeagueFuture = _loadCachedKboLeagueData(forceRefresh: true);
      });
      unawaited(_refreshFantasySoccerScores(forceRefreshLiveData: true));
      unawaited(_refreshVisibleHomeKboRoundPoints(forceRefresh: true));
    });

    // Restore persisted login state.
    _isLoggedIn = authController.isLoggedIn;
    _lastAvatarCacheAuthUid = _activeProfileAvatarUid();
    authController.addListener(_syncAuthToHomeState);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();

    // App launch transition (home animates in without a dedicated splash page).
    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _launchScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _launchController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _launchSlide =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.03)).animate(
          CurvedAnimation(
            parent: _launchController,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _launchOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _launchController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInCubic),
      ),
    );

    if (!_didPlayLaunchIntro) {
      _didPlayLaunchIntro = true;
      _showLaunchIntro = true;
      _launchController.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _showLaunchIntro = false);
      });
    } else {
      _launchController.value = 1;
      _showLaunchIntro = false;
    }

    _startDraftTimer();
    unawaited(_restoreLocalState());
    unawaited(_initLeagueLinkHandling());

    assert(() {
      // Only apply demo-random state when no persisted session exists.
      if (_demoRandomState && !authController.isLoggedIn) _applyDemoState();
      return true;
    }());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  void _syncAuthToHomeState() {
    if (!mounted) return;
    final v = authController.isLoggedIn;
    final currentAuthUid = _activeProfileAvatarUid();
    if (_lastAvatarCacheAuthUid != currentAuthUid) {
      _clearPublicProfileAvatarUrlCache();
      _lastAvatarCacheAuthUid = currentAuthUid;
    }
    if (_isLoggedIn == v) {
      if (v) {
        unawaited(_ensureProfileAvatarPathLoaded());
        unawaited(_restoreLocalState());
        _listenJoinedDrafts();
        _applyCurrentUserFantasyDisplayNameIfAvailable();
      } else {
        unawaited(_ensureProfileAvatarPathLoaded(uid: ''));
      }
      return;
    }
    setState(() => _isLoggedIn = v);
    if (v) {
      unawaited(_ensureProfileAvatarPathLoaded());
      unawaited(_restoreLocalState());
      _listenJoinedDrafts();
      _applyCurrentUserFantasyDisplayNameIfAvailable();
      if ((_pendingInviteCodeFromLink ?? '').isNotEmpty) {
        unawaited(_handleIncomingInviteCode(_pendingInviteCodeFromLink!));
      }
      return;
    }
    if (!v) {
      unawaited(_ensureProfileAvatarPathLoaded(uid: ''));
      // When logging out, clear league/draft state (same behavior as before).
      setState(() {
        _hasSoccerLeague = false;
        _hasBaseballLeague = false;
        _draftTime = null;
        _draftLeagueName = null;
        _draftRemaining = Duration.zero;
        _joinedDrafts = const [];
        _isMenuOpen = false;
        _isMyPageOpen = false;
      });
      _draftTimer?.cancel();
      _joinedDraftsSub?.cancel();
    }
  }

  Future<void> _initLeagueLinkHandling() async {
    _appLinks ??= AppLinks();
    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleIncomingLeagueUri(initialUri));
      }
    } catch (e, st) {
      debugPrint('initLeagueLinkHandling initial link failed: $e');
      debugPrint('$st');
    }

    _incomingLeagueLinkSub?.cancel();
    _incomingLeagueLinkSub = _appLinks!.uriLinkStream.listen(
      (uri) {
        unawaited(_handleIncomingLeagueUri(uri));
      },
      onError: (error, stackTrace) {
        debugPrint('league link stream error: $error');
        debugPrint('$stackTrace');
      },
    );
  }

  Future<void> _handleIncomingLeagueUri(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'leagueit') return;

    final serialized = uri.toString();
    if (_lastHandledLeagueLink == serialized) return;

    final host = uri.host.toLowerCase();
    final firstPath = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.first.toLowerCase();
    if (host != 'join' && firstPath != 'join') return;

    final inviteCode = uri.queryParameters['code']?.trim().toUpperCase() ?? '';
    if (inviteCode.isEmpty) return;

    _lastHandledLeagueLink = serialized;
    await _handleIncomingInviteCode(inviteCode);
  }

  Future<void> _handleIncomingInviteCode(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return;
    if (_isHandlingInviteCodeFromLink) return;

    if (!authController.isLoggedIn) {
      _pendingInviteCodeFromLink = code;
      return;
    }

    _pendingInviteCodeFromLink = null;
    _isHandlingInviteCodeFromLink = true;
    try {
      final data = await LeagueService.instance.joinLeagueByInviteCode(code);
      if (!mounted) return;
      final joined = _joinedDraftFromJoinLeagueResponse(
        data,
        fallbackCode: code,
      );
      addOrUpdateJoinedDraft(joined);
      setHasLeagueForSport(joined.isSoccer, true);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DraftDetailPage(draft: joined)));
    } catch (e, st) {
      debugPrint('handleIncomingInviteCode failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리그 참가 실패: $e')));
    } finally {
      _isHandlingInviteCodeFromLink = false;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    _suggestionsScrollController.dispose();
    authController.removeListener(_syncAuthToHomeState);
    _fadeController.dispose();
    _launchController.dispose();
    _draftTimer?.cancel();
    _kboLiveRefreshTimer?.cancel();
    _incomingLeagueLinkSub?.cancel();
    _joinedDraftsSub?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    _resetSearchUi();
  }

  void _toggleMenu() {
    _resetSearchUi();
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMyPageOpen = false;
    });
  }

  void _toggleMyPage() {
    _resetSearchUi();
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  List<_HomeSearchSuggestion> _buildSoccerSearchDirectory() {
    final entries =
        _docMetaByName.entries
            .map(
              (entry) => _HomeSearchSuggestion(
                name: entry.key,
                isSoccer: true,
                meta: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  Future<void> _primeHomePlayerDirectory() async {
    try {
      final kboPool = await _loadKboDraftPlayerPool();
      final kboEntries = kboPool
          .map(
            (player) => _HomeSearchSuggestion(
              name: player.name,
              isSoccer: false,
              meta: _DocPlayerMeta(
                position: player.position,
                club: player.club,
                number: player.number,
              ),
            ),
          )
          .toList();
      final combined =
          <_HomeSearchSuggestion>[
            ..._buildSoccerSearchDirectory(),
            ...kboEntries,
          ]..sort((a, b) {
            final nameCompare = a.name.compareTo(b.name);
            if (nameCompare != 0) return nameCompare;
            final leagueCompare = a.isSoccer == b.isSoccer
                ? 0
                : (a.isSoccer ? -1 : 1);
            if (leagueCompare != 0) return leagueCompare;
            final clubCompare = a.meta.club.compareTo(b.meta.club);
            if (clubCompare != 0) return clubCompare;
            return a.meta.position.compareTo(b.meta.position);
          });
      if (!mounted) return;
      setState(() {
        _playerDirectory = combined;
      });
    } catch (error, stackTrace) {
      debugPrint('primeHomePlayerDirectory failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _closeSuggestionsOverlay() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_suggestionsVisible) {
      _resetSuggestionsScroll();
      setState(() => _suggestionsVisible = false);
    }
  }

  void _resetSearchUi() {
    FocusManager.instance.primaryFocus?.unfocus();
    _resetSuggestionsScroll();
    setState(() {
      _suggestionsVisible = false;
      _suggestions = [];
    });
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  Future<void> _showHomeLeagueDropdown() async {
    _closeSuggestionsOverlay();
    final options = _homeDraftOptionsForSport(_frontLeagueIsSoccer);
    if (options.isEmpty) return;
    final currentDraft = fantasyDraftForSport(_frontLeagueIsSoccer);
    final currentLeagueId = currentDraft?.leagueId;
    final box = _homeTitleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final accent = _frontLeagueIsSoccer
            ? const Color(0xFF2E9B50)
            : const Color(0xFFB26A00);
        final accentSoft = _frontLeagueIsSoccer
            ? const Color(0xFFE7F7EA)
            : const Color(0xFFFFF1D6);
        final selectedLeagueId =
            currentLeagueId ??
            _selectedHomeLeagueIdForSport(_frontLeagueIsSoccer);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + box.size.height + 10,
              width: box.size.width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < options.length; i++) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(
                            dialogContext,
                          ).pop(options[i].leagueId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: currentLeagueId == options[i].leagueId
                                  ? accentSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    options[i].leagueName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          currentLeagueId == options[i].leagueId
                                          ? FontWeight.w900
                                          : FontWeight.w800,
                                      color: Colors.black.withOpacity(0.86),
                                    ),
                                  ),
                                ),
                                if (currentLeagueId == options[i].leagueId)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '현재',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: accent,
                                      ),
                                    ),
                                  )
                                else if (selectedLeagueId ==
                                    options[i].leagueId)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (i != options.length - 1)
                          Divider(
                            height: 8,
                            thickness: 0.8,
                            color: Colors.black.withOpacity(0.05),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (selected == null) return;
    _setSelectedHomeLeagueIdForSport(_frontLeagueIsSoccer, selected);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double sidebarWidth = (screenWidth * 0.72).clamp(280.0, 340.0);
    const double topGap = 140;

    return Stack(
      children: [
        ////////////////////////////////////////////////////////////////
        /// MAIN PAGE
        ////////////////////////////////////////////////////////////////
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          resizeToAvoidBottomInset: false,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _CustomAppBar(
              onMenuPressed: _toggleMenu,
              onMyPagePressed: _toggleMyPage,
              searchController: _searchController,
              onSearch: _handleSearch,
              onChanged: _updateSuggestions,
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    const SizedBox(height: topGap),
                                    Expanded(
                                      child: Center(
                                        child: CardSwitcher(
                                          isLoggedIn: _isLoggedIn,
                                          hasSoccerLeague: _hasSoccerLeague,
                                          hasBaseballLeague: _hasBaseballLeague,
                                          frontLeagueIsSoccer:
                                              _frontLeagueIsSoccer,
                                          onFrontLeagueChanged: (isSoccer) {
                                            if (_frontLeagueIsSoccer ==
                                                isSoccer) {
                                              return;
                                            }
                                            setState(
                                              () => _frontLeagueIsSoccer =
                                                  isSoccer,
                                            );
                                            unawaited(_saveLocalState());
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                                Positioned(
                                  top: 92,
                                  left: 0,
                                  right: 0,
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Center(
                                      child: InkWell(
                                        key: _homeTitleKey,
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: _showHomeLeagueDropdown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              'LeagueIt',
                                              style: TextStyle(
                                                fontSize: 45,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isLoggedIn && _draftTime != null)
                                  Positioned(
                                    top: 172,
                                    left: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        _resetSearchUi();
                                        final draft =
                                            homeKey.currentState?.primaryDraft;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DraftDetailPage(
                                              draft:
                                                  draft ??
                                                  _JoinedDraft(
                                                    leagueId: '',
                                                    leagueName:
                                                        _draftLeagueName ??
                                                        'My League',
                                                    when: _draftTime!,
                                                    isSoccer: true,
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: _DraftBanner(
                                        leagueName:
                                            _draftLeagueName ?? 'My League',
                                        remaining: _draftRemaining,
                                        draftTime: _draftTime!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Standings table: full height (no inner scrolling); page scroll handles it.
                          const SizedBox(height: 12),
                          // Only lift the standings card to reduce the gap to the main card area.
                          Transform.translate(
                            offset: const Offset(0, -160),
                            child: Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _resetSearchUi();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StandingsPage(
                                          isSoccer: _frontLeagueIsSoccer,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _HomeStandingsCard(
                                    key: ValueKey(
                                      'home-standings-${_frontLeagueIsSoccer ? 'soccer' : 'baseball'}',
                                    ),
                                    isSoccer: _frontLeagueIsSoccer,
                                    leagueFuture: _frontLeagueIsSoccer
                                        ? _leagueFuture
                                        : _kboLeagueFuture,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _resetSearchUi();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SchedulePage(
                                          isSoccer: _frontLeagueIsSoccer,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _HomeScheduleCard(
                                    key: ValueKey(
                                      'home-schedule-${_frontLeagueIsSoccer ? 'soccer' : 'baseball'}',
                                    ),
                                    isSoccer: _frontLeagueIsSoccer,
                                    leagueFuture: _frontLeagueIsSoccer
                                        ? _leagueFuture
                                        : _kboLeagueFuture,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_suggestionsVisible)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeSuggestionsOverlay,
                    child: const SizedBox.expand(),
                  ),
                ),
              Positioned(
                top: 1,
                right: 70,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _suggestionsVisible
                      ? Offset.zero
                      : const Offset(0, -0.14),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: _suggestionsVisible ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_suggestionsVisible,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 190,
                            maxWidth: 190,
                          ),
                          child: Builder(
                            builder: (context) {
                              const double maxH = 220;
                              const double rowH = 52;
                              final double desiredH =
                                  _suggestions.length * rowH;
                              final bool needsScroll = desiredH > maxH;
                              final double contentHeight =
                                  (_suggestions.isEmpty
                                          ? 0
                                          : (needsScroll ? maxH : desiredH))
                                      .clamp(0, maxH)
                                      .toDouble();

                              return ClipRect(
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  heightFactor: _suggestionsVisible ? 1 : 0,
                                  child: SizedBox(
                                    height: contentHeight,
                                    child: contentHeight == 0
                                        ? const SizedBox.shrink()
                                        : ScrollbarTheme(
                                            data: ScrollbarThemeData(
                                              thumbColor:
                                                  const WidgetStatePropertyAll(
                                                    Colors.white,
                                                  ),
                                              trackColor:
                                                  WidgetStatePropertyAll(
                                                    Colors.white.withOpacity(
                                                      0.18,
                                                    ),
                                                  ),
                                              thickness:
                                                  const WidgetStatePropertyAll(
                                                    4,
                                                  ),
                                              radius: const Radius.circular(
                                                999,
                                              ),
                                            ),
                                            child: Scrollbar(
                                              controller:
                                                  _suggestionsScrollController,
                                              thumbVisibility: needsScroll,
                                              trackVisibility: needsScroll,
                                              child: ListView.builder(
                                                controller:
                                                    _suggestionsScrollController,
                                                padding: EdgeInsets.zero,
                                                itemExtent: rowH,
                                                itemCount: _suggestions.length,
                                                itemBuilder: (_, i) {
                                                  final suggestion =
                                                      _suggestions[i];
                                                  final meta = suggestion.meta;
                                                  final isDark =
                                                      Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark;
                                                  final Color muted = isDark
                                                      ? Colors.white70
                                                      : Colors.black
                                                            .withOpacity(0.55);
                                                  return ListTile(
                                                    dense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    title: Text(
                                                      suggestion.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      meta.club,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: muted,
                                                      ),
                                                    ),
                                                    trailing: SizedBox(
                                                      width: 52,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                suggestion
                                                                    .isSoccer
                                                                ? const Color(
                                                                    0xFFE7F7EA,
                                                                  )
                                                                : const Color(
                                                                    0xFFFFF1D6,
                                                                  ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            suggestion.isSoccer
                                                                ? 'K리그'
                                                                : 'KBO',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            textAlign:
                                                                TextAlign.right,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color:
                                                                  suggestion
                                                                      .isSoccer
                                                                  ? const Color(
                                                                      0xFF2E9B50,
                                                                    )
                                                                  : const Color(
                                                                      0xFFB26A00,
                                                                    ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    onTap: () =>
                                                        _openSearchSuggestion(
                                                          suggestion,
                                                        ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        ////////////////////////////////////////////////////////////////
        /// DIM BACKGROUND (MENU)
        ////////////////////////////////////////////////////////////////
        if (_isMenuOpen)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: 0.45,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: const Color.fromARGB(255, 5, 5, 5)),
            ),
          ),

        ////////////////////////////////////////////////////////////////
        /// SIDE MENU
        ////////////////////////////////////////////////////////////////
        AnimatedPositioned(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          left: _isMenuOpen ? 0 : -sidebarWidth,
          top: 0,
          bottom: 0,
          child: SideMenu(width: sidebarWidth),
        ),

        _MyPagePopupOverlay(
          isOpen: _isMyPageOpen,
          onDismiss: _toggleMyPage,
          isLoggedIn: _isLoggedIn,
          onLogin: () {
            updateLogin(true);
            _toggleMyPage();
          },
          onLogout: () {
            updateLogin(false);
            _toggleMyPage();
          },
        ),
        if (_showLaunchIntro)
          Positioned.fill(
            child: IgnorePointer(
              // Block interaction until the intro finishes.
              ignoring: false,
              child: AnimatedBuilder(
                animation: _launchController,
                builder: (context, _) {
                  final theme = Theme.of(context);
                  final bg = theme.scaffoldBackgroundColor;
                  return Opacity(
                    opacity: _launchOpacity.value,
                    child: Container(
                      color: bg,
                      child: Center(
                        child: SlideTransition(
                          position: _launchSlide,
                          child: ScaleTransition(
                            scale: _launchScale,
                            child: Image.asset(
                              'assets/leagueit_logo.png',
                              width: 130,
                              height: 130,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  _HomeSearchSuggestion? _suggestionForQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    for (final suggestion in _playerDirectory) {
      if (suggestion.name == trimmed) return suggestion;
    }
    final qLower = trimmed.toLowerCase();
    for (final suggestion in _playerDirectory) {
      if (suggestion.name.toLowerCase().contains(qLower) ||
          suggestion.meta.club.toLowerCase().contains(qLower)) {
        return suggestion;
      }
    }
    return null;
  }

  void _openSearchSuggestion(_HomeSearchSuggestion suggestion) {
    final query = suggestion.name;
    if (query.isEmpty) return;
    _resetSearchUi();
    _searchController.clear();
    final ownership =
        _MatchDetailPageState._playerOwnerCache[query] ??
        PlayerOwnership.otherTeam;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(
          name: query,
          ownership: ownership,
          metaOverride: suggestion.meta,
        ),
      ),
    ).then((_) {
      _resetSearchUi();
    });
  }

  void _handleSearch(String query) {
    final suggestion = _suggestionForQuery(query);
    if (suggestion == null) return;
    _openSearchSuggestion(suggestion);
  }

  void _updateSuggestions(String text) {
    final q = text.trim();
    if (q.isEmpty) {
      _clearSuggestions();
      return;
    }
    _resetSuggestionsScroll();
    final qLower = q.toLowerCase();
    final matches = _playerDirectory
        .where(
          (entry) =>
              entry.name.toLowerCase().contains(qLower) ||
              entry.meta.club.toLowerCase().contains(qLower),
        )
        .toList();
    setState(() {
      _suggestions = matches;
      _suggestionsVisible = matches.isNotEmpty;
    });
  }

  void _clearSuggestions() {
    if (_suggestions.isEmpty && !_suggestionsVisible) return;
    _resetSuggestionsScroll();
    setState(() {
      _suggestionsVisible = false;
      _suggestions = [];
    });
  }

  void _resetSuggestionsScroll() {
    if (!_suggestionsScrollController.hasClients) return;
    _suggestionsScrollController.jumpTo(0);
  }
}

String _formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  if (days > 0) {
    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }
  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  }
  return '${minutes}m ${seconds}s';
}

class _DraftBanner extends StatelessWidget {
  final String leagueName;
  final Duration remaining;
  final DateTime draftTime;
  const _DraftBanner({
    required this.leagueName,
    required this.remaining,
    required this.draftTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.15),
            cs.secondary.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$leagueName Draft',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '시작까지 ${_formatDuration(remaining)}',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Draft: ${_kstMonthDayTimeLabel(draftTime)}',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class DraftDetailPage extends StatefulWidget {
  final _JoinedDraft draft;
  const DraftDetailPage({super.key, required this.draft});

  @override
  State<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends State<DraftDetailPage> {
  late Duration _remaining;
  Timer? _timer;
  late int _teamCount;
  late int _memberCount;
  late String _inviteCode;
  late List<_DraftOrderEntry> _draftOrder;
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.draft.when.difference(DateTime.now());
    _teamCount = widget.draft.teamCount;
    _memberCount = widget.draft.memberCount;
    _inviteCode = widget.draft.inviteCode;
    _draftOrder = List<_DraftOrderEntry>.from(widget.draft.draftOrder)
      ..sort((a, b) => a.slot.compareTo(b.slot));
    _startTimer();
    unawaited(_ensureDraftOrderIfNeeded());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = widget.draft.when.difference(DateTime.now());
      if (!mounted) return;
      if (diff.isNegative) {
        setState(() {
          _remaining = Duration.zero;
        });
        _timer?.cancel();
      } else {
        setState(() {
          _remaining = diff;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ensureDraftOrderIfNeeded() async {
    if (_ordering) return;
    if (widget.draft.leagueId.isEmpty) return;
    if (_memberCount < _teamCount) return;
    if (_draftOrder.length == _teamCount) return;

    setState(() => _ordering = true);
    try {
      final data = await LeagueService.instance.ensureDraftOrder(
        widget.draft.leagueId,
      );
      if (!mounted) return;
      final raw = data['draftOrder'] as List<dynamic>? ?? const [];
      final next = raw.whereType<Map>().map((item) {
        final uid = '${item['uid'] ?? ''}';
        return _DraftOrderEntry(
          uid: uid,
          displayName: _normalizedFantasyDisplayNameForUid(
            uid,
            '${item['displayName'] ?? 'Team'}',
          ),
          slot: item['slot'] is int
              ? item['slot'] as int
              : int.tryParse('${item['slot'] ?? 0}') ?? 0,
        );
      }).toList()..sort((a, b) => a.slot.compareTo(b.slot));
      setState(() {
        _memberCount = data['memberCount'] is int
            ? data['memberCount'] as int
            : _memberCount;
        _teamCount = data['teamCount'] is int
            ? data['teamCount'] as int
            : _teamCount;
        _draftOrder = next;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  String? _currentUserDraftTeamName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    for (final entry in _draftOrder) {
      if (entry.uid == user.uid) {
        return _normalizedFantasyDisplayNameForUid(user.uid, entry.displayName);
      }
    }

    final displayName = _currentSignedInFantasyDisplayName();
    if (displayName.isNotEmpty) {
      for (final entry in _draftOrder) {
        if (entry.displayName.trim().toLowerCase() ==
            displayName.toLowerCase()) {
          return entry.displayName;
        }
      }
      return displayName;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final bool isCompleted = _isDraftCompletedAt(widget.draft, now);
    final bool canReviewCompletedDraft =
        isCompleted && !_isDraftExpiredAt(widget.draft, now);
    final bool allowEnterWindow = _remaining <= const Duration(hours: 1);
    final bool hasEnoughTeams = _memberCount >= _teamCount;
    final bool hasDraftOrder = _draftOrder.length == _teamCount;
    final bool allowRealDraft =
        !isCompleted &&
        allowEnterWindow &&
        hasEnoughTeams &&
        hasDraftOrder &&
        !_ordering;
    final bool showDraftOrder = allowEnterWindow && _draftOrder.isNotEmpty;
    final String inviteCode = _inviteCode.trim().toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Draft')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.draft.leagueName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Draft 일정: ${_kstMonthDayTimeLabel(widget.draft.when)}',
              style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '참가 상태',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_memberCount/$_teamCount 팀 참가 중',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasEnoughTeams
                        ? '참가 팀 수가 충족되어 실제 Draft를 진행할 수 있습니다.'
                        : '설정된 참가 팀 수가 모두 모여야 실제 Draft가 열립니다.',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.78),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inviteCode.isEmpty
                              ? '초대 코드 준비 중'
                              : '초대 코드: $inviteCode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (inviteCode.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: inviteCode),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('초대 코드를 복사했습니다.')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('복사'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Draft 순서',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (!allowEnterWindow)
                    Text(
                      'Draft 시작 1시간 전부터 순서가 공개됩니다.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.76),
                        height: 1.4,
                      ),
                    )
                  else if (!hasEnoughTeams)
                    Text(
                      '참가 팀 수가 모두 모이면 랜덤 순서가 확정됩니다.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.76),
                        height: 1.4,
                      ),
                    )
                  else if (_ordering)
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Draft 순서를 확정하는 중입니다.'),
                      ],
                    )
                  else if (showDraftOrder)
                    Column(
                      children: _draftOrder
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${entry.slot}',
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry.displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Text(
                      '순서가 아직 확정되지 않았습니다. 잠시 후 다시 확인해 주세요.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.76),
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '카운트다운',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCompleted
                        ? 'Draft가 완료되었어요.'
                        : _remaining.isNegative || _remaining == Duration.zero
                        ? 'Draft가 시작되었어요.'
                        : _formatDuration(_remaining),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Draft 정보',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '드래프트 시작 1시간 전부터 실제 Draft 입장이 가능합니다. 참가 팀 수가 모이기 전에는 Mock Draft로만 연습할 수 있습니다.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: allowRealDraft || canReviewCompletedDraft
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DraftPage(
                                leagueId: widget.draft.leagueId,
                                draftTime: widget.draft.when,
                                leagueName: widget.draft.leagueName,
                                teamCount: _teamCount,
                                roundCount: widget.draft.roundCount,
                                isSoccer: widget.draft.isSoccer,
                                draftOrderEntries: _draftOrder,
                                savedBoard: widget.draft.draftBoard,
                                reviewOnly: canReviewCompletedDraft,
                                teamNames: _draftOrder
                                    .map((entry) => entry.displayName)
                                    .toList(),
                                myTeamName: _currentUserDraftTeamName(),
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    allowRealDraft
                        ? 'Enter Draft (실제)'
                        : canReviewCompletedDraft
                        ? 'Draft 결과 보기'
                        : isCompleted
                        ? 'Draft 완료'
                        : !allowEnterWindow
                        ? '입장 가능까지 ${_formatDuration(_remaining)}'
                        : _ordering
                        ? 'Draft 순서 확정 중...'
                        : !hasDraftOrder
                        ? 'Draft 순서 확정 대기 중'
                        : '참가 팀 $_memberCount/$_teamCount',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    final orderedNames = _draftOrder.length == _teamCount
                        ? _draftOrder.map((entry) => entry.displayName).toList()
                        : null;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DraftPage(
                          leagueId: widget.draft.leagueId,
                          draftTime: widget.draft.when,
                          leagueName: widget.draft.leagueName,
                          teamCount: widget.draft.teamCount,
                          roundCount: widget.draft.roundCount,
                          isMock: true,
                          isSoccer: widget.draft.isSoccer,
                          draftOrderEntries: _draftOrder,
                          teamNames: orderedNames,
                          myTeamName: _currentUserDraftTeamName(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Mock Draft'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
