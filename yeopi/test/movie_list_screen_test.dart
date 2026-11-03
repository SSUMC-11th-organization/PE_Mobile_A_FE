import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/services/movie_list_preferences.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/tmdb_fakes.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeTmdbMovieService service,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) =>
              MovieListViewModel(service, MovieListPreferences())
                ..loadInitial(),
          child: const MovieListScreen(),
        ),
      ),
    );
  }

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

  testWidgets('Loading을 보여준 뒤 Genre API 장르와 최대 30개 목록을 보여준다', (tester) async {
    final service = FakeTmdbMovieService()..gate = Completer<void>();
    await pumpScreen(tester, service);

    expect(find.byType(MovieListLoading), findsOneWidget);

    service.gate!.complete();
    service.gate = null;
    await tester.pumpAndSettle();

    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.text('30편 · 인기순'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '전체'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '애니메이션'), findsOneWidget);
  });

  testWidgets('장르를 고르면 다시 요청하고, 요청 중에는 다른 장르를 고를 수 없다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpScreen(tester, service);
    await tester.pumpAndSettle();

    service.gate = Completer<void>();
    await tester.tap(find.widgetWithText(ChoiceChip, '드라마'));
    await tester.pump();

    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(chip(tester, '액션').onSelected, isNull);

    service.gate!.complete();
    service.gate = null;
    await tester.pumpAndSettle();

    expect(service.discoverRequests.last.genreId, 18);
    expect(find.text('22편 · 인기순'), findsOneWidget);
    expect(chip(tester, '드라마').selected, isTrue);
    expect(chip(tester, '액션').onSelected, isNotNull);
  });

  testWidgets('실패하면 안내와 다시 시도를 보여주고, 재시도는 성공한다', (tester) async {
    final service = FakeTmdbMovieService()
      ..error = DioException(
        requestOptions: RequestOptions(path: '/genre/movie/list'),
        type: DioExceptionType.connectionError,
      );
    await pumpScreen(tester, service);
    await tester.pumpAndSettle();

    expect(find.textContaining('네트워크에 연결할 수 없어요'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);

    service.error = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('30편 · 인기순'), findsOneWidget);
  });

  testWidgets('결과가 없으면 Empty 안내를 보여준다', (tester) async {
    await pumpScreen(tester, FakeTmdbMovieService(movies: []));
    await tester.pumpAndSettle();

    expect(find.textContaining('아직 등록된 영화가 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('정렬 BottomSheet에서 제목순을 고르면 정렬이 바뀐다', (tester) async {
    await pumpScreen(tester, FakeTmdbMovieService());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('정렬'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('제목순'));
    await tester.pumpAndSettle();

    expect(find.text('30편 · 제목순'), findsOneWidget);
  });

  testWidgets('당겨서 새로고침하는 동안 기존 목록을 유지한다', (tester) async {
    final service = FakeTmdbMovieService();
    await pumpScreen(tester, service);
    await tester.pumpAndSettle();

    service.gate = Completer<void>();
    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.text('30편 · 인기순'), findsOneWidget);
    expect(chip(tester, '드라마').onSelected, isNull);

    service.gate!.complete();
    service.gate = null;
    await tester.pumpAndSettle();
    expect(find.text('30편 · 인기순'), findsOneWidget);
  });
}
