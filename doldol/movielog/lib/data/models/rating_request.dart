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

  final int movieId; // TmdbMovieDto.id
  final int score;
  final String? comment;

  Map<String, dynamic> toJson() {
    final text = comment?.trim();

    return {
      'movieId': movieId,
      'score': score,
      // 코멘트는 선택 항목이라 비어 있으면 생략한다
      if (text != null && text.isNotEmpty) 'comment': text,
    };
  }
}