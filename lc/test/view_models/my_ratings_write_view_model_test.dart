import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/my_ratings_view_model.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeRatingApiService ratingService;
  late FakeDetailTmdbService movieService;

  Future<MyRatingsViewModel> loaded({int memberId = 9}) async {
    final viewModel = MyRatingsViewModel(ratingService, movieService, memberId);
    await viewModel.load();
    return viewModel;
  }

  setUp(() {
    ratingService = FakeRatingApiService(
      ratings: [
        ratingDto(1, 550, score: 5, comment: '최고!'),
        ratingDto(2, 680, score: 3),
        ratingDto(3, 13, score: 4, comment: '좋다'),
      ],
    );
    movieService = FakeDetailTmdbService(
      known: {
        550: movieDto(550, title: '파이트 클럽'),
        680: movieDto(680, title: '펄프 픽션'),
        13: movieDto(13, title: '포레스트 검프'),
      },
    );
  });

  group('수정', () {
    test('성공하면 PATCH를 보내고 목록을 다시 조회해 서버 값으로 맞춘다', () async {
      final viewModel = await loaded();
      final callsBefore = ratingService.calls;

      await viewModel.updateRating(ratingId: 1, score: 2, comment: '별로');

      expect(ratingService.updateCalls.single.ratingId, 1);
      expect(ratingService.updateCalls.single.memberId, 9);
      expect(ratingService.calls, callsBefore + 1); // 저장 뒤 GET
      final updated = viewModel.ratings.firstWhere(
        (e) => e.rating.ratingId == 1,
      );
      expect(updated.rating.score, 2);
      expect(updated.rating.comment, '별로');
      viewModel.dispose();
    });

    test('comment를 null로 보내면 후기가 지워진다 (의도를 명시한다)', () async {
      final viewModel = await loaded();

      await viewModel.updateRating(ratingId: 1, score: 5, comment: null);

      expect(ratingService.updateCalls.single.comment, isNull);
      final updated = viewModel.ratings.firstWhere(
        (e) => e.rating.ratingId == 1,
      );
      expect(updated.rating.comment, isNull);
      viewModel.dispose();
    });

    test('403은 서버 message를 담은 RatingWriteException으로 던지고, 목록은 다시 조회한다', () async {
      final viewModel = await loaded();
      final callsBefore = ratingService.calls;
      ratingService.writeError = commonError(
        403,
        'COMMON403',
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
      expect(ratingService.calls, callsBefore + 1); // 화면과 서버를 맞추려고 재조회
      viewModel.dispose();
    });

    test('404도 재조회하지만 400은 재조회하지 않는다', () async {
      final viewModel = await loaded();

      ratingService.writeError = commonError(
        404,
        'COMMON404',
        '존재하지 않는 평점입니다.',
      );
      var before = ratingService.calls;
      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 2),
        throwsA(isA<RatingWriteException>()),
      );
      expect(ratingService.calls, before + 1);

      ratingService.writeError = commonError(
        400,
        'COMMON400',
        '별점은 5점 이하여야 합니다.',
      );
      before = ratingService.calls;
      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 2),
        throwsA(isA<RatingWriteException>()),
      );
      expect(ratingService.calls, before);
      viewModel.dispose();
    });

    test('저장은 성공했는데 GET만 실패하면 쓰기 실패로 던지지 않고 조회 안내만 남긴다', () async {
      final viewModel = await loaded();
      ratingService.failFetchTimes = 1;

      await viewModel.updateRating(ratingId: 1, score: 2, comment: '별로');

      expect(ratingService.updateCalls, hasLength(1));
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));
      viewModel.dispose();
    });

    test('조회만 다시 시도하면 쓰기를 다시 보내지 않고 복구된다', () async {
      final viewModel = await loaded();
      ratingService.failFetchTimes = 1;
      await viewModel.updateRating(ratingId: 1, score: 2, comment: '별로');
      expect(viewModel.status, MyRatingsLoadStatus.error);

      await viewModel.load(); // 화면의 "다시 시도"

      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.refreshWarning, isNull);
      expect(ratingService.updateCalls, hasLength(1)); // PATCH는 다시 가지 않는다.
      viewModel.dispose();
    });
  });

  group('삭제', () {
    test('성공하면 DELETE를 보내고 목록에서 사라진다', () async {
      final viewModel = await loaded();

      await viewModel.deleteRating(2);

      expect(ratingService.deleteCalls, [2]);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [1, 3]);
      viewModel.dispose();
    });

    test('마지막 항목을 지우면 Empty 상태가 된다', () async {
      ratingService.ratings = [ratingDto(1, 550)];
      final viewModel = await loaded();

      await viewModel.deleteRating(1);

      expect(viewModel.status, MyRatingsLoadStatus.empty);
      expect(viewModel.ratings, isEmpty);
      viewModel.dispose();
    });

    test('404는 서버 message로 던지고 목록을 다시 조회한다', () async {
      final viewModel = await loaded();
      final before = ratingService.calls;
      ratingService.writeError = commonError(
        404,
        'COMMON404',
        '존재하지 않는 평점입니다.',
      );

      await expectLater(
        viewModel.deleteRating(2),
        throwsA(
          isA<RatingWriteException>().having(
            (e) => e.message,
            'message',
            '존재하지 않는 평점입니다.',
          ),
        ),
      );
      expect(ratingService.calls, before + 1);
      viewModel.dispose();
    });

    test('삭제 성공 뒤 GET이 실패해도 삭제 실패가 아니다', () async {
      final viewModel = await loaded();
      ratingService.failFetchTimes = 1;

      await viewModel.deleteRating(2);

      expect(ratingService.deleteCalls, [2]);
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));
      viewModel.dispose();
    });
  });

  group('편집(다중 선택) 모드', () {
    test('편집을 누르면 선택 모드가 켜지고, 카드를 눌러 선택·해제한다', () async {
      final viewModel = await loaded();

      viewModel.enterEditMode();
      expect(viewModel.isEditMode, isTrue);
      expect(viewModel.selectedRatingIds, isEmpty);

      viewModel.toggleSelection(1);
      viewModel.toggleSelection(3);
      expect(viewModel.selectedRatingIds, {1, 3});

      viewModel.toggleSelection(1);
      expect(viewModel.selectedRatingIds, {3});
      viewModel.dispose();
    });

    test('취소하면 선택을 해제하고 기본 목록으로 돌아온다', () async {
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);

      viewModel.cancelEditMode();

      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
      viewModel.dispose();
    });

    test('편집 모드가 아닐 때는 선택되지 않는다', () async {
      final viewModel = await loaded();

      viewModel.toggleSelection(1);

      expect(viewModel.selectedRatingIds, isEmpty);
      viewModel.dispose();
    });

    test('선택한 항목만 삭제하고 성공하면 편집 모드를 끝낸다', () async {
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(3);

      final failed = await viewModel.deleteSelectedRatings();

      expect(failed, 0);
      expect(ratingService.deleteCalls, [1, 3]);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2]);
      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
      expect(viewModel.isDeletingSelected, isFalse);
      viewModel.dispose();
    });

    test('일부만 실패하면 성공한 항목만 사라지고 실패한 항목의 선택은 유지된다', () async {
      ratingService.failDeleteIds.add(3);
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(3);

      final failed = await viewModel.deleteSelectedRatings();

      expect(failed, 1);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2, 3]);
      expect(viewModel.selectedRatingIds, {3}); // 다시 확인하고 재시도할 수 있다.
      expect(viewModel.isEditMode, isTrue);
      expect(viewModel.message, contains('1개 항목을 삭제하지 못했습니다'));
      viewModel.dispose();
    });

    test('삭제하는 동안은 isDeletingSelected이고 다시 눌러도 요청이 늘지 않는다', () async {
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);
      ratingService.writeGate = Completer<void>();

      final pending = viewModel.deleteSelectedRatings();
      expect(viewModel.isDeletingSelected, isTrue);
      await viewModel.deleteSelectedRatings();
      expect(ratingService.deleteCalls, hasLength(1));

      // 삭제 중에는 편집 취소나 선택 변경도 막는다.
      viewModel.cancelEditMode();
      viewModel.toggleSelection(3);
      expect(viewModel.isEditMode, isTrue);
      expect(viewModel.selectedRatingIds, {1});

      ratingService.writeGate!.complete();
      await pending;
      expect(viewModel.isDeletingSelected, isFalse);
      viewModel.dispose();
    });

    test('선택이 없으면 삭제 요청을 보내지 않는다', () async {
      final viewModel = await loaded();
      viewModel.enterEditMode();

      expect(await viewModel.deleteSelectedRatings(), 0);

      expect(ratingService.deleteCalls, isEmpty);
      viewModel.dispose();
    });

    test('서버에서 사라진 평점은 재조회할 때 선택 상태에서도 빠진다', () async {
      final viewModel = await loaded();
      viewModel.enterEditMode();
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(2);

      ratingService.ratings.removeWhere((r) => r.ratingId == 1);
      await viewModel.load();

      expect(viewModel.selectedRatingIds, {2});
      viewModel.dispose();
    });
  });
}
