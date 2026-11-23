import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

// 내 즐겨찾기·검색 결과에서 쓰는 가로형 영화 카드
class MovieRowCard extends StatelessWidget {
  const MovieRowCard({
    super.key,
    required this.title,
    required this.posterPath,
    this.subtitle,
    this.caption,
    this.action,
    this.onTap,
  });

  final String title;
  final String? posterPath;
  final String? subtitle;
  final String? caption;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final caption = this.caption;
    final action = this.action;

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.skeleton, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TmdbPosterImage(
                  posterPath: posterPath,
                  width: 78,
                  height: 116,
                  size: 'w185',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium,
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.gray,
                          ),
                        ),
                      ],
                      if (caption != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          caption,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.violet,
                          ),
                        ),
                      ],
                      ?action,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
