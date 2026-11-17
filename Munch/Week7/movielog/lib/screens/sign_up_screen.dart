import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_member_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
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
    if (nickname.length > 12) return '닉네임은 12자 이하여야 합니다.';
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
    if (password != password.trim()) return '비밀번호 앞뒤에는 공백을 넣을 수 없습니다.';
    final hasAllKinds =
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*]').hasMatch(password);
    if (!hasAllKinds) return '비밀번호는 대문자/소문자/숫자/특수문자를 모두 포함해야 합니다.';
    return null;
  }

  bool _canSubmit(SignUpViewModel viewModel) =>
      _validateNickname(_nicknameController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      _validatePassword(_passwordController.text) == null &&
      viewModel.isNicknameAvailable &&
      viewModel.isEmailAvailable &&
      _agreedToTerms &&
      viewModel.submitStatus != SubmitStatus.submitting;

  Future<void> _handleSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final viewModel = context.read<SignUpViewModel>();
    if (!isValid || !_canSubmit(viewModel)) return;

    FocusScope.of(context).unfocus();
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    if (!mounted) return;

    final memberId = viewModel.createdMemberId;
    if (viewModel.submitStatus == SubmitStatus.success && memberId != null) {
      context.read<LearningMemberSession>().setMemberId(memberId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입이 완료되었습니다. (memberId: $memberId)')),
      );
      context.go('/movies');
      return;
    }

    final message = viewModel.snackbarMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static const double _checkButtonHeight = 48;

  String? _checkHelperText(CheckStatus status, String fieldName) {
    return switch (status) {
      CheckStatus.checking => '$fieldName 사용 가능 여부를 확인 중입니다.',
      CheckStatus.available => '사용 가능한 $fieldName입니다.',
      _ => null,
    };
  }

  Color? _checkHelperColor(CheckStatus status) {
    return switch (status) {
      CheckStatus.checking => AppColors.info,
      CheckStatus.available => AppColors.success,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignUpViewModel>();

    return PopScope(
      canPop: viewModel.submitStatus != SubmitStatus.submitting,
      child: Scaffold(
        appBar: const CommonAppBar(title: '회원가입', centerTitle: true),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                              onChanged: viewModel.onNicknameChanged,
                              onFieldSubmitted: (_) =>
                                  _emailFocusNode.requestFocus(),
                              errorText: viewModel.nicknameErrorText,
                              isConfirmed: viewModel.isNicknameAvailable,
                              helperText: _checkHelperText(
                                viewModel.nicknameCheckStatus,
                                '닉네임',
                              ),
                              helperColor: _checkHelperColor(
                                viewModel.nicknameCheckStatus,
                              ),
                              trailing: MovieLogButton(
                                label: '중복 확인',
                                height: _checkButtonHeight,
                                isLoading:
                                    viewModel.nicknameCheckStatus ==
                                    CheckStatus.checking,
                                onPressed:
                                    viewModel.canCheckNickname &&
                                        _validateNickname(
                                              _nicknameController.text,
                                            ) ==
                                            null
                                    ? () => viewModel.checkNickname(
                                        _nicknameController.text,
                                      )
                                    : null,
                              ),
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
                              onChanged: viewModel.onEmailChanged,
                              onFieldSubmitted: (_) =>
                                  _passwordFocusNode.requestFocus(),
                              errorText: viewModel.emailErrorText,
                              isConfirmed: viewModel.isEmailAvailable,
                              helperText: _checkHelperText(
                                viewModel.emailCheckStatus,
                                '이메일',
                              ),
                              helperColor: _checkHelperColor(
                                viewModel.emailCheckStatus,
                              ),
                              trailing: MovieLogButton(
                                label: '중복 확인',
                                height: _checkButtonHeight,
                                isLoading:
                                    viewModel.emailCheckStatus ==
                                    CheckStatus.checking,
                                onPressed:
                                    viewModel.canCheckEmail &&
                                        _validateEmail(_emailController.text) ==
                                            null
                                    ? () => viewModel.checkEmail(
                                        _emailController.text,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            MovieLogTextFormField(
                              label: '비밀번호',
                              hintText: '비밀번호를 입력해주세요',
                              controller: _passwordController,
                              validator: _validatePassword,
                              focusNode: _passwordFocusNode,
                              obscurable: true,
                              errorText: viewModel.passwordErrorText,
                              onChanged: (_) => viewModel.onPasswordChanged(),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (_canSubmit(viewModel)) _handleSubmit();
                              },
                            ),
                            const SizedBox(height: 40),
                            _TermsAgreement(
                              value: _agreedToTerms,
                              onChanged: (value) =>
                                  setState(() => _agreedToTerms = value),
                            ),
                            const SizedBox(height: 24),
                            MovieLogButton(
                              label: '가입하기',
                              width: double.infinity,
                              height: 52,
                              isLoading:
                                  viewModel.submitStatus ==
                                  SubmitStatus.submitting,
                              onPressed: _canSubmit(viewModel)
                                  ? _handleSubmit
                                  : null,
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
