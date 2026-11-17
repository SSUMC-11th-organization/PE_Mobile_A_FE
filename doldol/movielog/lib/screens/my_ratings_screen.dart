import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_card.dart';
import '../widgets/rating_dialog.dart';

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// 수정: 기존 별점·코멘트를 채운 RatingDialog를 다시 연다
Future<void> _onEditPressed(BuildContext context, RatingDto rating) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 빈 칸으로 시작
      onSubmit: (score, comment) =>
          context.read<MyRatingsViewModel>().updateRating(
                ratingId: rating.ratingId,
                score: score,
                comment: comment,
              ),
    ),
  );
  if (!context.mounted || saved != true) return;

  _showSnackBar(context, '평점을 수정했습니다.');
}

/// 삭제: 확인 Dialog를 거치고, 취소하면 요청을 보내지 않는다
Future<void> _onDeletePressed(BuildContext context, RatingDto rating) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () =>
          context.read<MyRatingsViewModel>().deleteRating(rating.ratingId),
    ),
  );
  if (!context.mounted || confirmed != true) return;

  _showSnackBar(context, '평점을 삭제했습니다.');
}

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내가 등록한 평점',
        centerTitle: true,
        titleStyle: AppTextStyles.titleMedium.copyWith(
          color: AppColors.violet,
        ),
        onBack: () => context.pop(),
      ),
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MyRatingsLoadStatus.idle ||
            MyRatingsLoadStatus.loading =>
              const MovieListLoading(),
            MyRatingsLoadStatus.error => MovieListError(
                // 저장은 성공했는데 조회만 실패한 경우의 안내가 있으면 그것을 보여준다
                message: viewModel.refreshWarning ?? viewModel.message,
                // 다시 시도는 조회(GET)만 다시 한다. 쓰기 요청은 다시 보내지 않는다.
                onRetry: () => context.read<MyRatingsViewModel>().load(),
              ),
            MyRatingsLoadStatus.empty =>
              const MovieListEmpty(message: '아직 등록한 평점이 없어요.'),
            MyRatingsLoadStatus.success => _RatingList(
                entries: viewModel.ratings,
                message: viewModel.message,
                memberId: viewModel.memberId,
                onEdit: (rating) => _onEditPressed(context, rating),
                onDelete: (rating) => _onDeletePressed(context, rating),
              ),
          };
        },
      ),
    );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({
    required this.entries,
    required this.message,
    required this.memberId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<RatingWithMovie> entries;
  final String? message;
  final int memberId;
  final ValueChanged<RatingDto> onEdit;
  final ValueChanged<RatingDto> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            '학습용 회원(memberId $memberId)의 평점',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
          ),
        ),
        if (message case final text?)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text, style: AppTextStyles.label),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return RatingCard(
                entry: entry,
                onEdit: () => onEdit(entry.rating),
                onDelete: () => onDelete(entry.rating),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;

  Future<void> _onConfirm() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
      _errorText = null;
    });

    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 403(본인 평점이 아님)과 404(평점 없음)를 서버 message로 구분해서 보여준다
      setState(() {
        _isDeleting = false;
        _errorText = error is DioException
            ? writeErrorMessage(error)
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting, // 삭제 중 뒤로가기 차단
      child: Dialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '평점을 삭제할까요?',
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '삭제한 평점은 복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              if (_errorText case final errorText?) ...[
                const SizedBox(height: 12),
                Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      width: double.infinity,
                      radius: 24,
                      backgroundColor: AppColors.lavender,
                      foregroundColor: AppColors.deepViolet,
                      // 취소하면 삭제 요청을 보내지 않는다
                      onPressed: _isDeleting
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      label: '삭제',
                      width: double.infinity,
                      radius: 24,
                      isLoading: _isDeleting,
                      onPressed: _onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}