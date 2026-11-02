import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/tmdb_poster_image.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: Consumer<MyRatingsViewModel>(
          builder: (context, viewModel, child) {
            return switch (viewModel.status) {
              MyRatingsLoadStatus.idle ||
              MyRatingsLoadStatus.loading => const _RatingsLoading(),
              MyRatingsLoadStatus.empty => const _RatingsEmpty(),
              MyRatingsLoadStatus.error => _RatingsError(
                message: viewModel.message ?? '평점을 불러오지 못했습니다.',
                onRetry: viewModel.load,
              ),
              MyRatingsLoadStatus.success => _RatingsList(
                ratings: viewModel.ratings,
                notice: viewModel.message,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _RatingsLoading extends StatelessWidget {
  const _RatingsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.violet),
          SizedBox(height: 16),
          Text('평점을 불러오는 중입니다.', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _RatingsEmpty extends StatelessWidget {
  const _RatingsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: AppColors.gray),
          SizedBox(height: 12),
          Text('등록된 평점이 없습니다.', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _RatingsError extends StatelessWidget {
  const _RatingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.ratings, this.notice});

  final List<RatingWithMovie> ratings;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: ratings.length + (notice == null ? 0 : 1),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (notice != null) {
          if (index == 0) return _RatingsNotice(message: notice!);
          index--;
        }
        return RatingCard(entry: ratings[index]);
      },
    );
  }
}

class _RatingsNotice extends StatelessWidget {
  const _RatingsNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.entry});

  final RatingWithMovie entry;

  static const _posterWidth = 82.0;
  static const _posterHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.skeleton, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: _posterWidth,
              height: _posterHeight,
              size: 'w185',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 #${rating.movieId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '별점 ${rating.score} / 5',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.violet,
                    ),
                  ),
                  if (movie == null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '영화 정보 없음',
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.gray,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(rating.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}.${twoDigits(local.month)}.${twoDigits(local.day)} 등록';
  }
}
