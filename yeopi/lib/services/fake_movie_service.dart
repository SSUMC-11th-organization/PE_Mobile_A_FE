import '../models/movie.dart';

// 실제 API 없이 Loading·Empty·Error·Success를 재현하기 위한 요청 결과 모드입니다.
enum MovieLoadMode {
  success('성공'),
  empty('빈 목록'),
  failure('실패'),
  slow('응답 지연');

  const MovieLoadMode(this.label);
  final String label;
}

class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

// 화면은 이 클래스가 Future.delayed를 쓰는지 실제 API를 부르는지 알 필요가 없습니다.
class FakeMovieService {
  const FakeMovieService({
    this.delay = const Duration(seconds: 1),
    this.slowDelay = const Duration(seconds: 5),
  });

  final Duration delay;
  final Duration slowDelay;

  // TODO(5주차 유저별 평점 조회 API): 같은 Future<List<Movie>> 시그니처의 실제 API Service로 교체
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    await Future<void>.delayed(mode == MovieLoadMode.slow ? slowDelay : delay);

    return switch (mode) {
      MovieLoadMode.success || MovieLoadMode.slow => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화를 불러오지 못했습니다.',
      ),
    };
  }
}
