import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';

// v7에는 토큰 기반 '내 평점 목록 GET'이 없어 현재 세션에서 등록한 평점만 보관한다.
class SessionRatingStore extends ChangeNotifier {
  final List<RatingDto> _ratings = [];

  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  void add(RatingDto rating) {
    _ratings
      ..removeWhere((item) => item.ratingId == rating.ratingId)
      ..insert(0, rating);
    notifyListeners();
  }

  void replace(RatingDto rating) {
    final index = _ratings.indexWhere(
      (item) => item.ratingId == rating.ratingId,
    );
    if (index < 0) return;
    _ratings[index] = rating;
    notifyListeners();
  }

  void remove(int ratingId) {
    _ratings.removeWhere((item) => item.ratingId == ratingId);
    notifyListeners();
  }

  void clear() {
    if (_ratings.isEmpty) return;
    _ratings.clear();
    notifyListeners();
  }
}
