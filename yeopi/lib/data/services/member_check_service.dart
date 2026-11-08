import 'package:dio/dio.dart';

import '../models/check_result.dart';

class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  // 닉네임·이메일은 path에 들어가므로 한글이나 @ 같은 문자를 인코딩해서 보냅니다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v5/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v5/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }
}
