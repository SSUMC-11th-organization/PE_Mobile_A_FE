import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/storage/saved_email_storage.dart';
import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/movielog_button.dart';

/// 로그인 화면. login()만 호출하고 직접 화면을 옮기지 않는다.
/// 상태가 signedIn이 되면 Router가 홈으로 보낸다.
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
    // 이미 만료된 상태로 이 화면이 처음 열리는 경우도 한 번 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  /// 저장해 둔 이메일이 있으면 채운다. (비밀번호와 토큰은 저장하지 않는다.)
  Future<void> _loadSavedEmail() async {
    try {
      final saved = await _savedEmail.read();
      if (!mounted || saved == null || saved.isEmpty) return;
      if (_email.text.isEmpty) _email.text = saved;
      setState(() => _rememberEmail = true);
    } catch (_) {
      // 편의 기능이므로 읽지 못해도 로그인은 그대로 할 수 있다.
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired(); // 먼저 꺼서 같은 안내가 반복되지 않게 한다.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')),
      );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    try {
      if (_rememberEmail) {
        await _savedEmail.save(email);
      } else {
        await _savedEmail.clear();
      }
    } catch (_) {
      // 이메일 저장 실패가 로그인을 막지 않는다.
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                SvgPicture.asset(
                  'assets/logos/movielog_logo.svg',
                  width: 84,
                  height: 84,
                  semanticsLabel: 'MovieLog 로고',
                ),
                const SizedBox(height: 24),
                const Text(
                  'MovieLog에 로그인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? '이메일을 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _password,
                  enabled: enabled,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                  onFieldSubmitted: (_) => enabled ? _submit() : null,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _rememberEmail,
                  onChanged: enabled
                      ? (value) =>
                            setState(() => _rememberEmail = value ?? false)
                      : null,
                  title: const Text('이메일 저장'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.violet,
                ),
                if (auth.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        auth.message!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          color: AppColors.error,
                        ),
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
                const SizedBox(height: 16),
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
