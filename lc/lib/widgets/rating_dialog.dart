import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../theme/app_colors.dart';
import '../view_models/submit_status.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

/// 별점과 코멘트를 입력받아 저장까지 마치는 Dialog.
///
/// 저장 로직은 [onSubmit]으로 받아 Dialog 안에서 실행한다. 예외 없이 끝나면 true를,
/// 취소하면 onSubmit을 호출하지 않고 false를 돌려준다. 저장 중에는 뒤로가기·중복 탭·입력 변경을
/// 막고, 실패하면 입력을 그대로 둔 채 오류 문구만 보여줘 다시 시도할 수 있게 한다.
/// (호출하는 쪽은 바깥 탭으로 닫히지 않도록 showDialog에 barrierDismissible: false를 함께 준다.)
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.onSubmit,
    this.initialScore = 0,
    this.initialComment,
    this.title = '영화는 어떠셨나요?',
  });

  final int initialScore;
  final String? initialComment;
  final String title;
  final Future<void> Function(int score, String? comment) onSubmit;

  static const maxCommentLength = 500;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;
  // build()마다 새로 만들면 별점을 누를 때마다 입력 중이던 코멘트가 지워진다. State당 한 번만 만든다.
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > RatingDialog.maxCommentLength) {
      setState(
        () => _errorText = '코멘트는 ${RatingDialog.maxCommentLength}자 이하로 입력해 주세요.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 버튼을 로딩에 남기지 않고, 입력은 그대로 둔 채 다시 시도할 수 있게 한다.
      setState(() {
        _isSubmitting = false;
        _errorText = error is RatingWriteException
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF25232A),
                ),
              ),
              const SizedBox(height: 24),
              MovieRatingInput(
                rating: _score.toDouble(),
                enabled: !_isSubmitting,
                onChanged: (value) =>
                    setState(() => _score = validateServerScore(value)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: RatingDialog.maxCommentLength,
                decoration: InputDecoration(
                  hintText: '코멘트를 남겨보세요 (선택)',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MovieLogButton(
                      label: '확인',
                      width: double.infinity,
                      isLoading: _isSubmitting,
                      // 별점을 고르기 전에는 코멘트를 입력했더라도 확인을 누를 수 없다.
                      onPressed: _score > 0 && !_isSubmitting
                          ? _onConfirm
                          : null,
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
