import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';

import '../fakes/fake_rating_api_service.dart';
import '../fakes/fake_sign_up_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';

void main() {
  testWidgets('/movies 자식 상세는 하단 탭과 함께 열리고 뒤로가면 이전 화면으로 돌아온다', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        movieService: FakeTmdbMovieService(),
        signUpService: FakeSignUpService(),
        ratingApiService: FakeRatingApiService(),
      ),
    );
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    AppRouter.router.push(
      AppRouter.movieDetailLocation(550),
      extra: movieFixture(550, posterPath: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('평점을 남기려면 학습용 회원가입이 필요합니다.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('평점을 남기려면 학습용 회원가입이 필요합니다.'), findsNothing);
    expect(
      AppRouter.router.routerDelegate.currentConfiguration.uri.path,
      '/home',
    );
  });
}
