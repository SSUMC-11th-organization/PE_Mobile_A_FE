import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  static const _genres = ['드라마', 'SF', '애니메이션'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('선호하는 장르', style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _genres
              .map((g) => Chip(
                    label: Text(g),
                    labelStyle: AppTextStyles.label.copyWith(color: AppColors.deepViolet),
                    backgroundColor: AppColors.lavender,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ))
              .toList(),
        ),
      ],
    );
  }
}