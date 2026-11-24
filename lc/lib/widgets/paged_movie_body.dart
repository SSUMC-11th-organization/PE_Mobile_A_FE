import 'package:flutter/material.dart';

import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movie_grid.dart';
import 'movie_list_empty.dart';
import 'movie_list_error.dart';
import 'movie_list_loading.dart';
import 'movie_page_footer.dart';

/// 영화 목록·검색 결과가 함께 쓰는 본문. 상태별 화면, 격자, "더 보기" 영역,
/// 바닥 근처에 닿으면 다음 페이지를 불러오는 무한 스크롤(Challenge B)을 담당한다.
class PagedMovieBody extends StatefulWidget {
  const PagedMovieBody({
    super.key,
    required this.viewModel,
    this.idleMessage,
    this.emptyMessage,
  });

  final PagedMoviesViewModel viewModel;

  /// 검색어가 없을 때 보여줄 안내. null이면 일반 로딩 화면.
  final String? idleMessage;
  final String? emptyMessage;

  @override
  State<PagedMovieBody> createState() => _PagedMovieBodyState();
}

class _PagedMovieBodyState extends State<PagedMovieBody> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final vm = widget.viewModel;
    if (!_controller.hasClients) return;
    // 실패한 뒤에는 자동 재요청하지 않고 "다시 시도"로만 이어간다.
    if (vm.loadMoreError != null) return;
    final position = _controller.position;
    if (position.maxScrollExtent - position.pixels < 300) vm.loadMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return switch (vm.phase) {
      LoadPhase.idle when widget.idleMessage != null => Center(
        child: Text(widget.idleMessage!),
      ),
      LoadPhase.idle || LoadPhase.loading => const MovieListLoading(),
      LoadPhase.error => MovieListError(
        message: vm.message,
        onRetry: vm.retry,
      ),
      LoadPhase.empty =>
        widget.emptyMessage != null
            ? Center(child: Text(widget.emptyMessage!))
            : const MovieListEmpty(),
      LoadPhase.ready => Column(
        children: [
          Expanded(
            child: MovieGrid(
              controller: _controller,
              movies: vm.movies,
              genreNames: vm.genreNames,
            ),
          ),
          MoviePageFooter(
            hasMore: vm.hasMore,
            isLoadingMore: vm.isLoadingMore,
            loadMoreError: vm.loadMoreError,
            onLoadMore: vm.loadMore,
          ),
        ],
      ),
    };
  }
}
