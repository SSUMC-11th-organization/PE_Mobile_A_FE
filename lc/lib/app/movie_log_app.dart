import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../data/services/member_check_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  /// 주입 값은 테스트에서 가짜 Service를 넣기 위한 자리다. 비워두면 실제 Service를 만든다.
  const MovieLogApp({
    super.key,
    this.movieService,
    this.memberCheckService,
    this.ratingApiService,
  });

  final TmdbMovieService? movieService;
  final MemberCheckService? memberCheckService;
  final RatingApiService? ratingApiService;

  @override
  Widget build(BuildContext context) {
    // 두 Service는 같은 백엔드를 호출하므로 Dio 하나를 공유한다. TMDB Client와는 합치지 않는다.
    final Dio movieLogClient = createMovieLogClient();

    // 여러 화면(Route)이 함께 쓰는 상태 없는 Service를 최상단에 하나만 둔다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<MemberCheckService>(
          create: (_) =>
              memberCheckService ?? MemberCheckService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) => ratingApiService ?? RatingApiService(movieLogClient),
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
