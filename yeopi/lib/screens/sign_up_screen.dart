import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_member_request.dart';
import '../theme/app_colors.dart';
import '../utils/sign_up_validators.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
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

  // 형식 검사는 validator가, 서버 중복 여부는 ViewModel이 담당하고 둘 다 통과해야 가입할 수 있습니다.
  bool _canSubmit(SignUpViewModel viewModel) =>
      SignUpValidators.password(_passwordController.text) == null &&
      viewModel.isNicknameAvailable &&
      viewModel.isEmailAvailable &&
      _agreedToTerms;

  Future<void> _submit() async {
    // 버튼 활성화 조건과 별개로 제출 시 Form 전체를 다시 검증합니다.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    final viewModel = context.read<SignUpViewModel>();
    final session = context.read<LearningMemberSession>();
    final messenger = ScaffoldMessenger.of(context);

    // 비밀번호는 요청 본문에만 담고 로그·저장소에 남기지 않습니다.
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
      session.setMemberId(memberId);
      messenger.showSnackBar(
        SnackBar(content: Text('회원가입이 완료되었습니다. (memberId $memberId)')),
      );
      // 영화 목록에서 뒤로 가기로 회원가입이 다시 나오지 않도록 push가 아닌 go를 씁니다.
      context.go('/movies');
      return;
    }
    final message = viewModel.snackbarMessage;
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 중복 확인 상태가 바뀌면 입력창 에러와 가입 버튼 활성화가 함께 바뀌므로 Form 전체가 구독합니다.
    final viewModel = context.watch<SignUpViewModel>();

    // 가입 요청 중에는 뒤로가기로 화면을 벗어나지 못하게 막습니다. (요청 결과를 잃지 않기 위해)
    return PopScope(
      canPop: !viewModel.isSubmitting,
      child: Scaffold(
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
                  _CheckableField(
                    field: TextFormField(
                      controller: _nicknameController,
                      decoration: _inputDecoration(
                        label: '닉네임',
                        hint: '영화로운 닉네임을 입력하세요',
                        icon: Icons.person_outline,
                        status: viewModel.nicknameCheckStatus,
                        serverErrorText: viewModel.nicknameErrorText,
                        availableText: '사용할 수 있는 닉네임입니다.',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: SignUpValidators.nickname,
                      onChanged: viewModel.onNicknameChanged,
                      onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                    ),
                    button: MovieLogButton(
                      label: '중복 확인',
                      isLoading:
                          viewModel.nicknameCheckStatus == CheckStatus.checking,
                      onPressed: viewModel.canCheckNickname
                          ? () => viewModel.checkNickname(
                              _nicknameController.text,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CheckableField(
                    field: TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      decoration: _inputDecoration(
                        label: '이메일',
                        hint: 'example@movielog.com',
                        icon: Icons.mail_outline,
                        status: viewModel.emailCheckStatus,
                        serverErrorText: viewModel.emailErrorText,
                        availableText: '사용할 수 있는 이메일입니다.',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: SignUpValidators.email,
                      onChanged: viewModel.onEmailChanged,
                      onFieldSubmitted: (_) =>
                          _passwordFocusNode.requestFocus(),
                    ),
                    button: MovieLogButton(
                      label: '중복 확인',
                      isLoading:
                          viewModel.emailCheckStatus == CheckStatus.checking,
                      onPressed: viewModel.canCheckEmail
                          ? () => viewModel.checkEmail(_emailController.text)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    decoration: _inputDecoration(
                      label: '비밀번호',
                      hint: '8자 이상, 대·소문자·숫자·특수문자 포함',
                      icon: Icons.lock_outline,
                      // 서버가 400으로 알려준 비밀번호 규칙 위반은 이 칸 아래에 보여줍니다.
                      serverErrorText: viewModel.passwordErrorText,
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: SignUpValidators.password,
                    onChanged: (_) {
                      setState(() {});
                      viewModel.onPasswordChanged();
                    },
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 16),
                  TermsAgreement(
                    value: _agreedToTerms,
                    onChanged: (value) =>
                        setState(() => _agreedToTerms = value),
                  ),
                  const SizedBox(height: 24),
                  MovieLogButton(
                    label: '가입하기',
                    width: double.infinity,
                    isLoading: viewModel.isSubmitting,
                    onPressed: _canSubmit(viewModel) && !viewModel.isSubmitting
                        ? _submit
                        : null,
                  ),
                ],
              ),
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
    CheckStatus? status,
    String? serverErrorText,
    String? availableText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    final isAvailable = status == CheckStatus.available;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      // 체크 표시는 입력창 안에만 두어 옆의 버튼과 겹치지 않게 합니다.
      suffixIcon: isAvailable
          ? const Icon(Icons.check_circle, color: AppColors.violet)
          : null,
      // validator 오류가 없을 때만 서버 중복 결과가 보입니다. (형식 오류가 먼저 보입니다.)
      errorText: serverErrorText,
      helperText: isAvailable ? availableText : null,
      helperStyle: const TextStyle(color: AppColors.violet),
      filled: true,
      fillColor: AppColors.inputFill,
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.violet, 2),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 2),
    );
  }
}

// 입력창과 중복 확인 버튼을 Row의 별도 형제로 두고 8px 간격을 줍니다.
class _CheckableField extends StatelessWidget {
  const _CheckableField({required this.field, required this.button});

  final Widget field;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Row(
      // 아래쪽 에러·안내 문구 높이가 바뀌어도 버튼은 입력창 높이에 맞춰 위쪽에 고정합니다.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        Padding(padding: const EdgeInsets.only(top: 6), child: button),
      ],
    );
  }
}
