import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/sign_up_service.dart';

class FakeSignUpService extends SignUpService {
  FakeSignUpService({Set<String>? duplicatedValues})
    : duplicatedValues = duplicatedValues ?? {},
      super(Dio());

  final Set<String> duplicatedValues;
  bool failing = false;
  Completer<void>? pending;

  final List<String> nicknameCalls = [];
  final List<String> emailCalls = [];
  int signUpCalls = 0;
  int? signUpFailStatus;
  String signUpFailMessage = '';
  Completer<void>? signUpPending;

  Future<bool> _respond(String value) async {
    final wait = pending;
    if (wait != null) await wait.future;
    if (failing) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v6/members'),
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

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls++;
    await signUpPending?.future;
    final status = signUpFailStatus;
    if (status != null) {
      final options = RequestOptions(path: '/v6/members');
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: {
            'isSuccess': false,
            'code': 'COMMON$status',
            'message': signUpFailMessage,
            'result': null,
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return CommonResponse(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입 성공',
      result: SignUpResult(
        memberId: 7,
        email: request.email,
        nickname: request.nickname,
      ),
    );
  }
}
