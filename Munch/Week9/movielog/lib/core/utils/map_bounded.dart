// 결과 순서는 입력 순서와 같고, 동시에 실행되는 convert는 최대 concurrency개다.
Future<List<R>> mapBounded<T, R>(
  Iterable<T> values,
  int concurrency,
  Future<R> Function(T value) convert,
) async {
  final input = values.toList(growable: false);
  if (input.isEmpty) return <R>[];
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }
  final output = List<R?>.filled(input.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  await Future.wait(
    List.generate(concurrency.clamp(1, input.length), (_) => worker()),
  );
  return output.cast<R>();
}
