import 'package:flutter/foundation.dart';

/// 학습용 현재 회원. 인증이 아니라 가입 결과의 memberId를 메모리에 보관할 뿐이다.
class LearningMemberSession extends ChangeNotifier {
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