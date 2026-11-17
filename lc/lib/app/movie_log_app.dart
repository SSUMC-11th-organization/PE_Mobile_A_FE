import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../core/storage/saved_email_storage.dart';
import '../core/storage/token_storage.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/session_rating_store.dart';

class MovieLogApp extends StatelessWidget {
  /// 주입 값은 테스트에서 가짜 Service·저장소를 넣기 위한 자리다. 비워두면 실제 객체를 만든다.
  const MovieLogApp({
    super.key,
    this.movieService,
    this.signUpService,
    this.ratingApiService,
    this.authApiService,
    this.memberApiService,
    this.tokenStorage,
    this.savedEmailStorage,
  });

  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final TokenStorage? tokenStorage;
  final SavedEmailStorage? savedEmailStorage;

  @override
  Widget build(BuildContext context) {
    final storage =
        tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());
    // 공개용에는 Interceptor가 없고, 보호용에만 AuthInterceptor가 있다.
    // TMDB Client와는 합치지 않는다. (TMDB 요청에 MovieLog JWT가 실리면 안 된다.)
    final publicClient = createMovieLogClient();
    final authClient = createAuthMovieLogClient(storage);

    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: storage),
        Provider<SavedEmailStorage>(
          create: (_) => savedEmailStorage ?? PrefsSavedEmailStorage(),
        ),
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client
        Provider<AuthApiService>(
          create: (_) => authApiService ?? AuthApiService(publicClient),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(publicClient),
        ),
        // 보호 Client (RatingApiService는 공개 조회용 Client도 함께 받는다)
        Provider<MemberApiService>(
          create: (_) => memberApiService ?? MemberApiService(authClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              ratingApiService ?? RatingApiService(publicClient, authClient),
        ),
        // Service를 주입받는 ViewModel
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 이번 세션에서 등록한 평점. 세션이 바뀌면 스스로 비운다.
        ChangeNotifierProvider<SessionRatingStore>(
          create: (context) =>
              SessionRatingStore(context.read<AuthViewModel>()),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

/// GoRouter를 한 번만 만들고 세션 복원을 시작하는 호스트.
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
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel);
    // 첫 build 이후에 세션 복원을 시작한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession();
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
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
