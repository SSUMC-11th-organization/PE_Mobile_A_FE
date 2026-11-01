import 'package:flutter_dotenv/flutter_dotenv.dart';

/// `.env`의 TMDB 설정을 읽는 곳을 한 군데로 모은다.
abstract final class TmdbConfig {
  static const _accessTokenKey = 'TMDB_ACCESS_TOKEN';

  static String get accessToken {
    if (!dotenv.isInitialized) return '';
    return dotenv.maybeGet(_accessTokenKey)?.trim() ?? '';
  }

  static bool get hasAccessToken => accessToken.isNotEmpty;
}
