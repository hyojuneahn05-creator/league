import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:leagueit/public_user_profile.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_session.dart';

class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();
}

class AuthController extends ChangeNotifier {
  static const String _googleWebClientId =
      '221389557876-j6865iha0ll1nuiqufq9bqvldlnn3sc6.apps.googleusercontent.com';
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  StreamSubscription<User?>? _authSub;
  bool _googleInitialized = false;
  AuthSession? _session;

  AuthController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  bool get isLoggedIn => _session != null;
  AuthSession? get session => _session;

  String _normalizeDisplayName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _sanitizeDisplayName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> init() async {
    await _ensureGoogleInitialized();
    _syncFromUser(_auth.currentUser);
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen(_syncFromUser);
    notifyListeners();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: '로그인 사용자 정보를 찾을 수 없습니다.',
      );
    }
    await _createUserIfNotExists(user);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: '회원가입 사용자 정보를 찾을 수 없습니다.',
      );
    }
    try {
      await _reserveUsernameForUser(user, username);
      await _createUserIfNotExists(_auth.currentUser ?? user);
    } catch (error, stackTrace) {
      debugPrint('Email sign-up bootstrap failed: $error');
      debugPrint('$stackTrace');
      try {
        await user.delete();
      } catch (deleteError, deleteStackTrace) {
        debugPrint('Email sign-up rollback failed: $deleteError');
        debugPrint('$deleteStackTrace');
      }
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication authData = account.authentication;

    if (authData.idToken == null) {
      throw FirebaseAuthException(
        code: 'google-auth-missing-token',
        message: 'Google 인증 토큰을 가져오지 못했습니다.',
      );
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: authData.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Google 로그인 사용자 정보를 찾을 수 없습니다.',
      );
    }
    await _createUserIfNotExists(user);
  }

  Future<void> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    if ((credential.identityToken ?? '').isEmpty ||
        (credential.authorizationCode).isEmpty) {
      throw FirebaseAuthException(
        code: 'apple-auth-missing-token',
        message: 'Apple 인증 토큰을 가져오지 못했습니다.',
      );
    }

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(
      oauthCredential,
    );
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Apple 로그인 사용자 정보를 찾을 수 없습니다.',
      );
    }

    final fullName = [
      credential.givenName?.trim() ?? '',
      credential.familyName?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty && (user.displayName?.trim().isEmpty ?? true)) {
      await user.updateDisplayName(fullName);
      await user.reload();
    }

    await _createUserIfNotExists(_auth.currentUser ?? user);
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    if (kIsWeb) {
      // google_sign_in_web requires clientId and does not allow serverClientId.
      await _googleSignIn.initialize(clientId: _googleWebClientId);
    } else {
      await _googleSignIn.initialize(serverClientId: _googleWebClientId);
    }
    _googleInitialized = true;
  }

  Future<void> _createUserIfNotExists(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final existingData = snapshot.data() ?? const <String, dynamic>{};
    final providerIds = user.providerData
        .map((p) => p.providerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final displayName = _sanitizeDisplayName(
      user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : '${existingData['displayName'] ?? ''}',
    );
    final normalizedDisplayName = _normalizeDisplayName(displayName);
    final photoUrl = user.photoURL?.trim().isNotEmpty == true
        ? user.photoURL!.trim()
        : '${existingData['photoUrl'] ?? ''}'.trim();

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': displayName,
      'normalizedDisplayName': normalizedDisplayName,
      'photoUrl': photoUrl,
      'providerIds': providerIds,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
    final publicPayload = <String, dynamic>{
      'uid': user.uid,
      'displayName': displayName,
      'normalizedDisplayName': normalizedDisplayName,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      await userRef.set({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.set(payload, SetOptions(merge: true));
    }

    await _syncPublicUserProfileIfAllowed(user.uid, publicPayload);
  }

  Future<void> _reserveUsernameForUser(User user, String username) async {
    final rawUsername = _sanitizeDisplayName(username);
    final normalizedUsername = _normalizeDisplayName(rawUsername);
    final userRef = _firestore.collection('users').doc(user.uid);
    final publicUserRef = publicUserProfileRef(_firestore, user.uid);
    final usernameRef = _firestore
        .collection('usernames')
        .doc(normalizedUsername);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final currentData = userSnapshot.data() ?? const <String, dynamic>{};
      final currentUsername = _sanitizeDisplayName(
        '${currentData['displayName'] ?? user.displayName ?? ''}',
      );
      final currentNormalized =
          '${currentData['normalizedDisplayName'] ?? _normalizeDisplayName(currentUsername)}';
      final reservedSnapshot = await transaction.get(usernameRef);
      DocumentReference<Map<String, dynamic>>? oldUsernameRef;
      DocumentSnapshot<Map<String, dynamic>>? oldUsernameSnapshot;

      if (reservedSnapshot.exists) {
        final reservedData =
            reservedSnapshot.data() ?? const <String, dynamic>{};
        final reservedUid = '${reservedData['uid'] ?? ''}';
        if (reservedUid.isNotEmpty && reservedUid != user.uid) {
          throw const UsernameAlreadyTakenException();
        }
      }

      if (currentNormalized.isNotEmpty &&
          currentNormalized != normalizedUsername) {
        oldUsernameRef = _firestore
            .collection('usernames')
            .doc(currentNormalized);
        oldUsernameSnapshot = await transaction.get(oldUsernameRef);
      }

      transaction.set(usernameRef, {
        'uid': user.uid,
        'displayName': rawUsername,
        'normalizedDisplayName': normalizedUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, {
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': rawUsername,
        'normalizedDisplayName': normalizedUsername,
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(publicUserRef, {
        'uid': user.uid,
        'displayName': rawUsername,
        'normalizedDisplayName': normalizedUsername,
        'photoUrl': user.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (currentNormalized.isNotEmpty &&
          currentNormalized != normalizedUsername) {
        final oldUsernameData =
            oldUsernameSnapshot?.data() ?? const <String, dynamic>{};
        final oldReservedUid = '${oldUsernameData['uid'] ?? ''}';
        if (oldReservedUid == user.uid && oldUsernameRef != null) {
          transaction.delete(oldUsernameRef);
        }
      }
    });

    await user.updateDisplayName(rawUsername);
    await user.reload();
  }

  Future<void> _syncPublicUserProfileIfAllowed(
    String uid,
    Map<String, dynamic> publicPayload,
  ) async {
    try {
      await syncPublicUserProfile(
        _firestore,
        uid: uid,
        displayName: publicPayload['displayName'] as String?,
        normalizedDisplayName:
            publicPayload['normalizedDisplayName'] as String?,
        photoUrl: publicPayload['photoUrl'] as String?,
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Public profile sync skipped during auth bootstrap: '
        '${error.code} ${error.message}',
      );
      debugPrint('$stackTrace');
    } catch (error, stackTrace) {
      debugPrint('Public profile sync failed during auth bootstrap: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if Google session doesn't exist.
    }
    await _auth.signOut();
  }

  Future<void> deleteCurrentUser({String? currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: '로그인 사용자 정보를 찾을 수 없습니다.',
      );
    }

    final uid = user.uid.trim();
    if (uid.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-user',
        message: '사용자 식별자를 찾을 수 없습니다.',
      );
    }

    await _reauthenticateForDeletion(
      user,
      currentPassword: currentPassword?.trim(),
    );

    final userSnapshot = await _firestore.collection('users').doc(uid).get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final normalizedDisplayName = _normalizedUsernameForDeletion(
      user,
      userData,
    );

    await _leaveAllLeaguesForUser(uid);
    await _deleteUserProfileDocuments(
      uid,
      normalizedDisplayName: normalizedDisplayName,
    );
    await _deleteProfileAvatarFolder(uid);
    await user.delete();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if Google session doesn't exist.
    }
  }

  Future<void> _reauthenticateForDeletion(
    User user, {
    String? currentPassword,
  }) async {
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .where((providerId) => providerId.isNotEmpty)
        .toSet();

    if (providerIds.contains('password')) {
      final email = user.email?.trim() ?? '';
      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: '계정 이메일을 찾을 수 없습니다.',
        );
      }
      final password = currentPassword?.trim() ?? '';
      if (password.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-password',
          message: '현재 비밀번호를 입력해 주세요.',
        );
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providerIds.contains('google.com')) {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication authData = account.authentication;
      if (authData.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-auth-missing-token',
          message: 'Google 인증 토큰을 가져오지 못했습니다.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: authData.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    throw FirebaseAuthException(
      code: 'unsupported-provider',
      message: '이 로그인 방식은 앱 내 회원탈퇴를 지원하지 않습니다.',
    );
  }

  String _normalizedUsernameForDeletion(
    User user,
    Map<String, dynamic> userData,
  ) {
    final normalizedStored = '${userData['normalizedDisplayName'] ?? ''}'
        .trim();
    if (normalizedStored.isNotEmpty) return normalizedStored;
    final rawDisplayName = _sanitizeDisplayName(
      '${userData['displayName'] ?? user.displayName ?? ''}',
    );
    if (rawDisplayName.isEmpty) return '';
    return _normalizeDisplayName(rawDisplayName);
  }

  Future<void> _leaveAllLeaguesForUser(String uid) async {
    final snapshots = await _firestore
        .collection('leagues')
        .where('members', arrayContains: uid)
        .get();
    for (final snapshot in snapshots.docs) {
      await _removeUserFromLeague(uid, snapshot.reference);
    }
  }

  Future<void> _removeUserFromLeague(
    String uid,
    DocumentReference<Map<String, dynamic>> leagueRef,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(leagueRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? const <String, dynamic>{};
      final ownerId = '${data['ownerId'] ?? ''}';
      final members = List<String>.from(
        (data['members'] as List<dynamic>? ?? const []).map(
          (entry) => '$entry',
        ),
      );
      if (!members.contains(uid)) return;

      final remainingMembers = members
          .where((member) => member != uid)
          .toList();
      if (remainingMembers.isEmpty) {
        transaction.delete(leagueRef);
        return;
      }

      final update = <String, dynamic>{
        'members': remainingMembers,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (ownerId == uid) {
        update['ownerId'] = remainingMembers.first;
      }
      transaction.update(leagueRef, update);
    });
  }

  Future<void> _deleteUserProfileDocuments(
    String uid, {
    required String normalizedDisplayName,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);
    final publicUserRef = publicUserProfileRef(_firestore, uid);

    batch.delete(userRef);
    batch.delete(publicUserRef);

    if (normalizedDisplayName.isNotEmpty) {
      final usernameRef = _firestore
          .collection('usernames')
          .doc(normalizedDisplayName);
      final usernameSnapshot = await usernameRef.get();
      final reservedUid = '${usernameSnapshot.data()?['uid'] ?? ''}';
      if (reservedUid == uid) {
        batch.delete(usernameRef);
      }
    }

    await batch.commit();
  }

  Future<void> _deleteProfileAvatarFolder(String uid) async {
    final ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('profile_avatars')
        .child(uid);
    try {
      await _deleteStorageTree(ref);
    } on firebase_storage.FirebaseException catch (error, stackTrace) {
      if (error.code == 'object-not-found' || error.code == 'unauthorized') {
        return;
      }
      debugPrint(
        'Profile avatar deletion skipped during account deletion: '
        '${error.code} ${error.message}',
      );
      debugPrint('$stackTrace');
    } catch (error, stackTrace) {
      debugPrint(
        'Profile avatar deletion failed during account deletion: $error',
      );
      debugPrint('$stackTrace');
    }
  }

  Future<void> _deleteStorageTree(firebase_storage.Reference ref) async {
    final result = await ref.listAll();
    for (final child in result.prefixes) {
      await _deleteStorageTree(child);
    }
    for (final item in result.items) {
      await item.delete();
    }
  }

  void _syncFromUser(User? user) {
    if (user == null) {
      _session = null;
    } else {
      _session = AuthSession(
        accessToken: user.uid,
        email: user.email ?? '',
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    _session = null;
    super.dispose();
  }
}

final AuthController authController = AuthController();
