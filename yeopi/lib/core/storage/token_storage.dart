import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 인증 흐름이 저장소 구현(FlutterSecureStorage)에 직접 의존하지 않도록 나눈 추상화입니다.
// 테스트에서는 메모리 구현으로 바꿔 끼웁니다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

// iOS Keychain·Android Keystore에 암호화해서 보관합니다. SharedPreferences(평문)에는 토큰을 두지 않습니다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);
}
