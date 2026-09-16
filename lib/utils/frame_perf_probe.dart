import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 帧耗时探针（**临时诊断件**，只在非 release 包生效）。
///
/// 存在的理由：2026-09-16 排查「柔光档下关掉『下拉选择弹窗』的玻璃后，弹窗显示
/// 实底、出场仍然有一点卡顿」。读代码排得出三条嫌疑（上游弹层淡入期的离屏层、
/// 每帧重算的 20px 模糊阴影、玻璃面驱动的页面逐帧录帧），但三条的**修法完全
/// 不同**，而它们的共同点是「不随弹窗材质切换而消失」—— 所以「关掉玻璃后还是卡」
/// 这件事本身反推不出是哪一条，必须有实测数据。
///
/// 本探针只做一件事：把**连续超预算**的帧聚合成一条日志，并把这一段时间花在
/// 哪个线程上直接判出来：
///
/// - `verdict=ui-bound`：UI 线程（build / layout / paint）超时。往「构建重建、
///   布局、paint 相位的同步录帧（`toImageSync`）」这条线找。
/// - `verdict=raster-bound`：渲染线程（GPU）超时。往「离屏层（Opacity /
///   saveLayer）、模糊阴影、着色器」这条线找。
/// - `verdict=both`：两边都超，通常是一条链上的连带（例如 UI 侧多一层离屏层，
///   渲染侧就要多合成一遍）。
///
/// ## 用法
///
/// 1. `main()` 里 `FramePerfProbe.install()` —— 启动时一次。
/// 2. 关键交互处 `FramePerfProbe.mark('label')` —— 汇总里会带上「标记落在这段
///    卡顿之前/之后多少毫秒」（如 `select:open@+3ms`），用来把卡顿归因到动作。
/// 3. 真机复现 → 在 `flutter run` 输出或 `adb logcat` 里搜 `[frame-perf]`。
///
/// ## 纪律
///
/// - 只打日志：不落盘、不上报、**不改任何绘制行为**，也不持有计时器（不会有
///   测试残留 pending timer）。
/// - 消息一律英文：CJK 硬编码审计按行计数，日志串不该混进去（同 `[wpp-glass]`
///   的口径）。
/// - 问题收敛后，本文件与全部 `FramePerfProbe.mark(...)` 调用点一起删
///   （清单见 `.agents/notes/implemented/process/2026-09-16-frame-perf-probe.md`）。
abstract final class FramePerfProbe {
  /// 日志前缀，搜这一个词就能捞出全部输出。
  static const String _tag = '[frame-perf]';

  /// 「这一帧算卡」的容差倍数：预算 = 1/刷新率，真机上帧耗时本来就在预算附近
  /// 抖动，乘 1.25 免得把正常抖动报成卡顿。
  static const double _budgetTolerance = 1.25;

  /// 一段卡顿最多累计这么多帧就强制结算一条，避免长时间持续卡顿时日志要等
  /// 「卡完」才出（120Hz 下 180 帧 ≈ 1.5s）。
  static const int _maxBurstFrames = 180;

  /// 标记保留窗口：更早的标记与本次卡顿无关，直接丢掉，不让它们无限堆积。
  static const int _markRetentionUs = 2000000;

  /// 归因窗口：卡顿开始**之前**这么久以内的标记也算相关（按下按钮到动画起帧
  /// 之间通常隔着一两帧）。
  static const int _markLookbackUs = 500000;

  /// 标记条数上限：一段卡顿前的标记再多也不该把日志行撑爆。
  static const int _maxMarks = 12;

  static bool _installed = false;

  /// 单帧卡顿阈值（微秒）：预算 × [_budgetTolerance]。
  static int _thresholdUs = 20800;

  /// 汇总输出落点；测试可替换成自己的收集器。
  static void Function(String line) _emit = debugPrint;

  /// 探针自己的单调时钟：与 `FrameTiming` 的时间戳无关，标记与卡顿段共用它，
  /// 偏移才有意义。
  static final Stopwatch _clock = Stopwatch();

  static int _framesTotal = 0;
  static int _jankyTotal = 0;

  // 当前「卡顿段」的累计值（无卡顿时全为 0）。
  static int _burstFrames = 0;
  static int _burstStartUs = 0;
  static int _burstLastUs = 0;
  static int _sumBuildUs = 0;
  static int _sumRasterUs = 0;
  static int _worstBuildUs = 0;
  static int _worstRasterUs = 0;
  static int _worstTotalUs = 0;

  /// 交互标记：(标签, 时间戳微秒)。
  static final List<(String, int)> _marks = <(String, int)>[];

  /// 安装探针。[kReleaseMode] 下是空壳（正式包一行日志都不会有）。
  static void install() {
    if (_installed || kReleaseMode) {
      return;
    }
    _installed = true;
    _thresholdUs = ((1000000 / _refreshRate()) * _budgetTolerance).round();
    _clock.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _emit('$_tag installed thresholdMs=${_ms(_thresholdUs)}');
  }

  /// 打一条交互标记（如 `select:open`）。未安装时是空操作。
  static void mark(String label) {
    if (!_installed) {
      return;
    }
    final nowUs = _clock.elapsedMicroseconds;
    _marks.add((label, nowUs));
    _pruneMarks(nowUs);
  }

  /// 一帧的预算（微秒）：按屏幕刷新率算，读不到显示信息时按 60Hz 兜底
  /// （探针不该因为拿不到刷新率而整条失效）。
  static int _refreshRate() {
    var rate = 60.0;
    try {
      final views = SchedulerBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        final detected = views.first.display.refreshRate;
        if (detected.isFinite && detected > 1) {
          rate = detected;
        }
      }
    } catch (_) {
      // 兜底 60Hz。
    }
    return rate.round();
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _ingest(
        buildUs: timing.buildDuration.inMicroseconds,
        rasterUs: timing.rasterDuration.inMicroseconds,
        nowUs: _clock.elapsedMicroseconds,
      );
    }
  }

  /// 收一帧。预算内 = 结算当前卡顿段；超预算 = 累进当前卡顿段。
  ///
  /// 时间戳由调用方给（不在这里读表）：录帧回调可能一次投递多帧，各帧用同一个
  /// 「现在」会把一段卡顿压成 0ms。
  static void _ingest({
    required int buildUs,
    required int rasterUs,
    required int nowUs,
  }) {
    if (!_installed) {
      return;
    }
    _framesTotal++;
    final totalUs = buildUs + rasterUs;
    if (totalUs <= _thresholdUs) {
      if (_burstFrames > 0) {
        _flushBurst();
      }
      return;
    }

    _jankyTotal++;
    if (_burstFrames == 0) {
      _burstStartUs = nowUs;
      _sumBuildUs = 0;
      _sumRasterUs = 0;
      _worstBuildUs = 0;
      _worstRasterUs = 0;
      _worstTotalUs = 0;
    }
    _burstFrames++;
    _burstLastUs = nowUs;
    _sumBuildUs += buildUs;
    _sumRasterUs += rasterUs;
    if (buildUs > _worstBuildUs) {
      _worstBuildUs = buildUs;
    }
    if (rasterUs > _worstRasterUs) {
      _worstRasterUs = rasterUs;
    }
    if (totalUs > _worstTotalUs) {
      _worstTotalUs = totalUs;
    }
    if (_burstFrames >= _maxBurstFrames) {
      _flushBurst();
    }
  }

  /// 结算当前卡顿段，打一条汇总。
  static void _flushBurst() {
    final frames = _burstFrames;
    _burstFrames = 0;
    // 单帧的轻微超预算不报（真机抖动），要么连着卡（≥2 帧），要么单帧就超
    // 两倍阈值（那已经掉了一整帧）。
    if (frames < 2 && _worstTotalUs < _thresholdUs * 2) {
      return;
    }

    final spanMs = (_burstLastUs - _burstStartUs) / 1000;
    final fps = spanMs <= 0 ? 0 : (frames * 1000 / spanMs).round();
    final marks = _marksNear(_burstStartUs, _burstLastUs);
    _emit(
      '$_tag burst frames=$frames spanMs=${spanMs.toStringAsFixed(0)} fps=$fps '
      'worstBuildMs=${_ms(_worstBuildUs)} '
      'worstRasterMs=${_ms(_worstRasterUs)} '
      'worstTotalMs=${_ms(_worstTotalUs)} '
      'avgBuildMs=${(_sumBuildUs / frames / 1000).toStringAsFixed(1)} '
      'avgRasterMs=${(_sumRasterUs / frames / 1000).toStringAsFixed(1)} '
      'verdict=${_verdictOf(_worstBuildUs, _worstRasterUs)} '
      'framesTotal=$_framesTotal jankyTotal=$_jankyTotal '
      'marks=[${marks.join(', ')}]',
    );
  }

  /// 谁把这一帧拖过预算了：两条线程各占一半以上（1.3 倍）才算单边。
  static String _verdictOf(int buildUs, int rasterUs) {
    if (buildUs >= rasterUs * 1.3) {
      return 'ui-bound';
    }
    if (rasterUs >= buildUs * 1.3) {
      return 'raster-bound';
    }
    return 'both';
  }

  /// 本段卡顿前后（含 [_markLookbackUs] 回看窗）的标记，带相对偏移。
  static List<String> _marksNear(int startUs, int endUs) {
    final result = <String>[];
    for (final (label, atUs) in _marks) {
      if (atUs < startUs - _markLookbackUs || atUs > endUs) {
        continue;
      }
      final offsetUs = atUs - startUs;
      final sign = offsetUs >= 0 ? '+' : '-';
      result.add('$label@$sign${(offsetUs.abs() / 1000).toStringAsFixed(0)}ms');
    }
    return result;
  }

  static void _pruneMarks(int nowUs) {
    _marks.removeWhere((entry) => nowUs - entry.$2 > _markRetentionUs);
    while (_marks.length > _maxMarks) {
      _marks.removeAt(0);
    }
  }

  /// 微秒 → 毫秒字符串（一位小数，不带单位后缀：字段名里已带 `Ms`）。
  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  static void _resetState() {
    _framesTotal = 0;
    _jankyTotal = 0;
    _burstFrames = 0;
    _burstStartUs = 0;
    _burstLastUs = 0;
    _sumBuildUs = 0;
    _sumRasterUs = 0;
    _worstBuildUs = 0;
    _worstRasterUs = 0;
    _worstTotalUs = 0;
    _marks.clear();
  }

  /// 测试专用安装：不碰 `SchedulerBinding`（不注册录帧回调、不开时钟），
  /// 阈值按给定刷新率算，输出收到 [emit]。
  @visibleForTesting
  static void debugInstall({
    required void Function(String line) emit,
    double refreshRate = 60,
  }) {
    _installed = true;
    _emit = emit;
    _thresholdUs = ((1000000 / refreshRate) * _budgetTolerance).round();
    _resetState();
  }

  /// 测试专用喂帧：时间戳由调用方显式给，不读探针时钟。
  @visibleForTesting
  static void debugIngest({
    required int buildUs,
    required int rasterUs,
    required int nowUs,
  }) => _ingest(buildUs: buildUs, rasterUs: rasterUs, nowUs: nowUs);

  /// 测试专用标记。
  @visibleForTesting
  static void debugMark(String label, int nowUs) {
    _marks.add((label, nowUs));
    _pruneMarks(nowUs);
  }

  /// 测试专用复位。
  @visibleForTesting
  static void debugReset() {
    _installed = false;
    _emit = debugPrint;
    _resetState();
  }
}
