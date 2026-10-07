import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/main.dart';
import 'package:movielog/models/movie.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/widgets/hero_banner.dart';

import 'test_helpers.dart';

void main() {
  setUp(useInMemoryPreferences);

  testWidgets('시작하기를 누르면 회원가입 화면으로 이동한다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const MovieLogApp());
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
  });

  testWidgets('홈 영화 카드를 누르면 상세로 이동하고 뒤로 돌아온다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const MovieLogApp());
    AppRouter.router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HeroBanner));
    await tester.pumpAndSettle();

    expect(find.text('Cinema Archive'), findsOneWidget);
    expect(find.text(movies.first.title), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(HeroBanner), findsOneWidget);
  });

  testWidgets('상세에서 평점 Dialog와 즐겨찾기 Snackbar가 동작한다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const MovieLogApp());
    AppRouter.router.go('/movies/1');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.text('영화는 어떠셨나요?'), findsOneWidget);
  });
}
