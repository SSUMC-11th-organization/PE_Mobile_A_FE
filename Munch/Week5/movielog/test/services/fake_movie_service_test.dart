import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/services/fake_movie_service.dart';

void main() {
  group('FakeMovieService', () {
    test('success 모드는 Mock 영화 목록을 반환한다', () async {
      final result = await const FakeMovieService().fetchMovies();

      expect(result, movies);
    });

    test('empty 모드는 빈 목록을 반환한다', () async {
      final result = await const FakeMovieService(mode: MovieLoadMode.empty)
          .fetchMovies();

      expect(result, isEmpty);
    });

    test('failure 모드는 MovieLoadException을 던진다', () async {
      await expectLater(
        const FakeMovieService(mode: MovieLoadMode.failure).fetchMovies(),
        throwsA(isA<MovieLoadException>()),
      );
    });

    test('결과는 최소 800ms 이후에 전달된다', () async {
      final stopwatch = Stopwatch()..start();
      await const FakeMovieService().fetchMovies();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(800));
    });

    test('slow 모드에 timeout을 걸면 TimeoutException이 발생한다', () async {
      await expectLater(
        const FakeMovieService(mode: MovieLoadMode.slow)
            .fetchMovies()
            .timeout(const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
