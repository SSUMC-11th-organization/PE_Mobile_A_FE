import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class StubHttpAdapter implements HttpClientAdapter {
  StubHttpAdapter(this.handler);

  final (int, Object?) Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio stubDio((int, Object?) Function(RequestOptions options) handler) {
  return Dio(BaseOptions(baseUrl: 'https://stub.test'))
    ..httpClientAdapter = StubHttpAdapter(handler);
}
