import 'package:flutter/foundation.dart';

/// 학습용 "현재 회원" 상태. 회원가입 성공 응답의 memberId를 보관해 평점 요청 path에 쓴다.
///
/// 메모리에만 있으므로 앱을 재시작하면 사라진다. memberId를 안다는 것은 인증이 아니다.
/// JWT 주차에서는 보호 요청에서 memberId path를 없애고 서버가 토큰으로 회원을 식별한다.
class LearningMemberSession extends ChangeNotifier {
  LearningMemberSession([this.memberId]);

  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}
