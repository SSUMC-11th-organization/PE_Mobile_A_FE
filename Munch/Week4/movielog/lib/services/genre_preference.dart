import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_movies.dart';

/// 마지막으로 선택한 장르 Chip을 로컬에 저장한다. 민감한 값은 저장하지 않는다.
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const allGenre = '전체';
  static const _selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  Future<String> read() async {
    final genre = await _preferences.getString(_selectedGenreKey);
    // 장르 목록이 바뀌어 더 이상 없는 값이 저장돼 있으면 '전체'로 되돌린다.
    if (genre == null || !movieGenres.contains(genre)) return allGenre;
    return genre;
  }

  Future<void> save(String genre) async {
    await _preferences.setString(_selectedGenreKey, genre);
  }

  Future<void> clear() async {
    await _preferences.remove(_selectedGenreKey);
  }
}
