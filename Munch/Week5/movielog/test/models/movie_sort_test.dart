import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/models/movie_sort.dart';

void main() {
  List<int> idsOf(MovieSort sort) =>
      sort.apply(movies).map((movie) => movie.id).toList();

  test('최신순은 연도 내림차순, 같은 연도는 id 오름차순이다', () {
    expect(idsOf(MovieSort.latest), [1, 2, 4, 3, 6, 5]);
  });

  test('평점순은 평점 내림차순이다', () {
    expect(idsOf(MovieSort.rating), [3, 1, 6, 2, 5, 4]);
  });

  test('제목순은 가나다순이다', () {
    expect(idsOf(MovieSort.title), [3, 6, 4, 1, 5, 2]);
  });

  test('원본 목록은 변경하지 않는다', () {
    final before = movies.map((movie) => movie.id).toList();
    MovieSort.title.apply(movies);

    expect(movies.map((movie) => movie.id).toList(), before);
  });
}
