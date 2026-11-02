import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/tmdb_config.dart';
import 'tmdb_logging_interceptor.dart';

/// TMDB 전용 Dio. MovieLog 자체 API와 인증 방식이 달라 Client를 분리한다.
Dio createTmdbClient() {
  // 로그는 개발 중 확인 용도라 release 빌드에서는 출력하지 않는다.
  if (kDebugMode && !TmdbConfig.hasAccessToken) {
    debugPrint('[TMDB 설정] .env에 TMDB_ACCESS_TOKEN 값이 없습니다.');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer ${TmdbConfig.accessToken}',
        'accept': 'application/json',
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(TmdbLoggingInterceptor());
  }

  return dio;
}
