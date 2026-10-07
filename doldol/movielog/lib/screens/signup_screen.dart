import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_text_form_field.dart';
import '../widgets/signup_button.dart';
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

  // 버튼 활성화 조건: 세 입력값이 모두 유효하고 약관에 동의했을 때
  bool get _canSubmit =>
      Validators.nickname(_nicknameController.text) == null &&
      Validators.email(_emailController.text) == null &&
      Validators.password(_passwordController.text) == null &&
      _agreedToTerms;

  void _refresh() => setState(() {});

  void _submit() {
    // 버튼을 누르면 Form 전체를 다시 검증
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원가입이 완료되었어요!')),
    );
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

  // 입력창 3개: 휴대폰과 넓은 화면이 같은 Controller, Validator, 상태를 재사용
  List<Widget> _buildFields({required bool isWide}) {
    return [
      MovieLogTextFormField(
        controller: _nicknameController,
        focusNode: _nicknameFocusNode,
        label: '닉네임',
        hint: isWide ? '영화로운 닉네임을 입력하세요' : '닉네임을 입력해주세요',
        validator: Validators.nickname,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _refresh(),
        onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
      ),
      const SizedBox(height: 20),
      MovieLogTextFormField(
        controller: _emailController,
        focusNode: _emailFocusNode,
        label: isWide ? '이메일 주소' : '이메일',
        hint: isWide ? 'example@movielog.com' : '이메일 주소를 입력해주세요',
        validator: Validators.email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _refresh(),
        onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
      ),
      const SizedBox(height: 20),
      MovieLogTextFormField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        label: '비밀번호',
        hint: isWide ? '영문, 숫자 포함 8자 이상' : '비밀번호를 입력해주세요',
        validator: Validators.password,
        isPassword: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => _refresh(),
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    ];
  }

  // 약관, 가입 버튼, 로그인 문구: 두 레이아웃에서 공통으로 사용
  List<Widget> _buildBottom() {
    return [
      TermsCheckbox(
        value: _agreedToTerms,
        onChanged: (checked) => setState(() => _agreedToTerms = checked),
      ),
      const SizedBox(height: 12),
      SignUpButton(enabled: _canSubmit, onPressed: _submit),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('이미 계정이 있나요?', style: AppTextStyles.label),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.violet,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '로그인',
              style: AppTextStyles.label.copyWith(
                color: AppColors.violet,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // 휴대폰: 입력창은 위, 약관·버튼은 화면 아래에 붙임
  Widget _buildMobile(double viewHeight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewHeight),
        child: IntrinsicHeight(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.black),
                ),
                const SizedBox(height: 32),
                ..._buildFields(isWide: false),
                const Spacer(),
                const SizedBox(height: 24),
                ..._buildBottom(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 넓은 화면: Form을 가운데에 두고 최대 너비를 560으로 제한
  Widget _buildWide(double viewHeight) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxFormWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewHeight - 48),
            child: Center(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '회원가입',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.violet,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MovieLog에 오신 것을 환영합니다!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 32),
                    ..._buildFields(isWide: true),
                    const SizedBox(height: 20),
                    ..._buildBottom(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 부모가 허용한 너비가 700 이상일 때만 넓은 화면 레이아웃 사용
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Scaffold(
          appBar: isWide
              ? null
              : CommonAppBar(
                  title: '회원가입',
                  centerTitle: true,
                  onBack: () => Navigator.maybePop(context),
                  titleStyle: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.violet,
                  ),
                ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, bodyConstraints) {
                final viewHeight = bodyConstraints.maxHeight;
                return isWide
                    ? _buildWide(viewHeight)
                    : _buildMobile(viewHeight);
              },
            ),
          ),
        );
      },
    );
  }
}