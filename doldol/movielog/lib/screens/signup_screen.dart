import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/validators.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/movielog_text_form_field.dart';
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

  // 모든 입력이 유효하고 중복 확인을 통과했으며 약관에 동의했을 때만 활성화
  bool _canSubmit(SignUpViewModel vm) =>
      Validators.nickname(_nicknameController.text) == null &&
      Validators.email(_emailController.text) == null &&
      Validators.password(_passwordController.text) == null &&
      vm.nicknameCheckStatus == CheckStatus.available &&
      vm.emailCheckStatus == CheckStatus.available &&
      _agreedToTerms;

  void _refresh() => setState(() {});

  void _submit() {
    // 버튼을 누르면 Form 전체를 다시 검증 (실제 가입 요청은 보내지 않는다)
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원가입이 완료되었어요!')),
    );
    context.go('/home');
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

  List<Widget> _buildFields(SignUpViewModel vm, {required bool isWide}) {
    final nicknameAvailable = vm.nicknameCheckStatus == CheckStatus.available;
    final emailAvailable = vm.emailCheckStatus == CheckStatus.available;

    return [
      MovieLogTextFormField(
        controller: _nicknameController,
        focusNode: _nicknameFocusNode,
        label: '닉네임',
        hint: isWide ? '영화로운 닉네임을 입력하세요' : '닉네임을 입력해주세요',
        validator: Validators.nickname,
        textInputAction: TextInputAction.next,
        errorText: vm.nicknameErrorText,
        successText: nicknameAvailable ? '사용할 수 있는 닉네임입니다.' : null,
        isVerified: nicknameAvailable,
        trailing: MovieLogButton(
          label: '중복 확인',
          isLoading: vm.nicknameCheckStatus == CheckStatus.checking,
          onPressed: vm.canCheckNickname
              ? () => vm.checkNickname(_nicknameController.text)
              : null,
        ),
        onChanged: vm.onNicknameChanged,
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
        errorText: vm.emailErrorText,
        successText: emailAvailable ? '사용할 수 있는 이메일입니다.' : null,
        isVerified: emailAvailable,
        trailing: MovieLogButton(
          label: '중복 확인',
          isLoading: vm.emailCheckStatus == CheckStatus.checking,
          onPressed: vm.canCheckEmail
              ? () => vm.checkEmail(_emailController.text)
              : null,
        ),
        onChanged: vm.onEmailChanged,
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

  List<Widget> _buildBottom(SignUpViewModel vm) {
    return [
      TermsCheckbox(
        value: _agreedToTerms,
        onChanged: (checked) => setState(() => _agreedToTerms = checked),
      ),
      const SizedBox(height: 12),
      MovieLogButton(
        label: '가입하기',
        width: double.infinity,
        onPressed: _canSubmit(vm) ? _submit : null,
      ),
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

  Widget _buildMobile(SignUpViewModel vm, double viewHeight) {
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
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.black),
                ),
                const SizedBox(height: 32),
                ..._buildFields(vm, isWide: false),
                const Spacer(),
                const SizedBox(height: 24),
                ..._buildBottom(vm),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWide(SignUpViewModel vm, double viewHeight) {
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
                    ..._buildFields(vm, isWide: true),
                    const SizedBox(height: 20),
                    ..._buildBottom(vm),
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
    // ViewModel 상태가 바뀌면 화면을 다시 그린다
    final vm = context.watch<SignUpViewModel>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Scaffold(
          appBar: isWide
              ? null
              : CommonAppBar(
                  title: '회원가입',
                  centerTitle: true,
                  titleStyle: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.violet,
                  ),
                ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, bodyConstraints) {
                final viewHeight = bodyConstraints.maxHeight;
                return isWide
                    ? _buildWide(vm, viewHeight)
                    : _buildMobile(vm, viewHeight);
              },
            ),
          ),
        );
      },
    );
  }
}