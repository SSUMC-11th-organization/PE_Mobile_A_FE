import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/widgets/hero_banner.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'test_helpers.dart';
import 'week6_helpers.dart';

void main() {
  late FakeRatingApiService ratings;

  setUp(() => ratings = FakeRatingApiService());

  /// AppRouter.router는 static이라 이전 테스트의 마지막 위치를 기억한다.
  /// 새 앱을 올리기 전에 시작 화면으로 되돌려, 이전 화면이 새 Service로 다시 그려지지 않게 한다.
  void resetRouter() => AppRouter.router.go('/start');

  /// 홈에서 배너를 눌러 상세 화면까지 들어간다. 회원가입을 마친 학습용 회원(memberId)이 있으면 넘긴다.
  Future<void> openDetail(
    WidgetTester tester, {
    int? memberId = 7,
    FakeTmdbMovieService? service,
  }) async {
    useTallScreen(tester);
    resetRouter();
    await tester.pumpWidget(
      MovieLogApp(
        movieService:
            service ??
            FakeTmdbMovieService(
              popular: [movieDto(550, title: '파이트 클럽'), ...movieDtos(5)],
            ),
        ratingApiService: ratings,
        memberSession: LearningMemberSession(memberId),
      ),
    );
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HeroBanner));
    await tester.pumpAndSettle();
  }

  Finder stars() => find.descendant(
    of: find.byType(MovieRatingInput),
    matching: find.byIcon(Icons.star_rounded),
  );

  /// Dialog 안의 MovieLogButton(확인). 저장 중에는 라벨이 사라지므로 라벨이 아니라 타입으로 찾는다.
  Finder confirmButton() => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.byType(ElevatedButton),
  );

  testWidgets('시작하기를 누르면 회원가입 화면으로 이동한다', (tester) async {
    useTallScreen(tester);
    resetRouter();
    await tester.pumpWidget(MovieLogApp(movieService: FakeTmdbMovieService()));
    AppRouter.router.go('/start');
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
  });

  testWidgets('홈 배너를 누르면 TMDB id로 상세에 이동하고 뒤로 돌아온다', (tester) async {
    await openDetail(tester);

    // 배열 index가 아니라 TMDB 영화 id가 경로에 담긴다.
    // (push는 주소창 경로를 바꾸지 않으므로 상세 Route 자신의 상태로 확인한다.)
    final detailState = GoRouterState.of(
      tester.element(find.byType(MovieDetailScreen)),
    );
    expect(detailState.uri.path, '/movies/550');
    expect(find.text('Cinema Archive'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MovieDetailScreen),
        matching: find.text('파이트 클럽'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailScreen), findsNothing);
    expect(find.byType(HeroBanner), findsOneWidget);
  });

  group('상세 주소로 바로 들어온 경우 (extra 없음)', () {
    Future<void> openDeepLink(
      WidgetTester tester,
      String path,
      FakeTmdbMovieService service,
    ) async {
      useTallScreen(tester);
      resetRouter();
      await tester.pumpWidget(
        MovieLogApp(movieService: service, ratingApiService: ratings),
      );
      AppRouter.router.go(path);
      await tester.pumpAndSettle();
    }

    testWidgets('TMDB 상세 API로 영화 정보를 다시 조회해서 보여준다', (tester) async {
      final service = FakeTmdbMovieService()
        ..details[550] = movieDto(550, title: '파이트 클럽');

      await openDeepLink(tester, '/movies/550', service);

      expect(service.fetchDetailCalls, 1);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.text('파이트 클럽'), findsWidgets);
    });

    testWidgets('조회에 실패하면 안내와 다시 시도가 보이고, 누르면 복구된다', (tester) async {
      final service = FakeTmdbMovieService()
        ..details[550] = movieDto(550, title: '파이트 클럽')
        ..failDetail = true;

      await openDeepLink(tester, '/movies/550', service);
      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);

      service.failDetail = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(service.fetchDetailCalls, 2);
    });

    testWidgets('없는 영화(404)도 같은 안내를 보여준다', (tester) async {
      await openDeepLink(tester, '/movies/999999', FakeTmdbMovieService());

      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
    });

    testWidgets('숫자가 아닌 영화 ID는 조회하지 않고 안내한다', (tester) async {
      final service = FakeTmdbMovieService();

      await openDeepLink(tester, '/movies/abc', service);

      expect(find.text('영화 ID가 올바르지 않습니다.'), findsOneWidget);
      expect(service.fetchDetailCalls, 0);
    });

    testWidgets('0 이하의 영화 ID도 조회하지 않는다', (tester) async {
      final service = FakeTmdbMovieService();

      await openDeepLink(tester, '/movies/0', service);

      expect(find.text('영화 ID가 올바르지 않습니다.'), findsOneWidget);
      expect(service.fetchDetailCalls, 0);
    });
  });

  group('평점 등록', () {
    testWidgets('별점을 고르기 전에는 코멘트를 입력해도 확인이 비활성이다', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      expect(find.text('영화는 어떠셨나요?'), findsOneWidget);

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '코멘트만 입력');
      await tester.pump();

      expect(tester.widget<ElevatedButton>(confirmButton()).onPressed, isNull);

      await tester.tap(stars().at(2));
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(confirmButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('저장하면 TMDB id·점수·코멘트로 등록하고, 성공 Snackbar와 내 평점이 보인다', (tester) async {
      await openDetail(tester, memberId: 7);
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();

      await tester.tap(stars().at(3)); // 4점
      await tester.pump();
      await tester.enterText(find.byType(TextField), '  다시 봐도 좋다  ');
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      final call = ratings.createCalls.single;
      expect(call.memberId, 7); // 가입 응답의 memberId path
      expect(call.request.movieId, 550); // 배열 index가 아니라 TMDB id
      expect(call.request.score, 4);
      expect(call.request.comment, '다시 봐도 좋다');
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('평점을 등록했습니다'), findsOneWidget);
      expect(find.textContaining('내 평점 4점'), findsOneWidget);
    });

    testWidgets('코멘트를 비우면 comment 키 없이 점수만 등록한다', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();

      await tester.tap(stars().at(4));
      await tester.pump();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(ratings.createCalls.single.request.toJson(), {
        'movieId': 550,
        'score': 5,
      });
    });

    testWidgets('취소하면 요청을 보내지 않는다', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(stars().at(2));
      await tester.pump();

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(ratings.createCalls, isEmpty);
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);
    });

    testWidgets('저장 중에는 확인 버튼이 로딩 상태이고 Dialog를 닫을 수 없다', (tester) async {
      await openDetail(tester);
      ratings.writeGate = Completer<void>();
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(stars().at(3));
      await tester.pump();

      await tester.tap(confirmButton());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RatingDialog),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<ElevatedButton>(confirmButton()).onPressed, isNull);
      // 취소·바깥 탭·뒤로가기 모두 막힌다.
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '취소'),
      );
      expect(cancel.onPressed, isNull);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);

      // 연속 탭해도 요청은 한 번이다.
      await tester.tap(confirmButton(), warnIfMissed: false);
      expect(ratings.createCalls, hasLength(1));

      ratings.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
    });

    testWidgets('409로 실패하면 서버 문구를 Dialog에 보여주고 입력은 그대로 남아 다시 시도할 수 있다', (tester) async {
      await openDetail(tester);
      ratings.writeError = commonError(
        409,
        'COMMON409',
        '이미 이 영화에 평점을 남기셨습니다.',
      );
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(stars().at(3));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '남기던 코멘트');

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      // 입력과 별점이 유지되고, 버튼은 로딩에서 풀려 다시 누를 수 있다.
      expect(find.text('남기던 코멘트'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(confirmButton()).onPressed,
        isNotNull,
      );
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);

      ratings.writeError = null;
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(ratings.createCalls, hasLength(2));
      expect(ratings.createCalls.last.request.score, 4); // 처음 고른 별점 그대로
      expect(find.textContaining('평점을 등록했습니다'), findsOneWidget);
    });

    testWidgets('별 입력은 정수 단위다 (반 점은 만들 수 없다)', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();

      final input = tester.widget<MovieRatingInput>(
        find.byType(MovieRatingInput),
      );
      expect(input.rating, 0);

      await tester.tap(stars().at(0));
      await tester.pump();
      expect(
        tester.widget<MovieRatingInput>(find.byType(MovieRatingInput)).rating,
        1.0,
      );
    });

    testWidgets('회원가입 전(memberId 없음)에는 평점 남기기가 비활성이고 안내가 보인다', (tester) async {
      await openDetail(tester, memberId: null);

      expect(find.textContaining('먼저 학습용 회원가입이 필요'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '평점 남기기'),
      );
      expect(button.onPressed, isNull);
      expect(ratings.createCalls, isEmpty);
    });

    testWidgets('코멘트는 500자까지만 입력된다', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ㄱ' * 600);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 500);
    });
  });

  testWidgets('즐겨찾기를 누르면 아이콘이 바뀌고 Snackbar가 보인다', (tester) async {
    await openDetail(tester);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('MovieLogButton이 Dialog 버튼에도 재사용된다', (tester) async {
    await openDetail(tester);
    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(RatingDialog),
        matching: find.byType(MovieLogButton),
      ),
      findsOneWidget,
    );
  });
}
