import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({
    super.key,
    this.title = '조건에 맞는 영화가 없습니다.',
    this.description = '다른 장르를 선택해 보세요.',
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 24 / 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
