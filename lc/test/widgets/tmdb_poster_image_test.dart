import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/widgets/tmdb_poster_image.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 100, height: 150, child: child)),
  );
}

void main() {
  const placeholderIcon = Icons.image_not_supported_outlined;

  testWidgets('poster_path가 null이면 placeholder를 보여주고 이미지를 요청하지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const TmdbPosterImage(posterPath: null)));

    expect(find.byIcon(placeholderIcon), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('poster_path가 빈 문자열이어도 placeholder를 보여준다', (tester) async {
    await tester.pumpWidget(wrap(const TmdbPosterImage(posterPath: '')));

    expect(find.byIcon(placeholderIcon), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('poster_path에 base URL과 크기를 붙여 이미지 주소를 만든다', (tester) async {
    await tester.pumpWidget(
      wrap(const TmdbPosterImage(posterPath: '/abc.jpg')),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://image.tmdb.org/t/p/w500/abc.jpg',
    );
  });

  testWidgets('이미지 로드에 실패하면 placeholder로 바뀐다', (tester) async {
    // 테스트 환경의 HTTP 요청은 실패하므로 로드 실패 상황이 된다.
    await tester.pumpWidget(
      wrap(const TmdbPosterImage(posterPath: '/abc.jpg')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(placeholderIcon), findsOneWidget);
  });
}
