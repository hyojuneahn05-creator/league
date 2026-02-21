import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

class AuthStorage {
  static const _kAccessToken = 'auth.access_token';
  static const _kEmail = 'auth.email';
  static const _kCreatedAt = 'auth.created_at';

  // Uses iOS Keychain / Android Keystore.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<AuthSession?> readSession() async {
    final accessToken = await _storage.read(key: _kAccessToken);
    if (accessToken == null || accessToken.isEmpty) return null;
    final email = await _storage.read(key: _kEmail) ?? '';
    final createdAtRaw = await _storage.read(key: _kCreatedAt);
    final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now();
    return AuthSession(accessToken: accessToken, email: email, createdAt: createdAt);
  }

  Future<void> writeSession(AuthSession s) async {
    await _storage.write(key: _kAccessToken, value: s.accessToken);
    await _storage.write(key: _kEmail, value: s.email);
    await _storage.write(key: _kCreatedAt, value: s.createdAt.toIso8601String());
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kCreatedAt);
  }
}

