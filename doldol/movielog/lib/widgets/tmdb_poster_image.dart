import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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

  /// null이거나 빈 문자열이면 null (이미지 주소를 만들 수 없음)
  String? get _imageUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$_size$path';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;

    // 포스터 경로가 없으면 네트워크 요청 없이 바로 placeholder
    if (imageUrl == null) return _placeholder();

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // 받아오는 동안 표시
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _box(
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.violet,
            ),
          ),
        );
      },
      // 주소가 틀렸거나 네트워크 오류일 때 표시
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return _box(
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.gray,
        size: 32,
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.cardBorder,
      alignment: Alignment.center,
      child: child,
    );
  }
}