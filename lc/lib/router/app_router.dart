import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../models/movie_detail_args.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/favorites_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/movie_search_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
import '../core/session/session_guard.dart';
import '../data/services/favorite_api_service.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_rating_store.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

/// 인증 상태와 가려는 경로만 보고 이동할 곳을 정한다. (null이면 그대로 둔다.)
/// 여기서는 상태만 읽고 판단하며, API 호출 같은 비동기 작업은 하지 않는다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 또는 확인 실패(재시도 버튼): 스플래시 화면 유지
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    // 로그아웃 또는 로그인 요청 중: 공개 화면만 허용
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    // 로그인됨: 스플래시와 로그인·회원가입 화면은 홈으로 보냄
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  /// 하단 NavigationBar를 가리는 화면을 띄우기 위한 root Navigator 키.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Router는 앱이 살아있는 동안 한 번만 만든다. (build()에서 만들면 위치가 초기화된다.)
  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // redirect는 이동할 때만 호출되므로, 인증 상태가 바뀔 때도 다시 실행되게 연결한다.
      refreshListenable: authViewModel,
      redirect: (context, state) =>
          authRedirect(authViewModel.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
            child: const SignUpScreen(),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => MainScreen(
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          ),
          routes: [
            // 화면(페이지)마다 ViewModel을 하나씩 만들고, 공용 Service는 앱 최상단에서 가져온다.
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieHomeViewModel>(
                    create: (context) =>
                        MovieHomeViewModel(context.read<TmdbMovieService>())
                          ..loadPopular(),
                    child: const HomeScreen(),
                  ),
            ),
            GoRoute(
              path: '/movies',
              builder: (context, state) =>
                  ChangeNotifierProvider<PagedMoviesViewModel>(
                    create: (context) =>
                        PagedMoviesViewModel(context.read<TmdbMovieService>())
                          ..loadInitial(),
                    child: const MovieListScreen(),
                  ),
            ),
            GoRoute(
              path: '/my',
              builder: (context, state) => const MyPageScreen(),
              routes: [
                GoRoute(
                  path: 'ratings', // 최종 경로: /my/ratings
                  // ShellRoute 안이 아니라 root Navigator 위에 열어 하단 NavigationBar를 가린다.
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      ChangeNotifierProvider<MyRatingsViewModel>(
                        // memberId 대신 토큰 기반 Service와 이번 세션의 평점을 쓴다.
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          context.read<SessionRatingStore>(),
                          context.read<AuthViewModel>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'favorites', // 최종 경로: /my/favorites
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    final guard = context.read<SessionGuard>();
                    final email = auth.member?.email;
                    if (email == null || guard.accountId != email) {
                      return _MemberRequiredScreen(auth: auth);
                    }
                    return ChangeNotifierProvider<FavoritesViewModel>(
                      // 계정이 바뀌면 이전 계정의 목록을 버리고 새로 만든다.
                      key: ValueKey('favorites:$email:${guard.generation}'),
                      create: (context) => FavoritesViewModel(
                        favoriteApi: context.read<FavoriteApiService>(),
                        movieService: context.read<TmdbMovieService>(),
                        sessionGuard: guard,
                        accountId: email,
                        onSessionExpired: auth.expireSession,
                      )..load(),
                      child: const FavoritesScreen(),
                    );
                  },
                ),
                GoRoute(
                  path: 'profile/edit', // 최종 경로: /my/profile/edit
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    if (auth.member == null) {
                      return _MemberRequiredScreen(auth: auth);
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        context.read<AuthViewModel>(),
                      ),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/movies/search', // 정적 경로는 :movieId보다 먼저 둔다.
          builder: (context, state) =>
              ChangeNotifierProvider<PagedMoviesViewModel>(
                create: (context) =>
                    PagedMoviesViewModel(context.read<TmdbMovieService>()),
                child: const MovieSearchScreen(),
              ),
        ),
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) {
            // 주소의 id는 TMDB 영화 id다. 숫자가 아니거나 1보다 작으면 조회하지 않는다.
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) return const _InvalidMovieIdScreen();
            final extra = state.extra;
            return MovieDetailLoader(
              movieId: id,
              initialArgs: extra is MovieDetailArgs && extra.movie.id == id
                  ? extra
                  : null,
            );
          },
        ),
      ],
    );
  }

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}

/// 내 정보를 아직 못 불러온 상태로 프로필 수정에 들어온 경우.
class _MemberRequiredScreen extends StatelessWidget {
  const _MemberRequiredScreen({required this.auth});

  final AuthViewModel auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
      body: Center(
        child: auth.memberStatus == MemberLoadStatus.error
            ? MovieLogButton(
                label: '다시 시도',
                onPressed: () => auth.loadMember(force: true),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class _InvalidMovieIdScreen extends StatelessWidget {
  const _InvalidMovieIdScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('영화 ID가 올바르지 않습니다.')));
  }
}
