import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'services/movie_list_preferences.dart';
import 'theme/app_theme.dart';
import 'view_models/learning_member_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 로드가 끝나기 전에 Client를 만들면 Token이 빈 값으로 읽히므로 runApp 전에 기다립니다.
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.movieService,
    this.preferences,
    this.signUpService,
    this.ratingApiService,
    this.session,
  });

  // 테스트에서 실제 서버 대신 Fake를 넣을 때만 전달합니다.
  final TmdbMovieService? movieService;
  final MovieListPreferences? preferences;
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final LearningMemberSession? session;

  @override
  Widget build(BuildContext context) {
    // 두 Service가 같은 백엔드를 부르므로 Dio 하나를 공유합니다. 처음 필요할 때 한 번만 만들어집니다.
    late final movieLogClient = createMovieLogClient();

    // 여러 Route가 함께 쓰는 Service는 MaterialApp.router 위에서 한 번만 만듭니다.
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
        Provider<MovieListPreferences>(
          create: (_) => preferences ?? MovieListPreferences(),
        ),
        // 회원가입으로 받은 memberId를 앱 실행 동안만 메모리에 들고 있습니다. (비밀번호는 저장하지 않습니다.)
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => session ?? LearningMemberSession(),
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
