import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/signup_validators.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/signup_text_field.dart';
import '../widgets/terms_checkbox.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const double _wideBreakpoint = 700;
  static const double _maxFormWidth = 560;

  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_refresh);
    _emailController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _canSubmit {
    // 서버가 중복이라고 답한 값이 입력칸에 남아 있으면 가입할 수 없다.
    final viewModel = context.read<SignUpViewModel>();
    return SignUpValidators.nickname(_nicknameController.text) == null &&
        SignUpValidators.email(_emailController.text) == null &&
        SignUpValidators.password(_passwordController.text) == null &&
        viewModel.nicknameCheckStatus != CheckStatus.duplicated &&
        viewModel.emailCheckStatus != CheckStatus.duplicated &&
        _agreedToTerms;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // 회원가입 화면에서는 뒤로 가기가 동작하지 않는다.
    return PopScope(canPop: false, child: _buildScaffold());
  }

  Widget _buildScaffold() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Scaffold(
          appBar: isWide
              ? null
              : const CommonAppBar(title: '회원가입', centerTitle: true),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, body) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(isWide ? 24 : 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: body.maxHeight - (isWide ? 48 : 32),
                  ),
                  child: isWide
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxFormWidth,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: _buildContent(wide: true),
                            ),
                          ),
                        )
                      : IntrinsicHeight(child: _buildContent(wide: false)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFields({required bool compact}) {
    final viewModel = context.watch<SignUpViewModel>();
    final nickname = _nicknameController.text;
    final email = _emailController.text;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignUpTextField(
            label: '닉네임',
            hintText: compact ? '영화로운 닉네임을 입력하세요' : '닉네임을 입력해주세요',
            compact: compact,
            controller: _nicknameController,
            focusNode: _nicknameFocusNode,
            validator: SignUpValidators.nickname,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
            onChanged: viewModel.onNicknameChanged,
            errorText: viewModel.nicknameErrorText,
            // 버튼은 입력창 바깥 오른쪽에 두고 너비는 지정하지 않아 내용 기반 크기를 쓴다.
            trailing: MovieLogButton(
              label: '중복 확인',
              isLoading: viewModel.nicknameCheckStatus == CheckStatus.checking,
              onPressed:
                  viewModel.canCheckNickname &&
                      SignUpValidators.nickname(nickname) == null
                  ? () => viewModel.checkNickname(nickname)
                  : null,
            ),
          ),
          _CheckMessage(
            available: viewModel.nicknameCheckStatus == CheckStatus.available,
            text: '사용할 수 있는 닉네임입니다.',
          ),
          SizedBox(height: compact ? 24 : 16),
          SignUpTextField(
            label: compact ? '이메일 주소' : '이메일',
            hintText: compact ? 'example@movielog.com' : '이메일 주소를 입력해주세요',
            compact: compact,
            controller: _emailController,
            focusNode: _emailFocusNode,
            validator: SignUpValidators.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            onChanged: viewModel.onEmailChanged,
            errorText: viewModel.emailErrorText,
            trailing: MovieLogButton(
              label: '중복 확인',
              isLoading: viewModel.emailCheckStatus == CheckStatus.checking,
              onPressed:
                  viewModel.canCheckEmail &&
                      SignUpValidators.email(email) == null
                  ? () => viewModel.checkEmail(email)
                  : null,
            ),
          ),
          _CheckMessage(
            available: viewModel.emailCheckStatus == CheckStatus.available,
            text: '사용할 수 있는 이메일입니다.',
          ),
          SizedBox(height: compact ? 24 : 16),
          SignUpTextField(
            label: '비밀번호',
            hintText: compact ? '영문, 숫자 포함 8자 이상' : '비밀번호를 입력해주세요',
            compact: compact,
            showVisibilityToggle: compact,
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            validator: SignUpValidators.password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({required bool wide}) {
    final sectionGap = SizedBox(height: wide ? 32 : 24);

    return Column(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide) ...[
          Text(
            '회원가입',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.violet,
              fontWeight: FontWeight.w500,
              height: 40 / 32,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          wide ? 'MovieLog에 오신 것을 환영합니다!' : '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.textSecondary,
            fontWeight: wide ? FontWeight.w400 : FontWeight.w500,
            letterSpacing: wide ? 0.5 : 0,
          ),
        ),
        const SizedBox(height: 40),
        _buildFields(compact: wide),
        if (!wide) const Spacer(),
        const SizedBox(height: 32),
        TermsCheckbox(
          compact: wide,
          value: _agreedToTerms,
          onChanged: (value) => setState(() => _agreedToTerms = value),
        ),
        sectionGap,
        // Form 아래 제출 버튼은 부모가 허용하는 최대 너비를 쓴다.
        MovieLogButton(
          label: '가입하기',
          width: double.infinity,
          onPressed: _canSubmit ? _submit : null,
        ),
        sectionGap,
        _LoginPrompt(compact: wide),
      ],
    );
  }
}

/// 서버가 사용 가능하다고 답했을 때만 입력창 아래에 보이는 안내 문구.
class _CheckMessage extends StatelessWidget {
  const _CheckMessage({required this.available, required this.text});

  final bool available;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (!available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 16 / 12,
          color: AppColors.violet,
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = compact
        ? AppTextStyles.labelSmall
        : AppTextStyles.sectionTitle;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text: '이미 계정이 있나요? ',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: '로그인',
            style: base.copyWith(
              color: AppColors.violet,
              fontWeight: compact ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
