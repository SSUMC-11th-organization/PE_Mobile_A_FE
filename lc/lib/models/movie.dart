class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.posterAsset,
    required this.rating,
    required this.runtimeMinutes,
    required this.tags,
    required this.synopsis,
  });

  final int id;
  final String title;
  final String genre;
  final int year;
  final String posterAsset;
  final double rating;
  final int runtimeMinutes;
  final List<String> tags;

  /// 문단은 빈 줄('\n\n')로 구분한다.
  final String synopsis;

  List<String> get synopsisParagraphs => synopsis.split('\n\n');

  bool matchesAnyGenre(Set<String> genres) =>
      genres.contains(genre) || tags.any(genres.contains);
}

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    year: 2023,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    rating: 4.8,
    runtimeMinutes: 124,
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '과거의 아픔으로 인해 사람에게 마음을 열지 못하던 여주인공은, 별자리처럼 변함없는 모습으로 자신을 기다려주는 남주인공을 통해 서서히 마음의 문을 열게 됩니다. 하지만 두 사람 앞에 놓인 현실적인 장벽들은 그들의 관계를 시험하게 되는데...\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 있을까요? 눈부신 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 올 겨울 최고의 로맨스 영화.\n\n'
        '잔잔한 감동과 함께 삶의 의미를 다시 한번 되돌아보게 만드는 수작입니다.',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genre: 'SF',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    rating: 4.2,
    runtimeMinutes: 128,
    tags: ['SF', '모험', '미스터리'],
    synopsis: '신호가 끊긴 심우주 탐사선에서 들려오는 정체불명의 메아리를 따라가는 승무원들의 마지막 항해.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genre: '애니메이션',
    year: 2022,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    rating: 4.9,
    runtimeMinutes: 96,
    tags: ['애니메이션', '판타지', '힐링'],
    synopsis: '숲이 들려주는 속삭임을 알아듣는 소녀가 사라져 가는 숲의 비밀을 찾아 떠나는 모험.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genre: '스릴러',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    rating: 3.8,
    runtimeMinutes: 112,
    tags: ['스릴러', '미스터리', '범죄'],
    synopsis: '도시가 잠든 사이 벌어지는 연쇄 사건, 그림자처럼 따라붙는 누군가의 시선이 형사를 옥죄어 온다.',
  ),
  Movie(
    id: 5,
    title: '봄날의 커피',
    genre: '로맨스',
    year: 2021,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    rating: 4.5,
    runtimeMinutes: 108,
    tags: ['로맨스', '드라마', '힐링'],
    synopsis: '매주 같은 카페, 같은 시간에 마주치던 두 사람이 네 번째 오후에 처음으로 말을 건넨다.',
  ),
  Movie(
    id: 6,
    title: '심연을 걷는 자',
    genre: '스릴러',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    rating: 4.1,
    runtimeMinutes: 118,
    tags: ['스릴러', 'SF', '서바이벌'],
    synopsis: '깊은 바다 밑 폐쇄된 연구소에서 사라진 동료를 찾던 잠수부가 예상치 못한 진실과 마주한다.',
  ),
];

const allGenresLabel = '전체';

const movieGenres = ['드라마', 'SF', '애니메이션', '스릴러', '로맨스', '코미디', '판타지', '다큐멘터리'];

/// [genre]가 '전체'이거나 목록에 없는 값이면 필터링하지 않는다.
List<Movie> filterMoviesByGenre(List<Movie> source, String genre) {
  if (genre == allGenresLabel) return source;
  return source.where((movie) => movie.matchesAnyGenre({genre})).toList();
}

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
