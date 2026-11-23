import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/widgets/movie_card.dart';

import '../fakes/fake_tmdb_movie_service.dart';
import '../fakes/pump_app.dart';

Future<void> pumpMovieList(
  WidgetTester tester,
  FakeTmdbMovieService service,
) async {
  await pumpApp(tester, movieService: service, location: '/movies');
}

ChoiceChip chip(WidgetTester tester, String label) {
  return tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('Genre API로 Chip을 만들고 장르를 누르면 with_genres로 다시 요청한다', (
    tester,
  ) async {
    final service = FakeTmdbMovieService();
    await pumpMovieList(tester, service);

    expect(find.text('전체'), findsOneWidget);
    expect(find.text('드라마'), findsOneWidget);
    expect(find.byType(MovieCard), findsWidgets);

    service.discoverCalls.clear();
    await tester.tap(find.text('드라마'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.first, isDiscoverCall(1, [18]));
    expect(chip(tester, '드라마').selected, isTrue);
  });

  testWidgets('Discover 요청 중에는 장르 Chip이 비활성화된다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpMovieList(tester, service);

    service.discoverGate = Completer<void>();
    await tester.tap(find.text('액션'));
    await tester.pump();

    expect(chip(tester, '드라마').onSelected, isNull);

    service.discoverGate!.complete();
    await tester.pumpAndSettle();
    expect(chip(tester, '드라마').onSelected, isNotNull);
  });

  testWidgets('장르 변경 후 첫 page가 실패하면 오류를 보여 주고 같은 조건으로 다시 시도한다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpMovieList(tester, service);

    service.failDiscover = true;
    await tester.tap(find.text('SF'));
    await tester.pumpAndSettle();

    expect(find.text('영화 목록을 불러오지 못했습니다.'), findsOneWidget);
    expect(find.byType(MovieCard), findsNothing);

    service
      ..failDiscover = false
      ..discoverCalls.clear();
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.byType(MovieCard), findsWidgets);
    expect(service.discoverCalls.single, isDiscoverCall(1, [878]));
  });

  testWidgets('더 보기는 다음 page를 붙이고, 실패하면 같은 page를 다시 요청한다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpMovieList(tester, service);
    final grid = find.byType(Scrollable).last;

    service.discoverCalls.clear();
    service.failDiscover = true;
    await tester.scrollUntilVisible(find.text('더 보기'), 600, scrollable: grid);
    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();

    expect(find.text('추가 영화 조회에 실패했습니다.'), findsOneWidget);
    expect(find.text('다음 페이지 다시 시도'), findsOneWidget);

    service.failDiscover = false;
    await tester.tap(find.text('다음 페이지 다시 시도'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.map((call) => call.page), [2, 2]);
    expect(find.text('추가 영화 조회에 실패했습니다.'), findsNothing);
  });

  testWidgets('마지막 page를 불러오면 더 보기 대신 끝 안내를 보여 준다', (tester) async {
    final service = FakeTmdbMovieService()
      ..discover = (page, genreIds) =>
          pageFixture(page, [page * 10 + 1, page * 10 + 2], totalPages: 2);
    await pumpMovieList(tester, service);
    final grid = find.byType(Scrollable).last;

    await tester.scrollUntilVisible(find.text('더 보기'), 600, scrollable: grid);
    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('모든 영화를 확인했습니다.'),
      600,
      scrollable: grid,
    );

    expect(find.text('더 보기'), findsNothing);
    expect(find.text('영화 22'), findsOneWidget);
  });

  testWidgets('검색 아이콘을 누르면 하단 탭 없이 검색 화면이 열린다', (tester) async {
    await pumpMovieList(tester, FakeTmdbMovieService());

    await tester.tap(find.byTooltip('영화 검색'));
    await tester.pumpAndSettle();

    expect(find.text('영화 검색'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('BottomSheet에서 여러 장르를 고르면 함께 요청한다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpMovieList(tester, service);

    await tester.tap(find.byTooltip('장르 필터'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '액션'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'SF'));
    service.discoverCalls.clear();
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.first, isDiscoverCall(1, [28, 878]));
    expect(chip(tester, '액션').selected, isTrue);
    expect(chip(tester, 'SF').selected, isTrue);
  });
}
