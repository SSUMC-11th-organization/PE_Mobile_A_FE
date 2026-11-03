import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// poster_path 조합, null 처리, 로드 실패 처리를 한 곳에 모은 포스터 위젯.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String? posterPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  static const _baseUrl = 'https://image.tmdb.org/t/p';
  static const _size = 'w500';

  String? get _imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$_size$path';
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
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(showIcon: false),
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder({bool showIcon = true}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: showIcon
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textSecondary,
            )
          : null,
    );
  }
}
