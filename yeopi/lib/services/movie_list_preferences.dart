import 'package:shared_preferences/shared_preferences.dart';

// 마지막 선택 장르·정렬처럼 잃어버려도 괜찮은 단순 설정값만 저장합니다.
// 토큰·비밀번호 같은 민감한 값은 flutter_secure_storage를 사용해야 합니다.
class MovieListPreferences {
  MovieListPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  // 4주차에는 장르 이름(String)을 저장했기 때문에 타입이 다른 새 key를 씁니다.
  static const selectedGenreIdKey = 'selected_genre_id';
  static const sortKey = 'movie_sort';

  final SharedPreferencesAsync _preferences;

  // null은 '전체'입니다. 저장된 ID가 지금 장르 목록에 있는지는 ViewModel이 확인합니다.
  Future<int?> readGenreId() => _preferences.getInt(selectedGenreIdKey);

  Future<void> saveGenreId(int? genreId) async {
    if (genreId == null) {
      await _preferences.remove(selectedGenreIdKey);
    } else {
      await _preferences.setInt(selectedGenreIdKey, genreId);
    }
  }

  Future<String?> readSort() => _preferences.getString(sortKey);

  Future<void> saveSort(String sortName) async {
    await _preferences.setString(sortKey, sortName);
  }
}
