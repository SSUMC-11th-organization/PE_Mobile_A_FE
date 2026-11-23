import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_list_item.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_row_card.dart';
import '../widgets/movielog_button.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Future<void> _open(FavoritesViewModel vm, TmdbMovieDto movie) async {
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    await vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 즐겨찾기',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: Consumer<FavoritesViewModel>(
          builder: (context, vm, _) {
            return switch (vm.phase) {
              LoadPhase.idle || LoadPhase.loading => const Center(
                child: CircularProgressIndicator(color: AppColors.violet),
              ),
              LoadPhase.empty => const _FavoritesEmpty(),
              LoadPhase.error => _FavoritesError(
                message: vm.errorMessage ?? '즐겨찾기를 불러오지 못했습니다.',
                onRetry: vm.refresh,
              ),
              LoadPhase.ready => RefreshIndicator(
                color: AppColors.violet,
                onRefresh: vm.refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  itemCount: vm.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = vm.items[index];
                    return _FavoriteCard(
                      key: ValueKey(item.favorite.favoriteId),
                      item: item,
                      onOpen: (movie) => _open(vm, movie),
                      onRetry: () => vm.retryMovie(item.favorite.movieId),
                    );
                  },
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onRetry,
  });

  final FavoriteListItem item;
  final ValueChanged<TmdbMovieDto> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final movie = item.movie;

    if (movie == null) {
      return MovieRowCard(
        title: '영화 #${item.favorite.movieId}',
        posterPath: null,
        subtitle: '영화 정보를 불러오지 못했습니다.',
        caption: '즐겨찾기한 영화',
        action: Align(
          alignment: Alignment.centerLeft,
          child: item.isRetrying
              ? const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.violet,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.violet,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('정보 다시 불러오기'),
                ),
        ),
      );
    }

    return MovieRowCard(
      title: movie.title,
      posterPath: movie.posterPath,
      subtitle: releaseYearOf(movie.releaseDate),
      caption: '즐겨찾기한 영화',
      onTap: () => onOpen(movie),
    );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 40, color: AppColors.violet),
          SizedBox(height: 16),
          Text('아직 즐겨찾기한 영화가 없습니다.', style: AppTextStyles.titleMedium),
          SizedBox(height: 8),
          Text('영화 상세에서 북마크를 눌러보세요.', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: AppTextStyles.titleMedium),
          const SizedBox(height: 20),
          MovieLogButton(label: '다시 시도', width: 220, onPressed: onRetry),
        ],
      ),
    );
  }
}
