import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../data/models/create_member_request.dart';
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

  /// 가입 조건: 로컬 Form 검증 통과 + 현재 닉네임·이메일이 서버 확인에서 "사용 가능" + 제출 중이 아님.
  bool get _canSubmit {
    final viewModel = context.read<SignUpViewModel>();
    return SignUpValidators.nickname(_nicknameController.text) == null &&
        SignUpValidators.email(_emailController.text) == null &&
        SignUpValidators.password(_passwordController.text) == null &&
        viewModel.isRemoteChecksPassed &&
        _agreedToTerms;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    // await 뒤에는 context를 쓰지 않도록 필요한 객체를 먼저 꺼내 둔다.
    final viewModel = context.read<SignUpViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    if (!mounted) return;

    if (viewModel.submitStatus == SubmitStatus.success) {
      // 가입만으로는 토큰이 없다. 로그인 화면으로 보내 로그인하게 한다.
      context.go('/login');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('회원가입이 완료됐어요. 로그인해 주세요.')),
        );
      return;
    }
    final message = viewModel.snackbarMessage;
    if (message != null) {
      viewModel.consumeSnackbarMessage();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 제출 중에는 화면을 벗어날 수 없다. 끝나면 로그인 화면으로 돌아갈 수 있다.
    final submitting = context.watch<SignUpViewModel>().isSubmitting;
    return PopScope(canPop: !submitting, child: _buildScaffold());
  }

  Widget _buildScaffold() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Scaffold(
          appBar: isWide
              ? null
              : const CommonAppBar(
                  title: '회원가입',
                  centerTitle: true,
                  showBackButton: true,
                ),
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
            hintText: compact ? '8자 이상, 대·소문자/숫자/특수문자 포함' : '비밀번호를 입력해주세요',
            compact: compact,
            showVisibilityToggle: compact,
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            validator: SignUpValidators.password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            onChanged: (_) => viewModel.onPasswordChanged(),
            // 로컬 검증을 통과해도 서버가 거부한 비밀번호면 에러 상태를 유지한다.
            errorText: viewModel.passwordErrorText,
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
          isLoading: context.watch<SignUpViewModel>().isSubmitting,
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
