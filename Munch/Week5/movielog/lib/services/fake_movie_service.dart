import '../data/mock_movies.dart';
import '../models/movie.dart';

enum MovieLoadMode { success, empty, failure, slow }

class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

class FakeMovieService {
  const FakeMovieService({this.mode = MovieLoadMode.success});

  static const loadDelay = Duration(seconds: 1);
  static const slowDelay = Duration(seconds: 10);

  final MovieLoadMode mode;

  // TODO(5주차 유저별 평점 조회 API): GET /v5/members/{memberId}/ratings 호출로 교체
  Future<List<Movie>> fetchMovies() async {
    await Future<void>.delayed(
      mode == MovieLoadMode.slow ? slowDelay : loadDelay,
    );

    return switch (mode) {
      MovieLoadMode.success || MovieLoadMode.slow => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화를 불러오지 못했습니다.',
      ),
    };
  }
}
