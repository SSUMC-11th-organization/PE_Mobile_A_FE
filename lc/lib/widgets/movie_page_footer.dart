import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 목록 아래의 "더 보기" 영역. 다음 페이지 요청 중에는 로딩, 실패하면 재시도 안내를 보여준다.
/// 기존 목록은 그대로 두고 이 영역만 바뀐다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({
    super.key,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.violet,
            ),
          ),
        ),
      );
    }
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loadMoreError!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
            TextButton(onPressed: onLoadMore, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (!hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextButton(onPressed: onLoadMore, child: const Text('더 보기')),
    );
  }
}
