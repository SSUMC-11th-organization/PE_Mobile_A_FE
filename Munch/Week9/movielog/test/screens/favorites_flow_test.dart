import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/router/app_router.dart';

import '../fakes/fake_auth.dart';
import '../fakes/fake_favorite_api_service.dart';
import '../fakes/fake_tmdb_movie_service.dart';
import '../fakes/pump_app.dart';
import 'auth_flow_test.dart' show tapLogin;

Future<void> openFavorites(WidgetTester tester) async {
  await tester.ensureVisible(find.text('내 즐겨찾기'));
  await tester.tap(find.text('내 즐겨찾기'));
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

  testWidgets('상세에서 북마크로 등록·해제하면 아이콘과 Snackbar가 바뀐다', (tester) async {
    final favorites = FakeFavoriteApiService();
    await pumpApp(tester, favoriteService: favorites, location: '/home');
    routerOf(tester)
        .push(AppRouter.movieDetailLocation(550), extra: movieFixture(550));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byTooltip('즐겨찾기 등록'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
    expect(favorites.movieIds, {550});

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('즐겨찾기 해제'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.text('즐겨찾기에서 삭제했습니다.'), findsOneWidget);
    expect(favorites.movieIds, isEmpty);
  });

  testWidgets('내 즐겨찾기 → 상세 해제 → 뒤로가기하면 목록에서 사라진다', (tester) async {
    final favorites = FakeFavoriteApiService(movieIds: [550, 551]);
    await pumpApp(tester, favoriteService: favorites, location: '/my');

    await openFavorites(tester);
    expect(find.text('영화 550'), findsOneWidget);
    expect(find.text('영화 551'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('영화 550'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('즐겨찾기 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('영화 550'), findsNothing);
    expect(find.text('영화 551'), findsOneWidget);
  });

  testWidgets('영화 정보 한 건 실패는 placeholder와 다시 불러오기를 보여 준다', (tester) async {
    final tmdb = FakeTmdbMovieService()..failingMovieIds = {551};
    await pumpApp(
      tester,
      movieService: tmdb,
      favoriteService: FakeFavoriteApiService(movieIds: [550, 551]),
      location: '/my',
    );

    await openFavorites(tester);
    expect(find.text('영화 550'), findsOneWidget);
    expect(find.text('영화 #551'), findsOneWidget);

    tmdb.failingMovieIds = {};
    await tester.tap(find.text('정보 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('영화 551'), findsOneWidget);
  });

  testWidgets('조회 오류와 빈 목록을 다른 화면으로 보여 준다', (tester) async {
    final favorites = FakeFavoriteApiService()..listFailure = connectionError();
    await pumpApp(tester, favoriteService: favorites, location: '/my');

    await openFavorites(tester);
    expect(find.text('즐겨찾기를 불러오지 못했습니다.'), findsOneWidget);

    favorites.listFailure = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('로그아웃 후 다른 계정으로 로그인하면 이전 계정 즐겨찾기가 보이지 않는다', (tester) async {
    final favorites = FakeFavoriteApiService(movieIds: [550]);
    final members = FakeMemberApiService();
    await pumpApp(
      tester,
      favoriteService: favorites,
      memberService: members,
      location: '/my',
    );
    await openFavorites(tester);
    expect(find.text('영화 550'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(currentPath(tester), '/login');

    members.member = MemberInfo(
      email: 'other@example.com',
      nickname: '다른계정',
      createdAt: DateTime(2026, 11, 1),
    );
    favorites.setFavorites([]);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'other@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Umc1234!');
    await tapLogin(tester);

    routerOf(tester).go('/my');
    await tester.pumpAndSettle();
    await openFavorites(tester);

    expect(find.text('영화 550'), findsNothing);
    expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('즐겨찾기 조회가 세션 만료면 로그인 화면으로 이동한다', (tester) async {
    final favorites = FakeFavoriteApiService()
      ..listFailure = apiError(401, 'AUTH401_4');
    await pumpApp(tester, favoriteService: favorites, location: '/my');

    await openFavorites(tester);
    expect(currentPath(tester), '/login');
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
  });

  group('영화 검색', () {
    testWidgets('빈 검색어는 요청하지 않고, 결과를 누르면 상세로 이동한다', (tester) async {
      final tmdb = FakeTmdbMovieService();
      await pumpApp(tester, movieService: tmdb, location: '/movies');
      routerOf(tester).push(AppRouter.movieSearchLocation);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tmdb.searchCalls, isEmpty);
      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '별빛');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tmdb.searchCalls.single, (page: 1, query: '별빛'));
      expect(find.text('영화 101'), findsOneWidget);

      await tester.tap(find.text('검색 결과 더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('영화 102'), findsOneWidget);
      expect(find.text('모든 영화를 확인했습니다.'), findsOneWidget);

      await tester.tap(find.text('영화 101'));
      await tester.pumpAndSettle();
      expect(find.text('평점 남기기'), findsOneWidget);
    });

    testWidgets('결과 없음과 오류를 구분한다', (tester) async {
      final tmdb = FakeTmdbMovieService()
        ..search = (page, query) => pageFixture(page, [], totalPages: 0);
      await pumpApp(tester, movieService: tmdb, location: '/movies');
      routerOf(tester).push(AppRouter.movieSearchLocation);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '없는영화');
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);

      tmdb.failSearch = true;
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      expect(find.text('검색 결과를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });
}
