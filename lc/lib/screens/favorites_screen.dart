import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_list_item.dart';
import '../models/movie_detail_args.dart';
import '../theme/app_colors.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/tmdb_poster_image.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('내 즐겨찾기')),
      body: switch (vm.phase) {
        LoadPhase.idle || LoadPhase.loading => const MovieListLoading(),
        LoadPhase.error => MovieListError(message: vm.message, onRetry: vm.load),
        LoadPhase.empty => const MovieListEmpty(),
        LoadPhase.ready => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vm.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _FavoriteTile(item: vm.items[index], onReturn: vm.load),
        ),
      },
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.item, required this.onReturn});

  final FavoriteListItem item;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final movie = item.movie;
    return ListTile(
      tileColor: AppColors.violetback,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: movie == null
          ? const Icon(Icons.movie_outlined)
          : SizedBox(
              width: 40,
              child: TmdbPosterImage(posterPath: movie.posterPath),
            ),
      title: Text(movie?.title ?? '영화 #${item.favorite.movieId}'),
      subtitle: item.errorMessage == null ? null : Text(item.errorMessage!),
      onTap: () async {
        // 상세에서 즐겨찾기를 해제하고 돌아오면 목록을 서버에서 다시 받는다.
        final id = item.favorite.movieId;
        await context.push(
          '/movies/$id',
          extra: movie == null ? null : MovieDetailArgs(movie: movie),
        );
        await onReturn();
      },
    );
  }
}
