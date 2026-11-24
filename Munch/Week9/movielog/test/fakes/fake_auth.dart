import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/storage/saved_email_storage.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';

DioException apiError(int status, String code, {String message = 'x'}) {
  final options = RequestOptions(path: '/v8');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'isSuccess': false,
        'code': code,
        'message': message,
        'result': null,
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

DioException connectionError() => DioException(
  requestOptions: RequestOptions(path: '/v8'),
  type: DioExceptionType.connectionError,
);

MemberInfo memberFixture({String nickname = '무비러버'}) => MemberInfo(
  email: 'movie@example.com',
  nickname: nickname,
  createdAt: DateTime(2026, 10, 10, 12),
);

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;
  Object? readError;

  @override
  Future<void> saveAccessToken(String token) async => this.token = token;

  @override
  Future<String?> readAccessToken() async {
    final error = readError;
    if (error != null) throw error;
    return token;
  }

  @override
  Future<void> deleteAccessToken() async => token = null;
}

class FakeSavedEmailStorage implements SavedEmailStorage {
  FakeSavedEmailStorage([this.email]);

  String? email;

  @override
  Future<String?> read() async => email;

  @override
  Future<void> save(String email) async => this.email = email;

  @override
  Future<void> clear() async => email = null;
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(Dio());

  DioException? failure;
  Completer<void>? pending;
  final requests = <LoginRequest>[];

  @override
  Future<LoginResult> login(LoginRequest request) async {
    requests.add(request);
    await pending?.future;
    final error = failure;
    if (error != null) throw error;
    return const LoginResult(nickname: '무비러버', accessToken: 'test-token');
  }
}

class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService({MemberInfo? member})
    : member = member ?? memberFixture(),
      super(Dio());

  MemberInfo member;
  DioException? fetchFailure;
  DioException? updateFailure;
  Completer<void>? fetchPending;
  int fetchCalls = 0;
  final nicknameUpdates = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCalls++;
    await fetchPending?.future;
    final error = fetchFailure;
    if (error != null) throw error;
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    nicknameUpdates.add(nickname);
    final error = updateFailure;
    if (error != null) throw error;
    member = MemberInfo(
      email: member.email,
      nickname: nickname,
      createdAt: member.createdAt,
    );
    return member;
  }
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).last));

String currentPath(WidgetTester tester) =>
    routerOf(tester).routerDelegate.currentConfiguration.last.matchedLocation;
