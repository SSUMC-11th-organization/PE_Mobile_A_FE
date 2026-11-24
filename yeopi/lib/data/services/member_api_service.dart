import 'package:dio/dio.dart';

import '../models/member_info.dart';

// 내 정보 API는 토큰으로 회원을 식별하므로 보호용 Client(AuthInterceptor 등록)로 보냅니다.
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v7/members/me');
    return parseMemberInfo(response.data);
  }

  // 성공 result가 수정된 최신 내 정보라 GET me를 다시 부르지 않습니다.
  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v7/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
