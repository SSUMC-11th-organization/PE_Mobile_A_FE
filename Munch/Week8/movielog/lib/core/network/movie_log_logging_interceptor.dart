import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class MovieLogLoggingInterceptor extends Interceptor {
  static const _masked = '***';
  static const _sensitiveKeys = {'password', 'accessToken'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[MovieLog 요청] ${options.method} ${options.uri}');
    debugPrint('[MovieLog 요청 Header] ${_maskHeaders(options.headers)}');
    if (options.data != null) {
      debugPrint('[MovieLog 요청 Body] ${_maskBody(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[MovieLog 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    debugPrint('[MovieLog 응답 Body] ${_maskBody(response.data)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[MovieLog 오류] ${err.requestOptions.method} ${err.requestOptions.uri}',
    );
    debugPrint(
      '[MovieLog 오류 Header] ${_maskHeaders(err.requestOptions.headers)}',
    );
    debugPrint(
      '[MovieLog 오류 Status] ${err.response?.statusCode ?? err.type.name}',
    );
    if (err.response?.data != null) {
      debugPrint('[MovieLog 오류 Body] ${_maskBody(err.response?.data)}');
    }
    handler.next(err);
  }

  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: entry.key.toLowerCase() == 'authorization'
            ? 'Bearer $_masked'
            : entry.value,
    };
  }

  Object? _maskBody(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _sensitiveKeys.contains(entry.key)
              ? _masked
              : _maskBody(entry.value),
      };
    }
    if (data is List) return data.map(_maskBody).toList();
    return data;
  }
}
