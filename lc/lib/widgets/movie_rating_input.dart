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

  /// false면 별을 눌러도 값이 바뀌지 않는다. (저장 요청 중에 점수를 바꾸지 못하게 한다.)
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      // v6 서버 점수는 1~5 정수다. 반 점을 허용한 뒤 조용히 버리지 않고 입력 단계에서 막는다.
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      unratedColor: const Color(0xFFDDD8E8),
      itemBuilder: (context, index) =>
          const Icon(Icons.star_rounded, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}
