import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_dto.dart';
import '../theme/app_colors.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movielog_button.dart';
import '../widgets/my_rating_card.dart';
import '../widgets/rating_dialog.dart';

/// 마이페이지 위에 열리는 자식 화면. 하단 NavigationBar 없이 뒤로가기와 중앙 제목만 둔다.
/// 평점의 조회·수정·삭제(개별·다중)를 이 화면이 맡는다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();
    final showMultiDeleteBar =
        viewModel.isEditMode && viewModel.status == MyRatingsLoadStatus.success;

    // 다중 삭제 중에는 뒤로가기도 막는다.
    return PopScope(
      canPop: !viewModel.isDeletingSelected,
      child: Scaffold(
        appBar: const CommonAppBar(
          title: '내가 등록한 평점',
          centerTitle: true,
          showBackButton: true,
        ),
        body: LoadingOverlay(
          isLoading: viewModel.isDeletingSelected,
          child: _Body(viewModel: viewModel),
        ),
        bottomNavigationBar: showMultiDeleteBar
            ? _MultiDeleteBar(viewModel: viewModel)
            : null,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return switch (viewModel.status) {
      MyRatingsLoadStatus.idle ||
      MyRatingsLoadStatus.loading => const MovieListLoading(
        message: '평점을 불러오는 중이에요',
      ),
      MyRatingsLoadStatus.error => MovieListError(
        // 저장은 성공했는데 조회만 실패한 경우에는 그 사실을 먼저 알린다.
        message: viewModel.refreshWarning ?? viewModel.message,
        description: '문제가 계속되면 잠시 후 다시 시도해 주세요.',
        onRetry: viewModel.load, // 조회만 다시 시도한다. 쓰기 요청은 다시 보내지 않는다.
      ),
      MyRatingsLoadStatus.empty => const MovieListEmpty(
        title: '아직 등록한 평점이 없어요.',
        description: '영화에 평점을 남기면 여기에 모여요.',
      ),
      MyRatingsLoadStatus.success => _RatingsList(viewModel: viewModel),
    };
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final message = viewModel.message;
    final ratings = viewModel.ratings;
    final offset = message == null ? 1 : 2;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      // 맨 위 헤더 1줄 + (일부 영화 정보 실패 문구) + 평점 카드들
      itemCount: ratings.length + offset,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _Header(viewModel: viewModel);
        if (message != null && index == 1) return _PartialFailureNotice(message);
        final entry = ratings[index - offset];
        final ratingId = entry.rating.ratingId;
        return MyRatingCard(
          entry: entry,
          selectionMode: viewModel.isEditMode,
          selected: viewModel.selectedRatingIds.contains(ratingId),
          onToggleSelected: () => viewModel.toggleSelection(ratingId),
          onEdit: () => _onEditPressed(context, entry.rating),
          onDelete: () => _onDeletePressed(context, entry.rating),
        );
      },
    );
  }
}

/// 기본 모드에서는 안내 문구와 "편집", 편집 모드에서는 선택 개수와 "취소"를 같은 줄에 둔다.
class _Header extends StatelessWidget {
  const _Header({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isEdit = viewModel.isEditMode;

    return Row(
      children: [
        Expanded(
          child: Text(
            isEdit
                ? '${viewModel.selectedRatingIds.length}개 선택'
                // 로그인 기능이 없어 가입한 학습용 회원의 평점임을 숨기지 않는다.
                : '학습용 회원(memberId ${viewModel.memberId})의 평점이에요.',
            style: TextStyle(
              fontSize: isEdit ? 14 : 12,
              fontWeight: isEdit ? FontWeight.w600 : FontWeight.w400,
              height: 16 / 12,
              color: isEdit ? AppColors.violet : AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: isEdit ? viewModel.cancelEditMode : viewModel.enterEditMode,
          child: Text(isEdit ? '취소' : '편집'),
        ),
      ],
    );
  }
}

class _MultiDeleteBar extends StatelessWidget {
  const _MultiDeleteBar({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final count = viewModel.selectedRatingIds.length;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MovieLogButton(
            label: '선택한 $count개 삭제',
            width: double.infinity,
            // 선택이 1개 이상일 때만 활성화한다.
            onPressed: count > 0 && !viewModel.isDeletingSelected
                ? () => _onDeleteSelectedPressed(context)
                : null,
          ),
        ),
      ),
    );
  }
}

class _PartialFailureNotice extends StatelessWidget {
  const _PartialFailureNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          color: AppColors.error,
        ),
      ),
    );
  }
}

void _showSnackBar(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 수정: 등록과 같은 RatingDialog를 기존 별점·코멘트가 채워진 채로 다시 연다.
/// comment가 null이면 TextField는 빈 칸으로 시작한다.
Future<void> _onEditPressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
    builder: (_) => RatingDialog(
      title: '평점을 수정해 주세요',
      initialScore: rating.score,
      initialComment: rating.comment,
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    ),
  );

  if (saved == true) _showSnackBar(messenger, '평점을 수정했습니다.');
}

/// 개별 삭제: 확인 Dialog를 열고, 취소하면 삭제 요청을 보내지 않는다.
Future<void> _onDeletePressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막는다.
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () => viewModel.deleteRating(rating.ratingId),
    ),
  );

  if (deleted == true) _showSnackBar(messenger, '평점을 삭제했습니다.');
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
      setState(() {
        _isDeleting = false;
        _errorText = error is RatingWriteException
            ? error.message
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        title: const Text('평점을 삭제할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('삭제한 평점은 복구할 수 없습니다.'),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }
}

/// 다중 삭제: 확인 Dialog는 삭제 여부만 묻고 요청 전에 닫힌다.
/// 이후의 로딩은 Dialog가 아니라 화면 위 LoadingOverlay가 맡는다.
Future<void> _onDeleteSelectedPressed(BuildContext context) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      title: const Text('선택한 평점을 삭제할까요?'),
      content: const Text('삭제한 평점은 복구할 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final failed = await viewModel.deleteSelectedRatings();
  if (failed > 0) {
    _showSnackBar(messenger, '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.');
  }
}
