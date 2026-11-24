import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({
    super.key,
    required this.vm,
    this.label = '더 보기',
    this.autoLoad = false,
  });

  final PagedMoviesViewModel vm;
  final String label;
  // true면 버튼 없이 스크롤로 다음 page를 불러오고, 하단에는 로딩만 보여 준다.
  final bool autoLoad;

  @override
  Widget build(BuildContext context) {
    final error = vm.loadMoreError;

    if (!vm.hasMore && !vm.isLoadingMore && error == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Text(
          '모든 영화를 확인했습니다.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    if (autoLoad && error == null) {
      return SizedBox(
        height: 96,
        child: vm.isLoadingMore
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.violet),
              )
            : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],
          MovieLogButton(
            width: double.infinity,
            label: error == null ? label : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
