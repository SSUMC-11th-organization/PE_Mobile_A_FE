import '../data/movie_data.dart';

/// 화면에서 어떤 결과를 받을지 고르는 값 (테스트용)
enum MovieLoadMode { success, empty, failure }

/// 영화 목록을 불러오지 못했을 때 던지는 예외
class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

/// 서버 대신 Future.delayed로 결과를 만들어 주는 가짜 서비스
class FakeMovieService {
  const FakeMovieService();

  // TODO(5주차 유저별 평점 조회 API): Future.delayed 기반 Mock을 실제 API 호출로 교체
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    // 서버 응답을 기다리는 것처럼 1초 지연 (최소 800ms 이상 조건)
    await Future<void>.delayed(const Duration(seconds: 1));

    return switch (mode) {
      MovieLoadMode.success => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure =>
        throw const MovieLoadException('영화를 불러오지 못했습니다.'),
    };
  }
}