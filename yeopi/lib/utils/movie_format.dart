import '../data/models/tmdb_movie_dto.dart';

// release_date가 null이거나 빈 문자열이면 연도를 표시하지 않습니다.
String? releaseYear(TmdbMovieDto movie) {
  final date = movie.releaseDate;
  if (date == null || date.length < 4) return null;
  return date.substring(0, 4);
}

String movieMetaLabel(TmdbMovieDto movie) {
  final rating = '★ ${movie.voteAverage.toStringAsFixed(1)}';
  final year = releaseYear(movie);
  return year == null ? rating : '$year · $rating';
}

// 서버의 UTC 시각을 기기 시간대로 바꿔 2026.09.06 형식으로 보여줍니다.
String formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}
