import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class TmdbConfig {
  static const _accessTokenKey = 'TMDB_ACCESS_TOKEN';

  static String get accessToken {
    if (!dotenv.isInitialized) return '';
    return dotenv.maybeGet(_accessTokenKey)?.trim() ?? '';
  }

  static bool get hasAccessToken => accessToken.isNotEmpty;
}
