import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 여러 화면이 함께 쓰는 공용 버튼.
///
/// 상태를 스스로 바꾸지 않고, View가 전달한 값으로 세 가지 상태만 표시한다.
/// - 기본: [onPressed]가 있고 [isLoading]이 false
/// - 통신 중: [isLoading]이 true → 회색 배경 + 중앙 인디케이터, 누를 수 없음
/// - 비활성: [onPressed]가 null
///
/// [width]
/// - null: 라벨 길이에 맞는 내용 기반 크기 (입력창 옆 보조 버튼)
/// - double.infinity: 부모가 허용하는 최대 너비 (Form 하단 제출 버튼)
/// - 고정 값: 항상 같은 크기
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: AppColors.white,
          // 통신 중에는 회색, 조건 미충족 비활성은 연한 보라색으로 구분한다.
          disabledBackgroundColor: isLoading
              ? AppColors.gray
              : AppColors.violet.withValues(alpha: 0.3),
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        // 라벨과 인디케이터는 동시에 그리지 않고 하나만 선택한다.
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
