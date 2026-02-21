import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_session.dart';

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

  Future<void> signUpWithEmail({
    required String email,
    required String password,
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
    await _createUserIfNotExists(user);
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

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    if (kIsWeb) {
      // google_sign_in_web requires clientId and does not allow serverClientId.
      await _googleSignIn.initialize(
        clientId: _googleWebClientId,
      );
    } else {
      await _googleSignIn.initialize(
        serverClientId: _googleWebClientId,
      );
    }
    _googleInitialized = true;
  }

  Future<void> _createUserIfNotExists(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final providerIds = user.providerData
        .map((p) => p.providerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',
      'providerIds': providerIds,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      await userRef.set({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await userRef.set(payload, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if Google session doesn't exist.
    }
    await _auth.signOut();
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
