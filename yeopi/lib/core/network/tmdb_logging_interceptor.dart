import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// TMDB Client를 거치는 모든 요청·응답·오류를 같은 형식으로 기록합니다.
class TmdbLoggingInterceptor extends Interceptor {
  static const _maxBodyLength = 800;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }
    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[TMDB 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[TMDB 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    // 페이지 응답 전체를 찍으면 콘솔이 밀리므로 응답 모양을 볼 수 있는 앞부분만 남깁니다.
    final body = '${response.data}';
    debugPrint(
      '[TMDB 응답 Body] ${body.length > _maxBodyLength ? '${body.substring(0, _maxBodyLength)}…(생략)' : body}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[TMDB 오류] ${err.response?.statusCode ?? '-'} ${err.requestOptions.uri}',
    );
    debugPrint('[TMDB 오류 내용] ${err.type.name} ${err.message}');
    handler.next(err);
  }
}
