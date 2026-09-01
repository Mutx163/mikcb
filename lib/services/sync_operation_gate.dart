import 'dart:async';

/// 串行化异步操作，防止并发写入同一资源。
///
/// Nested calls from within an already-running exclusive section re-enter
/// without waiting (same [Zone]). Concurrent callers always join the chain.
class SyncOperationGate {
  static final Object _zoneTokenKey = Object();

  Future<void> _tail = Future<void>.value();

  /// true ⇔ [_tail] 的持有者已释放且没有新排队者。
  ///
  /// Future 本身查不到「已完成」状态，用这个标记跟踪：每次入队置 false，
  /// 持有者释放时仅当自己仍是队尾（身后无人排队）才置回 true。
  bool _tailSettled = true;

  Future<T> runExclusive<T>(Future<T> Function() action) {
    // Nested call from the holder of this gate — re-enter without deadlocking.
    // Future.sync 保持动作体同步启动、同步抛出转为失败 Future 的旧语义。
    if (identical(Zone.current[_zoneTokenKey], this)) {
      return Future<T>.sync(action);
    }

    final previous = _tail;
    final wasIdle = _tailSettled;
    final gate = Completer<void>();
    _tail = gate.future;
    _tailSettled = false;

    // 快路径：门空闲时同步启动动作体。
    //
    // async 门闩即使空闲也会把动作体推迟到 `await previous` 的微任务之后，
    // 而且上一任持有者若创建于 tester.runAsync（真实 async 区），其完成
    // 回调是「真实微任务」——FakeAsync 的 pump 永远清不到它，排队中的写
    // 操作（周视图提交 setCurrentWeek 等）在 widget 测试里就永远轮不到执
    // 行；「先同步改内存状态并 notify，再等持久化」的时序也有测试锚定
    // （timetable_provider_profiles_test）。因此空闲时必须同步调用动作体，
    // 其完成后再放行后续排队者；忙时的排队语义保持原样。
    if (wasIdle) {
      Future<T> result;
      try {
        result = runZoned(
          action,
          zoneValues: <Object?, Object?>{_zoneTokenKey: this},
        );
      } catch (e, s) {
        // 动作体同步抛出（罕见：非 async 闭包）：立即释放门后以失败
        // Future 形式上抛，保持与排队路径相同的错误通道。
        _release(gate);
        return Future<T>.error(e, s);
      }
      // ignore() 仅用于屏蔽派生 Future 的重复错误上报：动作体失败时错误
      // 仍经 result 原样交给调用方，这里不能无人监听二次冒泡。
      result.whenComplete(() => _release(gate)).ignore();
      return result;
    }

    return _runQueued<T>(previous, gate, action);
  }

  Future<T> _runQueued<T>(
    Future<void> previous,
    Completer<void> gate,
    Future<T> Function() action,
  ) async {
    await previous;
    try {
      return await runZoned(
        action,
        zoneValues: <Object?, Object?>{_zoneTokenKey: this},
      );
    } finally {
      _release(gate);
    }
  }

  void _release(Completer<void> gate) {
    gate.complete();
    // 只有当自己仍是队尾时才标记空闲；身后已有新排队者时保持忙。
    if (identical(_tail, gate.future)) {
      _tailSettled = true;
    }
  }
}
