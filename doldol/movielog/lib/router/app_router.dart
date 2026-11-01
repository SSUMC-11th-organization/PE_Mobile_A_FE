import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../data/models/tmdb_movie_dto.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/register',
        // 회원가입 화면에서는 뒤로가기가 동작하지 않도록 막음
        builder: (context, state) =>
            const PopScope(canPop: false, child: SignUpScreen()),
      ),
      // 공통 NavigationBar를 가진 탭 화면들
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                ChangeNotifierProvider<MovieHomeViewModel>(
              // ViewModel 생성 직후 첫 로딩을 한 번 실행 (..은 캐스케이드)
              create: (context) => MovieHomeViewModel(
                context.read<TmdbMovieService>(),
              )..loadPopular(),
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) =>
                ChangeNotifierProvider<MovieListViewModel>(
              create: (context) => MovieListViewModel(
                context.read<TmdbMovieService>(),
              )..loadInitial(),
              child: const MovieListScreen(),
            ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
      // 상세 화면은 NavigationBar 없이 전체 화면으로 표시
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          // Path Parameter: 어떤 영화인지 식별하는 TMDB id
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');

          // Extra: 카드에서 함께 넘긴 영화 정보 (경로의 id와 같을 때만 사용)
          final extra = state.extra;
          final movie = extra is TmdbMovieDto && extra.id == movieId ? extra : null;

          return MovieDetailScreen(movieId: movieId, movie: movie);
        },
      ),
    ],
  );

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}