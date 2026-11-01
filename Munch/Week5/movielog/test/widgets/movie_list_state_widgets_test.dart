import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_card_skeleton.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:movielog/widgets/movie_load_retry_dialog.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

import '../fakes/fake_tmdb_movie_service.dart';

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

    expect(find.text(MovieListEmpty.defaultMessage), findsOneWidget);
  });

  testWidgets('Error는 다시 시도 버튼을 탭하면 onRetry를 호출한다', (tester) async {
    var retried = 0;
    await tester.pumpWidget(wrap(MovieListError(onRetry: () => retried++)));

    expect(find.text(MovieListError.defaultMessage), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    expect(retried, 1);
  });

  testWidgets('Success는 TMDB 영화 카드를 보여주고 탭하면 해당 영화를 전달한다', (tester) async {
    final movies = [movieFixture(1), movieFixture(2)];
    TmdbMovieDto? tapped;
    await tester.pumpWidget(
      wrap(
        MovieGrid(
          movies: movies,
          genreNames: const {28: '액션'},
          onMovieTap: (movie) => tapped = movie,
        ),
      ),
    );

    expect(find.text('영화 1'), findsOneWidget);
    expect(find.text('2024 · 액션'), findsNWidgets(2));

    await tester.tap(find.text('영화 2'));
    expect(tapped?.id, 2);
  });

  testWidgets('poster_path가 없으면 네트워크 요청 없이 placeholder를 보여준다', (tester) async {
    await tester.pumpWidget(
      wrap(const TmdbPosterImage(posterPath: null, width: 100, height: 150)),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('재시도 Dialog는 다시 시도 true, 취소 false를 반환한다', (tester) async {
    bool? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await MovieLoadRetryDialog.show(context),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('영화를 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
