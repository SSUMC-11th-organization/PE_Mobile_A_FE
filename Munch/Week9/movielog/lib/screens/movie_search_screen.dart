import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_page_footer.dart';
import '../widgets/movie_row_card.dart';
import '../widgets/movielog_button.dart';

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PagedMoviesViewModel>().loadGenres();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  // 글자마다 요청하지 않고 제출할 때만 page 1부터 검색한다.
  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }
    setState(() => _inputError = null);
    FocusScope.of(context).unfocus();
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 검색',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: '영화 제목을 입력하세요',
                  errorText: _inputError,
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: TextButton(
                    onPressed: () => _submit(_text.text),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.violet,
                    ),
                    child: const Text('검색'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Consumer<PagedMoviesViewModel>(
                builder: (context, vm, _) => switch (vm.phase) {
                  LoadPhase.idle => const _CenterText('검색어를 입력해 영화를 찾아보세요.'),
                  LoadPhase.loading => const Center(
                    child: CircularProgressIndicator(color: AppColors.violet),
                  ),
                  LoadPhase.empty => const _CenterText('검색 결과가 없습니다.'),
                  LoadPhase.error => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vm.errorMessage ?? '검색 결과를 불러오지 못했습니다.',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 20),
                        MovieLogButton(
                          label: '다시 시도',
                          width: 220,
                          onPressed: vm.reload,
                        ),
                      ],
                    ),
                  ),
                  LoadPhase.ready => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    itemCount: vm.movies.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == vm.movies.length) {
                        return MoviePageFooter(vm: vm, label: '검색 결과 더 보기');
                      }
                      final movie = vm.movies[index];
                      return MovieRowCard(
                        key: ValueKey(movie.id),
                        title: movie.title,
                        posterPath: movie.posterPath,
                        subtitle: _subtitleOf(movie, vm.genreNames),
                        onTap: () => widget.onOpenMovie(movie),
                      );
                    },
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitleOf(TmdbMovieDto movie, Map<int, String> genreNames) {
    final genres = movie.genreIds
        .map((id) => genreNames[id])
        .whereType<String>()
        .take(2);
    return [?releaseYearOf(movie.releaseDate), ...genres].join(' · ');
  }
}

class _CenterText extends StatelessWidget {
  const _CenterText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: AppTextStyles.titleMedium));
  }
}
