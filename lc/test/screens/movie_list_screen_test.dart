import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/genre_filter_chips.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

import '../test_helpers.dart';

Widget buildScreen(FakeTmdbMovieService service) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MovieListViewModel>(
      create: (_) => MovieListViewModel(service)..loadInitial(),
      child: const MovieListScreen(),
    ),
  );
}

MovieListViewModel viewModelOf(WidgetTester tester) {
  return Provider.of<MovieListViewModel>(
    tester.element(find.byType(MovieListScreen)),
    listen: false,
  );
}

void main() {
  testWidgets('Loading이 먼저 보이고 완료되면 영화 30개와 장르 Chip이 보인다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService()..discoverGate = Completer<void>();

    await tester.pumpWidget(buildScreen(service));
    await tester.pump();

    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GenreFilterChips), findsNothing);

    service.discoverGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(MovieListLoading), findsNothing);
    expect(
      tester.widget<MovieGrid>(find.byType(MovieGrid)).movies,
      hasLength(30),
    );
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('액션'), findsOneWidget);
  });

  testWidgets('장르 Chip을 누르면 with_genres로 다시 요청하고 선택 상태가 바뀐다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    service.discoverCalls.clear();

    await tester.tap(find.text('액션'));
    await tester.pumpAndSettle();

    expect(service.discoverCalls.first.genreId, 28);
    expect(service.discoverCalls.first.page, 1);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '액션'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('요청 중에는 장르 Chip이 비활성화되어 다른 장르를 고를 수 없다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    service.discoverGate = Completer<void>();
    await tester.tap(find.text('액션'));
    await tester.pump();

    expect(
      tester.widget<GenreFilterChips>(find.byType(GenreFilterChips)).enabled,
      isFalse,
    );
    expect(find.byType(MovieListLoading), findsOneWidget);

    service.discoverCalls.clear();
    await tester.tap(find.text('모험'), warnIfMissed: false);
    await tester.pump();

    expect(viewModelOf(tester).selectedGenreId, 28);
    expect(service.discoverCalls, isEmpty);

    service.discoverGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<GenreFilterChips>(find.byType(GenreFilterChips)).enabled,
      isTrue,
    );
  });

  testWidgets('결과가 없으면 Empty 화면이 보인다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService(catalog: (_) => const []);

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('실패하면 Error 화면이 보이고 다시 시도하면 복구된다', (tester) async {
    useTallScreen(tester);
    final service = FakeTmdbMovieService()..failDiscover = true;

    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    // 내부 오류 내용은 화면에 보이지 않는다.
    expect(find.textContaining('fake failure'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);

    service.failDiscover = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListError), findsNothing);
    expect(find.byType(MovieGrid), findsOneWidget);
  });
}
