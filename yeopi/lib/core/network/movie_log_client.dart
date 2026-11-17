import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_logging_interceptor.dart';

// 워크북 자체 백엔드 전용 Client입니다. TMDB와 baseUrl·인증 헤더가 달라서 절대 합치지 않습니다.
Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(ApiLoggingInterceptor('MovieLog'));
  }

  return dio;
}
