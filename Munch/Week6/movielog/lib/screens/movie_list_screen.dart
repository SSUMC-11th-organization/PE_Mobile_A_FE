import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_bar.dart';
import '../widgets/genre_filter_sheet.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movie_load_retry_dialog.dart';

/// 상태와 요청은 [MovieListViewModel]이 가진다. 이 화면은 상태를 그리고 입력을 전달만 한다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          const _GenreFilterButton(),
        ],
      ),
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.genres.isEmpty) {
            // 장르 목록을 아직 못 받은 첫 로딩·첫 실패 화면
            return switch (viewModel.status) {
              MovieListLoadStatus.error => MovieListError(
                message: viewModel.message ?? MovieListError.defaultMessage,
                onRetry: () => context.read<MovieListViewModel>().loadInitial(),
              ),
              _ => const MovieListLoading(),
            };
          }

          return Column(
            children: [
              GenreChipBar(
                genres: viewModel.genres,
                selectedGenreIds: viewModel.selectedGenreIds ?? const [],
                enabled: !viewModel.isBusy,
                onAllSelected: () => _selectGenres(context, null),
                onGenreSelected: (id) => _selectGenres(context, [id]),
              ),
              if (viewModel.isRefreshing)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.violet,
                  backgroundColor: Colors.transparent,
                ),
              Expanded(child: _MovieListBody(viewModel: viewModel)),
            ],
          );
        },
      ),
    );
  }
}

class _MovieListBody extends StatelessWidget {
  const _MovieListBody({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return switch (viewModel.status) {
      MovieListLoadStatus.idle || MovieListLoadStatus.loading =>
        const MovieListLoading(showGenreSkeleton: false),
      MovieListLoadStatus.error => MovieListError(
        message: viewModel.message ?? MovieListError.defaultMessage,
        onRetry: () =>
            _runAndHandle(context, context.read<MovieListViewModel>().retry()),
      ),
      MovieListLoadStatus.empty => _RefreshableList(
        enabled: !viewModel.isBusy,
        child: const _ScrollableEmpty(),
      ),
      MovieListLoadStatus.success => _RefreshableList(
        enabled: !viewModel.isBusy,
        child: MovieGrid(
          movies: viewModel.movies,
          genreNames: viewModel.genreNames,
          onMovieTap: (movie) => _openDetail(context, movie, viewModel),
        ),
      ),
    };
  }

  void _openDetail(
    BuildContext context,
    TmdbMovieDto movie,
    MovieListViewModel viewModel,
  ) {
    context.push(
      AppRouter.movieDetailLocation(movie.id),
      extra: MovieDetailArgs(movie: movie, genreNames: viewModel.genreNames),
    );
  }
}

/// 새로고침 중에도 기존 목록을 그대로 두고, 완료되면 ViewModel이 최신 목록으로 바꾼다.
/// Loading·새로고침 중에는 [enabled]가 false라 당김 제스처가 동작하지 않는다.
class _RefreshableList extends StatelessWidget {
  const _RefreshableList({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.violet,
      notificationPredicate: (notification) =>
          enabled && notification.depth == 0,
      onRefresh: () async {
        final result = await context.read<MovieListViewModel>().refresh();
        // Dialog는 새로고침 indicator가 닫힌 뒤에 띄운다.
        if (context.mounted) unawaited(_handleResult(context, result));
      },
      child: child,
    );
  }
}

class _GenreFilterButton extends StatelessWidget {
  const _GenreFilterButton();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieListViewModel>();
    final selectedCount = viewModel.selectedGenreIds?.length ?? 0;
    final enabled = viewModel.genres.isNotEmpty && !viewModel.isBusy;

    return IconButton(
      tooltip: '장르 필터',
      onPressed: enabled ? () => _openFilterSheet(context) : null,
      icon: Badge(
        isLabelVisible: selectedCount > 0,
        backgroundColor: AppColors.violet,
        label: Text('$selectedCount'),
        child: const Icon(Icons.filter_list),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final viewModel = context.read<MovieListViewModel>();

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.warmWhite,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return GenreFilterSheet(
              genres: viewModel.genres,
              initialGenreIds: viewModel.selectedGenreIds ?? const [],
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;
    await _selectGenres(context, result);
  }
}

class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const MovieListEmpty(),
          ),
        );
      },
    );
  }
}

/// 확인에서 아무것도 고르지 않으면 빈 목록이 오고, ViewModel이 null(전체)로 바꾼다.
Future<void> _selectGenres(BuildContext context, List<int>? genreIds) {
  return _runAndHandle(
    context,
    context.read<MovieListViewModel>().selectGenres(genreIds),
  );
}

Future<void> _runAndHandle(
  BuildContext context,
  Future<MovieListLoadResult> request,
) async {
  final result = await request;
  if (context.mounted) await _handleResult(context, result);
}

/// 최근 성공 목록을 유지한 채 실패했으면 재시도 Dialog를 띄운다.
/// 다시 시도는 마지막으로 선택한 장르로 page 1부터 다시 요청하고, 또 실패하면 Dialog를 다시 띄운다.
Future<void> _handleResult(
  BuildContext context,
  MovieListLoadResult result,
) async {
  if (result != MovieListLoadResult.failedWithPrevious) return;

  final viewModel = context.read<MovieListViewModel>();
  final retry = await MovieLoadRetryDialog.show(context);
  if (!retry || !context.mounted) return;

  final next = await viewModel.retry();
  if (context.mounted) await _handleResult(context, next);
}
