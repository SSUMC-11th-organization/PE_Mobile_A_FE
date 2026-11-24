import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieLogTextFormField extends StatefulWidget {
  const MovieLogTextFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.validator,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscurable = false,
    this.onFieldSubmitted,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.helperColor,
    this.isConfirmed,
    this.trailing,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscurable;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  final String? errorText;

  final String? helperText;
  final Color? helperColor;

  final bool? isConfirmed;

  final Widget? trailing;

  @override
  State<MovieLogTextFormField> createState() => _MovieLogTextFormFieldState();
}

class _MovieLogTextFormFieldState extends State<MovieLogTextFormField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() => setState(() {});

  void _toggleObscureText() => setState(() => _obscureText = !_obscureText);

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final localError = text.isEmpty ? null : widget.validator(text);
    final serverError = widget.errorText;
    final hasError = localError != null || serverError != null;
    final isValid =
        text.isNotEmpty && !hasError && (widget.isConfirmed ?? true);

    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscurable && _obscureText,
      validator: widget.validator,
      // 서버 에러가 있으면 validator 통과 여부와 관계없이 에러 상태로 보여준다.
      forceErrorText: serverError == null ? null : (localError ?? serverError),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: const TextStyle(fontSize: 16, color: AppColors.black),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(fontSize: 16, color: AppColors.gray),
        filled: true,
        fillColor: hasError ? AppColors.errorContainer : AppColors.fieldFill,
        suffixIcon: _buildSuffixIcon(hasError: hasError, isValid: isValid),
        helperText: widget.helperText,
        helperStyle: TextStyle(
          color: widget.helperColor ?? AppColors.gray,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        if (widget.trailing == null)
          field
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon({required bool hasError, required bool isValid}) {
    final icons = <Widget>[];

    if (widget.obscurable) {
      icons.add(
        _IconButtonSvg(
          asset: _obscureText
              ? 'assets/icons/visibility_off.svg'
              : 'assets/icons/visibility.svg',
          color: AppColors.gray,
          onPressed: _toggleObscureText,
        ),
      );
    }

    if (hasError || isValid) {
      icons.add(
        _StatusSvgIcon(
          asset: hasError
              ? 'assets/icons/error.svg'
              : 'assets/icons/check_circle.svg',
          color: hasError ? AppColors.error : AppColors.violet,
        ),
      );
    }

    if (icons.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
}

class _StatusSvgIcon extends StatelessWidget {
  const _StatusSvgIcon({required this.asset, required this.color});

  final String asset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

class _IconButtonSvg extends StatelessWidget {
  const _IconButtonSvg({
    required this.asset,
    required this.color,
    required this.onPressed,
  });

  final String asset;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
      onPressed: onPressed,
      splashRadius: 20,
    );
  }
}
