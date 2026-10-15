import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';

import '../fakes/fake_tmdb_movie_service.dart';

void main() {
  test('Popular 결과에서 앞의 5개만 보관한다', () async {
    final viewModel = MovieHomeViewModel(FakeTmdbMovieService());

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.success);
    expect(viewModel.popularMovies.map((movie) => movie.id), [1, 2, 3, 4, 5]);
  });

  test('5개보다 적으면 있는 만큼만 보여준다', () async {
    final service = FakeTmdbMovieService()
      ..popular = (page) => pageFixture(page, [10, 11]);
    final viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.popularMovies.map((movie) => movie.id), [10, 11]);
  });

  test('결과가 없으면 Empty, 요청이 실패하면 Error', () async {
    final emptyService = FakeTmdbMovieService()
      ..popular = (page) => pageFixture(page, []);
    final empty = MovieHomeViewModel(emptyService);
    await empty.loadPopular();
    expect(empty.status, MovieHomeLoadStatus.empty);

    final failing = MovieHomeViewModel(
      FakeTmdbMovieService()..failPopular = true,
    );
    await failing.loadPopular();
    expect(failing.status, MovieHomeLoadStatus.error);
    expect(failing.message, isNotNull);
  });
}
