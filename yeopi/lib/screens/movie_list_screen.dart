import 'dart:async';

import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../services/fake_movie_service.dart';
import '../services/movie_list_preferences.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_list.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

enum MovieSort {
  latest('최신순'),
  title('제목순');

  const MovieSort(this.label);
  final String label;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.service = const FakeMovieService(),
    this.preferences,
    this.timeout = const Duration(seconds: 3),
  });

  final FakeMovieService service;
  final MovieListPreferences? preferences;
  final Duration timeout;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final MovieListPreferences _preferences =
      widget.preferences ?? MovieListPreferences();

  // build가 아니라 initState·재시도·새로고침에서만 새 Future를 만듭니다.
  late Future<List<Movie>> _moviesFuture;

  // 테스트 메뉴로 고른 모드는 다음 요청 한 번에만 적용되고, 재시도는 성공 모드로 돌아갑니다.
  MovieLoadMode _nextMode = MovieLoadMode.success;
  bool _isRefreshing = false;

  String _selectedGenre = movieGenres.first;
  MovieSort _sort = MovieSort.latest;
  bool _filterChangedByUser = false;

  @override
  void initState() {
    super.initState();
    _moviesFuture = _loadMovies();
    _restoreFilters();
  }

  Future<List<Movie>> _loadMovies() async {
    final mode = _nextMode;
    _nextMode = MovieLoadMode.success;

    try {
      return await widget.service
          .fetchMovies(mode: mode)
          .timeout(widget.timeout);
    } on MovieLoadException catch (error, stackTrace) {
      debugPrint('영화 목록 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on TimeoutException {
      debugPrint('영화 목록 응답 시간 초과 (${widget.timeout.inSeconds}초)');
      rethrow;
    } finally {
      debugPrint('영화 목록 로드 시도 종료 (${mode.label})');
    }
  }

  void _reload() {
    // 화살표 함수로 쓰면 대입한 Future가 반환되어 setState가 오류를 던지므로 블록으로 씁니다.
    setState(() {
      _moviesFuture = _loadMovies();
    });
  }

  void _reloadWith(MovieLoadMode mode) {
    _nextMode = mode;
    _reload();
  }

  // 당겨서 새로고침하는 동안에는 기존 목록을 유지하고 RefreshIndicator로 진행 상태를 보여줍니다.
  Future<void> _refresh() async {
    final future = _loadMovies();
    setState(() {
      _isRefreshing = true;
      _moviesFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // 오류 화면은 FutureBuilder가 그립니다.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _restoreFilters() async {
    final saved = await Future.wait([
      _preferences.readGenre(),
      _preferences.readSort(),
    ]);
    // 기다리는 동안 화면을 벗어났거나 사용자가 먼저 고른 값은 덮어쓰지 않습니다.
    if (!mounted || _filterChangedByUser) return;

    setState(() {
      _selectedGenre = saved[0]!;
      _sort = MovieSort.values.firstWhere(
        (sort) => sort.name == saved[1],
        orElse: () => MovieSort.latest,
      );
    });
  }

  Future<void> _selectGenre(String genre) async {
    _filterChangedByUser = true;
    setState(() => _selectedGenre = genre);
    await _preferences.saveGenre(genre);
  }

  Future<void> _selectSort(MovieSort sort) async {
    _filterChangedByUser = true;
    setState(() => _sort = sort);
    await _preferences.saveSort(sort.name);
  }

  List<Movie> _filterAndSort(List<Movie> source) {
    final filtered = _selectedGenre == movieGenres.first
        ? [...source]
        : source.where((movie) => movie.genre == _selectedGenre).toList();

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
    if (selected != null && mounted) await _selectSort(selected);
  }

  String _errorMessage(Object? error) => error is TimeoutException
      ? '응답이 늦어지고 있어요.\n네트워크 상태를 확인하고 다시 시도해 주세요.'
      : '영화를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          PopupMenuButton<MovieLoadMode>(
            tooltip: '불러오기 모드 테스트',
            icon: const Icon(Icons.science_outlined),
            onSelected: _reloadWith,
            itemBuilder: (context) => [
              for (final mode in MovieLoadMode.values)
                PopupMenuItem(value: mode, child: Text('다음 요청: ${mode.label}')),
            ],
          ),
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
            onSelected: _selectGenre,
          ),
          Expanded(
            child: FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                final waiting =
                    snapshot.connectionState == ConnectionState.waiting;
                if (waiting && !(_isRefreshing && snapshot.hasData)) {
                  return const MovieListLoading();
                }

                // 오류를 먼저 확인해야 실패가 빈 목록으로 보이지 않습니다.
                if (snapshot.hasError) {
                  return _refreshable(
                    MovieListError(
                      message: _errorMessage(snapshot.error),
                      onRetry: _reload,
                    ),
                  );
                }

                final allMovies = snapshot.data ?? const <Movie>[];
                if (allMovies.isEmpty) {
                  return _refreshable(
                    MovieListEmpty(
                      message: '아직 등록된 영화가 없어요.\n잠시 후 다시 확인해 주세요.',
                      actionLabel: '새로고침',
                      onAction: _reload,
                    ),
                  );
                }

                final visibleMovies = _filterAndSort(allMovies);
                if (visibleMovies.isEmpty) {
                  return _refreshable(
                    MovieListEmpty(
                      message: '$_selectedGenre 장르의 영화가 없어요.',
                      actionLabel: '전체 보기',
                      onAction: () => _selectGenre(movieGenres.first),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '${visibleMovies.length}편 · ${_sort.label}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: MovieGrid(movies: visibleMovies),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Empty·Error 화면에서도 당겨서 새로고침할 수 있게 스크롤 영역으로 감쌉니다.
  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      onRefresh: _refresh,
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
