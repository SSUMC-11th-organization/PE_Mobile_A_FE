import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'api_logging_interceptor.dart';
import 'auth_interceptor.dart';

// 워크북 자체 백엔드 전용 Client입니다. TMDB와 baseUrl·인증 헤더가 달라서 절대 합치지 않습니다.
BaseOptions _movieLogOptions() => BaseOptions(
  baseUrl: 'https://workbook.devnoco.com',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
);

// 공개 요청용: 회원가입·중복 확인·로그인·유저별 평점 조회. 토큰을 붙이지 않습니다.
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());
  if (kDebugMode) dio.interceptors.add(ApiLoggingInterceptor('MovieLog'));
  return dio;
}

// 보호 요청용: 내 정보, 평점 등록·수정·삭제. AuthInterceptor가 Bearer 토큰을 붙입니다.
// 로그 Interceptor에서는 Authorization 값이 가려집니다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  if (kDebugMode) dio.interceptors.add(ApiLoggingInterceptor('MovieLog Auth'));
  return dio;
}
