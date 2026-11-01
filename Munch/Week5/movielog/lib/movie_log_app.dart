import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/tmdb_client.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, this.movieService});

  /// 테스트에서 가짜 Service를 주입할 때 쓴다. 없으면 TMDB Client로 만든다.
  final TmdbMovieService? movieService;

  @override
  Widget build(BuildContext context) {
    // 여러 Route가 함께 쓰는 stateless Service는 MaterialApp.router 위에서 한 번만 만든다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
