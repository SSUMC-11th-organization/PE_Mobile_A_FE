import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../theme/app_colors.dart';

class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // RatingBar는 항상 double을 돌려주지만, 반 점을 막아서 1.0, 2.0 같은 정수 값만 나온다
    return RatingBar(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4),
      ratingWidget: RatingWidget(
        full: const Icon(Icons.star_rounded, color: AppColors.violet),
        half: const Icon(Icons.star_half_rounded, color: AppColors.violet),
        empty: const Icon(Icons.star_border_rounded, color: AppColors.violet),
      ),
      onRatingUpdate: onChanged,
    );
  }
}