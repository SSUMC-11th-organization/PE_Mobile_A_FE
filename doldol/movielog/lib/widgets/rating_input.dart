import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../theme/app_colors.dart';

class RatingInput extends StatelessWidget {
  const RatingInput({super.key, required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: 0,
      minRating: 0.5,
      allowHalfRating: true,
      itemCount: 5,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, _) =>
          const Icon(Icons.star_rounded, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}