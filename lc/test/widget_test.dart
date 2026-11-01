import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/widgets/hero_banner.dart';
import 'package:movielog/widgets/movie_rating_input.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('시작하기를 누르면 회원가입 화면으로 이동한다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(MovieLogApp(movieService: FakeTmdbMovieService()));
    AppRouter.router.go('/start');
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
  });

  testWidgets('홈 배너를 누르면 TMDB id로 상세에 이동하고 뒤로 돌아온다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService(
      popular: [
        movieDto(550, title: '파이트 클럽'),
        ...movieDtos(5, startId: 1),
      ],
    );
    await tester.pumpWidget(MovieLogApp(movieService: service));
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HeroBanner));
    await tester.pumpAndSettle();

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

  testWidgets('목록을 거치지 않고 상세 주소로 들어오면 안내 문구가 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(MovieLogApp(movieService: FakeTmdbMovieService()));

    AppRouter.router.go('/movies/550');
    await tester.pumpAndSettle();

    expect(find.text('영화 정보를 찾을 수 없어요.'), findsOneWidget);
  });

  testWidgets('평점 Dialog는 선택한 영화의 TMDB id와 함께 점수를 돌려준다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService(popular: [movieDto(550)]);
    await tester.pumpWidget(MovieLogApp(movieService: service));
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HeroBanner));
    await tester.pumpAndSettle();

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.text('영화는 어떠셨나요?'), findsOneWidget);

    final stars = find.descendant(
      of: find.byType(MovieRatingInput),
      matching: find.byIcon(Icons.star_rounded),
    );
    await tester.tap(stars.at(3));
    await tester.pump();
    final logs = await collectDebugPrint(() async {
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
    });

    expect(find.textContaining('내 평점'), findsOneWidget);
    expect(logs.any((log) => log.contains('movieId=550')), isTrue);
  });

  testWidgets('즐겨찾기를 누르면 아이콘이 바뀌고 Snackbar가 보인다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService(popular: [movieDto(550)]);
    await tester.pumpWidget(MovieLogApp(movieService: service));
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HeroBanner));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
