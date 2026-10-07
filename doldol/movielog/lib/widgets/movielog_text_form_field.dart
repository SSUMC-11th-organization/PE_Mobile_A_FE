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
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final text = widget.controller.text;
            final hasText = text.isNotEmpty;
            final hasError = hasText && widget.validator(text) != null;
            final isValid = hasText && !hasError;

            return TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              obscureText: widget.isPassword && _obscure,
              validator: widget.validator,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onFieldSubmitted,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.bodySmall,
                filled: true,
                fillColor: hasError ? AppColors.errorBg : AppColors.fieldBg,
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
                focusedBorder: _border(color: AppColors.violet, width: 1.5),
                errorBorder: _border(color: AppColors.error),
                focusedErrorBorder:
                    _border(color: AppColors.error, width: 1.5),
              ),
            );
          },
        ),
      ],
    );
  }
}