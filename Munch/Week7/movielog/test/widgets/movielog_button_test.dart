import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/widgets/movielog_button.dart';

Future<void> pumpButton(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [child],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('width가 null이면 내용 기반, infinity면 최대, 고정값이면 그 값', (tester) async {
    await pumpButton(tester, MovieLogButton(label: '중복 확인', onPressed: () {}));
    final intrinsic = tester.getSize(find.byType(ElevatedButton)).width;
    expect(intrinsic, lessThan(400));

    await pumpButton(
      tester,
      MovieLogButton(label: '중복 확인', width: double.infinity, onPressed: () {}),
    );
    expect(tester.getSize(find.byType(ElevatedButton)).width, 400);

    await pumpButton(
      tester,
      MovieLogButton(label: '중복 확인', width: 96, onPressed: () {}),
    );
    expect(tester.getSize(find.byType(ElevatedButton)).width, 96);
  });

  testWidgets('통신 중에는 인디케이터만 보이고 누를 수 없다', (tester) async {
    var tapped = false;
    await pumpButton(
      tester,
      MovieLogButton(
        label: '중복 확인',
        isLoading: true,
        onPressed: () => tapped = true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('중복 확인'), findsNothing);
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isFalse);
  });

  testWidgets('onPressed가 null이면 비활성', (tester) async {
    await pumpButton(
      tester,
      const MovieLogButton(label: '가입하기', onPressed: null),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.text('가입하기'), findsOneWidget);
  });
}
