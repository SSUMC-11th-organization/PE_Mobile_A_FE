import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/widgets/movie_card.dart';

import '../fakes/fake_tmdb_movie_service.dart';

Future<void> pumpMovieList(
  WidgetTester tester,
  FakeTmdbMovieService service,
) async {
  await tester.pumpWidget(MovieLogApp(movieService: service));
  AppRouter.router.go('/movies');
  await tester.pumpAndSettle();
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

  testWidgets('성공 목록이 있는 상태에서 실패하면 목록을 유지하고 재시도 Dialog를 띄운다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpMovieList(tester, service);

    service.failDiscover = true;
    await tester.tap(find.text('SF'));
    await tester.pumpAndSettle();

    expect(find.text('영화를 불러오지 못했어요'), findsOneWidget);
    expect(find.byType(MovieCard), findsWidgets);

    service
      ..failDiscover = false
      ..discoverCalls.clear();
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('영화를 불러오지 못했어요'), findsNothing);
    expect(service.discoverCalls.first, isDiscoverCall(1, [878]));
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
