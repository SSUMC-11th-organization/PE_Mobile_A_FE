import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings_screen.dart';

import '../test_helpers.dart';
import '../week6_helpers.dart';

void main() {
  late FakeRatingApiService ratings;
  late FakeDetailTmdbService movies;

  /// [settle]이 false면 한 프레임만 그린다. (인디케이터는 계속 움직여 pumpAndSettle이 끝나지 않는다.)
  Future<void> pumpApp(
    WidgetTester tester, {
    String at = '/my',
    bool settle = true,
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MovieLogApp(movieService: movies, ratingApiService: ratings),
    );
    AppRouter.router.go(at);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  setUp(() {
    ratings = FakeRatingApiService();
    movies = FakeDetailTmdbService();
  });

  testWidgets('마이페이지의 진입 행을 누르면 하단 탭 없는 자식 화면이 열리고, 뒤로가기로 돌아온다', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내가 등록한 평점'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(ratings.calls, 1);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsNothing);
    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Loading: 응답을 기다리는 동안 인디케이터가 보인다', (tester) async {
    ratings.gate = Completer<void>();
    await pumpApp(tester, at: '/my/ratings', settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('평점을 불러오는 중이에요'), findsOneWidget);

    ratings.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Empty: 빈 배열은 안내 문구이고 Error가 아니다', (tester) async {
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('아직 등록한 평점이 없어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('Error: 상태 코드별 문구와 다시 시도 버튼이 보이고, 누르면 복구된다', (tester) async {
    ratings.failWithStatus = 404;
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    ratings
      ..failWithStatus = null
      ..ratings = [ratingDto(1, 550, comment: '최고')];
    movies = FakeDetailTmdbService(known: {550: movieDto(550, title: '파이트 클럽')});
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('파이트 클럽'), findsNothing); // 같은 Service를 쓰므로 새 영화 정보는 반영되지 않는다.
    expect(find.text('최고'), findsOneWidget);
  });

  testWidgets('Success: 영화 제목·점수·후기·등록일이 보이고 후기가 없으면 그리지 않는다', (tester) async {
    ratings.ratings = [
      ratingDto(1, 550, score: 5, comment: '최고의 영화!'),
      ratingDto(2, 27205, score: 3),
    ];
    movies = FakeDetailTmdbService(
      known: {
        550: movieDto(550, title: '파이트 클럽'),
        27205: movieDto(27205, title: '인셉션'),
      },
    );
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(find.text('인셉션'), findsOneWidget);
    expect(find.text('5점'), findsOneWidget);
    expect(find.text('3점'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'\d{4}\.\d{2}\.\d{2} 등록')),
      findsNWidgets(2),
    );
    expect(find.textContaining('memberId 1'), findsOneWidget);
  });

  testWidgets('영화 정보를 못 찾으면 placeholder 제목으로 평점은 유지하고 안내한다', (tester) async {
    ratings.ratings = [ratingDto(1, 999999, score: 4, comment: '기록은 남는다')];
    await pumpApp(tester, at: '/my/ratings');

    expect(find.text('영화 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('TMDB 영화 #999999'), findsOneWidget);
    expect(find.text('4점'), findsOneWidget);
    expect(find.text('기록은 남는다'), findsOneWidget);
    expect(find.textContaining('일부 영화 정보를 가져오지 못해'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
