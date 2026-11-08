import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieLogTextFormField extends StatefulWidget {
  const MovieLogTextFormField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.errorText,
    this.successText,
    this.isVerified,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  /// ViewModel 등 밖에서 내려주는 에러 문구 (null이 아니면 에러 상태)
  final String? errorText;

  /// 확인 완료 문구 (입력창 아래에 표시)
  final String? successText;

  /// null이면 로컬 검증 기준, 값이 있으면 true일 때만 체크 아이콘 표시
  final bool? isVerified;

  /// 입력창 오른쪽에 나란히 놓을 위젯 (예: 중복 확인 버튼)
  final Widget? trailing;

  @override
  State<MovieLogTextFormField> createState() => _MovieLogTextFormFieldState();
}

class _MovieLogTextFormFieldState extends State<MovieLogTextFormField> {
  bool _obscure = true;

  OutlineInputBorder _border({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  Widget? _suffix({required bool hasError, required bool isValid}) {
    final Widget? status = hasError
        ? const Icon(Icons.error_outline, color: AppColors.error)
        : isValid
            ? const Icon(Icons.check_circle, color: AppColors.violet)
            : null;

    if (!widget.isPassword) return status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          color: AppColors.gray,
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        ?status,
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final text = widget.controller.text;
                  final hasText = text.isNotEmpty;
                  final hasError = widget.errorText != null ||
                      (hasText && widget.validator(text) != null);
                  final isValid =
                      !hasError && (widget.isVerified ?? hasText);

                  return TextFormField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    obscureText: widget.isPassword && _obscure,
                    validator: widget.validator,
                    onChanged: widget.onChanged,
                    onFieldSubmitted: widget.onFieldSubmitted,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.black),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTextStyles.bodySmall,
                      errorText: widget.errorText,
                      filled: true,
                      fillColor:
                          hasError ? AppColors.errorBg : AppColors.fieldBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: _suffix(hasError: hasError, isValid: isValid),
                      errorStyle: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                      ),
                      border: _border(),
                      enabledBorder: _border(),
                      focusedBorder:
                          _border(color: AppColors.violet, width: 1.5),
                      errorBorder: _border(color: AppColors.error),
                      focusedErrorBorder:
                          _border(color: AppColors.error, width: 1.5),
                    ),
                  );
                },
              ),
            ),
            if (widget.trailing case final trailing?) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
        if (widget.successText case final successText?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              successText,
              style: AppTextStyles.label.copyWith(
                color: AppColors.violet,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}