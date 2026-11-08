import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/widgets/movielog_button.dart';

/// 부모가 "최대 400"까지 허용하는 자리에 버튼을 놓는다.
/// (SizedBox(width: 400)처럼 딱 400으로 고정하면 자식의 width가 무시되므로 loose 제약을 쓴다.)
Widget _host(Widget button) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: button,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('기본 상태에서는 라벨이 보이고 눌린다', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(MovieLogButton(label: '중복 확인', onPressed: () => pressed++)),
    );

    expect(find.text('중복 확인'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(ElevatedButton));
    expect(pressed, 1);
  });

  testWidgets('통신 중에는 라벨 없이 인디케이터만 보이고 눌리지 않는다', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        MovieLogButton(
          label: '중복 확인',
          isLoading: true,
          onPressed: () => pressed++,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('중복 확인'), findsNothing);

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    expect(pressed, 0);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('onPressed가 null이면 비활성이다', (tester) async {
    await tester.pumpWidget(
      _host(const MovieLogButton(label: '가입하기', onPressed: null)),
    );

    expect(find.text('가입하기'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('width가 null · double.infinity · 고정값일 때 서로 다른 너비가 된다', (tester) async {
    Future<double> widthOf(double? width) async {
      await tester.pumpWidget(
        _host(MovieLogButton(label: '확인', width: width, onPressed: () {})),
      );
      return tester.getSize(find.byType(MovieLogButton)).width;
    }

    final intrinsic = await widthOf(null);
    final max = await widthOf(double.infinity);
    final fixed = await widthOf(96);

    expect(max, 400); // 부모가 허용하는 최대 너비
    expect(fixed, 96); // 지정한 값 그대로
    expect(intrinsic, lessThan(200)); // 내용 기반 크기
    expect({intrinsic, max, fixed}, hasLength(3));
  });

  testWidgets('Row 안에서는 Expanded 입력칸 옆에서 내용 크기만 차지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Row(
              children: [
                const Expanded(child: TextField()),
                const SizedBox(width: 8),
                MovieLogButton(label: '중복 확인', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MovieLogButton)).width, lessThan(150));
  });
}
