import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

// 별점 입력 방식만 담당하고, 실제 값은 부모 Widget이 관리합니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0.5,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 40,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: Colors.amber),
      onRatingUpdate: onChanged,
    );
  }
}
