import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/rating_input.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '평점 남기기'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                '이 영화, 어떠셨나요?',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 24),
              Center(
                child: RatingInput(
                  onChanged: (value) => setState(() => _rating = value),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _rating == 0 ? '별을 눌러 선택해 주세요' : '내 평점 $_rating',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _rating > 0 ? () {} : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepViolet,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.cardBorder,
                    disabledForegroundColor: AppColors.gray,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('평점 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}