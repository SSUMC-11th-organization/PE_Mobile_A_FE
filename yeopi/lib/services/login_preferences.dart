import 'package:shared_preferences/shared_preferences.dart';

// Challenge '이메일 저장'용입니다. 평문 저장소라 이메일만 두고 비밀번호·토큰은 절대 저장하지 않습니다.
class LoginPreferences {
  LoginPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const savedEmailKey = 'movielog.saved_email';

  final SharedPreferencesAsync _preferences;

  Future<String?> readSavedEmail() => _preferences.getString(savedEmailKey);

  Future<void> saveEmail(String email) =>
      _preferences.setString(savedEmailKey, email.trim());

  Future<void> clearSavedEmail() => _preferences.remove(savedEmailKey);
}
