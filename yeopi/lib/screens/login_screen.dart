import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/login_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/movielog_button.dart';

// 로그인 화면은 AuthViewModel.login()만 호출하고 직접 이동하지 않습니다.
// 성공하면 상태가 signedIn이 되고 Router가 /home으로 보냅니다.
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
  late final LoginPreferences _preferences;
  bool _saveEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _preferences = context.read<LoginPreferences>();
    // 화면이 열려 있는 동안 만료되는 경우와, 이미 만료된 상태로 처음 열리는 경우를 모두 처리합니다.
    _auth.addListener(_showSessionExpired);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final saved = await _preferences.readSavedEmail();
      if (!mounted || saved == null || saved.isEmpty) return;
      // 사용자가 이미 입력하기 시작했다면 덮어쓰지 않습니다.
      if (_email.text.isEmpty) _email.text = saved;
      setState(() => _saveEmail = true);
    } catch (_) {
      // 저장된 이메일을 못 읽어도 로그인은 할 수 있으므로 무시합니다.
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    // 같은 Snackbar가 반복되지 않도록 먼저 끕니다.
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    // 체크했을 때만 이메일을 남기고, 해제하면 지웁니다. 비밀번호는 어디에도 저장하지 않습니다.
    try {
      if (_saveEmail) {
        await _preferences.saveEmail(email);
      } else {
        await _preferences.clearSavedEmail();
      }
    } catch (_) {
      // 이메일 저장 실패는 로그인을 막을 이유가 아닙니다.
    }
    await _auth.login(email, _password.text);
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
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                SvgPicture.asset(
                  'assets/logos/movielog_logo.svg',
                  width: 84,
                  height: 84,
                  semanticsLabel: 'MovieLog 로고',
                ),
                const SizedBox(height: 24),
                Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? '이메일을 입력해 주세요.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: enabled,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                  onFieldSubmitted: (_) {
                    if (enabled) _submit();
                  },
                ),
                // Challenge: 이메일만 저장합니다.
                CheckboxListTile(
                  value: _saveEmail,
                  onChanged: enabled
                      ? (value) => setState(() => _saveEmail = value ?? false)
                      : null,
                  title: const Text('이메일 저장'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                // 로그인 입력 오류·요청 실패·저장 실패를 서로 다른 문구로 보여줍니다.
                if (auth.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      auth.message!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: enabled ? () => context.push('/register') : null,
                  child: const Text('회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
