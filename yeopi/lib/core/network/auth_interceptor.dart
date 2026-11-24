import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

// 보호 API(내 정보, 평점 등록·수정·삭제)에만 MovieLog JWT를 붙입니다.
// 보호용 Client에만 등록하고, host·path도 다시 확인해서 다른 서버로 토큰이 새지 않게 합니다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  static const movieLogHost = 'workbook.devnoco.com';
  final TokenStorage _storage;

  static bool isProtected(Uri uri) {
    final path = uri.path;
    return uri.host == movieLogHost &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 이전 요청에 남은 토큰을 재사용하지 않도록 매번 지우고 다시 읽습니다.
    options.headers.remove('Authorization');
    if (!isProtected(options.uri)) {
      handler.next(options);
      return;
    }
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 기기 저장소를 읽지 못한 것은 서버 401과 다른 오류라 별도 예외로 넘깁니다.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
