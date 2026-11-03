import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// TMDB 요청·응답·오류를 한 곳에서 기록한다. 기록만 하고 화면에 표시하지는 않는다.
/// Authorization 같은 민감한 값은 원문으로 남기지 않는다.
class TmdbLoggingInterceptor extends Interceptor {
  static const _maxBodyLength = 800;

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
    debugPrint('[TMDB 응답 Body] ${_shorten('${response.data}')}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[TMDB 오류] ${err.response?.statusCode ?? '-'} ${err.requestOptions.uri}',
    );
    debugPrint('[TMDB 오류 내용] ${err.message}');
    handler.next(err);
  }

  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: entry.key.toLowerCase() == 'authorization'
            ? 'Bearer ***'
            : entry.value,
    };
  }

  String _shorten(String body) {
    if (body.length <= _maxBodyLength) return body;
    return '${body.substring(0, _maxBodyLength)}… (총 ${body.length}자)';
  }
}
