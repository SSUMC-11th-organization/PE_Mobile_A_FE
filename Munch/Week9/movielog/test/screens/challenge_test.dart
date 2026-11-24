import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/router/app_router.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_favorite_api_service.dart';
import '../fakes/fake_movie_record_api_service.dart';
import '../fakes/fake_rating_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';
import '../fakes/pump_app.dart';

Future<void> openDetail(WidgetTester tester, int movieId) async {
  routerOf(
    tester,
  ).push(AppRouter.movieDetailLocation(movieId), extra: movieFixture(movieId));
  await tester.pumpAndSettle();
}

Future<void> openRatingDialog(WidgetTester tester) async {
  await tester.tap(find.text('평점 남기기'));
  await tester.pumpAndSettle();
  final stars = find.descendant(
    of: find.byType(RatingBar),
    matching: find.byIcon(Icons.star),
  );
  await tester.tap(stars.at(3));
  await tester.pump();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
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

  group('검색 debounce', () {
    testWidgets('입력이 500ms 멈춘 뒤 마지막 검색어로 한 번만 요청한다', (tester) async {
      final tmdb = FakeTmdbMovieService();
      await pumpApp(tester, movieService: tmdb, location: '/movies');
      routerOf(tester).push(AppRouter.movieSearchLocation);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '어');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), '어벤');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), '어벤져스');
      await tester.pump(const Duration(milliseconds: 499));
      expect(tmdb.searchCalls, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(tmdb.searchCalls, [(page: 1, query: '어벤져스')]);
      expect(find.text('영화 101'), findsOneWidget);
    });

    testWidgets('공백만 입력하면 서버에 보내지 않는다', (tester) async {
      final tmdb = FakeTmdbMovieService();
      await pumpApp(tester, movieService: tmdb, location: '/movies');
      routerOf(tester).push(AppRouter.movieSearchLocation);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tmdb.searchCalls, isEmpty);
    });
  });

  group('평점·즐겨찾기 통합 저장', () {
    testWidgets('즐겨찾기 체크 후 저장하면 movie-records로 함께 저장하고 북마크를 맞춘다', (
      tester,
    ) async {
      final favorites = FakeFavoriteApiService();
      final records = FakeMovieRecordApiService(favorites: favorites);
      await pumpApp(
        tester,
        favoriteService: favorites,
        movieRecordService: records,
        location: '/home',
      );
      await openDetail(tester, 550);
      await openRatingDialog(tester);

      await tester.tap(find.text('즐겨찾기에도 추가'));
      await confirm(tester);

      final request = records.requests.single;
      expect(request.toJson(), {
        'movieId': 550,
        'score': 4,
        'addToFavorites': true,
      });
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('체크하지 않으면 addToFavorites false로 보내고 북마크는 그대로다', (tester) async {
      final records = FakeMovieRecordApiService();
      await pumpApp(tester, movieRecordService: records, location: '/home');
      await openDetail(tester, 550);
      await openRatingDialog(tester);
      await confirm(tester);

      expect(records.requests.single.addToFavorites, isFalse);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('이미 즐겨찾기한 영화는 체크박스 없이 평점 API로만 저장한다', (tester) async {
      final favorites = FakeFavoriteApiService(movieIds: [550]);
      final ratings = FakeRatingApiService();
      final records = FakeMovieRecordApiService(favorites: favorites);
      await pumpApp(
        tester,
        favoriteService: favorites,
        ratingService: ratings,
        movieRecordService: records,
        location: '/home',
      );
      await openDetail(tester, 550);
      await openRatingDialog(tester);

      expect(find.text('즐겨찾기에도 추가'), findsNothing);
      await confirm(tester);
      expect(ratings.createdRequests.single.movieId, 550);
      expect(records.requests, isEmpty);
    });

    testWidgets('COMMON400·네트워크 실패는 Dialog를 유지하고 입력값을 남긴다', (tester) async {
      final records = FakeMovieRecordApiService()
        ..failure = apiError(400, 'COMMON400', message: '코멘트가 너무 깁니다.');
      await pumpApp(tester, movieRecordService: records, location: '/home');
      await openDetail(tester, 550);
      await openRatingDialog(tester);
      await tester.enterText(find.byType(TextField), '좋았어요');
      await tester.tap(find.text('즐겨찾기에도 추가'));
      await confirm(tester);

      expect(find.text('코멘트가 너무 깁니다.'), findsOneWidget);
      expect(find.text('좋았어요'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );

      records.failure = connectionError();
      await confirm(tester);
      expect(find.text('네트워크 연결을 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('평점을 남겨주세요'), findsOneWidget);
    });

    testWidgets('RATING409_1은 Dialog를 닫고 Snackbar로 안내한다', (tester) async {
      final records = FakeMovieRecordApiService()
        ..failure = apiError(409, 'RATING409_1');
      await pumpApp(tester, movieRecordService: records, location: '/home');
      await openDetail(tester, 550);
      await openRatingDialog(tester);
      await confirm(tester);

      expect(find.text('평점을 남겨주세요'), findsNothing);
      expect(
        find.text('이미 이 영화에 평점을 남겼어요. 내가 등록한 평점에서 확인해 주세요.'),
        findsOneWidget,
      );
    });
  });
}
