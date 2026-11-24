import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/screens/favorites_screen.dart';
import 'package:movielog/screens/movie_search_screen.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'week6_helpers.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness());

  Finder bookmark(IconData icon) => find.byIcon(icon);

  testWidgets('상세에서 즐겨찾기를 누르면 서버 응답 뒤 북마크가 채워지고, 다시 누르면 해제된다', (tester) async {
    await app.pump(tester);
    await app.go(tester, '/movies/550');

    // 서버에서 여부를 확인(GET)한 뒤에만 버튼이 켜진다.
    expect(app.favorites.calls, contains('GET 550'));
    expect(bookmark(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(app.favorites.calls, contains('POST 550'));
    expect(bookmark(Icons.bookmark), findsOneWidget);

    // Snackbar가 버튼을 가리지 않도록 사라질 때까지 기다린다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(app.favorites.calls, contains('DELETE 550'));
    expect(bookmark(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('등록 요청 중에는 버튼이 눌리지 않아 POST가 한 번만 나간다', (tester) async {
    await app.pump(tester);
    await app.go(tester, '/movies/550');
    app.favorites.gate = Completer<void>();
    await tester.tap(find.text('즐겨찾기'));
    await tester.pump();
    await tester.tap(find.text('즐겨찾기'), warnIfMissed: false);
    await tester.pump();
    app.favorites.gate!.complete();
    await tester.pumpAndSettle();
    expect(app.favorites.calls.where((c) => c == 'POST 550'), hasLength(1));
  });

  testWidgets('등록 실패면 북마크를 바꾸지 않고 안내한다', (tester) async {
    await app.pump(tester);
    await app.go(tester, '/movies/550');
    app.favorites.addError = dioFailure('/v8/favorites', statusCode: 500);
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(bookmark(Icons.bookmark_border), findsOneWidget);
    expect(find.text('즐겨찾기 등록에 실패했습니다.'), findsOneWidget);
  });

  testWidgets('내 즐겨찾기 목록에서 상세로 가 해제하고 돌아오면 목록에서 사라진다', (tester) async {
    app.favorites.mine.add(550);
    await app.pump(tester);
    await app.go(tester, '/my/favorites');
    expect(find.byType(FavoritesScreen), findsOneWidget);
    expect(find.text('파이트 클럽'), findsOneWidget);

    await tester.tap(find.text('파이트 클럽'));
    await tester.pumpAndSettle();
    expect(bookmark(Icons.bookmark), findsOneWidget);
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    app.router(tester).pop();
    await tester.pumpAndSettle();

    expect(find.text('파이트 클럽'), findsNothing);
  });

  testWidgets('로그아웃 뒤 다른 계정으로 로그인하면 이전 계정의 즐겨찾기가 보이지 않는다', (tester) async {
    app.favorites.mine.add(550);
    await app.pump(tester);
    await app.go(tester, '/my/favorites');
    expect(find.text('파이트 클럽'), findsOneWidget);

    await app.go(tester, '/my');
    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();

    app.favorites.account = 'other@example.com';
    app.members.member = memberInfo(email: 'other@example.com');
    await app.login(tester);
    await app.go(tester, '/my/favorites');

    expect(find.text('파이트 클럽'), findsNothing);
  });

  testWidgets('검색 화면은 정적 경로로 열리고 입력 전에는 안내를 보여준다', (tester) async {
    await app.pump(tester);
    await app.go(tester, '/movies/search');
    expect(find.byType(MovieSearchScreen), findsOneWidget);
    expect(find.text('검색어를 입력하세요.'), findsOneWidget);
  });

  group('평점 + 즐겨찾기 한 번에 저장 (Challenge C)', () {
    Finder checkbox() => find.byType(CheckboxListTile);
    Finder confirm() => find.descendant(
      of: find.byType(RatingDialog),
      matching: find.byType(ElevatedButton),
    );

    Future<void> openAndRate(WidgetTester tester) async {
      await app.pump(tester);
      await app.go(tester, '/movies/550');
      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(MovieRatingInput),
              matching: find.byIcon(Icons.star_rounded),
            )
            .at(2),
      );
      await tester.pump();
    }

    testWidgets('체크하고 저장하면 movie-records로 한 번에 보내고 북마크가 채워진다', (tester) async {
      await openAndRate(tester);
      await tester.tap(checkbox());
      await tester.pump();
      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(app.records.calls, hasLength(1));
      expect(app.records.calls.single.addToFavorites, true);
      expect(app.records.calls.single.score, 3);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('체크하지 않으면 addToFavorites=false로 보내고 북마크는 그대로다', (tester) async {
      await openAndRate(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(app.records.calls.single.addToFavorites, false);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('이미 즐겨찾기한 영화는 체크박스가 없고 평점 API만 쓴다', (tester) async {
      app.favorites.mine.add(550);
      await openAndRate(tester);
      expect(checkbox(), findsNothing);
      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(app.records.calls, isEmpty);
      expect(app.ratings.createCalls, isNotEmpty);
    });

    testWidgets('COMMON400이면 Dialog를 유지하고 안내한다', (tester) async {
      app.records.error = dioFailure(
        '/v8/movie-records',
        statusCode: 400,
        body: {'code': 'COMMON400', 'message': '입력값이 올바르지 않습니다.'},
      );
      await openAndRate(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('입력값이 올바르지 않습니다.'), findsOneWidget);
    });

    testWidgets('FAVORITE409_1이면 Dialog를 닫고 Snackbar로 안내한다', (tester) async {
      app.records.error = dioFailure(
        '/v8/movie-records',
        statusCode: 409,
        body: {'code': 'FAVORITE409_1', 'message': '이미 즐겨찾기한 영화입니다.'},
      );
      await openAndRate(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('이미 즐겨찾기한 영화'), findsOneWidget);
    });
  });
}
