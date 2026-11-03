import 'package:flutter/material.dart';
import '../data/movie_data.dart';
import '../services/fake_movie_service.dart';
import '../services/genre_preference.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chip_list.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';

/// 화면이 처음 열릴 때 한 번에 받아오는 값 (영화 목록 + 저장된 장르)
class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenre,
  });

  final List<Movie> movies;
  final String selectedGenre;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();

  // 어떤 결과를 흉내 낼지 (AppBar 테스트 메뉴로 바꿀 수 있음)
  MovieLoadMode _mode = MovieLoadMode.success;

  late Future<MovieListInitialData> _initialDataFuture;

  // 사용자가 칩으로 직접 고른 장르. null이면 저장돼 있던 값을 사용
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    // Future는 build가 아니라 initState에서 한 번만 만든다
    _initialDataFuture = _loadInitialData();
  }

  Future<MovieListInitialData> _loadInitialData() async {
    try {
      // 서로 의존하지 않는 두 작업을 동시에 시작
      final results = await Future.wait([
        _movieService.fetchMovies(mode: _mode),
        _genrePreference.read(),
      ]);

      return MovieListInitialData(
        movies: results[0] as List<Movie>,
        selectedGenre: results[1] as String,
      );
    } on MovieLoadException catch (error, stackTrace) {
      // 개발자용 기록만 남기고, 화면에는 내부 정보를 보여주지 않는다
      debugPrint('영화 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow; // FutureBuilder가 오류를 알 수 있도록 다시 전달
    } finally {
      debugPrint('영화 로드 시도 종료 (mode: $_mode)');
    }
  }

  // 다시 시도: 이때만 새로운 Future를 만든다
  void _retry() {
    setState(() {
      // 가짜 서비스라서 재시도하면 성공하도록 바꿔 둔다 (재시도 성공 흐름 확인용)
      _mode = MovieLoadMode.success;
      _initialDataFuture = _loadInitialData();
    });
  }

  // 테스트 메뉴: 상태를 골라 처음부터 다시 불러온다
  void _changeMode(MovieLoadMode mode) {
    setState(() {
      _mode = mode;
      _initialDataFuture = _loadInitialData();
    });
  }

  Future<void> _onGenreSelected(String genre) async {
    await _genrePreference.save(genre); // 마지막 선택 장르 저장

    // await 사이에 화면이 사라졌을 수 있으니 확인 후 setState
    if (!mounted) return;
    setState(() => _selectedGenre = genre);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        titleStyle: AppTextStyles.titleMedium.copyWith(
          color: AppColors.violet,
        ),
        actions: [
          // 테스트용: 성공 / 빈 목록 / 실패 상태를 직접 확인
          PopupMenuButton<MovieLoadMode>(
            icon: const Icon(Icons.tune, color: AppColors.violet),
            tooltip: '상태 테스트',
            onSelected: _changeMode,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MovieLoadMode.success,
                child: Text('성공 상태'),
              ),
              PopupMenuItem(
                value: MovieLoadMode.empty,
                child: Text('빈 목록 상태'),
              ),
              PopupMenuItem(
                value: MovieLoadMode.failure,
                child: Text('실패 상태'),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: AppColors.violet),
          ),
        ],
      ),
      body: FutureBuilder<MovieListInitialData>(
        future: _initialDataFuture,
        builder: (context, snapshot) {
          // 1. 기다리는 중 → Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MovieListLoading();
          }

          // 2. 오류로 끝남 → Error (반드시 data 확인보다 먼저)
          if (snapshot.hasError) {
            return MovieListError(onRetry: _retry);
          }

          final data = snapshot.data;
          if (data == null) return const MovieListLoading();

          // 3. 정상 완료 → 선택된 장르로 걸러서 Empty 또는 Success
          final selected = _selectedGenre ?? data.selectedGenre;
          final filtered = selected == '전체'
              ? data.movies
              : data.movies.where((m) => m.genre == selected).toList();

          return Column(
            children: [
              const SizedBox(height: 8),
              GenreChipList(
                selected: selected,
                onSelected: _onGenreSelected,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const MovieListEmpty()
                    : MovieGrid(movies: filtered),
              ),
            ],
          );
        },
      ),
    );
  }
}