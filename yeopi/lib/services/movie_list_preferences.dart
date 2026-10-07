import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';

// 마지막 선택 장르·정렬처럼 잃어버려도 괜찮은 단순 설정값만 저장합니다.
// 토큰·비밀번호 같은 민감한 값은 flutter_secure_storage를 사용해야 합니다.
class MovieListPreferences {
  MovieListPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const selectedGenreKey = 'selected_genre';
  static const sortKey = 'movie_sort';

  final SharedPreferencesAsync _preferences;

  Future<String> readGenre() async {
    final genre = await _preferences.getString(selectedGenreKey);
    // 장르 목록이 바뀌어 저장된 값이 사라졌다면 기본값으로 돌아갑니다.
    return movieGenres.contains(genre) ? genre! : movieGenres.first;
  }

  Future<void> saveGenre(String genre) async {
    await _preferences.setString(selectedGenreKey, genre);
  }

  Future<String?> readSort() => _preferences.getString(sortKey);

  Future<void> saveSort(String sortName) async {
    await _preferences.setString(sortKey, sortName);
  }
}
