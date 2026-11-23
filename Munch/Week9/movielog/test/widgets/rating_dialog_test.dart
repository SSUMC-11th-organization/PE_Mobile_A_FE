import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/widgets/rating_dialog.dart';

Future<void> pumpDialog(
  WidgetTester tester, {
  int initialScore = 0,
  required Future<void> Function(int, String?) onSubmit,
  void Function(bool?)? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  RatingDialog(initialScore: initialScore, onSubmit: onSubmit),
            );
            onClosed?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

ElevatedButton confirmButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '확인'));

void main() {
  testWidgets('별점을 선택해야 확인이 활성화된다', (tester) async {
    await pumpDialog(tester, onSubmit: (_, _) async {});
    await tester.enterText(find.byType(TextField), '코멘트만 입력');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    expect(find.byType(RatingBar), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(RatingBar)));
    await tester.pump();

    expect(confirmButton(tester).onPressed, isNotNull);
    expect(find.text('코멘트만 입력'), findsOneWidget);
  });

  testWidgets('취소하면 저장을 호출하지 않고 false를 반환한다', (tester) async {
    var calls = 0;
    bool? closed;
    await pumpDialog(
      tester,
      initialScore: 3,
      onSubmit: (_, _) async => calls++,
      onClosed: (value) => closed = value,
    );

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(closed, isFalse);
  });

  testWidgets('저장 실패 시 입력을 유지하고 다시 시도할 수 있다', (tester) async {
    await pumpDialog(
      tester,
      initialScore: 3,
      onSubmit: (_, _) async => throw StateError('이미 이 영화에 평점을 남기셨습니다.'),
    );
    await tester.enterText(find.byType(TextField), '유지될 코멘트');

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('저장하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('유지될 코멘트'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('빈 코멘트는 null로 전달하고 저장 성공 시 true를 반환한다', (tester) async {
    String? received = 'unset';
    bool? closed;
    await pumpDialog(
      tester,
      initialScore: 5,
      onSubmit: (_, comment) async => received = comment,
      onClosed: (value) => closed = value,
    );
    await tester.enterText(find.byType(TextField), '   ');

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(received, isNull);
    expect(closed, isTrue);
  });
}
