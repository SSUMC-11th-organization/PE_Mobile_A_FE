import '../data/models/tmdb_movie_dto.dart';

/// DTO는 값만 담고, 화면에 보여주기 위한 변환은 여기서 한다.
extension TmdbMovieFormat on TmdbMovieDto {
  /// '2024-05-01' 같은 날짜에서 연도만 꺼낸다. 날짜가 없거나 형식이 달라도 null을 돌려준다.
  int? get releaseYear {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  /// TMDB 평점(0~10)을 MovieLog의 별 5개 기준(0~5)으로 바꾼다.
  double get ratingOutOfFive => voteAverage / 2;

  String get ratingLabel => ratingOutOfFive.toStringAsFixed(1);

  /// 장르 id를 이름으로 바꾼다. 이름을 모르는 id는 건너뛴다.
  List<String> genreNamesIn(Map<int, String> namesById) {
    return [
      for (final id in genreIds)
        if (namesById[id] != null) namesById[id]!,
    ];
  }
}
