import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_text_styles.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_list.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

// 화면은 ViewModel 상태를 그리기만 하고, 요청·필터·정렬은 MovieListViewModel이 담당합니다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  Future<void> _openSortSheet(BuildContext context) async {
    final viewModel = context.read<MovieListViewModel>();
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
                trailing: sort == viewModel.sort
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, sort),
              ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await viewModel.changeSort(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '정렬',
            icon: const Icon(Icons.sort),
            onPressed: () => _openSortSheet(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer<MovieListViewModel>(
            builder: (context, viewModel, child) => GenreChipList(
              genres: viewModel.genres,
              selectedId: viewModel.selectedGenreId,
              enabled: !viewModel.isBusy,
              onSelected: (genreId) =>
                  context.read<MovieListViewModel>().selectGenre(genreId),
            ),
          ),
          Expanded(
            child: Consumer<MovieListViewModel>(
              builder: (context, viewModel, child) => switch (viewModel
                  .status) {
                MovieListLoadStatus.idle ||
                MovieListLoadStatus.loading => const MovieListLoading(),
                MovieListLoadStatus.error => _refreshable(
                  context,
                  MovieListError(
                    message: viewModel.message ?? '영화를 불러오지 못했어요.',
                    onRetry: () => context.read<MovieListViewModel>().retry(),
                  ),
                ),
                MovieListLoadStatus.empty => _refreshable(
                  context,
                  _emptyView(context, viewModel.selectedGenreName),
                ),
                MovieListLoadStatus.success => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '${viewModel.movies.length}편 · ${viewModel.sort.label}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            context.read<MovieListViewModel>().refresh(),
                        child: MovieGrid(movies: viewModel.movies),
                      ),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(BuildContext context, String? genreName) {
    if (genreName == null) {
      return MovieListEmpty(
        message: '아직 등록된 영화가 없어요.\n잠시 후 다시 확인해 주세요.',
        actionLabel: '새로고침',
        onAction: () => context.read<MovieListViewModel>().retry(),
      );
    }
    return MovieListEmpty(
      message: '$genreName 장르의 영화가 없어요.',
      actionLabel: '전체 보기',
      onAction: () => context.read<MovieListViewModel>().selectGenre(null),
    );
  }

  // Empty·Error 화면에서도 당겨서 새로고침할 수 있게 스크롤 영역으로 감쌉니다.
  Widget _refreshable(BuildContext context, Widget child) {
    return RefreshIndicator(
      onRefresh: () => context.read<MovieListViewModel>().refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
