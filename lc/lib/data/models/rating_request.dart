/// 서버 평점은 1~5 사이의 정수다. 반 점이나 범위 밖 값을 조용히 바꾸지 않고 막는다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// POST /v6/members/{memberId}/ratings 요청 body.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  /// 영화 배열의 index가 아니라 TMDB 영화 id(TmdbMovieDto.id)다.
  final int movieId;
  final int score;
  final String? comment;

  /// 등록 comment는 선택 항목이라 비어 있으면 키 자체를 생략한다.
  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}
