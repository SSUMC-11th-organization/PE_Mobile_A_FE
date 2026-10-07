import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'movie_card.dart';

// 영화 목록 Success 상태의 포스터 Grid입니다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // 결과가 적어도 당겨서 새로고침이 동작하도록 항상 스크롤 가능하게 둡니다.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: movies.length,
      gridDelegate: movieGridDelegate,
      itemBuilder: (context, index) => MovieCard(movie: movies[index]),
    );
  }
}

// Skeleton Loading도 같은 배치를 써서 로딩 전후 화면이 흔들리지 않게 합니다.
const movieGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 16,
  childAspectRatio: 0.6,
);
