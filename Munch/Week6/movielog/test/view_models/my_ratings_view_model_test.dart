import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import '../fakes/fake_rating_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';

void main() {
  late FakeRatingApiService ratingService;
  late FakeTmdbMovieService movieService;
  late MyRatingsViewModel viewModel;

  setUp(() {
    ratingService = FakeRatingApiService();
    movieService = FakeTmdbMovieService();
    viewModel = MyRatingsViewModel(ratingService, movieService, sampleMemberId);
  });

  tearDown(() => viewModel.dispose());

  test('memberId 1을 조회하고 로딩 중에는 loading 상태다', () async {
    ratingService.pending = Completer<void>();
    final future = viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.loading);
    expect(ratingService.requestedMemberIds, [1]);

    ratingService.pending!.complete();
    await future;
  });

  test('평점이 있으면 영화 정보와 묶어 success', () async {
    ratingService.ratings = [ratingFixture(1, 550, comment: '최고')];
    movieService.movieDetails = {550: movieFixture(550)};

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings.single.movie?.title, '영화 550');
    expect(viewModel.message, isNull);
  });

  test('빈 배열은 error가 아니라 empty', () async {
    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.empty);
  });

  test('평점 조회 실패는 error와 상태 코드별 문구', () async {
    ratingService.failStatus = 404;
    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.error);
    expect(viewModel.message, '존재하지 않는 회원입니다.');
  });

  test('영화 상세 조회 실패는 평점을 유지하고 placeholder 안내만 한다', () async {
    ratingService.ratings = [ratingFixture(1, 550), ratingFixture(2, 13)];
    movieService.movieDetails = {550: movieFixture(550)};
    movieService.failingMovieIds = {13};

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings, hasLength(2));
    expect(viewModel.ratings[1].movie, isNull);
    expect(viewModel.message, contains('일부 영화 정보'));
  });

  test('같은 movieId는 한 번만 조회하고, 실패한 id는 다음 로딩에서 다시 조회한다', () async {
    ratingService.ratings = [
      ratingFixture(1, 550),
      ratingFixture(2, 550),
      ratingFixture(3, 13),
    ];
    movieService.movieDetails = {550: movieFixture(550), 13: movieFixture(13)};
    movieService.failingMovieIds = {13};

    await viewModel.load();
    expect(movieService.findMovieCalls, [550, 13]);

    movieService.failingMovieIds = {};
    await viewModel.load();
    expect(movieService.findMovieCalls, [550, 13, 13]);
    expect(viewModel.message, isNull);
  });
}
