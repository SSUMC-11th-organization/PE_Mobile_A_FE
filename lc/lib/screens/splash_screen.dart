import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/movielog_button.dart';

/// 앱 시작 시 세션을 확인하는 동안 보여주는 화면. 1주차 시작 화면의 레이아웃을 재사용한다.
/// [onRetry]가 없으면 확인 중(인디케이터), 있으면 확인 실패(다시 시도 버튼)다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'FLUTTER 8주차',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.gray,
                ),
              ),
              const SizedBox(height: 80),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 120,
                height: 120,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 48),
              const Text(
                '영화의 순간을\n기록하세요',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const Spacer(),
              // 1주차의 '시작하기' 버튼 자리를 로딩/재시도 상태로 대체한다.
              if (onRetry == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: CircularProgressIndicator(color: AppColors.violet),
                )
              else ...[
                Text(
                  message ?? '로그인 상태를 확인하지 못했어요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                MovieLogButton(
                  label: '다시 시도',
                  width: double.infinity,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
