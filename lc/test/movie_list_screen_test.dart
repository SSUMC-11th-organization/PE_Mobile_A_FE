import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/models/movie.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/genre_preference.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

import 'test_helpers.dart';

/// fetchMovies가 몇 번 호출됐는지 센다.
class CountingMovieService extends FakeMovieService {
  CountingMovieService() : super();

  int callCount = 0;

  @override
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) {
    callCount++;
    return super.fetchMovies(mode: mode);
  }
}

Widget buildScreen({
  FakeMovieService service = const FakeMovieService(),
  MovieLoadMode mode = MovieLoadMode.success,
  Key? key,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MovieListScreen(key: key, movieService: service, initialMode: mode),
  );
}

/// 1초(Mock 지연) 뒤 Future 완료와 화면 갱신까지 진행한다.
Future<void> finishLoading(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

int countOfGenre(String genre) => filterMoviesByGenre(movies, genre).length;

void main() {
  setUp(useInMemoryPreferences);

  testWidgets('Loading이 먼저 보이고 1초 뒤 Success 영화 Grid가 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildScreen());

    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MovieCard), findsNothing);

    await finishLoading(tester);

    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieCard), findsNWidgets(movies.length));
  });

  testWidgets('서비스가 빈 목록을 돌려주면 Empty 화면이 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildScreen(mode: MovieLoadMode.empty));
    await finishLoading(tester);

    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
    expect(find.byType(MovieCard), findsNothing);
  });

  testWidgets('조건에 맞는 영화가 없는 장르를 고르면 Empty 화면이 보인다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildScreen());
    await finishLoading(tester);

    await tester.ensureVisible(find.text('코미디'));
    await tester.tap(find.text('코미디'));
    await tester.pump();

    expect(find.byType(MovieListEmpty), findsOneWidget);
    // 다른 장르로 바꿀 수 있도록 Chip은 그대로 보인다.
    expect(find.text('코미디'), findsOneWidget);
  });

  testWidgets('실패하면 Error 화면과 다시 시도 버튼이 보이고 내부 예외는 숨겨진다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildScreen(mode: MovieLoadMode.failure));
    await finishLoading(tester);

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    // 오류를 빈 목록으로 오해하지 않는다.
    expect(find.byType(MovieListEmpty), findsNothing);
  });

  testWidgets('실패 후 재시도하면 Loading부터 다시 시작해 Success로 복구된다', (tester) async {
    useTallScreen(tester);
    final service = CountingMovieService();
    await tester.pumpWidget(buildScreen(service: service));
    await finishLoading(tester);
    expect(service.callCount, 1);

    // 디버그 메뉴에서 '실패 후 재시도하면 성공'을 고른다.
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실패 후 재시도하면 성공'));
    await tester.pump();
    await finishLoading(tester);
    expect(find.byType(MovieListError), findsOneWidget);
    expect(service.callCount, 2);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();

    // 재시도 시 오류 화면이 사라지고 Loading부터 다시 시작한다.
    expect(find.byType(MovieListError), findsNothing);
    expect(find.byType(MovieListLoading), findsOneWidget);

    await finishLoading(tester);
    expect(find.byType(MovieCard), findsNWidgets(movies.length));
    expect(service.callCount, 3);
  });

  testWidgets('화면이 다시 그려져도 Future는 다시 만들어지지 않는다', (tester) async {
    useTallScreen(tester);
    final service = CountingMovieService();
    await tester.pumpWidget(buildScreen(service: service));
    await finishLoading(tester);
    expect(service.callCount, 1);

    // 장르 선택(setState)과 화면 크기 변경으로 build가 여러 번 실행된다.
    await tester.tap(find.text('SF'));
    await tester.pump();
    tester.view.physicalSize = const Size(700, 2400);
    await tester.pump();

    expect(service.callCount, 1);
  });

  testWidgets('장르를 고르면 목록이 갱신되고 선택값이 저장된다', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildScreen());
    await finishLoading(tester);

    await tester.tap(find.text('SF'));
    await tester.pump();

    expect(find.byType(MovieCard), findsNWidgets(countOfGenre('SF')));
    expect(await GenrePreference().read(), 'SF');
  });

  testWidgets('저장된 장르는 화면을 다시 열어도 복원된다', (tester) async {
    useTallScreen(tester);
    await GenrePreference().save('드라마');

    await tester.pumpWidget(buildScreen(key: UniqueKey()));
    await finishLoading(tester);

    expect(find.byType(MovieCard), findsNWidgets(countOfGenre('드라마')));
    final dramaChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '드라마'),
    );
    expect(dramaChip.selected, isTrue);
  });
}
