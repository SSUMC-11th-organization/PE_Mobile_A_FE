import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating = 0});

  final double initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;

  int _resetCount = 0;

  bool get _canSubmit => _rating > 0 || widget.initialRating > 0;

  void _reset() {
    setState(() {
      _rating = 0;
      _resetCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '영화는 어떠셨나요?',
              style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _rating == 0
                  ? '별을 눌러 평점을 선택해주세요.'
                  : '${_rating.toStringAsFixed(1)}점',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _rating == 0 ? AppColors.gray : AppColors.violet,
                fontWeight: _rating == 0 ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            MovieRatingInput(
              key: ValueKey(_resetCount),
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _rating == 0 ? null : _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.violet,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canSubmit
                        ? () => Navigator.pop(context, _rating)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('확인'),
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
