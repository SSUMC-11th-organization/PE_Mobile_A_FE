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
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

// root Navigator 위에 열리는 자식 화면이라 하단 NavigationBar가 없습니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final count = viewModel.selectedRatingIds.length;
    // 다중 삭제는 확인 Dialog를 먼저 닫고, 진행 상황은 화면 위 LoadingOverlay로 보여줍니다.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('선택한 평점 $count개를 삭제할까요?'),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final failed = await viewModel.deleteSelectedRatings();
    if (!context.mounted) return;
    _showSnackBar(
      context,
      failed == 0
          ? '선택한 평점 $count개를 삭제했습니다.'
          : '$count개 중 $failed개를 삭제하지 못했습니다. 실패한 항목은 선택된 채로 남겨 두었습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();
    final selectedCount = viewModel.selectedRatingIds.length;
    final hasRatings = viewModel.status == MyRatingsLoadStatus.success;

    // 다중 삭제 중에는 뒤로가기로 화면을 벗어나지 못하게 막습니다.
    return PopScope(
      canPop: !viewModel.isDeletingSelected,
      child: LoadingOverlay(
        isLoading: viewModel.isDeletingSelected,
        child: Scaffold(
          appBar: CommonAppBar(
            title: viewModel.isEditing ? '$selectedCount개 선택' : '내가 등록한 평점',
            centerTitle: true,
            onBack: () => context.pop(),
            actions: [
              if (hasRatings)
                TextButton(
                  onPressed: viewModel.isEditing
                      ? viewModel.cancelEditing
                      : viewModel.startEditing,
                  child: Text(viewModel.isEditing ? '취소' : '편집'),
                ),
            ],
          ),
          bottomNavigationBar: viewModel.isEditing
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: MovieLogButton(
                      label: '선택한 $selectedCount개 삭제',
                      width: double.infinity,
                      onPressed: selectedCount > 0
                          ? () => _deleteSelected(context)
                          : null,
                    ),
                  ),
                )
              : null,
          body: switch (viewModel.status) {
            MyRatingsLoadStatus.idle || MyRatingsLoadStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            MyRatingsLoadStatus.empty => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: MovieListEmpty(
                  message: '이번 로그인에서 등록한 평점이 없어요.\n영화 상세에서 평점을 남겨 보세요.',
                ),
              ),
            ),
            MyRatingsLoadStatus.success => _RatingList(
              viewModel: viewModel,
              onMessage: (message) => _showSnackBar(context, message),
            ),
          },
        ),
      ),
    );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({required this.viewModel, required this.onMessage});

  final MyRatingsViewModel viewModel;
  final ValueChanged<String> onMessage;

  String _titleOf(RatingWithMovie entry) =>
      entry.movie?.title ?? '영화 #${entry.rating.movieId}';

  Future<void> _openEditDialog(
    BuildContext context,
    RatingWithMovie entry,
  ) async {
    final rating = entry.rating;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RatingDialog(
        movieTitle: _titleOf(entry),
        // 기존 점수와 코멘트를 채운 상태로 엽니다.
        initialScore: rating.score,
        initialComment: rating.comment,
        onSubmit: (score, comment) => viewModel.updateRating(
          ratingId: rating.ratingId,
          score: score,
          comment: comment,
        ),
      ),
    );
    if (saved == true) onMessage('평점을 수정했습니다.');
  }

  Future<void> _openDeleteDialog(
    BuildContext context,
    RatingWithMovie entry,
  ) async {
    // 단일 삭제는 DELETE 응답이 올 때까지 확인 Dialog를 유지합니다.
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DeleteConfirmDialog(
        title: '"${_titleOf(entry)}" 평점을 삭제할까요?',
        onConfirm: () => viewModel.deleteRating(entry.rating.ratingId),
      ),
    );
    if (deleted == true) onMessage('평점을 삭제했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final entries = viewModel.ratings;
    final notice = viewModel.message;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이번 로그인에서 등록한 평점 ${entries.length}개',
                style: AppTextStyles.bodySmall,
              ),
              // v7에는 토큰 기반 '내 평점 목록' API가 없어서 재시작 후에는 복원되지 않는다는 한계를 알립니다.
              Text(
                '앱을 다시 시작하거나 로그아웃하면 이 목록은 비워져요.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray),
              ),
              if (notice != null) ...[
                const SizedBox(height: 4),
                Text(
                  notice,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          );
        }
        final entry = entries[index - 1];
        final ratingId = entry.rating.ratingId;
        return _RatingCard(
          entry: entry,
          isEditing: viewModel.isEditing,
          isSelected: viewModel.selectedRatingIds.contains(ratingId),
          onToggle: () => viewModel.toggleSelection(ratingId),
          onEdit: () => _openEditDialog(context, entry),
          onDelete: () => _openDeleteDialog(context, entry),
        );
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.entry,
    required this.isEditing,
    required this.isSelected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingWithMovie entry;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return InkWell(
      // 편집 모드에서는 카드 전체를 눌러도 선택이 바뀝니다.
      onTap: isEditing ? onToggle : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
            color: isSelected ? AppColors.violet : AppColors.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEditing)
              Checkbox(value: isSelected, onChanged: (_) => onToggle()),
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
                    // TMDB에 없거나 못 불러온 영화도 평점은 지우지 않고 '영화 #movieId'로 보여줍니다.
                    movie?.title ?? '영화 #${rating.movieId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: movie == null ? AppColors.gray : null,
                    ),
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
                  // 편집 모드에서는 개별 수정·삭제 대신 선택만 할 수 있게 버튼을 숨깁니다.
                  if (!isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: onEdit, child: const Text('수정')),
                        TextButton(
                          onPressed: onDelete,
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
