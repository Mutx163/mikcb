import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/course_auto_refresh_decision.dart';
import '../services/app_log_service.dart';
import '../services/course_auto_refresh_store.dart';

/// 一次自动更新的结局。
///
/// 与 [CourseAutoRefreshDecision] 分开：那个是「该不该跑」的判定，这个是「跑完
/// 怎么样」。两者混成一个枚举的话，「没到点」和「跑失败」就会被同一个分支吞掉，
/// 而前者（安静跳过）与后者（该提示用户）需要的处理完全相反。
enum CourseAutoRefreshOutcome {
  /// 功能关着。
  disabled,

  /// 还没到时间窗（或失败冷却中），本次没跑。
  notDue,

  /// 本机没有可用的快捷导入记录（用户还没录制过宏），静默跳过。
  ///
  /// **必须与 [failed] 分开**：没配过的人是「还没设置」，弹「自动更新失败」
  /// 会让人以为功能坏了。
  noSource,

  /// 上一次自动更新还没结束。
  busy,

  /// 跑完了，课表内容没有变化。
  unchanged,

  /// 跑完了，课表内容确实变了。
  updated,

  /// 跑了但失败（教务不可达、需要手动登录、会话超时等）。
  failed,
}

/// 「课表自动更新」的编排：判定时机 → 静默跑一次仓库快捷导入 → 比内容指纹 →
/// 决定要不要提示用户。
///
/// ## 为什么需要它独立成一个控制器
///
/// 它要同时被两条路径调用（冷启动、从后台回前台），而这两条路径分别在
/// `main.dart` 与 `timetable_screen.dart` 里。把编排写进任一处，另一处就得复制
/// 一份「读存档 → 判时间 → 跑 → 记账 → 提示」的流程，于是两份迟早会漂开
/// （最容易漂的就是「失败要记尝试时间」这一步）。
///
/// ## 依赖全部注入，不读 Provider、不碰 BuildContext
///
/// - 抓课表（[runImport]）由调用方闭包持有，因为那条链路要挂 Overlay；
/// - 课表内容指纹（[captureSignature]）由调用方从 Provider 取；
/// - 结果提示（[onOutcome]）由调用方决定用 toast 还是静默。
///
/// 这样本类可以在纯单元测试里被驱动，且**不新增任何 Provider 读取调用点**
/// （`dependency_guards_test` 的读取点棘轮当前余量为 0）。
class CourseAutoRefreshController extends ChangeNotifier {
  CourseAutoRefreshController({
    required this.runImport,
    required this.captureSignature,
    this.preflight,
    this.onOutcome,
    CourseAutoRefreshStore? store,
    DateTime Function()? now,
  }) : _store = store ?? CourseAutoRefreshStore.instance,
       _now = now ?? DateTime.now;

  /// 真正去抓一次课表（仓库快捷导入）。返回 true 表示导入流程成功走完。
  final Future<bool> Function() runImport;

  /// 跑之前的可运行性检查：本机有没有录好的快捷导入记录、有没有别的导入在跑。
  ///
  /// 返回 false 时**不记账**（[CourseAutoRefreshStore.recordAttempt] 都不写）：
  /// 用户今天才录好宏，不该因为昨天（还没录）的「跳过」还在冷却期而等半小时。
  final Future<bool> Function()? preflight;

  /// 当前课表内容指纹（见 `timetableContentSignature`）。
  final String Function() captureSignature;

  /// 结局回调：只有「该让用户知道」的结局会到这里（updated / failed）。
  final void Function(CourseAutoRefreshOutcome outcome)? onOutcome;

  final CourseAutoRefreshStore _store;
  final DateTime Function() _now;

  bool _running = false;
  CourseAutoRefreshOutcome? _lastOutcome;

  bool get isRunning => _running;
  CourseAutoRefreshOutcome? get lastOutcome => _lastOutcome;

  /// 现在的配置（读的是内存那份，同步）。
  CourseAutoRefreshSchedule get schedule => _store.schedule;

  /// 下次预计运行时刻（界面显示用）。
  DateTime? get nextRunAt => _store.nextRunAt(_now());

  /// 上次成功时刻（界面显示用）。
  DateTime? get lastSuccessAt => _store.lastSuccessAt;

  /// 按当前存档判定，到点就跑一次。
  ///
  /// 重复调用安全：在跑的时候直接返回 [CourseAutoRefreshOutcome.busy]，
  /// 不会叠出两个 WebView 会话。
  Future<CourseAutoRefreshOutcome> maybeRunNow() async {
    if (_running) {
      return CourseAutoRefreshOutcome.busy;
    }
    if (!_store.isLoaded) {
      await _store.load();
    }
    final now = _now();
    final decision = decideCourseAutoRefresh(
      schedule: _store.schedule,
      now: now,
      lastSuccess: _store.lastSuccessAt,
      lastAttempt: _store.lastAttemptAt,
    );
    switch (decision) {
      case CourseAutoRefreshDecision.disabled:
        return _finish(CourseAutoRefreshOutcome.disabled);
      case CourseAutoRefreshDecision.wait:
        return _finish(CourseAutoRefreshOutcome.notDue);
      case CourseAutoRefreshDecision.run:
        break;
    }

    _running = true;
    notifyListeners();
    if (preflight != null && !await preflight!()) {
      _running = false;
      notifyListeners();
      return _finish(CourseAutoRefreshOutcome.noSource);
    }
    // 先记「尝试」再动手：会话中途被系统 KILL 时，没有这条记录下次打开会
    // 立刻重来，而那次可能已经把教务登录走了一半。
    await _store.recordAttempt(now);
    final before = captureSignature();
    bool ok = false;
    try {
      ok = await runImport();
    } catch (error, stackTrace) {
      await AppLogService.instance.warn(
        'course_auto_refresh_failed',
        '课表自动更新失败',
        error: error,
        stackTrace: stackTrace,
      );
      ok = false;
    }
    _running = false;

    final finishedAt = _now();
    if (!ok) {
      notifyListeners();
      return _finish(CourseAutoRefreshOutcome.failed);
    }
    await _store.recordSuccess(finishedAt);
    final changed = captureSignature() != before;
    notifyListeners();
    return _finish(
      changed
          ? CourseAutoRefreshOutcome.updated
          : CourseAutoRefreshOutcome.unchanged,
    );
  }

  CourseAutoRefreshOutcome _finish(CourseAutoRefreshOutcome outcome) {
    _lastOutcome = outcome;
    if (outcome == CourseAutoRefreshOutcome.updated ||
        outcome == CourseAutoRefreshOutcome.failed) {
      onOutcome?.call(outcome);
    }
    return outcome;
  }

  /// 把一份新配置落盘（设置页调用）。
  Future<bool> saveSchedule(CourseAutoRefreshSchedule next) async {
    final ok = await _store.saveSchedule(next);
    notifyListeners();
    return ok;
  }
}
