import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';

/// 영화 목록에서 마지막으로 선택한 장르를 저장한다.
/// 장르 이름 같은 중요하지 않은 값만 저장하며, 토큰·비밀번호는 저장하지 않는다.
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  /// 저장된 값이 없거나 읽기에 실패하면 '전체'를 돌려준다.
  /// 장르 복원은 부가 기능이라 실패해도 영화 목록 자체를 막지 않는다.
  Future<String> read() async {
    try {
      return await _preferences.getString(selectedGenreKey) ?? allGenresLabel;
    } on Exception catch (error) {
      debugPrint('선택 장르 읽기 실패: $error');
      return allGenresLabel;
    }
  }

  Future<void> save(String genre) async {
    try {
      await _preferences.setString(selectedGenreKey, genre);
    } on Exception catch (error) {
      debugPrint('선택 장르 저장 실패: $error');
    }
  }

  Future<void> clear() async {
    await _preferences.remove(selectedGenreKey);
  }
}
