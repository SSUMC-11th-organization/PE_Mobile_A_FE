import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면의 "이메일 저장"용. 이메일만 저장하고 비밀번호와 토큰은 저장하지 않는다.
abstract interface class SavedEmailStorage {
  Future<String?> read();
  Future<void> save(String email);
  Future<void> clear();
}

/// 이메일은 민감도가 낮은 편의 값이라 shared_preferences(평문)에 둔다.
class PrefsSavedEmailStorage implements SavedEmailStorage {
  PrefsSavedEmailStorage([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'movielog.saved_email';
  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> save(String email) => _prefs.setString(_key, email);

  @override
  Future<void> clear() => _prefs.remove(_key);
}
