import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 선택한 장르를 저장하고 불러오는 클래스
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  // 읽기와 쓰기에서 같은 Key를 써야 해서 상수로 한 번만 정의
  static const _selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  /// 저장된 장르를 읽는다. 저장된 값이 없으면 '전체'를 돌려준다.
  Future<String> read() async {
    return await _preferences.getString(_selectedGenreKey) ?? '전체';
  }

  /// 선택한 장르를 저장한다.
  Future<void> save(String genre) async {
    await _preferences.setString(_selectedGenreKey, genre);
  }

  /// 저장된 장르를 지운다. (테스트용)
  Future<void> clear() async {
    await _preferences.remove(_selectedGenreKey);
  }
}