import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;
  // 입력칸 아래에 보여줄 오류(길이·중복)와 Snackbar로 보여줄 오류(네트워크 등)를 나눕니다.
  String? nicknameError;
  String? message;
  bool _disposed = false;

  bool get isSaving => status == EditProfileStatus.saving;

  // 서버에 보내기 전에 확인할 수 있는 규칙은 먼저 검사해서 불필요한 요청을 줄입니다.
  static String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해 주세요.';
    }
    return null;
  }

  void onNicknameChanged() {
    if (nicknameError == null) return;
    nicknameError = null;
    _notify();
  }

  Future<bool> save(String input) async {
    if (isSaving) return false; // 연속 탭 방지
    final version = _auth.sessionVersion;
    if (_disposed ||
        _auth.status != AuthStatus.signedIn ||
        _auth.member == null) {
      return false;
    }

    final nickname = input.trim();
    message = null;
    nicknameError = validateNickname(nickname);
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임과 같으면 요청 없이 완료로 처리합니다. (자기 자신은 중복 검사에서 빠지므로 409도 아닙니다.)
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (!_isCurrent(version)) return false;
      _auth.updateMember(updated);
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return false;
      status = EditProfileStatus.failure;
      switch (apiErrorCode(error)) {
        case 'AUTH401_2' || 'AUTH401_3' || 'AUTH401_4':
          // 안내와 이동은 로그인 화면과 Router가 담당합니다.
          await _auth.expireSession(version: version);
        case 'MEMBER409_1':
          nicknameError = '이미 사용 중인 닉네임이에요.'; // 입력값은 그대로 둡니다.
        case 'COMMON400':
          nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
        case 'MEMBER404_1':
          message = '회원 정보를 찾을 수 없어요.';
        default:
          message = '네트워크 상태를 확인하고 다시 시도해 주세요.'; // 로그아웃하지 않습니다.
      }
    } catch (_) {
      if (!_isCurrent(version)) return false;
      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }
    _notify();
    return false;
  }

  // 화면이 닫혔거나 그 사이 로그아웃·다른 계정 로그인이 있었다면 늦은 응답을 버립니다.
  bool _isCurrent(int version) =>
      !_disposed &&
      version == _auth.sessionVersion &&
      _auth.status == AuthStatus.signedIn;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
