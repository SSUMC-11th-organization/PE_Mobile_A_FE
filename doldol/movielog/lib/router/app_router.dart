import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/start_screen.dart';

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
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) => MovieListScreen(
              // Query Parameter: /movies?genre=SF
              genre: state.uri.queryParameters['genre'],
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
        builder: (context, state) => MovieDetailScreen(
          // Path Parameter
          movieId: state.pathParameters['movieId'],
        ),
      ),
    ],
  );

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}