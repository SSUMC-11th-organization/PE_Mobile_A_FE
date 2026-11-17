import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/tmdb_config.dart';
import 'api_logging_interceptor.dart';

// 자체 API와 인증 방식이 달라서 TMDB 전용 Client를 따로 만듭니다.
Dio createTmdbClient() {
  if (kDebugMode && !TmdbConfig.hasAccessToken) {
    debugPrint('[TMDB] .env의 TMDB_ACCESS_TOKEN이 비어 있어요. 요청이 401로 실패합니다.');
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
    dio.interceptors.add(ApiLoggingInterceptor('TMDB'));
  }

  return dio;
}
