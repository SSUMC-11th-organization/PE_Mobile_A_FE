import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';

// Genre API로 받은 id·name으로 Chip을 만들고, 맨 앞에는 with_genres 없이 요청하는 '전체'를 둡니다.
class GenreChipList extends StatelessWidget {
  const GenreChipList({
    super.key,
    required this.genres,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final items = <(int?, String)>[
      (null, '전체'),
      for (final genre in genres) (genre.id, genre.name),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (id, name) = items[index];
          final selected = id == selectedId;
          return ChoiceChip(
            label: Text(name),
            selected: selected,
            // onSelected가 null이면 Chip이 비활성화되어 요청 중에는 장르를 바꿀 수 없습니다.
            onSelected: enabled ? (_) => onSelected(id) : null,
            selectedColor: AppColors.violet,
            labelStyle: TextStyle(
              color: selected ? AppColors.white : AppColors.black,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
