import 'package:flutter_dotenv/flutter_dotenv.dart';

// .env 키 문자열과 값 누락 검사를 이 파일 한 곳에서만 다룹니다.
abstract final class TmdbConfig {
  static const _accessTokenKey = 'TMDB_ACCESS_TOKEN';

  static String get accessToken {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[_accessTokenKey] ?? '';
  }

  static bool get hasAccessToken => accessToken.isNotEmpty;
}
