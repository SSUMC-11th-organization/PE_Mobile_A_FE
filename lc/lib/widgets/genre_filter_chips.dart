import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';

/// TMDB Genre API의 id/name으로 만든 단일 선택 Chip 줄. '전체'는 id가 null이다.
class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.onSelected,
    this.enabled = true,
  });

  static const allLabel = '전체';

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId;
  final ValueChanged<int?> onSelected;

  /// false이면 눌러도 반응하지 않는다. (요청 중에는 장르를 바꾸지 못하게 한다.)
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // (id, 이름) 쌍. null id가 '전체'이다.
    final options = <(int?, String)>[
      (null, allLabel),
      for (final genre in genres) (genre.id, genre.name),
    ];

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (id, label) = options[index];
              final selected = id == selectedGenreId;

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
                  onSelected: (_) => onSelected(id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
