import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
}

/// 공개 요청용(로그인, 회원가입, 중복 확인, 유저별 평점 조회). Interceptor가 없어 토큰이 붙지 않는다.
/// TMDB와 baseUrl·헤더가 다르므로 TMDB Client와 합치지 않는다.
Dio createMovieLogClient() {
  return Dio(_movieLogOptions());
}

/// 보호 요청용(내 정보, 평점 등록·수정·삭제). AuthInterceptor가 Bearer 토큰을 붙인다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  return dio;
}
