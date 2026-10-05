class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.year,
    required this.runtime,
    required this.posterAsset,
    required this.rating,
    required this.ratingCount,
    required this.tags,
    required this.synopsis,
  });

  final int id;
  final String title;
  final List<String> genres;
  final int year;
  final int runtime;
  final String posterAsset;
  final double rating;
  final int ratingCount;
  final List<String> tags;
  final String synopsis;
}
