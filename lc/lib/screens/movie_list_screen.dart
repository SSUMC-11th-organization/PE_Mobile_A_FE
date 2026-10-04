import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preference.dart';
import '../theme/app_colors.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    // TODO(5주차 유저별 평점 조회 API): 실제 API Service로 교체한다.
    this.movieService = const FakeMovieService(),
    this.genrePreference,
    this.initialMode = MovieLoadMode.success,
  });

  final FakeMovieService movieService;
  final GenrePreference? genrePreference;

  /// Loading·Empty·Error 화면을 확인하기 위한 Mock 동작 모드.
  final MovieLoadMode initialMode;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListData {
  const _MovieListData({required this.movies, required this.savedGenre});

  final List<Movie> movies;
  final String savedGenre;
}

/// 디버그 메뉴에서 고르는 Mock 시나리오.
/// failureThenSuccess는 '다시 시도' 버튼으로 복구되는 흐름을 확인하기 위한 것이다.
enum _MockScenario {
  success('성공', MovieLoadMode.success),
  empty('빈 목록', MovieLoadMode.empty),
  failure('실패', MovieLoadMode.failure),
  failureThenSuccess('실패 후 재시도하면 성공', MovieLoadMode.failure);

  const _MockScenario(this.label, this.mode);

  final String label;
  final MovieLoadMode mode;
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final GenrePreference _genrePreference =
      widget.genrePreference ?? GenrePreference();
  late _MockScenario _scenario = _MockScenario.values.firstWhere(
    (scenario) => scenario.mode == widget.initialMode,
  );

  // build에서 만들면 화면이 다시 그려질 때마다 요청이 반복되므로 필드로 보관한다.
  late Future<_MovieListData> _dataFuture;

  // 이번 화면에서 사용자가 직접 고른 장르. null이면 저장된 값을 사용한다.
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadInitialData();
  }

  Future<_MovieListData> _loadInitialData() async {
    try {
      // 두 작업은 서로 의존하지 않으므로 함께 시작한다.
      final results = await Future.wait<Object>([
        widget.movieService.fetchMovies(mode: _scenario.mode),
        _genrePreference.read(),
      ]);

      return _MovieListData(
        movies: results[0] as List<Movie>,
        savedGenre: results[1] as String,
      );
    } on MovieLoadException catch (error, stackTrace) {
      debugPrint('영화 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      debugPrint('영화 로드 시도 종료');
    }
  }

  // 재시도처럼 작업을 다시 시작해야 할 때만 새 Future를 만든다.
  void _retry() {
    setState(() {
      if (_scenario == _MockScenario.failureThenSuccess) {
        _scenario = _MockScenario.success;
      }
      _dataFuture = _loadInitialData();
    });
  }

  void _changeScenario(_MockScenario scenario) {
    setState(() {
      _scenario = scenario;
      _dataFuture = _loadInitialData();
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() => _selectedGenre = genre);
    await _genrePreference.save(genre);
  }

  Widget _buildScenarioMenu() {
    return PopupMenuButton<_MockScenario>(
      tooltip: '로드 상태 테스트 (디버그 전용)',
      icon: const Icon(Icons.bug_report_outlined, size: 22),
      iconColor: AppColors.textSecondary,
      initialValue: _scenario,
      onSelected: _changeScenario,
      itemBuilder: (context) => [
        for (final scenario in _MockScenario.values)
          PopupMenuItem(value: scenario, child: Text(scenario.label)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const Text('영화'),
        actions: [
          if (kDebugMode) _buildScenarioMenu(),
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search, size: 22),
            color: AppColors.textSecondary,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_MovieListData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // 재시도로 새 Future가 연결되면 이전 오류가 남아 있어도 Loading부터 보여준다.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MovieListLoading();
          }

          // 오류를 빈 목록으로 오해하지 않도록 hasError를 먼저 확인한다.
          if (snapshot.hasError) {
            return MovieListError(onRetry: _retry);
          }

          final data = snapshot.requireData;
          final selectedGenre = _selectedGenre ?? data.savedGenre;
          final filtered = filterMoviesByGenre(data.movies, selectedGenre);

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                GenreFilterChips(
                  genres: movieGenres,
                  selectedGenre: selectedGenre,
                  onSelected: _selectGenre,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const MovieListEmpty()
                      : MovieGrid(movies: filtered),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
