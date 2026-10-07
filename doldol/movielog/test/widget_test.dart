import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/main.dart';

void main() {
  testWidgets('프로필 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MovieLogApp());

    expect(find.text('내 프로필'), findsOneWidget);
  });
}