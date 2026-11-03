import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/network/tmdb_client.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'services/movie_list_preferences.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 로드가 끝나기 전에 Client를 만들면 Token이 빈 값으로 읽히므로 runApp 전에 기다립니다.
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, this.movieService, this.preferences});

  // 테스트에서 실제 TMDB 대신 Fake를 넣을 때만 전달합니다.
  final TmdbMovieService? movieService;
  final MovieListPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    // 여러 Route가 함께 쓰는 Service는 MaterialApp.router 위에서 한 번만 만듭니다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<MovieListPreferences>(
          create: (_) => preferences ?? MovieListPreferences(),
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
