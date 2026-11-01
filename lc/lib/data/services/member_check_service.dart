import 'package:dio/dio.dart';

import '../models/check_result.dart';

/// 닉네임·이메일 중복 확인 요청만 담당한다. true면 사용할 수 있는 값이다.
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v5/members/nickname/$encoded');
    return CheckResult.fromJson(
      response.data as Map<String, dynamic>,
    ).available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v5/members/email/$encoded');
    return CheckResult.fromJson(
      response.data as Map<String, dynamic>,
    ).available;
  }
}
