import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 48, color: AppColors.outline),
          SizedBox(height: 12),
          Text(
            '조건에 맞는 영화가 없습니다.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 24 / 16,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '다른 장르를 선택해 보세요.',
            style: TextStyle(
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
