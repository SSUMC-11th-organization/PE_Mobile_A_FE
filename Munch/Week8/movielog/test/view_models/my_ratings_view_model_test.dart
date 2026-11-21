import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_rating_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';

void main() {
  late FakeRatingApiService ratingService;
  late FakeTmdbMovieService movieService;
  late SessionRatingStore store;
  late InMemoryTokenStorage tokenStorage;
  late AuthViewModel auth;
  late MyRatingsViewModel viewModel;

  void seed(List<RatingDto> ratings) {
    for (final rating in ratings.reversed) {
      store.add(rating);
      ratingService.movieIdsByRatingId[rating.ratingId] = rating.movieId;
    }
  }

  setUp(() async {
    ratingService = FakeRatingApiService();
    movieService = FakeTmdbMovieService();
    store = SessionRatingStore();
    tokenStorage = InMemoryTokenStorage('token');
    auth = AuthViewModel(
      FakeAuthApiService(),
      FakeMemberApiService(),
      tokenStorage,
      store,
    );
    await auth.restoreSession();
    viewModel = MyRatingsViewModel(ratingService, movieService, store, auth);
  });

  tearDown(() {
    viewModel.dispose();
    auth.dispose();
  });

  test('세션에 등록한 평점을 영화 정보와 묶어 success', () async {
    seed([ratingFixture(1, 550, comment: '최고')]);
    movieService.movieDetails = {550: movieFixture(550)};

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings.single.movie?.title, '영화 550');
    expect(viewModel.message, isNull);
  });

  test('세션에 등록한 평점이 없으면 empty', () async {
    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.empty);
  });

  test('영화 상세 조회 실패는 평점을 유지하고 placeholder 안내만 한다', () async {
    seed([ratingFixture(1, 550), ratingFixture(2, 13)]);
    movieService.movieDetails = {550: movieFixture(550)};
    movieService.failingMovieIds = {13};

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings, hasLength(2));
    expect(viewModel.ratings[1].movie, isNull);
    expect(viewModel.message, contains('일부 영화 정보'));
  });

  test('수정 성공은 응답 Rating으로 목록과 세션 저장소를 교체한다', () async {
    seed([ratingFixture(1, 13, comment: '기존')]);
    await viewModel.load();

    await viewModel.updateRating(ratingId: 1, score: 2, comment: '수정');

    expect(ratingService.updates.single.comment, '수정');
    expect(viewModel.ratings.single.rating.score, 2);
    expect(viewModel.ratings.single.rating.movieId, 13);
    expect(store.ratings.single.comment, '수정');
  });

  test('삭제 성공은 목록과 세션 저장소에서 제거한다', () async {
    seed([ratingFixture(1, 13)]);
    await viewModel.load();

    await viewModel.deleteRating(1);

    expect(viewModel.status, MyRatingsLoadStatus.empty);
    expect(store.ratings, isEmpty);
  });

  test('403은 안내만 하고 로그아웃하지 않는다', () async {
    seed([ratingFixture(1, 13)]);
    await viewModel.load();
    ratingService.writeFailure = apiError(403, 'RATING403_1');

    await expectLater(viewModel.deleteRating(1), throwsA(isA<ActionFailure>()));

    expect(viewModel.message, '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.');
    expect(auth.status, AuthStatus.signedIn);
    expect(tokenStorage.token, 'token');
    expect(viewModel.ratings, hasLength(1));
  });

  test('404는 이미 없는 평점을 목록에서 정리한다', () async {
    seed([ratingFixture(1, 13), ratingFixture(2, 14)]);
    await viewModel.load();
    ratingService.writeFailure = apiError(404, 'RATING404_1');

    await expectLater(
      viewModel.updateRating(ratingId: 1, score: 3),
      throwsA(isA<ActionFailure>()),
    );

    expect(viewModel.ratings.single.rating.ratingId, 2);
    expect(auth.status, AuthStatus.signedIn);
  });

  test('401은 세션을 정리하고 토큰을 삭제한다', () async {
    seed([ratingFixture(1, 13)]);
    await viewModel.load();
    ratingService.writeFailure = apiError(401, 'AUTH401_4');

    await expectLater(viewModel.deleteRating(1), throwsA(isA<ActionFailure>()));

    expect(auth.status, AuthStatus.signedOut);
    expect(auth.sessionExpired, isTrue);
    expect(tokenStorage.token, isNull);
    expect(store.ratings, isEmpty);
  });

  test('다중 삭제 일부 실패 시 성공 항목만 사라지고 실패 항목은 선택을 유지한다', () async {
    seed([ratingFixture(1, 13), ratingFixture(2, 14)]);
    ratingService.failingDeleteIds = {2};
    await viewModel.load();
    viewModel
      ..startSelection()
      ..toggleSelected(1)
      ..toggleSelected(2);

    await viewModel.deleteSelectedRatings();

    expect(ratingService.deletedRatingIds, [1]);
    expect(viewModel.ratings.single.rating.ratingId, 2);
    expect(viewModel.selectedRatingIds, {2});
    expect(viewModel.isSelectionMode, isTrue);
    expect(viewModel.failedDeleteCount, 1);
    expect(viewModel.isDeletingSelected, isFalse);
  });

  test('다중 삭제가 모두 성공하면 선택 모드를 끝낸다', () async {
    seed([ratingFixture(1, 13)]);
    await viewModel.load();
    viewModel
      ..startSelection()
      ..toggleSelected(1);

    await viewModel.deleteSelectedRatings();

    expect(viewModel.isSelectionMode, isFalse);
    expect(viewModel.status, MyRatingsLoadStatus.empty);
    expect(viewModel.failedDeleteCount, 0);
  });

  test('로그아웃 뒤 늦게 도착한 수정 응답은 반영하지 않는다', () async {
    seed([ratingFixture(1, 13, comment: '기존')]);
    await viewModel.load();

    final pending = viewModel.updateRating(ratingId: 1, score: 1);
    await auth.logout();
    await pending;

    expect(store.ratings, isEmpty);
    expect(viewModel.ratings.single.rating.comment, '기존');
  });
}
