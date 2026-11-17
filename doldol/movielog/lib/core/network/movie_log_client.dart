import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 워크북 자체 백엔드 전용 Dio (TMDB Client와 절대 합치지 않는다)
Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // 트러블슈팅용 요청/응답 로그 (디버그 모드에서만)
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  return dio;
}