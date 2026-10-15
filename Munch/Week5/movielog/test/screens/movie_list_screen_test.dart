import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/models/movie_sort.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/genre_preference.dart';
import 'package:movielog/services/sort_preference.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> pumpScreen(
  WidgetTester tester, {
  MovieLoadMode mode = MovieLoadMode.success,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MovieListScreen(movieService: FakeMovieService(mode: mode)),
    ),
  );
}

Future<void> finishLoading(WidgetTester tester) async {
  await tester.pump(FakeMovieService.loadDelay);
  await tester.pumpAndSettle();
}

List<String> visibleTitles(WidgetTester tester) => tester
    .widgetList<MovieCard>(find.byType(MovieCard))
    .map((card) => card.movie.title)
    .toList();

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
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

  testWidgets('Loading이 800ms 이상 보인 뒤 Success로 바뀐다', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(MovieListLoading), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(MovieListLoading), findsOneWidget);

    await finishLoading(tester);
    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieCard), findsWidgets);
  });

  testWidgets('empty 모드에서는 Empty 화면을 보여준다', (tester) async {
    await pumpScreen(tester, mode: MovieLoadMode.empty);
    await finishLoading(tester);

    expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('failure 모드에서는 Exception 없이 Error 화면을 보여주고 재시도한다', (
    tester,
  ) async {
    await pumpScreen(tester, mode: MovieLoadMode.failure);
    await finishLoading(tester);

    expect(find.text(MovieListError.defaultMessage), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.byType(MovieListLoading), findsOneWidget);

    await finishLoading(tester);
    expect(find.text(MovieListError.defaultMessage), findsOneWidget);
  });

  testWidgets('응답이 loadTimeout보다 늦으면 Timeout 안내를 보여준다', (tester) async {
    await pumpScreen(tester, mode: MovieLoadMode.slow);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MovieListLoading), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(MovieListError.timeoutMessage), findsOneWidget);

    await tester.pump(FakeMovieService.slowDelay);
  });

  testWidgets('장르 Chip을 누르면 목록이 바뀌고 다시 열면 복원된다', (tester) async {
    await pumpScreen(tester);
    await finishLoading(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '로맨스'));
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['별빛 아래 우리']);
    expect(await GenrePreference().read(), '로맨스');

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester);
    await finishLoading(tester);

    expect(visibleTitles(tester), ['별빛 아래 우리']);
  });

  testWidgets('정렬을 바꾸면 순서가 바뀌고 다시 열면 복원된다', (tester) async {
    await pumpScreen(tester);
    await finishLoading(tester);

    await tester.tap(find.byTooltip('정렬'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MovieSort.rating.label));
    await tester.pumpAndSettle();

    expect(visibleTitles(tester).first, '기억의 숲');
    expect(await SortPreference().read(), MovieSort.rating);

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester);
    await finishLoading(tester);

    expect(visibleTitles(tester).first, '기억의 숲');
  });

  testWidgets('당겨서 새로고침하면 목록을 유지한 채 다시 불러온다', (tester) async {
    await pumpScreen(tester);
    await finishLoading(tester);

    await tester.fling(
      find.byType(MovieCard).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieCard), findsWidgets);

    await finishLoading(tester);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byType(MovieCard), findsWidgets);
  });
}
