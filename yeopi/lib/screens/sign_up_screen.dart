import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../utils/sign_up_validators.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/sign_up_button.dart';
import '../widgets/sign_up_header.dart';
import '../widgets/terms_agreement.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controller와 FocusNode는 build가 아닌 State에서 한 번만 생성합니다.
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      SignUpValidators.nickname(_nicknameController.text) == null &&
      SignUpValidators.email(_emailController.text) == null &&
      SignUpValidators.password(_passwordController.text) == null &&
      _agreedToTerms;

  void _submit() {
    // 버튼 활성화 조건과 별개로 제출 시 Form 전체를 다시 검증합니다.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다.')));
    // 홈에서 뒤로 가기로 회원가입이 다시 나오지 않도록 push가 아닌 go를 씁니다.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '회원가입', centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            // 버튼이 비활성일 때도 오류가 보이도록, 입력한 칸은 바로 검사합니다.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SignUpHeader(),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nicknameController,
                  decoration: _inputDecoration(
                    label: '닉네임',
                    hint: '영화로운 닉네임을 입력하세요',
                    icon: Icons.person_outline,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: SignUpValidators.nickname,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  decoration: _inputDecoration(
                    label: '이메일',
                    hint: 'example@movielog.com',
                    icon: Icons.mail_outline,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: SignUpValidators.email,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  decoration: _inputDecoration(
                    label: '비밀번호',
                    hint: '8자 이상 입력하세요',
                    icon: Icons.lock_outline,
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: SignUpValidators.password,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 16),
                TermsAgreement(
                  value: _agreedToTerms,
                  onChanged: (value) => setState(() => _agreedToTerms = value),
                ),
                const SizedBox(height: 24),
                SignUpButton(onPressed: _canSubmit ? _submit : null),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.inputFill,
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.violet, 2),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 2),
    );
  }
}
