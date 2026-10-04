import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/featured_movie_banner.dart';
import '../widgets/movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;
    final others = movies.skip(1).toList();

    return Scaffold(
      appBar: const CommonAppBar(title: 'MovieLog'),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FeaturedMovieBanner(movie: featured),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('지금 인기 있는 영화', style: AppTextStyles.titleMedium),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: others.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  SizedBox(width: 130, child: MovieCard(movie: others[index])),
            ),
          ),
        ],
      ),
    );
  }
}
