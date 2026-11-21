import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/router/app_router.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_tmdb_movie_service.dart';
import '../fakes/pump_app.dart';

void main() {
  testWidgets('/movies 자식 상세는 하단 탭과 함께 열리고 뒤로가면 이전 화면으로 돌아온다', (tester) async {
    await pumpApp(tester, location: '/home');

    routerOf(tester).push(
      AppRouter.movieDetailLocation(550),
      extra: movieFixture(550, posterPath: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('평점 남기기'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('평점 남기기'), findsNothing);
    expect(currentPath(tester), '/home');
  });
}
