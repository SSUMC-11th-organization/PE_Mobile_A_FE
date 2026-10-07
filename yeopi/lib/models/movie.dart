class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.posterAsset,
    required this.summary,
  });

  final int id;
  final String title;
  final String genre;
  final int year;
  final String posterAsset;
  final String summary;
}

// 홈·목록·상세가 모두 이 Mock Data를 읽어 같은 영화를 보여줍니다.
const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    year: 2024,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    summary: '작은 바닷가 마을에서 다시 만난 두 친구가 잊고 지낸 꿈을 되찾아 가는 이야기.',
  ),
  Movie(
    id: 2,
    title: '미션 임프로버블',
    genre: '액션',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    summary: '허세 가득한 스파이 맥스가 사상 최악의 임무에 휘말리며 벌어지는 좌충우돌 액션 코미디.',
  ),
  Movie(
    id: 3,
    title: '공허의 메아리',
    genre: 'SF',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    summary: '우주 끝에서 들려오는 신호를 해독하던 연구원이 자신의 과거와 마주한다.',
  ),
  Movie(
    id: 4,
    title: '네 번째 오후',
    genre: '드라마',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    summary: '매주 같은 카페에서 마주치는 네 사람의 조용하고 따뜻한 오후.',
  ),
  Movie(
    id: 5,
    title: '밤의 그림자',
    genre: '스릴러',
    year: 2022,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    summary: '도시의 불이 꺼진 밤, 사라진 목격자를 쫓는 형사의 하룻밤.',
  ),
  Movie(
    id: 6,
    title: '속삭이는 숲',
    genre: '판타지',
    year: 2022,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    summary: '숲의 목소리를 듣게 된 소녀가 사라진 동생을 찾아 떠나는 모험.',
  ),
];

const movieGenres = ['전체', '드라마', '액션', 'SF', '스릴러', '판타지'];

// 영화 평균 평점은 서버 대신 Mock 값으로 표시합니다.
const mockAverageRating = 4.5;

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
