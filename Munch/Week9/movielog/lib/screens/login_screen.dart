import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/storage/saved_email_storage.dart';
import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/movielog_text_form_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthViewModel _auth;
  late final SavedEmailStorage _savedEmail;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _savedEmail = context.read<SavedEmailStorage>();
    _auth.addListener(_showSessionExpired);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final email = await _savedEmail.read();
      if (!mounted || email == null || email.isEmpty) return;
      if (_email.text.isEmpty) _email.text = email;
      setState(() => _rememberEmail = true);
    } catch (_) {
      // 이메일 자동 입력은 편의 기능이므로 실패해도 로그인은 그대로 진행한다.
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')));
  }

  Future<void> _submit() async {
    // 서버 오류 문구(forceErrorText)가 남아 있어도 같은 값으로 재시도할 수 있게 직접 검사한다.
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    await _auth.login(email, _password.text);
    if (_auth.status != AuthStatus.signedIn) return;
    try {
      if (_rememberEmail) {
        await _savedEmail.save(email);
      } else {
        await _savedEmail.clear();
      }
    } catch (_) {
      // 이메일 저장 실패는 로그인 결과에 영향을 주지 않는다.
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: const CommonAppBar(title: '로그인', centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 64),
                Center(
                  child: SvgPicture.asset(
                    'assets/logos/movielog_logo.svg',
                    width: 64,
                    height: 64,
                    semanticsLabel: 'MovieLog 로고',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, color: AppColors.black),
                ),
                const SizedBox(height: 40),
                AbsorbPointer(
                  absorbing: !enabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MovieLogTextFormField(
                        label: '이메일',
                        hintText: '이메일을 입력해 주세요',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => auth.clearMessage(),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? '이메일을 입력해 주세요.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      MovieLogTextFormField(
                        label: '비밀번호',
                        hintText: '비밀번호를 입력해 주세요',
                        controller: _password,
                        obscurable: true,
                        textInputAction: TextInputAction.done,
                        errorText: auth.message,
                        onChanged: (_) => auth.clearMessage(),
                        onFieldSubmitted: (_) {
                          if (enabled) _submit();
                        },
                        validator: (value) =>
                            (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                      ),
                      const SizedBox(height: 16),
                      _RememberEmailCheckbox(
                        value: _rememberEmail,
                        onChanged: (value) =>
                            setState(() => _rememberEmail = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  height: 48,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '계정이 없나요?',
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                    TextButton(
                      onPressed: enabled
                          ? () => context.push('/register')
                          : null,
                      child: const Text(
                        '회원가입',
                        style: TextStyle(color: AppColors.violet),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RememberEmailCheckbox extends StatelessWidget {
  const _RememberEmailCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: AppColors.violet,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
          const Text(
            '이메일 저장',
            style: TextStyle(fontSize: 14, color: AppColors.black),
          ),
        ],
      ),
    );
  }
}
