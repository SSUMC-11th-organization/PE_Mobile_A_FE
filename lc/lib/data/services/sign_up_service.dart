import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입과 닉네임·이메일 중복 확인 요청만 담당한다. 확인 메서드는 true면 사용할 수 있는 값이다.
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  /// 성공 응답은 직접 객체({ "available": true })이고, 오류만 공통 응답 형식이다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(
      response.data as Map<String, dynamic>,
    ).available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(
      response.data as Map<String, dynamic>,
    ).available;
  }

  /// 성공(201)은 `CommonResponse<SignUpResult>`다. 중복 확인 직후에도 다른 사람이 먼저
  /// 가입할 수 있으므로 이 요청의 409가 최종 중복 결과다.
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 서버 message에 이미 사용자에게 보여줄 문장이 들어 있으므로 문구를 새로 만들지 않고 그대로 쓴다.
String writeSignUpErrorMessage(DioException error) {
  return readServerMessage(error) ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
