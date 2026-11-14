import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/utils/signup_validators.dart';
import 'package:movielog/view_models/learning_member_session.dart';

void main() {
  group('닉네임(2~12자)', () {
    test('비어 있거나 1자이면 안내한다', () {
      expect(SignUpValidators.nickname(''), isNotNull);
      expect(SignUpValidators.nickname('  '), isNotNull);
      expect(SignUpValidators.nickname('영'), contains('2자 이상'));
    });

    test('2자와 12자는 통과한다', () {
      expect(SignUpValidators.nickname('영화'), isNull);
      expect(SignUpValidators.nickname('가' * 12), isNull);
    });

    test('13자부터는 안내한다', () {
      expect(SignUpValidators.nickname('가' * 13), contains('12자 이하'));
    });

    test('앞뒤 공백은 세지 않는다', () {
      expect(SignUpValidators.nickname('  영화  '), isNull);
      expect(SignUpValidators.nickname('  ${'가' * 12}  '), isNull);
    });
  });

  group('비밀번호(8자 이상, 대·소문자·숫자·특수문자 각 1개 이상)', () {
    test('모두 갖추면 통과한다', () {
      expect(SignUpValidators.password('Password1!'), isNull);
      expect(SignUpValidators.password('aA1@aaaa'), isNull);
    });

    test('8자 미만이면 길이를 안내한다', () {
      expect(SignUpValidators.password('Aa1!'), contains('8자 이상'));
    });

    test('종류가 하나라도 빠지면 규칙을 안내한다', () {
      for (final weak in [
        'password1!', // 대문자 없음
        'PASSWORD1!', // 소문자 없음
        'Password!!', // 숫자 없음
        'Password11', // 특수문자 없음
        'Password1?', // 허용 특수문자(!@#\$%^&*)가 아님
      ]) {
        expect(
          SignUpValidators.password(weak),
          contains('특수문자'),
          reason: weak,
        );
      }
    });

    test('허용된 특수문자 8개를 모두 인정한다', () {
      for (final special in '!@#\$%^&*'.split('')) {
        expect(
          SignUpValidators.password('Password1$special'),
          isNull,
          reason: special,
        );
      }
    });

    test('비밀번호의 공백은 그대로 둔다 (trim하지 않는다)', () {
      expect(SignUpValidators.password('Pass 1!aa'), isNull);
    });
  });

  group('LearningMemberSession', () {
    test('처음에는 memberId가 없고, 설정하면 알림이 간다', () {
      final session = LearningMemberSession();
      var notified = 0;
      session.addListener(() => notified++);
      expect(session.memberId, isNull);

      session.setMemberId(42);

      expect(session.memberId, 42);
      expect(notified, 1);
    });

    test('clear하면 다시 비어 있다', () {
      final session = LearningMemberSession(7)..clear();

      expect(session.memberId, isNull);
    });
  });
}
