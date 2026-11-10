import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// 다중 삭제처럼 Dialog가 닫힌 뒤 진행되는 작업 동안 화면 위에 어두운 막과 인디케이터만 올려 입력을 막습니다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const ModalBarrier(dismissible: false, color: Colors.black45),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          ),
      ],
    );
  }
}
