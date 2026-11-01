import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';

/// TMDB Genre API의 id/name으로 Chip을 그린다. [enabled]가 false면 선택할 수 없다.
class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenreIds,
    required this.onAllSelected,
    required this.onGenreSelected,
    this.enabled = true,
  });

  static const allLabel = '전체';

  final List<TmdbGenreDto> genres;
  final List<int> selectedGenreIds;
  final VoidCallback onAllSelected;
  final ValueChanged<int> onGenreSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GenreChip(
              label: allLabel,
              selected: selectedGenreIds.isEmpty,
              onSelected: enabled ? onAllSelected : null,
            );
          }

          final genre = genres[index - 1];
          return _GenreChip(
            label: genre.name,
            selected: selectedGenreIds.contains(genre.id),
            onSelected: enabled ? () => onGenreSelected(genre.id) : null,
          );
        },
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = onSelected != null;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onSelected!() : null,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.black,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppColors.violet,
      disabledColor: selected
          ? AppColors.violet.withValues(alpha: 0.5)
          : AppColors.fieldFill.withValues(alpha: 0.6),
      backgroundColor: AppColors.fieldFill,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}
