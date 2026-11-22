import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/splash_screen.dart';
import '../services/movie_list_preferences.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_rating_store.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

// 인증 상태만 보고 어느 화면에 있어야 하는지 정합니다. 여기서는 API 호출 같은 비동기 작업을 하지 않습니다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중·확인 실패: 스플래시에 머물러서 보호 화면이 잠깐이라도 보이지 않게 합니다.
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    // 로그아웃·로그인 요청 중: 로그인·회원가입만 허용합니다.
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    // 로그인됨: 스플래시·로그인·회원가입에 있으면 홈으로 보냅니다.
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  // 하단 NavigationBar 바깥의 앱 전체 Navigator입니다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  // refreshListenable에 AuthViewModel을 연결해야 하므로 인스턴스를 받아 Router를 만듭니다.
  // 앱이 살아 있는 동안 한 번만 만들어야 해서 MovieLogApp의 State에서 호출합니다.
  static GoRouter createRouter(AuthViewModel auth) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // 로그인·로그아웃·만료로 상태가 바뀌면 redirect를 다시 실행합니다.
      refreshListenable: auth,
      redirect: (context, state) => authRedirect(auth.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start',
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
        // 탭 화면은 MainScreen의 NavigationBar 안에 표시됩니다.
        ShellRoute(
          builder: (context, state, child) => MainScreen(
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          ),
          routes: [
            // 화면별 ViewModel은 각 Route에서 만들고, 화면을 벗어나면 함께 dispose 됩니다.
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
                  ChangeNotifierProvider<MovieListViewModel>(
                    create: (context) => MovieListViewModel(
                      context.read<TmdbMovieService>(),
                      context.read<MovieListPreferences>(),
                    )..loadInitial(),
                    child: const MovieListScreen(),
                  ),
            ),
            GoRoute(
              path: '/my',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'ratings', // 최종 경로: /my/ratings
                  // 지정하지 않으면 ShellRoute의 Navigator에 쌓여 하단 NavigationBar가 남습니다.
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      ChangeNotifierProvider<MyRatingsViewModel>(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          context.read<AuthViewModel>(),
                          context.read<SessionRatingStore>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'profile/edit', // 최종 경로: /my/profile/edit
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    // 내 정보가 아직 없으면 불러오는 중/재시도를 보여주고, 있을 때만 수정 화면을 엽니다.
                    if (auth.member == null) {
                      return const _MemberPendingScreen();
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        auth,
                      ),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // 상세는 NavigationBar 없이 전체 화면으로 push 됩니다.
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null) return const _InvalidMovieScreen();
            final extra = state.extra;
            // 카드에서 넘긴 TMDB 영화가 주소의 id와 같을 때만 사용하고, 아니면 Loader가 다시 조회합니다.
            final movie = extra is TmdbMovieDto && extra.id == id
                ? extra
                : null;
            return MovieDetailLoader(movieId: id, initialMovie: movie);
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

class _MemberPendingScreen extends StatelessWidget {
  const _MemberPendingScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: CommonAppBar(
        title: '프로필 수정',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: Center(
        child: auth.memberStatus == MemberLoadStatus.error
            ? MovieLogButton(
                label: '다시 시도',
                width: 120,
                onPressed: () => auth.loadMember(force: true),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class _InvalidMovieScreen extends StatelessWidget {
  const _InvalidMovieScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: '영화 상세', onBack: () => context.pop()),
      body: const Center(child: Text('영화를 불러오지 못했습니다.')),
    );
  }
}
