import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import 'auth_view_model.dart';

/// 현재 로그인 세션에서 등록한 평점을 메모리에 보관한다.
///
/// v7에는 토큰 기반 "내 평점 목록 GET"이 없고 로그인·내 정보 응답에도 memberId가 없다.
/// 그래서 등록 응답으로 받은 Rating만 이번 세션에서 수정·삭제할 수 있고,
/// 앱을 재시작하면 이전에 등록한 평점 목록은 복원되지 않는다. (API 계약의 한계)
/// 로그아웃·만료·회원 전환으로 세션이 바뀌면 이전 세션의 평점을 비운다.
class SessionRatingStore extends ChangeNotifier {
  SessionRatingStore(this._auth) : _sessionVersion = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _sessionVersion;
  final List<RatingDto> _ratings = [];

  /// 최근에 등록한 평점이 앞에 온다.
  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  void _onAuthChanged() {
    if (_auth.sessionVersion == _sessionVersion) return;
    _sessionVersion = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings.clear();
    notifyListeners();
  }

  void add(RatingDto rating) {
    _ratings.removeWhere((r) => r.ratingId == rating.ratingId);
    _ratings.insert(0, rating);
    notifyListeners();
  }

  /// 수정 응답의 Rating으로 같은 ratingId의 항목을 교체한다.
  void replace(RatingDto rating) {
    final index = _ratings.indexWhere((r) => r.ratingId == rating.ratingId);
    if (index < 0) return;
    _ratings[index] = rating;
    notifyListeners();
  }

  void remove(int ratingId) {
    final before = _ratings.length;
    _ratings.removeWhere((r) => r.ratingId == ratingId);
    if (_ratings.length != before) notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
