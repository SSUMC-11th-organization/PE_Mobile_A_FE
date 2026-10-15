import 'package:flutter/material.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 3주차 장르 BottomSheet를 TMDB 장르 id 기반으로 재사용한다.
/// 확인을 누르면 선택한 장르 id 목록을 반환한다. 체크 중에는 Sheet 내부 상태만 바뀐다.
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.initialGenreIds,
    required this.scrollController,
  });

  final List<TmdbGenreDto> genres;
  final List<int> initialGenreIds;
  final ScrollController scrollController;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  late final Set<int> _selected = {...widget.initialGenreIds};

  void _toggle(int genreId, bool checked) {
    setState(() {
      checked ? _selected.add(genreId) : _selected.remove(genreId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('장르 필터', style: AppTextStyles.titleMedium),
                    SizedBox(height: 4),
                    Text(
                      '여러 장르를 선택할 수 있어요',
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => setState(_selected.clear),
                child: const Text('선택 해제'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: widget.genres.length,
            itemBuilder: (context, index) {
              final genre = widget.genres[index];
              return CheckboxListTile(
                value: _selected.contains(genre.id),
                onChanged: (checked) => _toggle(genre.id, checked ?? false),
                title: Text(genre.name),
                activeColor: AppColors.violet,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            },
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, [
                for (final genre in widget.genres)
                  if (_selected.contains(genre.id)) genre.id,
              ]),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
