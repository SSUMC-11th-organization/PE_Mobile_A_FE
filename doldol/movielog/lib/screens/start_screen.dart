import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:go_router/go_router.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('FLUTTER 1주차', style: AppTextStyles.label),
              const Spacer(flex: 1),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 72,
                height: 72,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 32),
              Text(
                '영화의 순간을\n기록하세요',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 12),
              Text(
                '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.black),
              ),
              const Spacer(flex: 5),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/register'), // 1주차는 모양만
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepViolet,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('시작하기'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}