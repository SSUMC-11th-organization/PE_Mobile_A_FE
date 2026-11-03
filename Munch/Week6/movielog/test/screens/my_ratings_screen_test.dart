import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';

import '../fakes/fake_member_check_service.dart';
import '../fakes/fake_rating_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';

Future<void> pumpProfile(
  WidgetTester tester,
  FakeRatingApiService ratingService, {
  FakeTmdbMovieService? movieService,
}) async {
  await tester.pumpWidget(
    MovieLogApp(
      movieService: movieService ?? FakeTmdbMovieService(),
      memberCheckService: FakeMemberCheckService(),
      ratingApiService: ratingService,
    ),
  );
  AppRouter.router.go('/my');
  await tester.pumpAndSettle();
}

Future<void> openMyRatings(WidgetTester tester) async {
  await tester.ensureVisible(find.text('내가 등록한 평점'));
  await tester.tap(find.text('내가 등록한 평점'));
  await tester.pump();
}

void main() {
  testWidgets('마이페이지에서 진입하면 하단 탭 없이 열리고, 뒤로가면 돌아온다', (tester) async {
    final movieService = FakeTmdbMovieService()
      ..movieDetails = {550: movieFixture(550)};
    await pumpProfile(
      tester,
      FakeRatingApiService(
        ratings: [ratingFixture(1, 550, comment: '최고의 영화!')],
      ),
      movieService: movieService,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await openMyRatings(tester);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('영화 550'), findsOneWidget);
    expect(find.text('별점 4 / 5'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('내 프로필'), findsOneWidget);
  });

  testWidgets('Loading 상태', (tester) async {
    final service = FakeRatingApiService()..pending = Completer<void>();
    await pumpProfile(tester, service);
    await openMyRatings(tester);

    expect(find.text('평점을 불러오는 중입니다.'), findsOneWidget);

    service.pending!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Empty 상태', (tester) async {
    await pumpProfile(tester, FakeRatingApiService());
    await openMyRatings(tester);
    await tester.pumpAndSettle();

    expect(find.text('등록된 평점이 없습니다.'), findsOneWidget);
  });

  testWidgets('Error 상태에서 다시 시도하면 Success로 바뀐다', (tester) async {
    final service = FakeRatingApiService()..failStatus = 500;
    await pumpProfile(tester, service);
    await openMyRatings(tester);
    await tester.pumpAndSettle();

    expect(find.text('평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);

    service
      ..failStatus = null
      ..ratings = [ratingFixture(1, 13)];
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('영화 #13'), findsOneWidget);
    expect(find.text('영화 정보 없음'), findsOneWidget);
  });
}
