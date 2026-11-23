import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final member = context.read<AuthViewModel>().member;
    _controller = TextEditingController(text: member?.nickname ?? '')
      ..addListener(() => setState(() {}));
  }

  // PopScope의 canPop이 다시 그려진 뒤에 pop해야 막히지 않는다.
  void _leave() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    FocusScope.of(context).unfocus();
    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      _leave();
    } else if (viewModel.message != null) {
      messenger.showSnackBar(SnackBar(content: Text(viewModel.message!)));
    }
  }

  void _handleBack() {
    final viewModel = context.read<EditProfileViewModel>();
    if (viewModel.isSaving) return;
    if (viewModel.hasChanges(_controller.text)) {
      _confirmLeave();
    } else {
      context.pop();
    }
  }

  Future<void> _confirmLeave() async {
    if (context.read<EditProfileViewModel>().isSaving) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => const _DiscardChangesDialog(),
    );
    if (leave == true && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (a) => a.member?.email,
    );

    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, child) {
        final saving = viewModel.isSaving;
        final dirty = viewModel.hasChanges(_controller.text);
        final canPop = _leaving || (!saving && !dirty);
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            backgroundColor: AppColors.warmWhite,
            appBar: CommonAppBar(
              title: '프로필 수정',
              centerTitle: true,
              onBack: _handleBack,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      '이메일 (변경할 수 없습니다)',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: email,
                      enabled: false,
                      style: const TextStyle(color: AppColors.gray),
                      decoration: _fieldDecoration(
                        fillColor: AppColors.skeleton,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('닉네임', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      enabled: !saving,
                      maxLength: 12,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => viewModel.onNicknameChanged(),
                      onSubmitted: (_) {
                        if (!saving) _submit();
                      },
                      decoration: _fieldDecoration(
                        fillColor: AppColors.white,
                        errorText: viewModel.nicknameError,
                      ),
                    ),
                    const Spacer(),
                    MovieLogButton(
                      label: '저장',
                      width: double.infinity,
                      height: 48,
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration({
    required Color fillColor,
    String? errorText,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      filled: true,
      fillColor: fillColor,
      errorText: errorText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border(AppColors.skeleton),
      disabledBorder: border(AppColors.skeleton),
      focusedBorder: border(AppColors.violet),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
    );
  }
}

class _DiscardChangesDialog extends StatelessWidget {
  const _DiscardChangesDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '변경 내용을 버릴까요?',
              style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            const Text('저장하지 않은 내용은 사라집니다.', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: MovieLogButton(
                    label: '계속 수정',
                    tonal: true,
                    width: double.infinity,
                    height: 48,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MovieLogButton(
                    label: '나가기',
                    width: double.infinity,
                    height: 48,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
