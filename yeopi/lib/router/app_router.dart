import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../services/movie_list_preferences.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';

class AppRouter {
  AppRouter._();

  // 하단 NavigationBar 바깥의 앱 전체 Navigator입니다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: '/start',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
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
                builder: (context, state) {
                  // 회원가입에서 받은 memberId만 사용합니다. 다른 사람의 memberId를 임의로 넣지 않습니다.
                  final memberId = context
                      .watch<LearningMemberSession>()
                      .memberId;
                  if (memberId == null) return const _SignUpRequiredScreen();
                  return ChangeNotifierProvider<MyRatingsViewModel>(
                    // memberId가 바뀌면 새 ViewModel로 다시 조회합니다.
                    key: ValueKey(memberId),
                    create: (context) => MyRatingsViewModel(
                      context.read<RatingApiService>(),
                      context.read<TmdbMovieService>(),
                      memberId,
                    )..load(),
                    child: const MyRatingsScreen(),
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
          final movie = extra is TmdbMovieDto && extra.id == id ? extra : null;
          return MovieDetailLoader(movieId: id, initialMovie: movie);
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

class _SignUpRequiredScreen extends StatelessWidget {
  const _SignUpRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('학습용 회원가입이 필요합니다.'),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('회원가입하러 가기'),
            ),
          ],
        ),
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
