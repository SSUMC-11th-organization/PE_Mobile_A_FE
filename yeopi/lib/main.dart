import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'services/login_preferences.dart';
import 'services/movie_list_preferences.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/session_rating_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 로드가 끝나기 전에 Client를 만들면 Token이 빈 값으로 읽히므로 runApp 전에 기다립니다.
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({
    super.key,
    this.movieService,
    this.preferences,
    this.loginPreferences,
    this.tokenStorage,
    this.signUpService,
    this.authApiService,
    this.memberApiService,
    this.ratingApiService,
  });

  // 테스트에서 실제 서버·기기 저장소 대신 Fake를 넣을 때만 전달합니다.
  final TmdbMovieService? movieService;
  final MovieListPreferences? preferences;
  final LoginPreferences? loginPreferences;
  final TokenStorage? tokenStorage;
  final SignUpService? signUpService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final RatingApiService? ratingApiService;

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // build가 다시 불려도 Client·저장소가 새로 생기지 않도록 State에 한 번만 만듭니다.
  late final TokenStorage _tokenStorage =
      widget.tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());
  // 공개용(로그인·회원가입·중복 확인·공개 조회)과 보호용(내 정보·평점 쓰기) Client를 나눕니다.
  late final _publicClient = createMovieLogClient();
  late final _authClient = createAuthMovieLogClient(_tokenStorage);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        // TMDB Client에는 AuthInterceptor를 붙이지 않습니다. MovieLog JWT가 TMDB로 가면 안 됩니다.
        Provider<TmdbMovieService>(
          create: (_) => w.movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<MovieListPreferences>(
          create: (_) => w.preferences ?? MovieListPreferences(),
        ),
        Provider<LoginPreferences>(
          create: (_) => w.loginPreferences ?? LoginPreferences(),
        ),
        // 공개 Client
        Provider<SignUpService>(
          create: (_) => w.signUpService ?? SignUpService(_publicClient),
        ),
        Provider<AuthApiService>(
          create: (_) => w.authApiService ?? AuthApiService(_publicClient),
        ),
        // 보호 Client (RatingApiService는 공개 조회용 Client도 함께 받습니다.)
        Provider<MemberApiService>(
          create: (_) => w.memberApiService ?? MemberApiService(_authClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              w.ratingApiService ??
              RatingApiService(_publicClient, _authClient),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 세션이 바뀌면 스스로 비워지도록 AuthViewModel을 구독합니다.
        ChangeNotifierProvider<SessionRatingStore>(
          create: (context) =>
              SessionRatingStore(context.read<AuthViewModel>()),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

// GoRouter는 앱이 살아 있는 동안 한 번만 만들어야 해서 StatefulWidget의 initState에서 만듭니다.
class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(auth);
    // 첫 build 이후 세션 복원을 시작합니다. 그동안은 스플래시가 보입니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) auth.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
