class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.genreLabel,
    required this.year,
    required this.runtime,
    required this.rating,
    required this.ratingCount,
    required this.tags,
    required this.synopsis,
    required this.posterAsset,
  });

  final int id;
  final String title;
  final String genre; // 목록 필터에 쓰는 대표 장르
  final String genreLabel; // 상세 화면에 표시하는 장르 문구
  final int year;
  final int runtime;
  final double rating;
  final int ratingCount;
  final List<String> tags;
  final String synopsis;
  final String posterAsset;
}

const genres = ['전체', '드라마', 'SF', '애니메이션', '스릴러', '로맨스', '다큐멘터리'];

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    genreLabel: '로맨스/드라마',
    year: 2024,
    runtime: 124,
    rating: 4.5,
    ratingCount: 1245,
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n별이 쏟아지는 밤하늘 아래 나누는 약속은 과연 영원할 수 있을까요? 눈부신 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 올 겨울 최고의 로맨스 영화.',
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genre: 'SF',
    genreLabel: 'SF/모험',
    year: 2024,
    runtime: 138,
    rating: 4.2,
    ratingCount: 982,
    tags: ['SF', '모험', '우주'],
    synopsis: '지구를 떠난 탐사대가 우주의 끝에서 마주한 거대한 비밀을 풀어가는 SF 어드벤처입니다.',
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genre: '애니메이션',
    genreLabel: '애니메이션/판타지',
    year: 2022,
    runtime: 102,
    rating: 4.5,
    ratingCount: 764,
    tags: ['애니메이션', '판타지', '힐링'],
    synopsis: '잃어버린 기억을 찾아 숲속을 여행하는 소녀와 신비로운 친구들의 따뜻한 이야기입니다.',
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genre: '스릴러',
    genreLabel: '스릴러/범죄',
    year: 2025,
    runtime: 116,
    rating: 3.8,
    ratingCount: 530,
    tags: ['스릴러', '범죄', '긴장감'],
    synopsis: '도시의 밤마다 벌어지는 의문의 사건을 쫓던 형사가 믿기 힘든 진실과 마주하게 됩니다.',
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
  ),
  Movie(
    id: 5,
    title: '봄날의 커피',
    genre: '로맨스',
    genreLabel: '로맨스/일상',
    year: 2021,
    runtime: 109,
    rating: 4.5,
    ratingCount: 688,
    tags: ['로맨스', '일상', '따뜻한'],
    synopsis: '작은 동네 카페에서 시작된 두 사람의 느리지만 다정한 사랑 이야기입니다.',
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
  ),
  Movie(
    id: 6,
    title: '도시의 섬',
    genre: '다큐멘터리',
    genreLabel: '다큐멘터리',
    year: 2023,
    runtime: 95,
    rating: 4.1,
    ratingCount: 301,
    tags: ['다큐멘터리', '건축', '도시'],
    synopsis: '빌딩 숲 한가운데 자리 잡은 작은 공간들을 통해 도시의 삶을 들여다보는 다큐멘터리입니다.',
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
  ),
];

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}

// 평점 높은 순 상위 5개 (홈의 인기 영화)
List<Movie> get popularMovies {
  final sorted = [...movies]..sort((a, b) => b.rating.compareTo(a.rating));
  return sorted.take(5).toList();
}