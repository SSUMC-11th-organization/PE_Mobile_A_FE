import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/paged_movies_view_model.dart';
import '../widgets/paged_movie_body.dart';

/// 영화 검색. 입력이 멈춘 뒤(debounce)에만 TMDB 검색을 호출한다.
class MovieSearchScreen extends StatelessWidget {
  const MovieSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PagedMoviesViewModel>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로가기',
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/movies'),
        ),
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '영화 제목을 검색하세요',
            border: InputBorder.none,
          ),
          onChanged: viewModel.onQueryChanged,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: PagedMovieBody(
          viewModel: viewModel,
          idleMessage: '검색어를 입력하세요.',
          emptyMessage: '검색 결과가 없어요.',
        ),
      ),
    );
  }
}
