/// 평점 Dialog가 돌려주는 값. [movieId]는 배열 index가 아니라 TMDB 영화 id이며,
/// 이후 자체 백엔드에 평점을 저장할 때 그대로 movieId로 전달한다.
class RatingSubmission {
  const RatingSubmission({required this.movieId, required this.score});

  final int movieId;
  final double score;
}
