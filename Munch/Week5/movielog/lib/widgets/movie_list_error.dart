import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieListError extends StatelessWidget {
  const MovieListError({
    super.key,
    this.message = defaultMessage,
    required this.onRetry,
  });

  static const defaultMessage = '영화를 불러오지 못했습니다.';
  static const timeoutMessage = '응답이 늦어지고 있습니다.\n잠시 후 다시 시도해 주세요.';

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
