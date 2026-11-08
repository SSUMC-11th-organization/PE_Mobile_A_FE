import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/movie_format.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movielog_button.dart';
import '../widgets/tmdb_poster_image.dart';

// root Navigator 위에 열리는 자식 화면이라 하단 NavigationBar가 없습니다.
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
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) => switch (viewModel.status) {
          MyRatingsLoadStatus.idle || MyRatingsLoadStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          MyRatingsLoadStatus.error => _MyRatingsError(
            message: viewModel.message ?? '평점을 불러오지 못했습니다.',
            onRetry: () => context.read<MyRatingsViewModel>().load(),
          ),
          MyRatingsLoadStatus.empty => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: MovieListEmpty(message: '아직 등록한 평점이 없어요.'),
            ),
          ),
          MyRatingsLoadStatus.success => _RatingList(
            entries: viewModel.ratings,
            memberId: viewModel.memberId,
            notice: viewModel.message,
          ),
        },
      ),
    );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({
    required this.entries,
    required this.memberId,
    required this.notice,
  });

  final List<RatingWithMovie> entries;
  final int memberId;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 로그인 기능이 없으므로 '내 평점'이 아니라 학습용 회원의 공개 평점이라고 안내합니다.
              Text(
                '학습용 회원(memberId $memberId)의 공개 평점 ${entries.length}개',
                style: AppTextStyles.bodySmall,
              ),
              if (notice != null) ...[
                const SizedBox(height: 4),
                Text(
                  notice!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          );
        }
        return _RatingCard(entry: entries[index - 1]);
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 64,
              height: 96,
              size: 'w185',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 정보를 불러오지 못했어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: movie == null ? AppColors.gray : null,
                  ),
                ),
                // 영화 정보가 없어도 어떤 영화의 평점인지 알 수 있도록 movieId를 남깁니다.
                if (movie == null)
                  Text(
                    'movieId ${rating.movieId}',
                    style: AppTextStyles.bodySmall,
                  ),
                const SizedBox(height: 6),
                RatingBarIndicator(
                  rating: rating.score.toDouble(),
                  itemCount: 5,
                  itemSize: 18,
                  itemBuilder: (context, index) =>
                      const Icon(Icons.star, color: Colors.amber),
                ),
                if (comment != null) ...[
                  const SizedBox(height: 6),
                  Text(comment, style: AppTextStyles.bodyMedium),
                ],
                const SizedBox(height: 6),
                Text(
                  formatDate(rating.createdAt),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRatingsError extends StatelessWidget {
  const _MyRatingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
            // 고정 너비 예시: 문구 길이와 관계없이 항상 120으로 그립니다.
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
