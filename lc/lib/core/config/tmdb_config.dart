import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env에 저장한 TMDB 설정을 읽는 한 곳. 키 문자열을 여러 파일에 흩뿌리지 않는다.
abstract final class TmdbConfig {
  static const accessTokenKey = 'TMDB_ACCESS_TOKEN';

  static String get accessToken => dotenv.env[accessTokenKey] ?? '';
}
