import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 장르를 하나만 고르는 가로 Chip 목록.
class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;
  final String selectedGenre;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: genres.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final selected = genre == selectedGenre;
          return ChoiceChip(
            label: Text(genre),
            selected: selected,
            onSelected: (_) => onSelected(genre),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? AppColors.white : AppColors.black,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AppColors.violet,
            backgroundColor: AppColors.fieldFill,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }
}
