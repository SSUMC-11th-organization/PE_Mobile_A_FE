import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// poster_path는 파일 경로만 오므로 base URL과 크기를 붙이고, null·로드 실패는 placeholder로 대신합니다.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.size = 'w500',
  });

  final String? posterPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String size;

  static const _baseUrl = 'https://image.tmdb.org/t/p';

  String? get _imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$size$path';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    if (imageUrl == null) return _placeholder(showIcon: true);

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // 첫 프레임이 그려지기 전까지는 같은 크기의 빈 상자로 자리를 잡아 둡니다.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded
          ? _placeholder(showIcon: false)
          : child,
      errorBuilder: (context, error, stackTrace) =>
          _placeholder(showIcon: true),
    );
  }

  Widget _placeholder({required bool showIcon}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.inputFill,
      alignment: Alignment.center,
      child: showIcon
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.gray,
              semanticLabel: '포스터 이미지 없음',
            )
          : null,
    );
  }
}
