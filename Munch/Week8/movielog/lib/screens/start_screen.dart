import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            const Text(
              'FLUTTER 0주차',
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: ElevatedButton(
                onPressed: () => context.go('/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6750A4),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text(
                  '시작하기',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
