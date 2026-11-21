import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/saved_email_storage.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/session_rating_store.dart';

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({
    super.key,
    this.movieService,
    this.signUpService,
    this.ratingApiService,
    this.authApiService,
    this.memberApiService,
    this.tokenStorage,
    this.savedEmailStorage,
    this.sessionRatingStore,
  });

  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final TokenStorage? tokenStorage;
  final SavedEmailStorage? savedEmailStorage;
  final SessionRatingStore? sessionRatingStore;

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // Client가 build마다 새로 만들어지지 않도록 State에서 한 번만 만든다.
  late final TokenStorage _tokenStorage =
      widget.tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());
  late final _publicClient = createMovieLogClient();
  late final _authClient = createAuthMovieLogClient(_tokenStorage);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        Provider<SavedEmailStorage>(
          create: (_) => widget.savedEmailStorage ?? SavedEmailStorage(),
        ),
        Provider<TmdbMovieService>(
          create: (_) =>
              widget.movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<AuthApiService>(
          create: (_) => widget.authApiService ?? AuthApiService(_publicClient),
        ),
        Provider<SignUpService>(
          create: (_) => widget.signUpService ?? SignUpService(_publicClient),
        ),
        Provider<MemberApiService>(
          create: (_) =>
              widget.memberApiService ?? MemberApiService(_authClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              widget.ratingApiService ??
              RatingApiService(_publicClient, _authClient),
        ),
        ChangeNotifierProvider<SessionRatingStore>(
          create: (_) => widget.sessionRatingStore ?? SessionRatingStore(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
            context.read<SessionRatingStore>(),
          ),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

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
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
