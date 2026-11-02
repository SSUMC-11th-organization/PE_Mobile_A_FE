import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/services/member_check_service.dart';

class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService({Set<String>? duplicatedValues})
    : duplicatedValues = duplicatedValues ?? {},
      super(Dio());

  final Set<String> duplicatedValues;
  bool failing = false;
  Completer<void>? pending;

  final List<String> nicknameCalls = [];
  final List<String> emailCalls = [];

  Future<bool> _respond(String value) async {
    final wait = pending;
    if (wait != null) await wait.future;
    if (failing) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v5/members'),
        type: DioExceptionType.connectionError,
      );
    }
    return !duplicatedValues.contains(value.trim());
  }

  @override
  Future<bool> checkNickname(String nickname) {
    nicknameCalls.add(nickname.trim());
    return _respond(nickname);
  }

  @override
  Future<bool> checkEmail(String email) {
    emailCalls.add(email.trim());
    return _respond(email);
  }
}
