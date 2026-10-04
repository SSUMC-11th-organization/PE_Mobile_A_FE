import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../theme/app_colors.dart';

class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;

  /// '전체'(allGenresLabel)도 하나의 선택값으로 다룬다.
  final String selectedGenre;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [allGenresLabel, ...genres];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          final selected = label == selectedGenre;

          return Center(
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              backgroundColor: AppColors.surfaceVariant,
              selectedColor: AppColors.violet,
              labelStyle: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              onSelected: (_) => onSelected(label),
            ),
          );
        },
      ),
    );
  }
}
