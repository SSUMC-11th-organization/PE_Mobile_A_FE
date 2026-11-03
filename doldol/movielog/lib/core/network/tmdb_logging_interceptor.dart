import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TmdbLoggingInterceptor extends Interceptor {
  // 응답 본문은 길어서 앞부분만 출력
  static const _maxBodyLength = 300;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 원본 헤더를 복사한 뒤 Authorization만 가려서 출력
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }

    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[TMDB 요청 Query] ${options.queryParameters}');
    }

    handler.next(options); // 요청을 다음 단계로 통과시킨다
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data.toString();
    final shortBody = body.length > _maxBodyLength
        ? '${body.substring(0, _maxBodyLength)}...'
        : body;

    debugPrint(
      '[TMDB 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    debugPrint('[TMDB 응답 Body] $shortBody');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[TMDB 오류] ${err.requestOptions.uri}');
    debugPrint('[TMDB 오류 내용] ${err.message}');

    handler.next(err);
  }
}