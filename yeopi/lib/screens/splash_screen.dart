import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/movielog_button.dart';

// 1주차 시작 화면의 로고·제목·설명 배치를 그대로 쓰고, '시작하기' 버튼 자리만 상태 표시로 바꿉니다.
// onRetry가 없으면 세션 확인 중(initializing), 있으면 확인 실패(retryRequired)입니다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 96,
                height: 96,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 24),
              const Text(
                '영화의 순간을 기록하세요',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '보고 싶은 영화부터 나만의 평점까지 한곳에서 관리해요',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              // 같은 높이를 유지해서 확인 중 → 실패로 바뀔 때 화면이 튀지 않게 합니다.
              SizedBox(
                height: 96,
                child: onRetry == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Text(
                            message ?? '로그인 상태를 확인하지 못했어요.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          MovieLogButton(
                            label: '다시 시도',
                            width: double.infinity,
                            onPressed: onRetry,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
