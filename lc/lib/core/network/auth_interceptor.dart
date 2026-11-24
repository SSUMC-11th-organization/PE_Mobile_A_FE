import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// MovieLog 보호 API(내 정보, 평점 등록·수정·삭제, 즐겨찾기)에만 Bearer 토큰을 붙인다.
/// 다른 host나 공개 경로로 가는 요청에는 토큰을 보내지 않는다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  static const _host = 'workbook.devnoco.com';

  /// 보호 요청(JWT를 붙일 요청)인지 판단한다.
  bool _isProtected(RequestOptions options) {
    // MovieLog 서버가 아닌 곳(TMDB 등)에는 JWT를 붙이지 않는다.
    if (options.uri.host != _host) return false;
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    // 8주차의 경로. 로그인·회원가입·중복 확인·유저별 평점 조회는 보호 요청이 아니다.
    final authProtected =
        path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');

    // 즐겨찾기: 등록(POST)·목록(GET) / 여부 조회(GET)·해제(DELETE)
    final favorites =
        (path == '/v8/favorites' && (method == 'GET' || method == 'POST')) ||
        (RegExp(r'^/v8/favorites/[1-9]\d*$').hasMatch(path) &&
            (method == 'GET' || method == 'DELETE'));

    // 영화 기록 저장(평점 + 즐겨찾기 한 번에)
    final movieRecord = path == '/v8/movie-records' && method == 'POST';

    return authProtected || favorites || movieRecord;
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
