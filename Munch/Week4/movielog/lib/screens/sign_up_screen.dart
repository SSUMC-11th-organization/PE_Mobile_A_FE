import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_text_form_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = true;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_handleFormChanged);
    _emailController.addListener(_handleFormChanged);
    _passwordController.addListener(_handleFormChanged);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleFormChanged() => setState(() {});

  String? _validateNickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < 2) return '닉네임은 2자 이상이어야 합니다.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
    return null;
  }

  bool get _canSubmit =>
      _validateNickname(_nicknameController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      _validatePassword(_passwordController.text) == null &&
      _agreedToTerms;

  void _handleSubmit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다.')));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '회원가입', centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 560 : double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SignUpIntro(),
                          const SizedBox(height: 40),
                          MovieLogTextFormField(
                            label: '닉네임',
                            hintText: '닉네임을 입력해주세요',
                            controller: _nicknameController,
                            validator: _validateNickname,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _emailFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          MovieLogTextFormField(
                            label: '이메일',
                            hintText: '이메일 주소를 입력해주세요',
                            controller: _emailController,
                            validator: _validateEmail,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          MovieLogTextFormField(
                            label: '비밀번호',
                            hintText: '비밀번호를 입력해주세요',
                            controller: _passwordController,
                            validator: _validatePassword,
                            focusNode: _passwordFocusNode,
                            obscurable: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (_canSubmit) _handleSubmit();
                            },
                          ),
                          const SizedBox(height: 40),
                          _TermsAgreement(
                            value: _agreedToTerms,
                            onChanged: (value) =>
                                setState(() => _agreedToTerms = value),
                          ),
                          const SizedBox(height: 24),
                          _SignUpSubmitButton(
                            enabled: _canSubmit,
                            onPressed: _handleSubmit,
                          ),
                          const SizedBox(height: 24),
                          const _LoginPrompt(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignUpIntro extends StatelessWidget {
  const _SignUpIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('환영합니다!', style: AppTextStyles.titleMedium),
        SizedBox(height: 8),
        Text(
          '간단한 정보만 입력하고 시작해보세요.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TermsAgreement extends StatelessWidget {
  const _TermsAgreement({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.violet,
          onChanged: (checked) => onChanged(checked ?? false),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: const Text(
            '필수 약관에 동의합니다',
            style: TextStyle(fontSize: 15, color: AppColors.black),
          ),
        ),
      ],
    );
  }
}

class _SignUpSubmitButton extends StatelessWidget {
  const _SignUpSubmitButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.violet,
        disabledBackgroundColor: AppColors.violet.withValues(alpha: 0.35),
        foregroundColor: AppColors.white,
        disabledForegroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        '가입하기',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '이미 계정이 있나요? ',
          style: TextStyle(fontSize: 14, color: AppColors.gray),
        ),
        GestureDetector(
          onTap: () {},
          child: const Text(
            '로그인',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.violet,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
