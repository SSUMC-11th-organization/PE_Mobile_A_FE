/// [values]를 [convert]로 바꾸되, 동시에 진행하는 작업을 [concurrency]개로 제한한다.
/// 결과는 입력과 같은 순서로 돌려준다. (Future.wait에 100개를 한꺼번에 던지지 않기 위한 것이다.)
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

  // worker마다 아직 안 한 index를 하나씩 가져가 처리한다.
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  final workers = List.generate(
    concurrency.clamp(1, input.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return output.cast<R>();
}
