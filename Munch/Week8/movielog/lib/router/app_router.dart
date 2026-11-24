import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/button_preview_screen.dart';
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
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
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
                    ChangeNotifierProvider<MovieListViewModel>(
                      create: (context) =>
                          MovieListViewModel(context.read<TmdbMovieService>())
                            ..loadInitial(),
                      child: const MovieListScreen(),
                    ),
                routes: [
                  GoRoute(
                    path: ':movieId',
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
                      return MovieDetailLoader(
                        movieId: id,
                        initialMovie: extra is TmdbMovieDto && extra.id == id
                            ? extra
                            : null,
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
}
