/// "지금 도착한 응답이 현재 로그인 세션의 것인지"를 판정한다.
///
/// 사용자별 데이터(즐겨찾기 등)를 요청할 때 [generation]과 계정을 기억해 두었다가,
/// 응답이 도착했을 때 [isCurrent]가 true일 때만 화면 상태에 반영한다.
/// 로그아웃·만료·계정 전환 뒤에 늦게 도착한 이전 세션의 응답을 버리기 위한 장치다.
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  /// 인증 쪽(AuthSessionBridge)이 검증된 새 세션을 시작할 때만 호출한다.
  /// 화면이나 ViewModel에서 호출하지 않고, build마다 호출하지도 않는다.
  /// 같은 계정이라도 토큰이 새로 발급되면 새 세션이다.
  int startSession(String accountId) {
    _accountId = accountId;
    return ++_generation;
  }

  void invalidate() {
    _accountId = null;
    _generation++;
  }

  bool isCurrent(int generation, String accountId) =>
      _generation == generation && _accountId == accountId;
}
