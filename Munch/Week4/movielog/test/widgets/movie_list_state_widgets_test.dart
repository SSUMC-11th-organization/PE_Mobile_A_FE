import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_card_skeleton.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

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

  testWidgets('Loading은 영화 카드 형태의 Skeleton을 보여준다', (tester) async {
    await tester.pumpWidget(wrap(const MovieListLoading()));

    expect(
      find.byType(MovieCardSkeleton),
      findsNWidgets(MovieListLoading.skeletonCount),
    );
    expect(find.byType(MovieCard), findsNothing);
  });

  testWidgets('Empty는 안내 문구를 보여준다', (tester) async {
    await tester.pumpWidget(wrap(const MovieListEmpty()));

    expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('Error는 안내 문구와 다시 시도 버튼을 보여주고 탭하면 onRetry를 호출한다', (tester) async {
    var retried = 0;
    await tester.pumpWidget(wrap(MovieListError(onRetry: () => retried++)));

    expect(find.text(MovieListError.defaultMessage), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    expect(retried, 1);
  });

  testWidgets('Error는 전달받은 메시지를 보여준다', (tester) async {
    await tester.pumpWidget(
      wrap(
        MovieListError(message: MovieListError.timeoutMessage, onRetry: () {}),
      ),
    );

    expect(find.text(MovieListError.timeoutMessage), findsOneWidget);
  });

  testWidgets('Success는 영화 카드를 보여주고 탭하면 해당 영화를 전달한다', (tester) async {
    Object? tapped;
    await tester.pumpWidget(
      wrap(MovieGrid(movies: movies, onMovieTap: (movie) => tapped = movie)),
    );

    expect(find.text(movies.first.title), findsOneWidget);

    await tester.tap(find.text(movies.first.title));
    expect(tapped, movies.first);
  });
}
