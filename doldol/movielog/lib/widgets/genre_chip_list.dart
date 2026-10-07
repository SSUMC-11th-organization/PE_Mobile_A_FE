import 'package:flutter/material.dart';
import '../data/movie_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GenreChipList extends StatelessWidget {
  const GenreChipList({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = genre == selected;

          return ChoiceChip(
            label: Text(genre),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: AppColors.deepViolet,
            backgroundColor: AppColors.lavender,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: AppTextStyles.label.copyWith(
              color: isSelected ? AppColors.white : AppColors.black,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            onSelected: (_) => onSelected(genre),
          );
        },
      ),
    );
  }
}