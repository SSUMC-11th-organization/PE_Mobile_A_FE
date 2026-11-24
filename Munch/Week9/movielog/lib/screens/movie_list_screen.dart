import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_bar.dart';
import '../widgets/genre_filter_sheet.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movie_page_footer.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '영화 검색',
            onPressed: () => context.push(AppRouter.movieSearchLocation),
            icon: const Icon(Icons.search),
          ),
          const _GenreFilterButton(),
        ],
      ),
      body: Consumer<PagedMoviesViewModel>(
        builder: (context, vm, child) {
          if (vm.genres.isEmpty) {
            return vm.genresFailed
                ? MovieListError(
                    onRetry: () {
                      vm.loadGenres();
                      if (vm.phase != LoadPhase.ready) vm.reload();
                    },
                  )
                : const MovieListLoading();
          }

          return Column(
            children: [
              GenreChipBar(
                genres: vm.genres,
                selectedGenreIds: vm.selectedGenreIds ?? const [],
                enabled: !vm.isBusy,
                onAllSelected: () => vm.loadInitial(),
                onGenreSelected: (id) => vm.loadInitial(genreIds: [id]),
              ),
              Expanded(child: _MovieListBody(vm: vm)),
            ],
          );
        },
      ),
    );
  }
}

class _MovieListBody extends StatefulWidget {
  const _MovieListBody({required this.vm});

  final PagedMoviesViewModel vm;

  @override
  State<_MovieListBody> createState() => _MovieListBodyState();
}

class _MovieListBodyState extends State<_MovieListBody> {
  static const loadMoreThreshold = 400.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // 실패한 뒤에는 자동으로 다시 요청하지 않고 재시도 버튼을 누르게 한다.
  void _onScroll() {
    final vm = widget.vm;
    if (vm.loadMoreError != null) return;
    if (_scrollController.position.extentAfter <= loadMoreThreshold) {
      vm.loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return switch (vm.phase) {
      LoadPhase.idle ||
      LoadPhase.loading => const MovieListLoading(showGenreSkeleton: false),
      LoadPhase.error => MovieListError(
        message: vm.errorMessage ?? MovieListError.defaultMessage,
        onRetry: vm.reload,
      ),
      LoadPhase.empty => RefreshIndicator(
        color: AppColors.violet,
        onRefresh: vm.reload,
        child: const _ScrollableEmpty(),
      ),
      LoadPhase.ready => RefreshIndicator(
        color: AppColors.violet,
        notificationPredicate: (notification) =>
            !vm.isLoadingMore && notification.depth == 0,
        onRefresh: vm.reload,
        child: MovieGrid(
          controller: _scrollController,
          movies: vm.movies,
          genreNames: vm.genreNames,
          footer: MoviePageFooter(vm: vm, autoLoad: true),
          onMovieTap: (movie) => context.push(
            AppRouter.movieDetailLocation(movie.id),
            extra: movie,
          ),
        ),
      ),
    };
  }
}

class _GenreFilterButton extends StatelessWidget {
  const _GenreFilterButton();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagedMoviesViewModel>();
    final selectedCount = vm.selectedGenreIds?.length ?? 0;
    final enabled = vm.genres.isNotEmpty && !vm.isBusy;

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
    final vm = context.read<PagedMoviesViewModel>();

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
              genres: vm.genres,
              initialGenreIds: vm.selectedGenreIds ?? const [],
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;
    await vm.loadInitial(genreIds: result);
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
