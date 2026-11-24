/// 쓰기(제출) 요청의 진행 상태. 목록 조회의 Loading·Empty·Error·Success와 구분한다.
enum SubmitStatus { idle, submitting, success, error }

/// 등록·수정·삭제가 실패했을 때 Dialog에 그대로 보여줄 사용자 안내 문구를 담는다.
/// 서버 message나 DioException 같은 내부 정보가 화면에 직접 노출되지 않게 한 번 감싼다.
class RatingWriteException implements Exception {
  const RatingWriteException(this.message, {this.dismissDialog = false});

  final String message;

  /// true이면 Dialog를 닫고 화면의 Snackbar로 안내한다. (이미 평점·즐겨찾기함, 회원 없음 등)
  /// false이면 Dialog를 열어 둔 채 입력을 유지하고 Dialog 안에 이유를 보여준다.
  final bool dismissDialog;

  @override
  String toString() => 'RatingWriteException($message)';
}
