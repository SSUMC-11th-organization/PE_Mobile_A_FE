import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import 'fake_auth.dart';
import 'fake_favorite_api_service.dart';
import 'fake_rating_api_service.dart';
import 'fake_sign_up_service.dart';
import 'fake_tmdb_movie_service.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  FakeTmdbMovieService? movieService,
  FakeSignUpService? signUpService,
  FakeRatingApiService? ratingService,
  FakeFavoriteApiService? favoriteService,
  FakeAuthApiService? authService,
  FakeMemberApiService? memberService,
  InMemoryTokenStorage? tokenStorage,
  FakeSavedEmailStorage? savedEmailStorage,
  SessionRatingStore? sessionRatingStore,
  bool signedIn = true,
  String? location,
}) async {
  await tester.pumpWidget(
    MovieLogApp(
      movieService: movieService ?? FakeTmdbMovieService(),
      signUpService: signUpService ?? FakeSignUpService(),
      ratingApiService: ratingService ?? FakeRatingApiService(),
      favoriteApiService: favoriteService ?? FakeFavoriteApiService(),
      authApiService: authService ?? FakeAuthApiService(),
      memberApiService: memberService ?? FakeMemberApiService(),
      tokenStorage:
          tokenStorage ?? InMemoryTokenStorage(signedIn ? 'saved-token' : null),
      savedEmailStorage: savedEmailStorage ?? FakeSavedEmailStorage(),
      sessionRatingStore: sessionRatingStore,
    ),
  );
  await tester.pumpAndSettle();
  if (location != null) {
    routerOf(tester).go(location);
    await tester.pumpAndSettle();
  }
}
