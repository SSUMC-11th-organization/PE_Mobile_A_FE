import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MovieCardSkeleton extends StatelessWidget {
  const MovieCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SkeletonBox(radius: 12)),
        SizedBox(height: 10),
        SkeletonBox(width: 120, height: 18),
        SizedBox(height: 6),
        SkeletonBox(width: 80, height: 14),
      ],
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 6});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
