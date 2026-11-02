import 'package:dio/dio.dart';

import '../models/check_result.dart';

/// 회원가입 Form의 닉네임·이메일 중복 확인 (v5).
///
/// 서버가 정상 응답한 `available: false`는 반환값으로,
/// 통신 자체의 실패는 DioException으로 구분된다.
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

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
