import '../data/mock_movies.dart';
import '../models/movie.dart';

/// Loading 이후 어떤 결과로 끝날지 정한다. Empty·Error 화면 확인용.
enum MovieLoadMode { success, empty, failure }

class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

/// 화면은 이 클래스가 Mock인지 실제 API인지 모른 채 `fetchMovies()`만 호출한다.
class FakeMovieService {
  const FakeMovieService({this.mode = MovieLoadMode.success});

  final MovieLoadMode mode;

  // TODO(5주차 유저별 평점 조회 API): GET /v5/members/{memberId}/ratings 호출로 교체
  Future<List<Movie>> fetchMovies() async {
    await Future<void>.delayed(const Duration(seconds: 1));

    return switch (mode) {
      MovieLoadMode.success => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화를 불러오지 못했습니다.',
      ),
    };
  }
}
