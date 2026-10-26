import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/widgets/hero_banner.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:movielog/widgets/popular_movie_card.dart';

import '../test_helpers.dart';

Widget buildScreen(FakeTmdbMovieService service) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MovieHomeViewModel>(
      create: (_) => MovieHomeViewModel(service)..loadPopular(),
      child: const HomeScreen(),
    ),
  );
}

void main() {
  testWidgets('인기 영화 5개가 홈에 보이고 첫 번째 영화가 배너가 된다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService(popular: movieDtos(20));

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.byType(HeroBanner), findsOneWidget);
    expect(tester.widget<HeroBanner>(find.byType(HeroBanner)).movie.id, 1);
    expect(find.byType(PopularMovieCard), findsNWidgets(5));
    expect(service.popularCalls, 1);
  });

  testWidgets('인기 영화가 5개보다 적어도 있는 만큼만 보인다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService(popular: movieDtos(2));

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.byType(PopularMovieCard), findsNWidgets(2));
  });

  testWidgets('Loading 후 Success로 바뀐다', (tester) async {
    useTallScreen(tester);
    final gate = Completer<void>();
    final service = _GatedPopularService(gate);

    await tester.pumpWidget(buildScreen(service));
    await tester.pump();
    expect(find.byType(MovieListLoading), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(HeroBanner), findsOneWidget);
  });

  testWidgets('실패하면 Error 화면이 보이고 다시 시도하면 복구된다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService()..failPopular = true;

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    expect(find.byType(MovieListError), findsOneWidget);

    service.failPopular = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.byType(HeroBanner), findsOneWidget);
  });
}

class _GatedPopularService extends FakeTmdbMovieService {
  _GatedPopularService(this._gate);

  final Completer<void> _gate;

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    await _gate.future;
    return super.fetchPopular(page: page);
  }
}
