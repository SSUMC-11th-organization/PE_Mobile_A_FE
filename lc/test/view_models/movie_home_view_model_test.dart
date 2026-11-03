import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_home_view_model.dart';

import '../test_helpers.dart';

void main() {
  late MovieHomeViewModel viewModel;

  tearDown(() => viewModel.dispose());

  test('인기 영화는 앞의 5개만 사용한다', () async {
    final service = FakeTmdbMovieService(popular: movieDtos(20));
    viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.success);
    expect(viewModel.popularMovies.map((movie) => movie.id), [1, 2, 3, 4, 5]);
  });

  test('5개보다 적게 와도 범위 오류 없이 있는 만큼만 사용한다', () async {
    final service = FakeTmdbMovieService(popular: movieDtos(3));
    viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.success);
    expect(viewModel.popularMovies, hasLength(3));
  });

  test('결과가 없으면 Empty 상태다', () async {
    final service = FakeTmdbMovieService(popular: const []);
    viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.empty);
  });

  test('요청이 실패하면 Error 상태이고 재시도하면 복구된다', () async {
    final service = FakeTmdbMovieService()..failPopular = true;
    viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();
    expect(viewModel.status, MovieHomeLoadStatus.error);
    expect(viewModel.message, isNotNull);

    service.failPopular = false;
    await viewModel.loadPopular();
    expect(viewModel.status, MovieHomeLoadStatus.success);
  });

  test('장르 이름 요청이 실패해도 인기 영화는 보여주고 장르만 생략한다', () async {
    final service = FakeTmdbMovieService()..failGenres = true;
    viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.success);
    expect(viewModel.genreNamesOf(viewModel.popularMovies.first), isEmpty);
  });

  test('장르 이름을 함께 가져와 영화의 장르 id를 이름으로 바꾼다', () async {
    final service = FakeTmdbMovieService(
      popular: [
        movieDto(1, genreIds: [28, 12]),
      ],
    );
    viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.genreNamesOf(viewModel.popularMovies.first), ['액션', '모험']);
  });
}
