import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 0;
  int _resetCount = 0; // 값이 바뀌면 별 위젯을 새로 만들어 초기화

  void _reset() {
    setState(() {
      _rating = 0;
      _resetCount += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('영화는 어떠셨나요?', style: AppTextStyles.titleMedium),
            const SizedBox(height: 20),
            MovieRatingInput(
              key: ValueKey(_resetCount),
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            SizedBox(
              height: 40,
              child: _rating > 0
                  ? TextButton(
                      onPressed: _reset,
                      child: Text(
                        '다시 선택하기',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed:
                    _rating > 0 ? () => Navigator.pop(context, _rating) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.disabledViolet,
                  disabledForegroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}