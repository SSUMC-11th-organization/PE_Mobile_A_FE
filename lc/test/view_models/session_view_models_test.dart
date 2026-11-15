import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeMemberApiService memberApi;
  late FakeTokenStorage storage;
  late FakeRatingApiService ratingApi;
  late FakeDetailTmdbService movies;
  late AuthViewModel auth;
  late SessionRatingStore store;

  setUp(() async {
    memberApi = FakeMemberApiService();
    storage = FakeTokenStorage('stored');
    ratingApi = FakeRatingApiService();
    movies = FakeDetailTmdbService(
      known: {
        550: movieDto(550, title: '파이트 클럽'),
        680: movieDto(680, title: '펄프 픽션'),
      },
    );
    auth = AuthViewModel(FakeAuthApiService(), memberApi, storage);
    await auth.restoreSession(); // 저장된 토큰 + GET me → signedIn
    store = SessionRatingStore(auth);
  });

  tearDown(() {
    store.dispose();
    auth.dispose();
  });

  group('EditProfileViewModel', () {
    late EditProfileViewModel viewModel;

    setUp(() => viewModel = EditProfileViewModel(memberApi, auth));
    tearDown(() => viewModel.dispose());

    test('2~12자가 아니면 요청 없이 필드 오류다', () async {
      expect(await viewModel.save('가'), isFalse);
      expect(viewModel.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
      expect(await viewModel.save('가' * 13), isFalse);
      expect(memberApi.updateCalls, isEmpty);
    });

    test('현재 닉네임과 같으면 요청 없이 완료다 (409가 아니다)', () async {
      expect(await viewModel.save(' 영화광 '), isTrue);

      expect(memberApi.updateCalls, isEmpty);
      expect(viewModel.status, EditProfileStatus.success);
    });

    test('성공하면 응답으로 AuthViewModel.member를 교체한다 (GET me를 다시 부르지 않는다)', () async {
      final fetchBefore = memberApi.fetchCalls;

      expect(await viewModel.save('새이름'), isTrue);

      expect(memberApi.updateCalls, ['새이름']);
      expect(auth.member?.nickname, '새이름');
      expect(memberApi.fetchCalls, fetchBefore);
    });

    test('저장 중에는 saving이며 연속 탭이 요청을 늘리지 않는다', () async {
      memberApi.updateGate = Completer<void>();

      final pending = viewModel.save('새이름');
      expect(viewModel.status, EditProfileStatus.saving);
      expect(await viewModel.save('새이름'), isFalse);
      expect(memberApi.updateCalls, hasLength(1));

      memberApi.updateGate!.complete();
      expect(await pending, isTrue);
    });

    test('MEMBER409_1은 필드 오류이고 로그인 상태와 기존 닉네임을 유지한다', () async {
      memberApi.updateError = commonError(409, 'MEMBER409_1', '이미 사용 중인 닉네임입니다.');

      expect(await viewModel.save('중복이름'), isFalse);

      expect(viewModel.nicknameError, '이미 사용 중인 닉네임이에요.');
      expect(viewModel.message, isNull);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '영화광');
    });

    test('COMMON400은 서버 message를 필드 아래에 그대로 보여준다', () async {
      memberApi.updateError = commonError(400, 'COMMON400', '닉네임은 12자 이하여야 합니다.');

      await viewModel.save('새이름');

      expect(viewModel.nicknameError, '닉네임은 12자 이하여야 합니다.');
    });

    test('네트워크 실패는 Snackbar 문구이고 로그아웃하지 않는다', () async {
      memberApi.updateError = dioFailure('/v7/members/me');

      expect(await viewModel.save('새이름'), isFalse);

      expect(viewModel.message, contains('네트워크'));
      expect(viewModel.nicknameError, isNull);
      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, isNotNull);
    });

    test('만료(401)면 세션을 정리한다', () async {
      memberApi.updateError = expiredError('AUTH401_4');

      expect(await viewModel.save('새이름'), isFalse);

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('입력을 고치기 시작하면 이전 서버 오류가 사라진다', () async {
      memberApi.updateError = commonError(409, 'MEMBER409_1', 'x');
      await viewModel.save('중복이름');

      viewModel.onNicknameChanged();

      expect(viewModel.nicknameError, isNull);
    });
  });

  group('MovieDetailViewModel (등록)', () {
    MovieDetailViewModel build([int movieId = 550]) =>
        MovieDetailViewModel(ratingApi, store, auth, movieDto(movieId));

    test('TMDB id를 movieId로 보내고, 요청에 memberId가 없다. 응답 Rating을 세션 목록에 넣는다', () async {
      final viewModel = build(27205);

      await viewModel.createRating(score: 4, comment: '재밌다');

      final request = ratingApi.createCalls.single;
      expect(request.toJson(), {'movieId': 27205, 'score': 4, 'comment': '재밌다'});
      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(store.ratings.single.movieId, 27205);
      expect(store.ratings.single.ratingId, 1000); // 서버가 준 ratingId
      viewModel.dispose();
    });

    test('RATING409_1은 서버 문구로 안내하고 로그인 상태를 유지한다', () async {
      ratingApi.writeError = commonError(409, 'RATING409_1', '이미 이 영화에 평점을 남기셨습니다.');
      final viewModel = build();

      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
      expect(auth.status, AuthStatus.signedIn);
      expect(store.ratings, isEmpty);
      viewModel.dispose();
    });

    test('만료(AUTH401_2/3/4)면 세션을 정리한다', () async {
      ratingApi.writeError = expiredError('AUTH401_2');
      final viewModel = build();

      await viewModel.createRating(score: 5);

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
      viewModel.dispose();
    });

    test('네트워크 실패는 로그아웃하지 않는다', () async {
      ratingApi.writeError = dioFailure('/v7/ratings');
      final viewModel = build();

      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(auth.status, AuthStatus.signedIn);
      viewModel.dispose();
    });

    test('로그아웃 뒤 늦게 도착한 등록 응답은 반영하지 않는다', () async {
      ratingApi.writeGate = Completer<void>();
      final viewModel = build();
      final pending = viewModel.createRating(score: 5);

      await auth.logout();
      ratingApi.writeGate!.complete();
      await pending;

      expect(store.ratings, isEmpty);
      expect(viewModel.submitStatus, SubmitStatus.submitting); // 결과를 반영하지 않았다.
      viewModel.dispose();
    });
  });

  group('MyRatingsViewModel (수정·삭제)', () {
    Future<MyRatingsViewModel> loaded() async {
      final viewModel = MyRatingsViewModel(ratingApi, movies, store, auth);
      await viewModel.load();
      return viewModel;
    }

    setUp(() {
      store
        ..add(ratingDto(3, 999999, score: 4, comment: '영화 정보 없음'))
        ..add(ratingDto(2, 680, score: 3))
        ..add(ratingDto(1, 550, score: 5, comment: '최고!'));
    });

    test('세션의 평점을 movieId로 TMDB 영화 정보와 묶고, 없는 영화는 placeholder로 남긴다', () async {
      final viewModel = await loaded();

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings.map((e) => e.movie?.title), [
        '파이트 클럽',
        '펄프 픽션',
        null,
      ]);
      expect(viewModel.ratings.last.rating.movieId, 999999); // 평점은 지우지 않는다.
      expect(viewModel.message, contains('일부 영화 정보를 가져오지 못해'));
      viewModel.dispose();
    });

    test('세션에 평점이 없으면 empty다', () async {
      await auth.logout(); // 세션이 바뀌면 이전 평점이 비워진다.
      final viewModel = await loaded();

      expect(viewModel.status, MyRatingsLoadStatus.empty);
      viewModel.dispose();
    });

    test('수정은 ratingId만으로 요청하고, 응답 Rating으로 카드를 갱신한다', () async {
      final viewModel = await loaded();

      await viewModel.updateRating(ratingId: 1, score: 2, comment: '별로');

      final call = ratingApi.updateCalls.single;
      expect(call.ratingId, 1);
      expect(call.score, 2);
      expect(call.comment, '별로');
      final updated = viewModel.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(updated.rating.score, 2);
      expect(updated.rating.comment, '별로');
      viewModel.dispose();
    });

    test('삭제하면 목록에서 사라지고, 마지막 항목이면 empty가 된다', () async {
      final viewModel = await loaded();

      await viewModel.deleteRating(2);
      expect(ratingApi.deleteCalls, [2]);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [1, 3]);

      await viewModel.deleteRating(1);
      await viewModel.deleteRating(3);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
      viewModel.dispose();
    });

    test('RATING403_1은 안내만 하고 로그아웃하지 않는다. 목록도 그대로다', () async {
      final viewModel = await loaded();
      ratingApi.writeError = commonError(
        403,
        'RATING403_1',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 2),
        throwsA(
          isA<RatingWriteException>().having(
            (e) => e.message,
            'message',
            '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
          ),
        ),
      );
      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, isNotNull);
      expect(viewModel.ratings, hasLength(3));
      viewModel.dispose();
    });

    test('RATING404_1은 안내하고 이미 없는 평점을 목록에서 뺀다', () async {
      final viewModel = await loaded();
      ratingApi.writeError = commonError(404, 'RATING404_1', '존재하지 않는 평점입니다.');

      await expectLater(
        viewModel.deleteRating(2),
        throwsA(isA<RatingWriteException>()),
      );
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [1, 3]);
      expect(auth.status, AuthStatus.signedIn);
      viewModel.dispose();
    });

    test('만료(401)면 세션을 정리하고 만료 문구를 던진다', () async {
      final viewModel = await loaded();
      ratingApi.writeError = expiredError('AUTH401_3');

      await expectLater(
        viewModel.deleteRating(1),
        throwsA(
          isA<RatingWriteException>().having(
            (e) => e.message,
            'message',
            contains('만료'),
          ),
        ),
      );
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      viewModel.dispose();
    });

    test('다중 삭제: 일부만 실패하면 성공한 항목만 사라지고 실패한 항목의 선택은 유지된다', () async {
      ratingApi.failDeleteIds.add(2);
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(2);

      final failed = await viewModel.deleteSelectedRatings();

      expect(failed, 1);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2, 3]);
      expect(viewModel.selectedRatingIds, {2});
      expect(viewModel.isEditMode, isTrue);
      expect(viewModel.isDeletingSelected, isFalse);
      viewModel.dispose();
    });

    test('다중 삭제가 모두 성공하면 편집 모드가 끝난다', () async {
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(3);

      expect(await viewModel.deleteSelectedRatings(), 0);

      expect(ratingApi.deleteCalls, [1, 3]);
      expect(viewModel.ratings.single.rating.ratingId, 2);
      expect(viewModel.isEditMode, isFalse);
      viewModel.dispose();
    });
  });
}
