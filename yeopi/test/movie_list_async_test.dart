import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/models/movie.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/movie_list_preferences.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('FakeMovieService', () {
    const service = FakeMovieService(delay: Duration.zero);

    test('success 모드는 Mock 영화 목록을 반환한다', () async {
      expect(await service.fetchMovies(), movies);
    });

    test('empty 모드는 빈 목록을 반환한다', () async {
      expect(await service.fetchMovies(mode: MovieLoadMode.empty), isEmpty);
    });

    test('failure 모드는 MovieLoadException으로 완료된다', () {
      expect(
        service.fetchMovies(mode: MovieLoadMode.failure),
        throwsA(isA<MovieLoadException>()),
      );
    });
  });

  group('MovieListPreferences', () {
    test('저장한 장르와 정렬을 다시 읽는다', () async {
      final preferences = MovieListPreferences();
      await preferences.saveGenre('드라마');
      await preferences.saveSort('title');

      expect(await preferences.readGenre(), '드라마');
      expect(await preferences.readSort(), 'title');
    });

    test('저장된 값이 없거나 없는 장르면 전체로 돌아간다', () async {
      expect(await MovieListPreferences().readGenre(), '전체');

      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            MovieListPreferences.selectedGenreKey: '삭제된 장르',
          });
      expect(await MovieListPreferences().readGenre(), '전체');
    });
  });

  group('MovieListScreen 비동기 상태', () {
    Future<void> pumpScreen(WidgetTester tester, {Key? key}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: MovieListScreen(key: key)));
    }

    Future<void> chooseNextMode(WidgetTester tester, MovieLoadMode mode) async {
      await tester.tap(find.byTooltip('불러오기 모드 테스트'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음 요청: ${mode.label}'));
      // PopupMenu는 닫힘 애니메이션이 끝난 뒤 onSelected를 호출합니다.
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('처음에는 Loading을 보여주고 1초 뒤 Success 목록을 보여준다', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(MovieListLoading), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(MovieListLoading), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byType(MovieListLoading), findsNothing);
      expect(find.text('6편 · 최신순'), findsOneWidget);
    });

    testWidgets('실패하면 Exception 대신 안내와 다시 시도를 보여주고, 재시도는 성공한다', (tester) async {
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 1));

      await chooseNextMode(tester, MovieLoadMode.failure);
      expect(find.byType(MovieListLoading), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.textContaining('MovieLoadException'), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(find.byType(MovieListLoading), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('6편 · 최신순'), findsOneWidget);
    });

    testWidgets('빈 목록이면 Empty 안내를 보여준다', (tester) async {
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 1));

      await chooseNextMode(tester, MovieLoadMode.empty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.textContaining('아직 등록된 영화가 없어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('응답이 3초를 넘으면 Timeout 안내를 보여준다', (tester) async {
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 1));

      await chooseNextMode(tester, MovieLoadMode.slow);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.textContaining('응답이 늦어지고 있어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);

      // 지연된 Mock 요청 타이머가 끝날 때까지 기다립니다.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('선택한 장르는 저장되고 화면을 다시 열면 복원된다', (tester) async {
      await pumpScreen(tester, key: const ValueKey('first'));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(ChoiceChip, '드라마'));
      await tester.pump();
      expect(find.text('2편 · 최신순'), findsOneWidget);
      expect(await MovieListPreferences().readGenre(), '드라마');

      // 앱을 다시 실행한 것처럼 새 State로 화면을 만듭니다.
      await pumpScreen(tester, key: const ValueKey('second'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('2편 · 최신순'), findsOneWidget);
      final selectedChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '드라마'),
      );
      expect(selectedChip.selected, isTrue);
    });

    testWidgets('저장된 정렬 방식도 복원된다', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            MovieListPreferences.selectedGenreKey: 'SF',
            MovieListPreferences.sortKey: 'title',
          });

      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('1편 · 제목순'), findsOneWidget);
    });

    testWidgets('당겨서 새로고침하는 동안 기존 목록을 유지한다', (tester) async {
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(MovieListLoading), findsNothing);
      expect(find.text('6편 · 최신순'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('6편 · 최신순'), findsOneWidget);
    });
  });
}
