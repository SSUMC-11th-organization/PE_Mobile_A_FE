import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 모든 TMDB 요청/응답/오류를 같은 형식으로 기록한다. Authorization 원문은 남기지 않는다.
class TmdbLoggingInterceptor extends Interceptor {
  static const _maskedAuthorization = 'Bearer ***';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] ${_maskHeaders(options.headers)}');
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
    debugPrint('[TMDB 응답 Body] ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[TMDB 오류] ${err.requestOptions.method} ${err.requestOptions.uri}',
    );
    debugPrint('[TMDB 오류 Header] ${_maskHeaders(err.requestOptions.headers)}');
    debugPrint('[TMDB 오류 종류] ${err.type.name}');
    if (err.response != null) {
      debugPrint('[TMDB 오류 Status] ${err.response?.statusCode}');
      debugPrint('[TMDB 오류 Body] ${err.response?.data}');
    }
    debugPrint('[TMDB 오류 내용] ${err.message ?? err.error}');
    handler.next(err);
  }

  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: entry.key.toLowerCase() == 'authorization'
            ? _maskedAuthorization
            : entry.value,
    };
  }
}
