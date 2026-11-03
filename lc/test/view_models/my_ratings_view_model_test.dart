import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/my_ratings_view_model.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeRatingApiService ratingService;
  late FakeDetailTmdbService movieService;

  MyRatingsViewModel build() =>
      MyRatingsViewModel(ratingService, movieService, sampleMemberId);

  setUp(() {
    ratingService = FakeRatingApiService();
    movieService = FakeDetailTmdbService();
  });

  test('학습용 memberId는 1이다', () {
    expect(sampleMemberId, 1);
  });

  test('처음에는 idle이다', () {
    final viewModel = build();
    expect(viewModel.status, MyRatingsLoadStatus.idle);
    viewModel.dispose();
  });

  test('요청 중에는 loading이다', () async {
    ratingService.gate = Completer<void>();
    final viewModel = build();

    final pending = viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.loading);

    ratingService.gate!.complete();
    await pending;
    viewModel.dispose();
  });

  test('빈 배열은 Error가 아니라 Empty다', () async {
    final viewModel = build();

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.empty);
    expect(viewModel.ratings, isEmpty);
    viewModel.dispose();
  });

  test('평점이 있으면 success이고 TMDB 영화 정보가 묶인다', () async {
    ratingService.ratings = [ratingDto(1, 550, score: 5, comment: '최고')];
    movieService = FakeDetailTmdbService(
      known: {550: movieDto(550, title: '파이트 클럽')},
    );
    final viewModel = build();

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings.single.movie?.title, '파이트 클럽');
    expect(viewModel.ratings.single.rating.comment, '최고');
    expect(viewModel.message, isNull);
    viewModel.dispose();
  });

  test('같은 movieId는 한 번만 조회한다', () async {
    ratingService.ratings = [
      ratingDto(1, 550),
      ratingDto(2, 550, score: 2),
      ratingDto(3, 27205),
    ];
    movieService = FakeDetailTmdbService(
      known: {550: movieDto(550), 27205: movieDto(27205)},
    );
    final viewModel = build();

    await viewModel.load();

    expect(movieService.detailCalls, [550, 27205]);
    expect(viewModel.ratings, hasLength(3));
    viewModel.dispose();
  });

  test('TMDB에서 영화를 못 찾아도(404) 평점은 남고 안내 문구가 생긴다', () async {
    ratingService.ratings = [ratingDto(1, 999999, score: 4)];
    final viewModel = build();

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings.single.movie, isNull);
    expect(viewModel.ratings.single.rating.movieId, 999999);
    expect(viewModel.message, contains('일부 영화 정보를 가져오지 못해'));
    viewModel.dispose();
  });

  test('영화 정보 조회가 네트워크로 실패해도 평점 목록은 Error가 되지 않는다', () async {
    ratingService.ratings = [ratingDto(1, 550), ratingDto(2, 27205)];
    movieService = FakeDetailTmdbService(
      known: {27205: movieDto(27205)},
      networkFailIds: {550},
    );
    final viewModel = build();

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings, hasLength(2));
    expect(viewModel.ratings.first.movie, isNull);
    expect(viewModel.ratings.last.movie, isNotNull);

    // 일시적인 네트워크 실패는 캐시하지 않으므로 다음 로딩에서 다시 시도한다.
    movieService.networkFailIds = {};
    movieService.known[550] = movieDto(550);
    await viewModel.load();
    expect(viewModel.ratings.first.movie, isNotNull);
    expect(viewModel.message, isNull);
    viewModel.dispose();
  });

  test('평점 조회 400 · 404 · 통신 실패는 서로 다른 문구의 error다', () async {
    final messages = <String>{};
    for (final status in [400, 404, 0]) {
      ratingService.failWithStatus = status;
      final viewModel = build();

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.error);
      messages.add(viewModel.message!);
      viewModel.dispose();
    }
    expect(messages, hasLength(3));
  });

  test('다시 시도하면 error에서 success로 돌아온다', () async {
    ratingService
      ..failWithStatus = 500
      ..ratings = [ratingDto(1, 550)];
    movieService = FakeDetailTmdbService(known: {550: movieDto(550)});
    final viewModel = build();
    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.error);

    ratingService.failWithStatus = null;
    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    viewModel.dispose();
  });

  test('화면이 사라진 뒤 도착한 응답은 무시한다', () async {
    ratingService
      ..gate = Completer<void>()
      ..ratings = [ratingDto(1, 550)];
    final viewModel = build();

    final pending = viewModel.load();
    viewModel.dispose();
    ratingService.gate!.complete();

    // dispose된 뒤 notifyListeners를 부르면 예외가 나므로, 조용히 끝나야 한다.
    await pending;
  });
}
