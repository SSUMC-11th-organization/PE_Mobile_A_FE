import 'package:flutter/foundation.dart';

import 'session_guard.dart';

// 인증 상태의 기준은 AuthViewModel이고, 이 클래스는 변화를 SessionGuard에 전달만 한다.
class AuthSessionBridge {
  AuthSessionBridge({
    required this.authSignals,
    required this.sessionVersion,
    required this.verifiedEmail,
  }) {
    authSignals.addListener(_sync);
    _sync();
  }

  final Listenable authSignals;
  final int Function() sessionVersion;
  final String? Function() verifiedEmail;
  final guard = SessionGuard();
  int? _seenVersion;
  String? _seenEmail;
  bool _disposed = false;

  void _sync() {
    if (_disposed) return;
    final version = sessionVersion();
    final email = verifiedEmail();
    if (version == _seenVersion && email == _seenEmail) return;
    _seenVersion = version;
    _seenEmail = email;
    guard.invalidate();
    if (email != null) guard.startSession(email);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    authSignals.removeListener(_sync);
    guard.invalidate();
  }
}
