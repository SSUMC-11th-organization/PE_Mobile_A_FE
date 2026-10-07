import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/movie_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_list.dart';
import '../widgets/movie_card.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, this.genre});

  final String? genre;

  @override
  Widget build(BuildContext context) {
    final selected = genre ?? '전체';
    final filtered = selected == '전체'
        ? movies
        : movies.where((movie) => movie.genre == selected).toList();

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        titleStyle: AppTextStyles.titleMedium.copyWith(
          color: AppColors.violet,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: AppColors.violet),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          GenreChipList(
            selected: selected,
            onSelected: (value) {
              final location = value == '전체'
                  ? '/movies'
                  : Uri(
                      path: '/movies',
                      queryParameters: {'genre': value},
                    ).toString();
              context.go(location);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '해당 장르의 영화가 없어요.',
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.62,
                    ),
                    itemBuilder: (context, index) {
                      final movie = filtered[index];
                      return MovieCard(
                        movie: movie,
                        showRatingBadge: true,
                        subtitle: '${movie.year} · ${movie.genre}',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}