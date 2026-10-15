import '../models/movie.dart';

const movieGenres = ['드라마', '로맨스', 'SF', '애니메이션', '판타지', '스릴러', '액션'];

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genres: ['드라마', '로맨스'],
    year: 2024,
    runtime: 124,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    rating: 4.5,
    ratingCount: 1245,
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 천문대에서 만나게 됩니다. '
        '매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '과거의 아픔으로 인해 사람에게 마음을 열지 못하던 여주인공은, 별자리처럼 변함없는 모습으로 자신을 기다려주는 '
        '남주인공을 통해 서서히 마음의 문을 열게 됩니다. 하지만 두 사람 앞에 놓인 현실적인 장벽들은 그들의 관계를 시험하게 되는데...\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 있을까요? '
        '눈부신 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 올 겨울 최고의 로맨스 영화.\n\n'
        '잔잔한 감동과 함께 삶의 의미를 다시 한번 되돌아보게 만드는 수작입니다.',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genres: ['SF'],
    year: 2024,
    runtime: 138,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    rating: 4.2,
    ratingCount: 892,
    tags: ['SF', '우주', '미스터리'],
    synopsis:
        '인류 최초로 태양계 끝에 도착한 탐사대원은 정체를 알 수 없는 거대한 구조물을 발견합니다. '
        '구조물에서 흘러나오는 신호를 해독할수록, 그는 지구에 남겨두고 온 기억과 마주하게 됩니다.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genres: ['애니메이션', '판타지'],
    year: 2023,
    runtime: 102,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    rating: 4.9,
    ratingCount: 2031,
    tags: ['애니메이션', '판타지', '힐링'],
    synopsis:
        '할머니 댁에 내려온 소녀는 뒷산 숲에서 속삭이는 작은 정령을 만납니다. '
        '사라져 가는 숲을 지키기 위해 소녀와 정령은 오래된 약속의 흔적을 따라 모험을 떠납니다.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genres: ['스릴러'],
    year: 2024,
    runtime: 115,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    rating: 3.8,
    ratingCount: 654,
    tags: ['스릴러', '누아르', '긴장감'],
    synopsis:
        '비 내리는 도심의 뒷골목, 연쇄 실종 사건을 쫓던 형사는 모든 사건 현장에 남겨진 같은 그림자를 발견합니다. '
        '진실에 가까워질수록 그림자는 점점 그를 향해 다가옵니다.',
  ),
  Movie(
    id: 5,
    title: '심연을 걷는 자',
    genres: ['액션', 'SF'],
    year: 2022,
    runtime: 131,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    rating: 4.0,
    ratingCount: 1103,
    tags: ['액션', 'SF', '모험'],
    synopsis:
        '심해 기지가 원인 모를 사고로 고립되자, 전직 구조대원은 마지막 생존자들을 구하기 위해 '
        '아무도 돌아오지 못한 심연 속으로 내려갑니다.',
  ),
  Movie(
    id: 6,
    title: '네 번째 오후',
    genres: ['드라마'],
    year: 2023,
    runtime: 108,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    rating: 4.3,
    ratingCount: 478,
    tags: ['드라마', '일상', '잔잔한'],
    synopsis:
        '매주 목요일 오후, 같은 카페 같은 자리에 앉는 두 사람. '
        '말 한마디 나누지 않던 그들의 네 번째 오후에 작은 변화가 찾아옵니다.',
  ),
];

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
