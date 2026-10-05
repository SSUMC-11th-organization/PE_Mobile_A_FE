import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_filter_sheet.dart';
import '../widgets/movie_card.dart';

/// 선택한 장르는 `/movies?genres=드라마,SF`처럼 Query Parameter로 관리한다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, required this.selectedGenres});

  final List<String> selectedGenres;

  static List<String> parseGenres(String? query) {
    if (query == null) return const [];
    return query.split(',').where(movieGenres.contains).toList();
  }

  static String location(List<String> genres) {
    if (genres.isEmpty) return '/movies';
    return Uri(
      path: '/movies',
      queryParameters: {'genres': genres.join(',')},
    ).toString();
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return GenreFilterSheet(
              initialGenres: selectedGenres,
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;
    context.go(location(result));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = selectedGenres.isEmpty
        ? movies
        : movies
              .where((movie) => movie.genres.any(selectedGenres.contains))
              .toList();

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(
            onPressed: () => _openFilterSheet(context),
            icon: Badge(
              isLabelVisible: selectedGenres.isNotEmpty,
              label: Text('${selectedGenres.length}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedGenres.isNotEmpty)
            _SelectedGenreBar(
              genres: selectedGenres,
              onRemoved: (genre) => context.go(
                location(selectedGenres.where((g) => g != genre).toList()),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '선택한 장르의 영화가 없어요.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.55,
                        ),
                    itemBuilder: (context, index) {
                      final movie = filtered[index];
                      return MovieCard(
                        movie: movie,
                        onTap: () => context.push('/movies/${movie.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SelectedGenreBar extends StatelessWidget {
  const _SelectedGenreBar({required this.genres, required this.onRemoved});

  final List<String> genres;
  final ValueChanged<String> onRemoved;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: genres.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          return InputChip(
            label: Text(genre),
            labelStyle: const TextStyle(
              color: AppColors.violet,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppColors.violet.withValues(alpha: 0.1),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onDeleted: () => onRemoved(genre),
          );
        },
      ),
    );
  }
}
