import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieListError extends StatelessWidget {
  const MovieListError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('영화를 불러오지 못했습니다.', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          const Text('잠시 후 다시 시도해 주세요.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: AppColors.white,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}