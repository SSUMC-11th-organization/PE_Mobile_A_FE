import '../models/movie.dart';

enum MovieLoadMode { success, empty, failure }

class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

// TODO(5주차 유저별 평점 조회 API): 실제 API Service로 교체한다. 화면은 fetchMovies()의 호출 경계만 알고 있다.
class FakeMovieService {
  const FakeMovieService({this.delay = const Duration(seconds: 1)});

  /// Loading 화면이 눈에 보이도록 두는 지연 시간. 테스트에서만 줄여서 사용한다.
  final Duration delay;

  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    await Future<void>.delayed(delay);

    return switch (mode) {
      MovieLoadMode.success => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화를 불러오지 못했습니다.',
      ),
    };
  }
}
