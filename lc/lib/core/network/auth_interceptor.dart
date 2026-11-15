import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// MovieLog 보호 API(내 정보, 평점 등록·수정·삭제)에만 Bearer 토큰을 붙인다.
/// 다른 host나 공개 경로로 가는 요청에는 토큰을 보내지 않는다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  static const _host = 'workbook.devnoco.com';

  bool _isProtected(RequestOptions options) {
    final path = options.uri.path;
    return options.uri.host == _host &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }
    options.headers.remove('Authorization'); // 이전 요청의 토큰을 재사용하지 않는다.
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 서버의 401과 기기 저장소 실패는 다른 오류다. 요청을 보내지 않고 저장소 오류로 끝낸다.
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
