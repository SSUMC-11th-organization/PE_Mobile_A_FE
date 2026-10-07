import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MoviePoster extends StatelessWidget {
  const MoviePoster({
    super.key,
    required this.asset,
    this.width,
    this.height,
  });

  final String asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.cover,
      // 파일이 없어도 앱이 죽지 않도록 대체 화면 표시
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: AppColors.cardBorder,
          alignment: Alignment.center,
          child: const Icon(
            Icons.movie_outlined,
            color: AppColors.gray,
            size: 32,
          ),
        );
      },
    );
  }
}