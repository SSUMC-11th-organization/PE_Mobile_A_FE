import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../widgets/movielog_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'FLUTTER 8주차',
              style: TextStyle(
                fontSize: 11,
                height: 16 / 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
                color: Color(0xFF625B71),
              ),
            ),
            const SizedBox(height: 88),
            SvgPicture.asset(
              'assets/logos/movielog_logo.svg',
              width: 72,
              height: 72,
              semanticsLabel: 'MovieLog 로고',
            ),
            const SizedBox(height: 88),
            const Text(
              '영화의 순간을\n기록하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                height: 36 / 28,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1B1C1A),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '보고 싶은 영화부터 나만의 평점까지\n한 곳에서 관리해요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF625B71),
              ),
            ),
            const Spacer(),
            // 1주차 '시작하기' 버튼 자리를 세션 확인 중/재시도 상태로 대체한다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: onRetry == null
                  ? const SizedBox(
                      height: 60,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Text(
                          message ?? '로그인 상태를 확인하지 못했어요.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF625B71),
                          ),
                        ),
                        const SizedBox(height: 16),
                        MovieLogButton(
                          label: '다시 시도',
                          width: double.infinity,
                          height: 48,
                          onPressed: onRetry,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
