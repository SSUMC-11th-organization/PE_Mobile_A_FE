import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// 가로 ListView로 장르 Chip을 나열합니다. 선택 상태는 부모가 관리합니다.
class GenreChipList extends StatelessWidget {
  const GenreChipList({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          return ChoiceChip(
            label: Text(genre),
            selected: genre == selected,
            onSelected: (_) => onSelected(genre),
            selectedColor: AppColors.violet,
            labelStyle: TextStyle(
              color: genre == selected ? AppColors.white : AppColors.black,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
