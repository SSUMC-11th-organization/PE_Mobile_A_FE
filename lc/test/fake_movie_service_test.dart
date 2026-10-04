import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/models/movie.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/genre_preference.dart';

import 'test_helpers.dart';

void main() {
  group('FakeMovieService', () {
    const service = FakeMovieService(delay: Duration.zero);

    test('success 모드는 Mock 영화 목록을 돌려준다', () async {
      expect(await service.fetchMovies(), movies);
    });

    test('empty 모드는 빈 목록을 돌려준다', () async {
      expect(await service.fetchMovies(mode: MovieLoadMode.empty), isEmpty);
    });

    test('failure 모드는 MovieLoadException으로 완료된다', () async {
      expect(
        service.fetchMovies(mode: MovieLoadMode.failure),
        throwsA(isA<MovieLoadException>()),
      );
    });

    test('기본 지연 시간은 Loading이 보이도록 800ms 이상이다', () {
      expect(
        const FakeMovieService().delay,
        greaterThanOrEqualTo(const Duration(milliseconds: 800)),
      );
    });
  });

  group('GenrePreference', () {
    setUp(useInMemoryPreferences);

    test('저장된 값이 없으면 전체를 돌려준다', () async {
      expect(await GenrePreference().read(), allGenresLabel);
    });

    test('저장한 장르를 다시 읽을 수 있다', () async {
      await GenrePreference().save('SF');
      expect(await GenrePreference().read(), 'SF');
    });

    test('clear하면 기본값으로 돌아간다', () async {
      final preference = GenrePreference();
      await preference.save('SF');
      await preference.clear();
      expect(await preference.read(), allGenresLabel);
    });
  });

  group('filterMoviesByGenre', () {
    test('전체는 필터링하지 않는다', () {
      expect(filterMoviesByGenre(movies, allGenresLabel), movies);
    });

    test('장르나 태그가 맞는 영화만 남긴다', () {
      final result = filterMoviesByGenre(movies, 'SF');
      expect(result, isNotEmpty);
      expect(result.every((movie) => movie.matchesAnyGenre({'SF'})), isTrue);
    });

    test('맞는 영화가 없으면 빈 목록이다', () {
      expect(filterMoviesByGenre(movies, '코미디'), isEmpty);
    });
  });
}
