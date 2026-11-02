import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// `poster_path` URL 조합, null 처리, 로드 실패 placeholder를 한 곳에서 처리한다.
/// [width]·[height]를 비우면 부모 크기를 채운다.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.size = 'w500',
  });

  static const _baseUrl = 'https://image.tmdb.org/t/p';

  final String? posterPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String size;

  String? get _imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$size$path';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    if (imageUrl == null) return _placeholder();

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.skeleton,
      alignment: Alignment.center,
      child: loading
          ? null
          : const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.gray,
              size: 32,
            ),
    );
  }
}
