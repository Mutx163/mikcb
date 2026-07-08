import 'dart:async';

/// 串行化异步操作，防止并发写入同一资源。
class SyncOperationGate {
  Future<void> _tail = Future<void>.value();

  Future<T> runExclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }
}
