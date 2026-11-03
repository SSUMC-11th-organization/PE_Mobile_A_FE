import 'package:flutter/material.dart';

import '../models/rating_submission.dart';
import '../theme/app_colors.dart';
import 'movie_rating_input.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.movieId,
    this.initialRating = 0,
  });

  /// 평점을 남길 영화의 TMDB id. 확인을 누르면 점수와 함께 돌려준다.
  final int movieId;
  final double initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '영화는 어떠셨나요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF25232A),
              ),
            ),
            const SizedBox(height: 24),
            MovieRatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating == 0
                    ? null
                    : () => Navigator.of(context).pop(
                        RatingSubmission(
                          movieId: widget.movieId,
                          score: _rating,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.violetDisabled,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
