import 'dart:async';

/// 串行化异步操作，防止并发写入同一资源。
///
/// Nested calls from within an already-running exclusive section re-enter
/// without waiting (same [Zone]). Concurrent callers always join the chain.
class SyncOperationGate {
  static final Object _zoneTokenKey = Object();

  Future<void> _tail = Future<void>.value();

  Future<T> runExclusive<T>(Future<T> Function() action) async {
    // Nested call from the holder of this gate — re-enter without deadlocking.
    if (identical(Zone.current[_zoneTokenKey], this)) {
      return action();
    }

    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    await previous;
    try {
      return await runZoned(
        action,
        zoneValues: <Object?, Object?>{_zoneTokenKey: this},
      );
    } finally {
      gate.complete();
    }
  }
}
