import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../view_models/learning_member_session.dart';

class MovieLogApp extends StatelessWidget {
  /// 주입 값은 테스트에서 가짜 Service·세션을 넣기 위한 자리다. 비워두면 실제 객체를 만든다.
  const MovieLogApp({
    super.key,
    this.movieService,
    this.signUpService,
    this.ratingApiService,
    this.memberSession,
  });

  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final LearningMemberSession? memberSession;

  @override
  Widget build(BuildContext context) {
    // 두 Service는 같은 백엔드를 호출하므로 Dio 하나를 공유한다. TMDB Client와는 합치지 않는다.
    final Dio movieLogClient = createMovieLogClient();
    final injectedSession = memberSession;

    // 여러 화면(Route)이 함께 쓰는 상태 없는 Service와 학습용 회원 세션을 최상단에 하나만 둔다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) => ratingApiService ?? RatingApiService(movieLogClient),
        ),
        if (injectedSession != null)
          ChangeNotifierProvider<LearningMemberSession>.value(
            value: injectedSession,
          )
        else
          ChangeNotifierProvider<LearningMemberSession>(
            create: (_) => LearningMemberSession(),
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
