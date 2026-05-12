import 'dart:async';

/// 格式化当前时间为日志时间戳 `[HH:mm:ss.SSS]`。
String formatLogTimestamp([DateTime? time]) {
  final t = time ?? DateTime.now();
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  final s = t.second.toString().padLeft(2, '0');
  final ms = t.millisecond.toString().padLeft(3, '0');
  return '[$h:$m:$s.$ms]';
}

/// 并行竞争结果。
class RaceResult<T> {
  /// 胜出者，所有候选都返回 null 时为 null。
  final T? winner;

  /// 所有未胜出的 future 的错误或返回 null 时附带的信息。
  final List<Object> errors;

  const RaceResult({required this.winner, required this.errors});
}

/// 让一组 future 并行竞争，返回第一个 [extract] 不为 null 的结果。
///
/// [futures] 中的 future 通过 [extract] 从原始结果中提取有效值；
/// 返回 null 表示该候选不是胜者，继续等待其他候选。
///
/// 任一 future 胜出时立即返回；全部返回 null 或抛异常时，
/// 返回 [RaceResult] 其中 winner 为 null，errors 收集了所有错误。
Future<RaceResult<T>> raceFutures<S, T>(
  Iterable<Future<S>> futures,
  T? Function(S result) extract,
) async {
  final completer = Completer<RaceResult<T>>();
  var completedCount = 0;
  final total = futures.length;
  final errors = <Object>[];
  T? winner;

  for (final future in futures) {
    future.then((result) {
      final extracted = extract(result);
      if (extracted != null) {
        winner = extracted;
      }
      completedCount++;
      if (winner != null && !completer.isCompleted) {
        completer.complete(RaceResult(winner: winner, errors: errors));
      } else if (completedCount >= total && !completer.isCompleted) {
        completer.complete(RaceResult(winner: winner, errors: errors));
      }
    }).catchError((error) {
      errors.add(error);
      completedCount++;
      if (completedCount >= total && !completer.isCompleted) {
        completer.complete(RaceResult(winner: winner, errors: errors));
      }
    });
  }

  return completer.future;
}
