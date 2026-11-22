import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late final String _original;

  @override
  void initState() {
    super.initState();
    _original = context.read<AuthViewModel>().member?.nickname ?? '';
    _controller = TextEditingController(text: _original);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 저장에 성공한 뒤에는 '변경 내용' 확인 없이 나갈 수 있어야 합니다.
  bool _saved = false;

  bool get _hasChanges => !_saved && _controller.text.trim() != _original;

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      // PopScope의 canPop이 true로 다시 그려진 뒤에 돌아가야 변경 확인 Dialog가 뜨지 않습니다.
      // 새 닉네임은 이미 AuthViewModel.member에 반영돼 있습니다.
      setState(() => _saved = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) navigator.pop();
    } else if (viewModel.message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(viewModel.message!)));
    }
    // 401 만료는 save()가 false를 돌려주고 Router가 /login으로 보내므로 여기서 pop하지 않습니다.
  }

  // Challenge: 바꾼 내용이 있을 때 뒤로가기를 누르면 버릴지 묻습니다.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('변경 내용을 저장하지 않고 나갈까요?'),
        content: const Text('수정한 닉네임은 저장되지 않습니다.'),
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
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (auth) => auth.member?.email,
    );
    final viewModel = context.watch<EditProfileViewModel>();
    final saving = viewModel.isSaving;

    return PopScope(
      // 저장 중에는 나갈 수 없고, 변경 내용이 있으면 확인 Dialog를 거칩니다.
      canPop: !saving && !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || saving) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: CommonAppBar(
          title: '프로필 수정',
          centerTitle: true,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 이메일은 읽기 전용이고 닉네임만 바꿀 수 있습니다.
                TextFormField(
                  initialValue: email,
                  enabled: false,
                  decoration: const InputDecoration(labelText: '이메일'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  enabled: !saving,
                  maxLength: 12,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    errorText: viewModel.nicknameError,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    viewModel.onNicknameChanged();
                  },
                  onSubmitted: (_) {
                    if (!saving) _submit();
                  },
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
