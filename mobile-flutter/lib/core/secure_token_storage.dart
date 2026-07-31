import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Auth token persistence - Keychain on iOS, EncryptedSharedPreferences on
/// Android. This is a hard project security rule: the auth token is never
/// written to `SharedPreferences` (or any other plaintext store), unlike the
/// web app's `localStorage`-backed client, because a mobile app's local
/// storage is a materially different threat model (device compromise,
/// shared devices, backup extraction).
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _tokenKey = 'mudbase_auth_token';
  static const String _refreshTokenKey = 'mudbase_refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveSession({
    required String token,
    String? refreshToken,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
