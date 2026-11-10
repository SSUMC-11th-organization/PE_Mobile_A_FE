import 'package:flutter/foundation.dart';

// 회원가입 결과의 memberId를 메모리에만 보관하는 학습용 상태입니다.
// memberId를 안다고 인증된 것이 아니며, JWT 주차에 서버가 토큰으로 회원을 식별하도록 바뀝니다.
class LearningMemberSession extends ChangeNotifier {
  // 테스트에서 이미 가입한 상태를 만들 때만 memberId를 넘깁니다.
  LearningMemberSession([this._memberId]);

  int? _memberId;

  int? get memberId => _memberId;

  void setMemberId(int id) {
    _memberId = id;
    notifyListeners();
  }

  void clear() {
    _memberId = null;
    notifyListeners();
  }
}
