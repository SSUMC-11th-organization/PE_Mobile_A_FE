import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

// 닉네임과 그 아래 한 줄 안내(가입일 등)는 GET me 결과를 받아서 보여줍니다.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.nickname, this.caption});

  final String nickname;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 44,
          backgroundImage: AssetImage(
            'assets/images/profile/profile_movielog.jpg',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleLarge,
              ),
            ),
            const SizedBox(width: 6),
            SvgPicture.asset(
              'assets/icons/movie.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.violet,
                BlendMode.srcIn,
              ),
              semanticsLabel: '영화 아이콘',
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
          ),
        ],
      ],
    );
  }
}
