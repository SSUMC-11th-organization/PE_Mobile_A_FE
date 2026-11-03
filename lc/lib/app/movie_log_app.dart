import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/tmdb_client.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  /// [movieService]는 테스트에서 가짜 Service를 넣기 위한 자리다.
  const MovieLogApp({super.key, this.movieService});

  final TmdbMovieService? movieService;

  @override
  Widget build(BuildContext context) {
    final injected = movieService;

    // 여러 화면(Route)이 함께 쓰는 상태 없는 Service를 최상단에 하나만 둔다.
    return MultiProvider(
      providers: [
        if (injected != null)
          Provider<TmdbMovieService>.value(value: injected)
        else
          Provider<TmdbMovieService>(
            create: (_) => TmdbMovieService(createTmdbClient()),
          ),
      ],
      child: MaterialApp.router(
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
