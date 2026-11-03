import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'movie_grid.dart';

// 영화 카드 모양의 Skeleton으로 Loading 상태를 표시합니다.
class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '영화 목록을 불러오는 중',
      child: Column(
        children: [
          const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              gridDelegate: movieGridDelegate,
              itemBuilder: (context, index) => const _SkeletonCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _box(width: double.infinity, radius: 12)),
        const SizedBox(height: 8),
        _box(width: 110, height: 16),
        const SizedBox(height: 6),
        _box(width: 70, height: 12),
      ],
    );
  }

  Widget _box({required double width, double? height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
