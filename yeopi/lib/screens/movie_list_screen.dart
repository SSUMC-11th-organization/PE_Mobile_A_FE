import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_list.dart';
import '../widgets/movie_card.dart';

enum MovieSort {
  latest('최신순'),
  title('제목순');

  const MovieSort(this.label);
  final String label;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  String _selectedGenre = movieGenres.first;
  MovieSort _sort = MovieSort.latest;

  List<Movie> get _visibleMovies {
    final filtered = _selectedGenre == movieGenres.first
        ? [...movies]
        : movies.where((movie) => movie.genre == _selectedGenre).toList();

    switch (_sort) {
      case MovieSort.latest:
        // 같은 연도끼리는 id로 보조 정렬해 순서가 바뀌지 않게 합니다.
        filtered.sort((a, b) {
          final byYear = b.year.compareTo(a.year);
          return byYear != 0 ? byYear : a.id.compareTo(b.id);
        });
      case MovieSort.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
    }
    return filtered;
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<MovieSort>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text('정렬 기준', style: AppTextStyles.titleMedium),
            ),
            for (final sort in MovieSort.values)
              ListTile(
                title: Text(sort.label),
                trailing: sort == _sort ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, sort),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _sort = selected);
  }

  @override
  Widget build(BuildContext context) {
    final visibleMovies = _visibleMovies;

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '정렬',
            icon: const Icon(Icons.sort),
            onPressed: _openSortSheet,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GenreChipList(
            genres: movieGenres,
            selected: _selectedGenre,
            onSelected: (genre) => setState(() => _selectedGenre = genre),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${visibleMovies.length}편 · ${_sort.label}',
              style: AppTextStyles.bodySmall,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleMovies.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.6,
              ),
              itemBuilder: (context, index) =>
                  MovieCard(movie: visibleMovies[index]),
            ),
          ),
        ],
      ),
    );
  }
}
