import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

// 저장은 onSubmit으로 받아 Dialog 안에서 실행합니다. 성공하면 true, 취소하면 false를 돌려줍니다.
// 저장이 실패하면 Dialog를 닫지 않고 입력한 별점·코멘트를 그대로 둔 채 안내 문구를 보여줍니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.movieTitle,
    required this.onSubmit,
    this.initialScore,
    this.initialComment,
  });

  final String movieTitle;
  final Future<void> Function(int score, String? comment) onSubmit;
  final int? initialScore;
  final String? initialComment;

  static const maxCommentLength = 500;

  bool get isEdit => initialScore != null;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _score = (widget.initialScore ?? 0).toDouble();
  // Controller는 State에 한 번만 만들어 Dialog가 다시 그려져도 입력이 초기화되지 않게 합니다.
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

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final comment = _commentController.text.trim();
    try {
      await widget.onSubmit(
        validateServerScore(_score),
        comment.isEmpty ? null : comment,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 저장 중에는 뒤로가기로 닫히지 않게 막습니다. (바깥 탭은 showDialog의 barrierDismissible: false로 막습니다.)
    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isEdit ? '평점을 수정할까요?' : '영화는 어떠셨나요?',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(widget.movieTitle, style: AppTextStyles.bodySmall),
              const SizedBox(height: 24),
              MovieRatingInput(
                rating: _score,
                enabled: !_isSubmitting,
                onChanged: (value) => setState(() => _score = value),
              ),
              const SizedBox(height: 8),
              Text(
                _score == 0 ? '별을 눌러 평점을 선택해주세요' : '${_score.toInt()}점',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLength: RatingDialog.maxCommentLength,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: '코멘트를 남겨주세요 (선택)',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
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
                    // 별점을 고르기 전에는 코멘트를 써도 저장할 수 없습니다.
                    child: MovieLogButton(
                      label: widget.isEdit ? '수정' : '저장',
                      width: double.infinity,
                      isLoading: _isSubmitting,
                      onPressed: _score > 0 ? _submit : null,
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
