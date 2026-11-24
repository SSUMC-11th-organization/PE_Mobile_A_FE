class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  // AuthSessionBridge만 호출한다. 같은 계정이어도 토큰이 새로 발급되면 새 세션이다.
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
