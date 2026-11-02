import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/member_check_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, this.movieService, this.memberCheckService});

  /// 테스트에서 가짜 Service를 주입할 때 쓴다. 없으면 실제 Client로 만든다.
  final TmdbMovieService? movieService;
  final MemberCheckService? memberCheckService;

  @override
  Widget build(BuildContext context) {
    // 워크북 백엔드를 호출하는 Service들은 Dio 인스턴스 하나를 공유한다.
    final movieLogClient = createMovieLogClient();

    // 여러 Route가 함께 쓰는 stateless Service는 MaterialApp.router 위에서 한 번만 만든다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<MemberCheckService>(
          create: (_) =>
              memberCheckService ?? MemberCheckService(movieLogClient),
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
