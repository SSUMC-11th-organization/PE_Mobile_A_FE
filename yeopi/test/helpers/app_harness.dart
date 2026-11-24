import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/main.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/services/login_preferences.dart';
import 'package:movielog/services/movie_list_preferences.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'movielog_fakes.dart';
import 'tmdb_fakes.dart';

// 앱 전체를 Fake Service로 띄우고, 테스트가 상태를 확인할 수 있게 Fake들을 모아 돌려줍니다.
class AppHarness {
  AppHarness({
    required this.tester,
    required this.movies,
    required this.tokens,
    required this.authApi,
    required this.memberApi,
    required this.ratings,
    required this.signUp,
  });

  final WidgetTester tester;
  final FakeTmdbMovieService movies;
  final FakeTokenStorage tokens;
  final FakeAuthApiService authApi;
  final FakeMemberApiService memberApi;
  final FakeRatingApiService ratings;
  final FakeSignUpService signUp;

  BuildContext get _context =>
      AppRouter.rootNavigatorKey.currentContext ??
      tester.element(find.byType(Navigator).first);

  AuthViewModel get auth => _context.read<AuthViewModel>();
  SessionRatingStore get store => _context.read<SessionRatingStore>();
  // push로 쌓인 화면까지 포함한 현재 위치입니다.
  String get location => GoRouter.of(_context).state.uri.path;

  Future<void> go(String path, {Object? extra}) async {
    GoRouter.of(_context).go(path, extra: extra);
    await tester.pumpAndSettle();
  }

  Future<void> push(String path, {Object? extra}) async {
    GoRouter.of(_context).push(path, extra: extra);
    await tester.pumpAndSettle();
  }
}

// 영화 목록이 장르를, 로그인 화면이 저장 이메일을 쓰므로 테스트마다 메모리 저장소로 바꿉니다.
void useInMemoryPreferences() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
}

// signedIn이 true면 저장된 토큰과 GET me 성공으로 세션이 복원된 상태(/home)에서 시작합니다.
Future<AppHarness> pumpMovieLogApp(
  WidgetTester tester, {
  bool signedIn = true,
  FakeTokenStorage? tokens,
  FakeMemberApiService? memberApi,
  FakeAuthApiService? authApi,
  FakeRatingApiService? ratings,
  FakeSignUpService? signUp,
  FakeTmdbMovieService? movies,
  String? savedEmail,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  useInMemoryPreferences();
  if (savedEmail != null) {
    await SharedPreferencesAsync().setString(
      LoginPreferences.savedEmailKey,
      savedEmail,
    );
  }

  final harness = AppHarness(
    tester: tester,
    movies: movies ?? FakeTmdbMovieService(),
    tokens: tokens ?? FakeTokenStorage(signedIn ? fakeAccessToken : null),
    authApi: authApi ?? FakeAuthApiService(),
    memberApi: memberApi ?? FakeMemberApiService(),
    ratings: ratings ?? FakeRatingApiService(),
    signUp: signUp ?? FakeSignUpService(),
  );
  await tester.pumpWidget(
    MovieLogApp(
      movieService: harness.movies,
      preferences: MovieListPreferences(),
      loginPreferences: LoginPreferences(),
      tokenStorage: harness.tokens,
      authApiService: harness.authApi,
      memberApiService: harness.memberApi,
      ratingApiService: harness.ratings,
      signUpService: harness.signUp,
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}
