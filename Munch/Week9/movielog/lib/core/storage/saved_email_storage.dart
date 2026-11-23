import 'package:shared_preferences/shared_preferences.dart';

class SavedEmailStorage {
  SavedEmailStorage([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _emailKey = 'movielog.saved_email';
  final SharedPreferencesAsync _prefs;

  Future<String?> read() => _prefs.getString(_emailKey);

  Future<void> save(String email) => _prefs.setString(_emailKey, email);

  Future<void> clear() => _prefs.remove(_emailKey);
}
