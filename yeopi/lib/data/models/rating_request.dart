// 위젯이 이미 정수 단위로 막아 주지만, 서버로 보내기 직전에 한 번 더 확인하는 안전장치입니다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  // 영화 배열 index가 아니라 TMDB 영화 id입니다.
  final int movieId;
  final int score;
  final String? comment;

  // 등록 comment는 선택 항목이라 비어 있으면 key 자체를 보내지 않습니다.
  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}
