import 'package:flutter/material.dart';

import '../data/mock_movies.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 확인을 누르면 선택한 장르 목록을 반환한다. 체크 중에는 Sheet 내부 상태만 바뀐다.
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.initialGenres,
    required this.scrollController,
  });

  final List<String> initialGenres;
  final ScrollController scrollController;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  late final Set<String> _selected = {...widget.initialGenres};

  void _toggle(String genre, bool checked) {
    setState(() {
      checked ? _selected.add(genre) : _selected.remove(genre);
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
              const Text('장르 선택', style: AppTextStyles.titleMedium),
              const Spacer(),
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
            itemCount: movieGenres.length,
            itemBuilder: (context, index) {
              final genre = movieGenres[index];
              return CheckboxListTile(
                value: _selected.contains(genre),
                onChanged: (checked) => _toggle(genre, checked ?? false),
                title: Text(genre),
                activeColor: AppColors.violet,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                movieGenres.where(_selected.contains).toList(),
              ),
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
