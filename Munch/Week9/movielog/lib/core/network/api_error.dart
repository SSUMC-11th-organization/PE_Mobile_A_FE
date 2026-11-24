import 'package:dio/dio.dart';

const sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};

String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

bool isSessionExpired(DioException error) =>
    sessionExpiredCodes.contains(apiErrorCode(error));

class ActionFailure implements Exception {
  const ActionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

// Dialog를 닫고 Snackbar로 안내해야 하는 실패
class DismissFailure implements Exception {
  const DismissFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
