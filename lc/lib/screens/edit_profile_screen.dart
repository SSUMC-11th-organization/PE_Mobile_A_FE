import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/movielog_button.dart';

/// 프로필 수정 화면. 이메일은 읽기 전용이고 닉네임만 고칠 수 있다.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  late final String _initialNickname;

  @override
  void initState() {
    super.initState();
    _initialNickname = context.read<AuthViewModel>().member?.nickname ?? '';
    _controller = TextEditingController(text: _initialNickname);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    context.read<EditProfileViewModel>().onNicknameChanged();
    setState(() {}); // 변경 여부(뒤로가기 확인)를 다시 계산한다.
  }

  bool get _isDirty => _controller.text.trim() != _initialNickname;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      // 저장이 끝났다는 것이 PopScope(canPop)에 반영된 다음 프레임에 닫는다.
      // 바로 pop하면 아직 "저장하지 않은 변경"으로 보고 닫기를 막는다.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      router.pop(); // 마이페이지에는 새 닉네임이 이미 반영되어 있다.
    } else if (viewModel.message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(viewModel.message!)));
    }
  }

  /// 변경 내용이 있을 때 뒤로가기를 누르면 나갈지 확인한다.
  Future<void> _confirmLeave() async {
    final router = GoRouter.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        title: const Text('수정을 그만둘까요?'),
        content: const Text('변경한 내용은 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (auth) => auth.member?.email,
    );
    final viewModel = context.watch<EditProfileViewModel>();
    final saving = viewModel.status == EditProfileStatus.saving;
    final saved = viewModel.status == EditProfileStatus.success;
    // 저장 중에는 나갈 수 없고, 저장하지 않은 변경이 있으면 먼저 확인한다.
    final canPop = !saving && (!_isDirty || saved);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || saving) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('프로필 수정'),
          leading: IconButton(
            tooltip: '뒤로가기',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TextFormField(
                  initialValue: email,
                  enabled: false, // email은 읽기 전용이다.
                  decoration: const InputDecoration(labelText: '이메일'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  enabled: !saving,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    errorText: viewModel.nicknameError,
                  ),
                ),
                const Spacer(),
                MovieLogButton(
                  label: '저장',
                  width: double.infinity,
                  isLoading: saving,
                  onPressed: saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
