import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_movies.dart';

class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const allGenre = '전체';
  static const _selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  Future<String> read() async {
    final genre = await _preferences.getString(_selectedGenreKey);
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
