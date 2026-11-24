/// 즐겨찾기 한 건. 제목·포스터는 없고 TMDB 영화 id(movieId)만 있다.
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('FavoriteResponseDto must be a JSON object.');
    }
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;

  /// TMDB 영화 id. 해제·여부 조회 경로에는 favoriteId가 아니라 이 값을 쓴다.
  final int movieId;
  final DateTime createdAt;
}
