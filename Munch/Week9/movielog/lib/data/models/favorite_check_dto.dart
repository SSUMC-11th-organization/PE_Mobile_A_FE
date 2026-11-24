class FavoriteCheckDto {
  const FavoriteCheckDto({required this.movieId, required this.isFavorite});

  // 여부 조회 응답에는 movieId가 없어서 요청에 쓴 값을 따로 받는다.
  factory FavoriteCheckDto.fromJson(Object? json, {required int movieId}) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('FavoriteCheckDto must be a JSON object.');
    }
    final isFavorite = json['isFavorite'];
    if (isFavorite is! bool) {
      throw const FormatException('isFavorite must be a boolean.');
    }
    return FavoriteCheckDto(movieId: movieId, isFavorite: isFavorite);
  }

  final int movieId;
  final bool isFavorite;
}
