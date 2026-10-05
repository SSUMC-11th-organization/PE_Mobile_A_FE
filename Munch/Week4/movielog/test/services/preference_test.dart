import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/models/movie_sort.dart';
import 'package:movielog/services/genre_preference.dart';
import 'package:movielog/services/sort_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('GenrePreference', () {
    test('저장된 값이 없으면 전체를 반환한다', () async {
      expect(await GenrePreference().read(), GenrePreference.allGenre);
    });

    test('저장한 장르를 다시 읽어온다', () async {
      final preference = GenrePreference();
      await preference.save('SF');

      expect(await GenrePreference().read(), 'SF');
    });

    test('목록에 없는 장르가 저장돼 있으면 전체를 반환한다', () async {
      await SharedPreferencesAsync().setString('selected_genre', '뮤지컬');

      expect(await GenrePreference().read(), GenrePreference.allGenre);
    });

    test('clear 이후에는 전체를 반환한다', () async {
      final preference = GenrePreference();
      await preference.save('SF');
      await preference.clear();

      expect(await preference.read(), GenrePreference.allGenre);
    });
  });

  group('SortPreference', () {
    test('저장된 값이 없으면 기본 정렬을 반환한다', () async {
      expect(await SortPreference().read(), SortPreference.defaultSort);
    });

    test('저장한 정렬 방식을 다시 읽어온다', () async {
      await SortPreference().save(MovieSort.rating);

      expect(await SortPreference().read(), MovieSort.rating);
    });

    test('알 수 없는 값이 저장돼 있으면 기본 정렬을 반환한다', () async {
      await SharedPreferencesAsync().setString('selected_sort', 'unknown');

      expect(await SortPreference().read(), SortPreference.defaultSort);
    });
  });
}
