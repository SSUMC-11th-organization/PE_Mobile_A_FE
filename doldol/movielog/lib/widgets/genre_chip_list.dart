import 'package:flutter/material.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GenreChipList extends StatelessWidget {
  const GenreChipList({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId; // null이면 "전체"
  final ValueChanged<int?> onSelected;
  final bool enabled; // false면 요청 중이라 장르를 바꿀 수 없다

  @override
  Widget build(BuildContext context) {
    // 요청 중에는 흐리게 보이고 터치도 막는다
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: genres.length + 1, // "전체" 칩 1개 + 장르 칩들
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final int? genreId = index == 0 ? null : genres[index - 1].id;
              final name = index == 0 ? '전체' : genres[index - 1].name;
              final isSelected = genreId == selectedGenreId;

              return ChoiceChip(
                label: Text(name),
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
                onSelected: (_) => onSelected(genreId),
              );
            },
          ),
        ),
      ),
    );
  }
}