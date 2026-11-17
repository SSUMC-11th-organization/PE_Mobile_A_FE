import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// accessToken을 저장·조회·삭제하는 규칙. 인증 흐름이 구체적인 저장소 구현에 직접 의존하지 않게 한다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// iOS Keychain·Android Keystore 같은 OS 보안 저장 영역에 토큰을 암호화해 보관한다.
/// (SharedPreferences는 평문 저장이라 토큰에는 쓰지 않는다.)
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}
