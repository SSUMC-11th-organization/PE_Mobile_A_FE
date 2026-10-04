import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';

// 확인을 누르면 Navigator.pop으로 선택한 별점을 showDialog 호출부에 돌려줍니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, required this.movieTitle});

  final String movieTitle;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('영화는 어떠셨나요?', style: AppTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text(widget.movieTitle, style: AppTextStyles.bodySmall),
            const SizedBox(height: 24),
            MovieRatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 8),
            Text(
              _rating == 0
                  ? '별을 눌러 평점을 선택해주세요'
                  : '${_rating.toStringAsFixed(1)}점',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // 별점을 고르기 전에는 저장 버튼을 비활성화합니다.
                  child: ElevatedButton(
                    onPressed: _rating == 0
                        ? null
                        : () => Navigator.pop(context, _rating),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.violetDisabled,
                      disabledForegroundColor: AppColors.white,
                    ),
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
