import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

class ButtonPreviewScreen extends StatelessWidget {
  const ButtonPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'MovieLogButton',
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _SectionTitle('width'),
            _Example(
              label: 'null',
              child: Row(
                children: [
                  const Expanded(child: _FakeField()),
                  const SizedBox(width: 8),
                  MovieLogButton(label: '중복 확인', onPressed: () {}),
                ],
              ),
            ),
            _Example(
              label: 'double.infinity',
              child: MovieLogButton(
                label: '가입하기',
                width: double.infinity,
                onPressed: () {},
              ),
            ),
            _Example(
              label: '96',
              child: Align(
                alignment: Alignment.centerLeft,
                child: MovieLogButton(label: '확인', width: 96, onPressed: () {}),
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('상태'),
            _Example(
              label: '기본',
              child: Align(
                alignment: Alignment.centerLeft,
                child: MovieLogButton(label: '중복 확인', onPressed: () {}),
              ),
            ),
            const _Example(
              label: '통신 중',
              child: Align(
                alignment: Alignment.centerLeft,
                child: MovieLogButton(
                  label: '중복 확인',
                  isLoading: true,
                  onPressed: null,
                ),
              ),
            ),
            const _Example(
              label: '비활성',
              child: Align(
                alignment: Alignment.centerLeft,
                child: MovieLogButton(label: '중복 확인', onPressed: null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: AppTextStyles.titleMedium),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FakeField extends StatelessWidget {
  const _FakeField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
