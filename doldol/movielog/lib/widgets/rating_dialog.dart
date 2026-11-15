import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

/// 저장 로직은 onSubmit으로 받는다. 예외 없이 끝나면 true, 취소하면 false를 반환한다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    required this.onSubmit,
  });

  final int initialScore;
  final String? initialComment;
  final Future<void> Function(int score, String? comment) onSubmit;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;
  // State가 살아 있는 동안 한 번만 만든다 (build에서 만들면 입력이 초기화된다)
  late final TextEditingController _commentController =
      TextEditingController(text: widget.initialComment ?? '');
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _messageOf(Object error) {
    if (error is DioException) return writeErrorMessage(error);
    if (error is StateError) return error.message;
    return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  Future<void> _onConfirm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final trimmed = _commentController.text.trim();
    if (trimmed.length > 500) {
      setState(() {
        _isSubmitting = false;
        _errorText = '코멘트는 500자 이하로 입력해 주세요.';
      });
      return;
    }

    try {
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 입력(별점, 코멘트)은 그대로 유지하고 버튼 상태만 되돌린다
      setState(() {
        _isSubmitting = false;
        _errorText = _messageOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting, // 저장 중 뒤로가기 차단
      child: Dialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  '평점을 남겨주세요',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: MovieRatingInput(
                  rating: _score.toDouble(),
                  enabled: !_isSubmitting,
                  onChanged: (value) => setState(
                    () => _score = validateServerScore(value),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '코멘트 (선택, 최대 500자)',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.gray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 500,
                enabled: !_isSubmitting,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.black),
                decoration: InputDecoration(
                  hintText: '이 영화의 인상적인 장면은...',
                  hintStyle: AppTextStyles.bodySmall,
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF9F7FD),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.starEmpty,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.starEmpty,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.violet,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (_errorText case final errorText?) ...[
                const SizedBox(height: 8),
                Text(
                  errorText,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      width: double.infinity,
                      radius: 24,
                      backgroundColor: AppColors.lavender,
                      foregroundColor: AppColors.deepViolet,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      label: '확인',
                      width: double.infinity,
                      radius: 24,
                      disabledColor: AppColors.disabledViolet,
                      isLoading: _isSubmitting,
                      // 별점을 선택해야 활성화된다
                      onPressed: _score > 0 ? _onConfirm : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}