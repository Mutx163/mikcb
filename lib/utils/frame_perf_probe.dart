import 'dart:ui' show FramePhase;

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
/// ## 首轮实测暴露的问题（本文件的预算口径就是为此改的）
///
/// 首轮跑在 `com.mutx163.qingyu.profile`（Redmi 25060RK16C / Android 16）上，
/// 探针自报 `thresholdMs=20.8`（= 16.7 × 1.25），也就是它认定屏幕是 60Hz。但
/// `adb shell dumpsys SurfaceFlinger --latency <SurfaceView 图层>` 的头行给出的
/// 是 **8333333ns（8.33ms = 120Hz）**，实测滚动时一半的送显间隔也正好是 8.3ms。
///
/// 原因：面板在**空闲 60Hz / 交互 120Hz** 之间切换，而探针是在启动（空闲）时读
/// `FlutterView.display.refreshRate` 的，读到的正是那个 60。于是**真实预算 8.3ms
/// 被放宽成了 20.8ms**，一整个交互过程里一帧都没被记为卡 —— 数据看着「全绿」，
/// 却跟用户看到的不流畅对不上。教训：预算不能只信显示上报，必须用**实测帧间隔**
/// 收紧（见 [_budgetUs]）。
///
/// ## 两种输出
///
/// - `[frame-perf] mark <label> ...`（主）：每次 [mark] 开一个窗口，把这次交互
///   之后 700ms 内（或 400 帧内）的帧汇总成**一条**：帧数、墙钟跨度、等效 fps、
///   窗口内实测 vsync 间隔、超预算帧数、最差与平均的 build / raster。**有没有
///   「超阈值」都照样出读数** —— 这正是首轮缺的那块：一帧没超标，但动画只跑到
///   60fps。
/// - `[frame-perf] burst ...`（粗）：没有标记的那类卡顿（冷启动、页面转场、未打点
///   的路径）靠它兜底。连续超预算的帧聚合成一条，附 `verdict=ui-bound /
///   raster-bound / both`，直接说明该往哪条线程找。
///
/// 判据：
/// - `verdict=ui-bound`，或窗口里 `worstBuildMs` 明显大于 `worstRasterMs`：UI 线程
///   （build / layout / paint）超时 —— 找构建重建、布局、paint 相位里的同步录帧
///   （`toImageSync`）。
/// - `raster-bound`，或 `worstRasterMs` 大：渲染线程（GPU）超时 —— 找离屏层
///   （Opacity / saveLayer）、模糊阴影、着色器。
/// - 窗口里 `fps` 明显低于 `1000 / vsyncMs`：动画掉帧，帧成本压不过 vsync 周期。
///
/// ## 用法
///
/// 1. `main()` 里 `FramePerfProbe.install()` —— 启动时一次。
/// 2. 关键交互处 `FramePerfProbe.mark('label')` —— 每条标记对应一条窗口读数。
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

  /// 「这一帧算卡」的容差倍数：真机上帧耗时本来就在预算附近抖动，乘 1.25
  /// 免得把正常抖动报成卡顿。**只用于 burst 的粗判**：标记窗口不做门槛，它按
  /// 实测间隔把每一帧都算一遍。
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

  /// 标记窗口的长度：一次弹层入场动画约 300~400ms，给到 700ms 把尾巴（弹簧
  /// 收敛、内容淡入）一起收进去。
  static const int _markWindowUs = 700000;

  /// 没有任何标记在跑时的兜底窗口长度：每 2 秒（且这段里真有帧）结算一条
  /// `steady` 读数，用来给「当下正在发生的任何事」（滚动、转场、悬停动画）
  /// 一个基线 —— 判「是弹层特别贵，还是这台设备/这块屏本来就贴着 120Hz 门槛」
  /// 就靠它对照。
  static const int _steadyWindowUs = 2000000;

  /// 兜底窗口的标签（不是交互标记，出线时不带 `mark` 前缀）。
  static const String _steadyLabel = 'steady';

  /// 单个窗口最多累计多少帧就强制结算（长动画 / 长滚动时给个上界）。
  static const int _windowMaxFrames = 400;

  /// 可信帧间隔的下限（微秒）：低于 4ms 的间隔不是 vsync 节奏 —— 引擎一次回调
  /// 可能投递多帧，同批帧的时间戳几乎相同。
  static const int _minPlausibleGapUs = 4000;

  /// 可信帧间隔的上限（微秒）：高于 40ms 的间隔是卡顿，不是面板节奏。
  static const int _maxPlausibleGapUs = 40000;

  /// `steady` 兜底窗口至少要有这么多帧才出一行：闲着没动画时几分钟才来一两帧，
  /// 那种「窗口」报出来只是噪音。
  static const int _minSteadyWindowFrames = 10;

  static bool _installed = false;

  /// 是否启用 `steady` 兜底窗口（测试里关掉，免得用例被它多打的行干扰）。
  static bool _steadyEnabled = true;

  /// 显示上报的单帧预算（微秒）：安装时按 `display.refreshRate` 算，读不到按 60Hz。
  static int _configuredBudgetUs = 16700;

  /// 实测到的最小相邻帧间隔（微秒）：0 = 还没采到可信样本。取自**引擎给的
  /// 每帧 vsync 时刻**，不是回调到达时间（见 [_sampleVsyncPeriod]）。
  ///
  /// 一次会话内**只收紧、不放宽**（取到过的最紧周期）。代价是面板从 120 掉回
  /// 60 档后预算会偏紧、`over` 偏悲观；收益是读数不会因为一次采样的窗口边界
  /// 而反复跳档。`budgetMs` 字段本身就打在同一行里，判读以它为准。
  static int _observedMinGapUs = 0;
  static int? _lastVsyncUs;

  /// 汇总输出落点；测试可替换成自己的收集器。
  static void Function(String line) _emit = debugPrint;

  /// 探针自己的单调时钟：与 `FrameTiming` 的时间戳无关，标记与卡顿段共用它，
  /// 偏移才有意义。
  static final Stopwatch _clock = Stopwatch();

  static int _framesTotal = 0;
  static int _jankyTotal = 0;

  // 当前「卡顿段」（burst）的累计值。
  static int _burstFrames = 0;
  static int _burstStartUs = 0;
  static int _burstLastUs = 0;
  static int _sumBuildUs = 0;
  static int _sumRasterUs = 0;
  static int _worstBuildUs = 0;
  static int _worstRasterUs = 0;
  static int _worstTotalUs = 0;

  // 当前「标记窗口」的累计值（`_windowLabel == null` 时无窗口）。
  static String? _windowLabel;
  static int _windowStartUs = 0;
  static int _windowFrames = 0;
  static int _windowLastUs = 0;
  static int _windowSumBuildUs = 0;
  static int _windowSumRasterUs = 0;
  static int _windowWorstBuildUs = 0;
  static int _windowWorstRasterUs = 0;
  static int _windowOverCount = 0;

  /// 交互标记：(标签, 时间戳微秒)。
  static final List<(String, int)> _marks = <(String, int)>[];

  /// 安装探针。[kReleaseMode] 下是空壳（正式包一行日志都不会有）。
  static void install() {
    if (_installed || kReleaseMode) {
      return;
    }
    _installed = true;
    final reportedRate = _reportedRefreshRate();
    _configuredBudgetUs = (1000000 / reportedRate).round();
    _clock.start();
    _steadyEnabled = true;
    _beginWindow(_steadyLabel, 0);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _emit(
      '$_tag installed reportedRateFps=$reportedRate '
      'budgetMs=${_ms(_configuredBudgetUs)} '
      '(budget tightens to the measured vsync gap)',
    );
  }

  /// 打一条交互标记（如 `select:open`）。未安装时是空操作。
  ///
  /// 会开一个新的读数窗口；上一个窗口若还没结算，先结算掉。
  static void mark(String label) {
    if (!_installed) {
      return;
    }
    final nowUs = _clock.elapsedMicroseconds;
    _openOrExtendWindow(label, nowUs);
    _marks.add((label, nowUs));
    _pruneMarks(nowUs);
  }

  /// 当前生效的单帧预算（微秒）：取「显示上报的」与「实测最小帧间隔」里**更紧**
  /// 的那个。
  ///
  /// 必须收紧的原因见类文档：面板空闲时 60Hz、交互时升 120Hz，而安装那一刻读到
  /// 的往往是空闲档 —— 照它算会把预算放宽一倍，把「每两帧掉一帧」读成正常。
  static int get _budgetUs {
    final observed = _observedMinGapUs;
    if (observed <= 0) {
      return _configuredBudgetUs;
    }
    return observed < _configuredBudgetUs ? observed : _configuredBudgetUs;
  }

  static int get _burstThresholdUs => (_budgetUs * _budgetTolerance).round();

  /// 显示上报的刷新率，读不到按 60Hz 兜底。
  static int _reportedRefreshRate() {
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
        vsyncUs: _vsyncStampOf(timing),
      );
    }
  }

  /// 这一帧的 vsync 时刻（引擎时间轴微秒，单调）；拿不到返回 null。
  static int? _vsyncStampOf(FrameTiming timing) {
    try {
      final stamp = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      return stamp > 0 ? stamp : null;
    } catch (_) {
      return null;
    }
  }

  /// 收一帧。窗口与标记的时间戳由调用方给（不在这里读表）：录帧回调可能一次
  /// 投递多帧，各帧用同一个「现在」会把一段卡顿压成 0ms。
  static void _ingest({
    required int buildUs,
    required int rasterUs,
    required int nowUs,
    int? vsyncUs,
  }) {
    if (!_installed) {
      return;
    }
    _framesTotal++;
    _sampleVsyncPeriod(vsyncUs);

    final totalUs = buildUs + rasterUs;

    final label = _windowLabel;
    if (label != null && nowUs - _windowStartUs <= _windowDurationUs(label)) {
      _accumulateWindow(
        buildUs: buildUs,
        rasterUs: rasterUs,
        totalUs: totalUs,
        nowUs: nowUs,
      );
    } else {
      // 窗口到期（或当前没有窗口）：先结算上一段读数，再用本帧开一段新的
      // 兜底窗口 —— 标记窗口结束后，基线读数要立刻接上。
      if (label != null) {
        _flushWindow();
      }
      if (_steadyEnabled) {
        _beginWindow(_steadyLabel, nowUs);
        _accumulateWindow(
          buildUs: buildUs,
          rasterUs: rasterUs,
          totalUs: totalUs,
          nowUs: nowUs,
        );
      }
    }

    if (totalUs <= _burstThresholdUs) {
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

  /// 窗口长度按标签分档：标记窗口短（一次交互动画），兜底窗口长（基线）。
  static int _windowDurationUs(String label) =>
      label == _steadyLabel ? _steadyWindowUs : _markWindowUs;

  /// 采一个 vsync 周期样本，用来把预算收紧到屏幕真实节奏（见 [_budgetUs]）。
  ///
  /// **必须用引擎给的每帧 vsync 时刻**，不能用回调到达时间：引擎在 UI 线程忙时
  /// 会把积压的多帧一次性投递，同批帧的到达时间几乎相同、批次之间又隔得很远，
  /// 于是「最小到达间隔」要么被过滤成 0 样本、要么是个自相矛盾的 100ms+。
  /// 2026-09-16 两轮真机分别打出了 `vsyncMs=126.8`（同窗口平均才 45ms）与
  /// 恒为 `?` 的读数 —— 都出在这个口径上。
  static void _sampleVsyncPeriod(int? vsyncUs) {
    if (vsyncUs == null) {
      return;
    }
    final previous = _lastVsyncUs;
    _lastVsyncUs = vsyncUs;
    if (previous == null) {
      return;
    }
    // 相邻两帧的 vsync 相隔整数个刷新周期：取窗口内最小的可信值即面板节奏
    // （掉了 vsync 的帧给出 2 倍、3 倍周期，取最小自然被排除在外）。
    final gap = vsyncUs - previous;
    if (gap < _minPlausibleGapUs || gap > _maxPlausibleGapUs) {
      return;
    }
    if (_observedMinGapUs == 0 || gap < _observedMinGapUs) {
      _observedMinGapUs = gap;
    }
  }

  /// 开窗口：无窗口时直接开；同一瞬间连着打两条（`dialog:open` → `sheet:open`
  /// 这类转发链）时合并标签 —— 否则前一条会以 0 帧收场、什么也读不到；已有帧的
  /// 窗口则先结算再开新的。
  static void _openOrExtendWindow(String label, int nowUs) {
    if (_windowLabel == null) {
      _beginWindow(label, nowUs);
      return;
    }
    if (_windowFrames == 0) {
      _windowLabel = '$_windowLabel+$label';
      _windowStartUs = nowUs;
      return;
    }
    _flushWindow();
    _beginWindow(label, nowUs);
  }

  static void _beginWindow(String label, int nowUs) {
    _windowLabel = label;
    _windowStartUs = nowUs;
    _windowFrames = 0;
    _windowLastUs = nowUs;
    _windowSumBuildUs = 0;
    _windowSumRasterUs = 0;
    _windowWorstBuildUs = 0;
    _windowWorstRasterUs = 0;
    _windowOverCount = 0;
  }

  static void _accumulateWindow({
    required int buildUs,
    required int rasterUs,
    required int totalUs,
    required int nowUs,
  }) {
    _windowFrames++;
    _windowLastUs = nowUs;
    _windowSumBuildUs += buildUs;
    _windowSumRasterUs += rasterUs;
    if (buildUs > _windowWorstBuildUs) {
      _windowWorstBuildUs = buildUs;
    }
    if (rasterUs > _windowWorstRasterUs) {
      _windowWorstRasterUs = rasterUs;
    }
    if (totalUs > _budgetUs) {
      _windowOverCount++;
    }
    if (_windowFrames >= _windowMaxFrames) {
      _flushWindow();
    }
  }

  /// 结算标记窗口，打一条读数。0 帧的窗口静默丢弃（标记打了但一帧都没出）。
  static void _flushWindow() {
    final label = _windowLabel;
    final frames = _windowFrames;
    final spanMs = (_windowLastUs - _windowStartUs) / 1000;
    final overCount = _windowOverCount;
    final worstBuildUs = _windowWorstBuildUs;
    final worstRasterUs = _windowWorstRasterUs;
    final sumBuildUs = _windowSumBuildUs;
    final sumRasterUs = _windowSumRasterUs;
    _windowLabel = null;
    if (label == null || frames == 0) {
      return;
    }
    if (label == _steadyLabel && frames < _minSteadyWindowFrames) {
      // 闲着没动：窗口里只有零星几帧，报出来只是噪音。
      return;
    }

    final budgetUs = _budgetUs;
    // vsync 取**全局**实测下限（引擎时间轴），不取本窗口自己的最小间隔：
    // 理由见 [_sampleVsyncPeriod]。
    final vsyncUs = _observedMinGapUs;
    final prefix = label == _steadyLabel ? _steadyLabel : 'mark $label';
    _emit(
      '$_tag $prefix frames=$frames spanMs=${spanMs.toStringAsFixed(0)} '
      'fps=${_fps(frames, spanMs)} '
      'vsyncMs=${vsyncUs == 0 ? '?' : _ms(vsyncUs)} '
      'budgetMs=${_ms(budgetUs)} over=$overCount '
      'worstBuildMs=${_ms(worstBuildUs)} '
      'worstRasterMs=${_ms(worstRasterUs)} '
      'avgBuildMs=${(sumBuildUs / frames / 1000).toStringAsFixed(1)} '
      'avgRasterMs=${(sumRasterUs / frames / 1000).toStringAsFixed(1)}',
    );
  }

  /// 结算当前卡顿段，打一条汇总。
  static void _flushBurst() {
    final frames = _burstFrames;
    _burstFrames = 0;
    final thresholdUs = _burstThresholdUs;
    // 单帧的轻微超预算不报（真机抖动），要么连着卡（≥2 帧），要么单帧就超
    // 两倍阈值（那已经掉了一整帧）。
    if (frames < 2 && _worstTotalUs < thresholdUs * 2) {
      return;
    }

    final spanMs = (_burstLastUs - _burstStartUs) / 1000;
    final marks = _marksNear(_burstStartUs, _burstLastUs);
    _emit(
      '$_tag burst frames=$frames spanMs=${spanMs.toStringAsFixed(0)} '
      'fps=${_fps(frames, spanMs)} '
      'worstBuildMs=${_ms(_worstBuildUs)} '
      'worstRasterMs=${_ms(_worstRasterUs)} '
      'worstTotalMs=${_ms(_worstTotalUs)} '
      'avgBuildMs=${(_sumBuildUs / frames / 1000).toStringAsFixed(1)} '
      'avgRasterMs=${(_sumRasterUs / frames / 1000).toStringAsFixed(1)} '
      'verdict=${_verdictOf(_worstBuildUs, _worstRasterUs)} '
      'budgetMs=${_ms(_budgetUs)} framesTotal=$_framesTotal '
      'jankyTotal=$_jankyTotal marks=[${marks.join(', ')}]',
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

  /// 等效帧率。`spanMs` 过小说明这批帧是引擎攒着一次性投递的（UI 线程刚被卡住
  /// 过），此时「帧数 ÷ 时间」的分子分母都不可信 —— 给 `?`，别报出
  /// `fps=3000000` 这种数字（2026-09-16 第二轮真机实见）。
  static String _fps(int frames, double spanMs) =>
      spanMs < 1 ? '?' : (frames * 1000 / spanMs).round().toString();

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
    _observedMinGapUs = 0;
    _lastVsyncUs = null;
    _windowLabel = _steadyEnabled ? _steadyLabel : null;
    _windowStartUs = 0;
    _windowFrames = 0;
    _windowLastUs = 0;
    _windowSumBuildUs = 0;
    _windowSumRasterUs = 0;
    _windowWorstBuildUs = 0;
    _windowWorstRasterUs = 0;
    _windowOverCount = 0;
    _marks.clear();
  }

  /// 测试专用安装：不碰 `SchedulerBinding`（不注册录帧回调、不开时钟），
  /// 预算按给定刷新率算，输出收到 [emit]。
  ///
  /// [steadyWindows] 默认关：兜底窗口会按 2 秒周期多打行，用例只想看自己那一条。
  @visibleForTesting
  static void debugInstall({
    required void Function(String line) emit,
    double refreshRate = 60,
    bool steadyWindows = false,
  }) {
    _installed = true;
    _emit = emit;
    _steadyEnabled = steadyWindows;
    _configuredBudgetUs = (1000000 / refreshRate).round();
    _resetState();
  }

  /// 测试专用喂帧：时间戳由调用方显式给，不读探针时钟。[vsyncUs] 是引擎时间轴
  /// 上的 vsync 时刻（用来估面板周期），不传就等于这一帧没有该样本。
  @visibleForTesting
  static void debugIngest({
    required int buildUs,
    required int rasterUs,
    required int nowUs,
    int? vsyncUs,
  }) => _ingest(
    buildUs: buildUs,
    rasterUs: rasterUs,
    nowUs: nowUs,
    vsyncUs: vsyncUs,
  );

  /// 测试专用标记。
  @visibleForTesting
  static void debugMark(String label, int nowUs) {
    if (!_installed) {
      return;
    }
    _openOrExtendWindow(label, nowUs);
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
