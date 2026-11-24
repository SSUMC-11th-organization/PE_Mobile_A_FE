import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/button_preview_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/movie_search_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
import '../view_models/session_rating_store.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

// redirect 안에서는 상태만 읽고 판단한다. 비동기 작업은 하지 않는다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  static String movieDetailLocation(int movieId) => '/movies/$movieId';
  static const movieSearchLocation = '/movies/search';

  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthViewModel authViewModel) => GoRouter(
    initialLocation: '/start',
    navigatorKey: rootNavigatorKey,
    refreshListenable: authViewModel,
    redirect: (context, state) =>
        authRedirect(authViewModel.status, state.uri.path),
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/button-preview',
        builder: (context, state) => const ButtonPreviewScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) => SignUpViewModel(context.read<SignUpService>()),
          child: const SignUpScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/movies',
                builder: (context, state) =>
                    ChangeNotifierProvider<PagedMoviesViewModel>(
                      create: (context) =>
                          PagedMoviesViewModel(
                              tmdbApi: context.read<TmdbMovieService>(),
                            )
                            ..loadGenres()
                            ..loadInitial(),
                      child: const MovieListScreen(),
                    ),
                routes: [
                  // 정적 경로 search를 :movieId보다 먼저 등록해야 영화 ID로 해석되지 않는다.
                  GoRoute(
                    path: 'search',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        ChangeNotifierProvider<PagedMoviesViewModel>(
                          create: (context) => PagedMoviesViewModel(
                            tmdbApi: context.read<TmdbMovieService>(),
                          ),
                          child: MovieSearchScreen(
                            onOpenMovie: (movie) => _openMovie(context, movie),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: ':movieId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final id = int.tryParse(
                        state.pathParameters['movieId'] ?? '',
                      );
                      if (id == null || id < 1) {
                        return const Scaffold(
                          body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
                        );
                      }
                      final extra = state.extra;
                      return _withVerifiedMember(
                        context,
                        title: '영화 상세',
                        builder: (auth, guard, email) =>
                            ChangeNotifierProvider<FavoriteDetailViewModel>(
                              key: ValueKey('$email:${guard.generation}'),
                              create: (context) => FavoriteDetailViewModel(
                                movieId: id,
                                favoriteApi: context.read<FavoriteApiService>(),
                                sessionGuard: guard,
                                accountId: email,
                                onSessionExpired: auth.expireSession,
                              ),
                              child: MovieDetailLoader(
                                movieId: id,
                                initialMovie:
                                    extra is TmdbMovieDto && extra.id == id
                                    ? extra
                                    : null,
                              ),
                            ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'ratings',
                    // root Navigator 위에 띄워 하단 NavigationBar를 가린다.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        ChangeNotifierProvider<MyRatingsViewModel>(
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
                    path: 'favorites',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => _withVerifiedMember(
                      context,
                      title: '내 즐겨찾기',
                      builder: (auth, guard, email) =>
                          ChangeNotifierProvider<FavoritesViewModel>(
                            // 계정이나 세션이 바뀌면 이전 사용자의 ViewModel을 버리고 새로 만든다.
                            key: ValueKey('$email:${guard.generation}'),
                            create: (context) => FavoritesViewModel(
                              favoriteApi: context.read<FavoriteApiService>(),
                              tmdbApi: context.read<TmdbMovieService>(),
                              sessionGuard: guard,
                              accountId: email,
                              onSessionExpired: auth.expireSession,
                            ),
                            child: FavoritesScreen(
                              onOpenMovie: (movie) =>
                                  _openMovie(context, movie),
                            ),
                          ),
                    ),
                  ),
                  GoRoute(
                    path: 'profile/edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final auth = context.watch<AuthViewModel>();
                      if (auth.member == null) {
                        return Scaffold(
                          appBar: AppBar(
                            centerTitle: true,
                            title: const Text('프로필 수정'),
                          ),
                          body: Center(
                            child: auth.memberStatus == MemberLoadStatus.error
                                ? MovieLogButton(
                                    label: '다시 시도',
                                    onPressed: () =>
                                        auth.loadMember(force: true),
                                  )
                                : const CircularProgressIndicator(),
                          ),
                        );
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
        ],
      ),
    ],
  );

  static Future<void> _openMovie(BuildContext context, TmdbMovieDto movie) =>
      context.push(movieDetailLocation(movie.id), extra: movie);

  // 내 정보가 준비되고 SessionGuard가 같은 계정으로 시작된 뒤에만 사용자별 화면을 만든다.
  static Widget _withVerifiedMember(
    BuildContext context, {
    required String title,
    required Widget Function(
      AuthViewModel auth,
      SessionGuard guard,
      String email,
    )
    builder,
  }) {
    final auth = context.watch<AuthViewModel>();
    final guard = context.read<SessionGuard>();
    final member = auth.member;

    if (member == null || guard.accountId != member.email) {
      return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(title)),
        body: Center(
          child: auth.memberStatus == MemberLoadStatus.error
              ? MovieLogButton(
                  label: '내 정보 다시 조회',
                  width: 220,
                  onPressed: () => auth.loadMember(force: true),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return builder(auth, guard, member.email);
  }
}
