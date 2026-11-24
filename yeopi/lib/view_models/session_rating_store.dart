import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import 'auth_view_model.dart';

// 이번 로그인 세션에서 등록 응답으로 받은 평점만 메모리에 보관합니다.
// v7에는 토큰 기반 '내 평점 목록 GET'이 없고 로그인·내 정보 응답에 memberId도 없어서,
// 앱을 다시 켜면 기존 평점 전체를 복원할 수 없습니다. (명세 확인 전까지 완료 기능으로 표시하지 않습니다.)
class SessionRatingStore extends ChangeNotifier {
  SessionRatingStore(this._auth) : _version = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _version;
  final List<RatingDto> _ratings = [];

  // 최근에 등록한 평점이 위로 오게 보여줍니다.
  List<RatingDto> get ratings => List.unmodifiable(_ratings.reversed);

  // 로그아웃·만료·다른 계정 로그인으로 세션이 바뀌면 이전 회원의 평점을 비웁니다.
  void _onAuthChanged() {
    if (_auth.sessionVersion == _version) return;
    _version = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings.clear();
    notifyListeners();
  }

  // 요청을 시작한 세션이 지금 세션과 다르면(늦게 온 응답) 반영하지 않습니다.
  bool _accepts(int version) => version == _version;

  void add(RatingDto rating, {required int version}) {
    if (!_accepts(version)) return;
    _ratings.removeWhere((r) => r.ratingId == rating.ratingId);
    _ratings.add(rating);
    notifyListeners();
  }

  void replace(RatingDto rating, {required int version}) {
    if (!_accepts(version)) return;
    final index = _ratings.indexWhere((r) => r.ratingId == rating.ratingId);
    if (index < 0) return;
    _ratings[index] = rating;
    notifyListeners();
  }

  void remove(int ratingId, {required int version}) {
    if (!_accepts(version)) return;
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
