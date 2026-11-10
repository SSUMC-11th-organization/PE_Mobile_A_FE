import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/movielog_fakes.dart';
import 'helpers/tmdb_fakes.dart';

const _request = CreateMemberRequest(
  email: 'me@movielog.com',
  password: 'Password1!',
  nickname: '여비',
);

void main() {
  // 가입 후 이동하는 영화 목록이 장르를 로컬에 저장하므로 메모리 저장소를 씁니다.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SignUpViewModel.submit', () {
    test('성공하면 응답 result의 memberId를 보관한다', () async {
      final service = FakeSignUpService()..signUpMemberId = 31;
      final viewModel = SignUpViewModel(service);

      final pending = viewModel.submit(_request);
      expect(viewModel.isSubmitting, isTrue);
      await pending;

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.createdMemberId, 31);
    });

    test('비밀번호 400은 입력칸 오류로, 409는 Snackbar 문구로 나눈다', () async {
      final service = FakeSignUpService()
        ..signUpError = httpError(
          '/v6/members',
          400,
          message: '비밀번호는 대문자를 포함해야 합니다.',
        );
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(_request);
      expect(viewModel.passwordErrorText, '비밀번호는 대문자를 포함해야 합니다.');
      expect(viewModel.snackbarMessage, isNull);

      // 비밀번호를 고치면 서버 오류는 지웁니다.
      viewModel.onPasswordChanged();
      expect(viewModel.passwordErrorText, isNull);

      service.signUpError = httpError(
        '/v6/members',
        409,
        message: '이미 사용 중인 이메일입니다.',
      );
      await viewModel.submit(_request);
      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(viewModel.createdMemberId, isNull);
    });

    test('요청 중에 다시 제출해도 POST는 한 번만 보낸다', () async {
      final service = FakeSignUpService()..signUpGate = Completer<void>();
      final viewModel = SignUpViewModel(service);

      final first = viewModel.submit(_request);
      await viewModel.submit(_request);
      service.signUpGate!.complete();
      await first;

      expect(service.signUpRequests, hasLength(1));
    });
  });

  group('MovieDetailViewModel.createRating', () {
    test('memberId 경로로 movieId·score·comment를 보낸다', () async {
      final ratings = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(ratings, 5, movieFixture(550));

      await viewModel.createRating(score: 4, comment: '재밌어요');

      expect(ratings.requestedMemberIds.single, 5);
      final request = ratings.createRequests.single;
      expect(request.movieId, 550);
      expect(request.score, 4);
      expect(request.comment, '재밌어요');
    });

    test('memberId가 없으면 요청하지 않고 실패를 알린다', () async {
      final ratings = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(ratings, null, movieFixture(1));

      expect(viewModel.canRate, isFalse);
      await expectLater(
        viewModel.createRating(score: 3),
        throwsA(isA<WriteFailure>()),
      );
      expect(ratings.createRequests, isEmpty);
    });

    test('서버 오류 문구를 WriteFailure로 전달한다', () async {
      final ratings = FakeRatingApiService()
        ..writeError = httpError(
          '/v6/members/5/ratings',
          409,
          message: '이미 평점을 등록한 영화입니다.',
        );
      final viewModel = MovieDetailViewModel(ratings, 5, movieFixture(1));

      await expectLater(
        viewModel.createRating(score: 3),
        throwsA(
          isA<WriteFailure>().having(
            (error) => error.message,
            'message',
            '이미 평점을 등록한 영화입니다.',
          ),
        ),
      );
    });
  });

  group('MyRatingsViewModel 쓰기', () {
    MyRatingsViewModel create(FakeRatingApiService ratings) =>
        MyRatingsViewModel(ratings, FakeTmdbMovieService(), 1);

    test('수정·삭제에 성공하면 목록을 다시 조회한다', () async {
      final ratings = FakeRatingApiService();
      final viewModel = create(ratings);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 2, comment: '다시 보니 별로');
      expect(ratings.updateRequests.single, (1, 2, '다시 보니 별로'));
      expect(viewModel.ratings.first.rating.score, 2);

      await viewModel.deleteRating(2);
      expect(ratings.deleteRequests.single, 2);
      expect(viewModel.ratings, hasLength(1));
      expect(ratings.requestedMemberIds, hasLength(3));
    });

    test('쓰기는 성공했는데 재조회만 실패하면 저장 실패가 아니라 재조회 안내를 둔다', () async {
      final ratings = FakeRatingApiService();
      final viewModel = create(ratings);
      await viewModel.load();

      ratings.errorAfterWrite = networkError('/v6/members/1/ratings');
      // 쓰기 실패가 아니므로 예외 없이 끝나야 합니다.
      await viewModel.deleteRating(1);

      expect(ratings.deleteRequests.single, 1);
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));

      ratings.error = null;
      await viewModel.load();
      expect(viewModel.refreshWarning, isNull);
      expect(viewModel.status, MyRatingsLoadStatus.success);
    });

    test('403·404 쓰기 실패는 목록을 다시 맞추고 WriteFailure를 던진다', () async {
      final ratings = FakeRatingApiService();
      final viewModel = create(ratings);
      await viewModel.load();
      final loadsBefore = ratings.requestedMemberIds.length;

      ratings.writeError = httpError(
        '/v6/members/1/ratings/1',
        404,
        message: '존재하지 않는 평점입니다.',
        code: 'COMMON404',
      );
      await expectLater(
        viewModel.deleteRating(1),
        throwsA(isA<WriteFailure>()),
      );
      expect(ratings.requestedMemberIds.length, loadsBefore + 1);
    });

    test('400 쓰기 실패는 다시 조회하지 않는다', () async {
      final ratings = FakeRatingApiService();
      final viewModel = create(ratings);
      await viewModel.load();
      final loadsBefore = ratings.requestedMemberIds.length;

      ratings.writeError = httpError(
        '/v6/members/1/ratings/1',
        400,
        message: 'score는 1~5 사이여야 합니다.',
        code: 'COMMON400',
      );
      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 3, comment: null),
        throwsA(isA<WriteFailure>()),
      );
      expect(ratings.requestedMemberIds.length, loadsBefore);
    });

    test('다중 삭제는 순서대로 지우고 실패한 항목만 선택에 남긴다', () async {
      final ratings = FakeRatingApiService(
        ratings: [
          ratingFixture(1, movieId: 1),
          ratingFixture(2, movieId: 2),
          ratingFixture(3, movieId: 3),
        ],
      )..failingDeleteIds.add(2);
      final viewModel = create(ratings);
      await viewModel.load();

      viewModel
        ..startEditing()
        ..toggleSelection(1)
        ..toggleSelection(2)
        ..toggleSelection(3);
      final failed = await viewModel.deleteSelectedRatings();

      expect(failed, 1);
      expect(ratings.deleteRequests, [1, 2, 3]);
      expect(viewModel.selectedRatingIds, {2});
      expect(viewModel.isEditing, isTrue);
      expect(viewModel.ratings.map((entry) => entry.rating.ratingId), [2]);
    });
  });

  group('week 7 화면', () {
    Future<FakeRatingApiService> pumpAppAt(
      WidgetTester tester,
      String location, {
      int? memberId = 1,
      FakeRatingApiService? ratings,
      FakeSignUpService? signUp,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final ratingService = ratings ?? FakeRatingApiService();
      AppRouter.router.go(location);
      await tester.pumpWidget(
        MovieLogApp(
          movieService: FakeTmdbMovieService(),
          signUpService: signUp ?? FakeSignUpService(),
          ratingApiService: ratingService,
          session: LearningMemberSession(memberId),
        ),
      );
      await tester.pumpAndSettle();
      return ratingService;
    }

    testWidgets('memberId가 없으면 평점 목록 대신 가입 안내를 보여준다', (tester) async {
      final ratings = await pumpAppAt(tester, '/my/ratings', memberId: null);

      expect(find.text('학습용 회원가입이 필요합니다.'), findsOneWidget);
      expect(ratings.requestedMemberIds, isEmpty);
    });

    testWidgets('주소로 직접 들어오면 TMDB 상세를 조회해서 보여준다', (tester) async {
      await pumpAppAt(tester, '/movies/3');

      expect(find.text('영화 3'), findsWidgets);
      expect(find.text('평점 남기기'), findsOneWidget);
    });

    testWidgets('수정 Dialog는 기존 점수·코멘트를 채우고 PATCH 후 목록을 갱신한다', (tester) async {
      final ratings = await pumpAppAt(tester, '/my/ratings');

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();
      expect(find.text('평점을 수정할까요?'), findsOneWidget);
      expect(find.text('5점'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '최고의 영화!',
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(RatingBar),
              matching: find.byIcon(Icons.star),
            )
            .at(1),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '수정'));
      await tester.pumpAndSettle();

      expect(ratings.updateRequests.single, (1, 2, '최고의 영화!'));
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('단일 삭제는 응답이 올 때까지 확인 Dialog를 유지한다', (tester) async {
      final ratings = FakeRatingApiService()..writeGate = Completer<void>();
      await pumpAppAt(tester, '/my/ratings', ratings: ratings);

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
      await tester.pump();
      // 요청 중에는 Dialog가 그대로 있고 바깥을 눌러도 닫히지 않습니다.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsNothing);
      expect(ratings.deleteRequests.single, 1);
      expect(find.text('평점을 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('편집 모드에서 여러 개를 골라 삭제하고, 실패는 Snackbar로 알린다', (tester) async {
      final ratings = FakeRatingApiService()..failingDeleteIds.add(2);
      await pumpAppAt(tester, '/my/ratings', ratings: ratings);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.text('0개 선택'), findsOneWidget);
      final deleteButton = find.widgetWithText(ElevatedButton, '선택한 0개 삭제');
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(find.text('2개 선택'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '선택한 2개 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('선택한 평점 2개를 삭제할까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      expect(ratings.deleteRequests, [1, 2]);
      expect(find.textContaining('2개 중 1개를 삭제하지 못했습니다.'), findsOneWidget);
      // 실패한 평점은 선택된 채로 편집 모드에 남습니다.
      expect(find.text('1개 선택'), findsOneWidget);
    });

    testWidgets('가입에 성공하면 memberId를 세션에 넣고 영화 목록으로 간다', (tester) async {
      final signUp = FakeSignUpService()..signUpMemberId = 77;
      await pumpAppAt(tester, '/register', memberId: null, signUp: signUp);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '영화광');
      await tester.enterText(fields.at(1), 'movie@movielog.com');
      await tester.enterText(fields.at(2), 'Password1!');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '중복 확인').at(0));
      await tester.tap(find.widgetWithText(ElevatedButton, '중복 확인').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();

      expect(signUp.signUpRequests.single.nickname, '영화광');
      expect(AppRouter.router.state.uri.path, '/movies');

      AppRouter.router.go('/my/ratings');
      await tester.pumpAndSettle();
      expect(find.text('학습용 회원(memberId 77)의 평점 2개'), findsOneWidget);
    });
  });
}
