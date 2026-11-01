import 'package:flutter/material.dart';

import 'movie_card_skeleton.dart';
import 'movie_grid.dart';

class MovieListLoading extends StatefulWidget {
  const MovieListLoading({super.key, this.showGenreSkeleton = true});

  static const skeletonCount = 6;

  /// 장르 Chip이 이미 화면에 있으면 false로 두어 Grid skeleton만 그린다.
  final bool showGenreSkeleton;

  @override
  State<MovieListLoading> createState() => _MovieListLoadingState();
}

class _MovieListLoadingState extends State<MovieListLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.4,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Column(
        children: [
          if (widget.showGenreSkeleton)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    const SkeletonBox(width: 64, radius: 20),
              ),
            ),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: MovieGrid.padding,
              itemCount: MovieListLoading.skeletonCount,
              gridDelegate: MovieGrid.gridDelegate,
              itemBuilder: (context, index) => const MovieCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}
