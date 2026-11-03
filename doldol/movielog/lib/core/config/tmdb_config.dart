import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class TmdbConfig {
  /// .env의 TMDB_ACCESS_TOKEN 값. 없으면 빈 문자열
  static String get accessToken => dotenv.env['TMDB_ACCESS_TOKEN'] ?? '';

  /// 토큰이 설정돼 있는지 확인 (값 자체는 출력하지 않는다)
  static bool get hasToken => accessToken.isNotEmpty;
}