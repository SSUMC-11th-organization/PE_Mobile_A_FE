import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  static final _favoriteMoviePath = RegExp(r'^/v8/favorites/[1-9]\d*$');

  bool _isProtected(RequestOptions options) {
    if (options.uri.host != 'workbook.devnoco.com') return false;
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    final memberOrRating =
        path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');
    final favorites =
        (path == '/v8/favorites' && (method == 'GET' || method == 'POST')) ||
        (_favoriteMoviePath.hasMatch(path) &&
            (method == 'GET' || method == 'DELETE'));
    final movieRecord = path == '/v8/movie-records' && method == 'POST';

    return memberOrRating || favorites || movieRecord;
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
    options.headers.remove('Authorization');
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 서버 401과 기기 저장소 실패를 구분하기 위해 unknown으로 거절한다.
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
