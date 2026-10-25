// 性能探针门面：把「页面归属 + 帧账本 + 能耗代理 + 启动分段 + 落盘」接成一张网。
//
// ## 为什么要有这一层
//
// 仓里已有三件诊断件（`frame_perf_probe` 逐次交互、`first_frame_probe` 首帧拆解、
// `paint_probe` 层重绘计数）。它们共同的短板是**都要人手工打点**：没打标记的
// 路径（页面内滚动、设置子页、后台任务）就没有数据，而「这个版本到底哪一页
// 变慢了」需要的是**全页面**横向对比，不是几个被点名的动作。
//
// 这一层的做法是**零手工打点**：挂一个 [NavigatorObserver] 到 MaterialApp，
// 每个被推入/弹出的路由自动成为一行账。全仓 ~40 条路由入口因此一次性进表，
// 以后新增页面也不需要记得打点。只有**不经过 Navigator** 的两类切换
// （首页日/周/月视图、玻璃坞内嵌页）需要显式 [markPage]。
//
// ## 正式版的零开销怎么保证
//
// 门控在**装配那一侧**，不是靠探针内部到处判断：
// * [install] 在 release 且没带 `--dart-define=PERF_PROBE=true` 时直接返回，
//   不注册录帧回调、不起采样计时器、不读 /proc；
// * `main.dart` 的 `navigatorObservers` 取 [observer]——未安装时它是 null，
//   列表里连对象都不建。
// 于是正式版对每一帧、每一次 build 都是零调用，而不只是「调用很快」。
//
// ## 能耗口径（别被问成「功耗」）
//
// 未 root 读不到电流与 GPU 频率（2026-10-24 在 25060RK16C 实测
// `/sys/class/power_supply/battery/current_now` Permission denied），所以报表
// 给的是**能耗代理**：进程 CPU 时间、RSS 增量、每帧 build/raster 成本。
// 差分看趋势，不看绝对瓦数。
//
// ## 探针自己不制造它要找的东西
//
// 两条纪律（都是写的时候想到的失效方式，不是事后补的）：
// * 不调 `getprop` / 不做任何**主线程起进程**或同步列目录的读数：那一下是
//   毫秒级，探针会把自己要抓的卡顿造出来。
// * 落盘只在「这段时间真的多出帧了」时发生：空闲/挂机不写盘。否则一个
//   常驻诊断件等于给用户手机加了个每 5 秒的写盘任务——测功耗的工具自己费电。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'perf_page_ledger.dart';
import 'perf_proc_reader.dart';
import 'perf_startup.dart';

/// 探针总开关与接线点。
abstract final class PerfProbe {
  /// 快照 JSON 的结构版本。字段改名/加义时**必须**升它，
  /// 否则差分脚本会把「旧包没这个字段」读成「这一页归零了」。
  static const int schemaVersion = 1;

  /// 匿名路由先挂这个占位名，等它的首帧建完再回溯改成真正的页面名。
  static const String pendingPage = 'route:pending';

  /// 归一化失败时的最后一档行名。
  static const String unnamedPage = 'unnamed';

  /// 每页 CPU/RSS 的采样周期。
  ///
  /// 为什么不每帧读：`/proc/self/stat` 一次几十微秒，120Hz 下每帧读会让探针
  /// 自己变成掉帧来源，而它正是被派来找掉帧的。「这页一共烧了多少 CPU」按
  /// 250ms 采样的误差远小于页面之间的差异。代价是停留不足一个采样周期的页
  /// CPU 记 0——那种页的账本来就该由 `firstFrameMs` 说明。
  static const Duration _costSampleInterval = Duration(milliseconds: 250);

  /// 落盘检查周期。真正写不写由 [PerfPageLedger.totalFrames] 有没有涨决定。
  static const Duration _flushInterval = Duration(seconds: 5);

  /// 导出快照最多保留几轮（json+txt 成对计数）。
  static const int _maxKeptExports = 12;

  /// 匿名路由补名字时的回溯深度上界（见 [resolveWidgetPageId]）。
  static const int _resolveMaxDepth = 12;

  static bool _installed = false;
  static PerfPageLedger? _ledger;
  static PerfStartup? _startup;
  static NavigatorObserver? _observer;
  static WidgetsBindingObserver? _lifecycleObserver;
  static Timer? _sampleTimer;
  static Timer? _flushTimer;

  /// 录帧回调是否真的注册过。`debugInstall` 不注册它，所以卸载时不能靠
  /// 别的字段推断——SDK 的 `removeTimingsCallback` 里有
  /// `assert(_timingsCallbacks.contains(callback))`，摘一个没注册过的会直接断言失败。
  static bool _timingsRegistered = false;

  // 采样器读数。-1 = 还没量到（**不是**「量到 0」，见 [CostReading] 的口径）。
  static int _lastCpuMicros = -1;
  static int _lastRssKb = -1;

  /// 上一次落盘时的帧数，用来判断「这 5 秒到底有没有新东西」。
  static int _framesAtLastFlush = 0;

  /// 探针是否已安装（未安装时所有接口是空操作）。
  static bool get isInstalled => _installed;

  /// 供 `main()` 的 `navigatorObservers` 使用：未安装时是 null。
  static NavigatorObserver? get observer => _observer;

  /// 安装探针。重复调用是空操作。
  static void install() {
    if (_installed || (kReleaseMode && !_enabledInRelease)) {
      return;
    }
    _installed = true;
    _ledger = PerfPageLedger(
      nowUs: _nowUs,
      readCost: _currentCost,
      refreshRateHz: _reportedRefreshRate,
    );
    _startup = PerfStartup();
    _observer = _PerfRouteObserver();
    // 录帧回调是唯一「每帧都走」的入口，其余都靠低频计时器采样。
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _timingsRegistered = true;
    // 实例必须存下来：`removeObserver` 按 identical 比对，
    // 摘的时候 new 一个新对象会静默摘不掉（观察者泄漏，探针卸载不干净）。
    _lifecycleObserver = _PerfLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    _sampleTimer = Timer.periodic(_costSampleInterval, (_) => _sampleCost());
    _flushTimer = Timer.periodic(_flushInterval, (_) => unawaited(_flushIfBusy()));
    // 起点先取一次读数，第一段页面才不会一上来就是 null。
    _sampleCost();
    debugPrint(
      '[perf-probe] installed mode=${kReleaseMode ? 'release' : 'profile/debug'} '
      'schema=$schemaVersion costSampleMs=${_costSampleInterval.inMilliseconds}',
    );
  }

  /// 记一个启动阶段（用探针自己的单调时钟）。未安装时空操作。
  static void startupMark(String label) => _startup?.mark(label, _nowUs());

  /// 手工切换「当前页面」：只用于**不经过 Navigator** 的页面切换
  /// （首页日/周/月三个视图、玻璃坞的内嵌页）。
  static void markPage(String pageId) {
    final ledger = _ledger;
    if (ledger == null) {
      return;
    }
    final id = canonicalPageId(pageId);
    _lastPageId = id;
    ledger.beginPage(id);
  }

  static String? _lastPageId;

  /// 当前首页视图（`week` / `day` / `month`，未接追踪器时为 null）。
  ///
  /// 存在的理由：首页有两条互不相识的到达路径 —— 从子页 pop 回来时路由
  /// 观察者叫它 `TimetableScreen`（→ `home`），切视图时追踪器叫它
  /// `home:day`。两套名字各写一半，同一页在差分表里就**拆成两行**，两个
  /// 版本还未必按同样比例分裂，那会产生谁也对不上的假增减。所以路由侧
  /// 也要能用上「现在停在哪个视图」这件事。
  static String? _homeViewMode;

  /// 生命周期变化点落账：别让退后台的静止期记在最后一页头上。
  /// 回前台时把最后那页重新开起来（路由观察者不会为「恢复」而触发）。
  static void handleLifecycle(AppLifecycleState state) {
    final ledger = _ledger;
    if (ledger == null) {
      return;
    }
    switch (state) {
      // 五种状态都要覆盖（enum 加了新值时这里会编译不过，提醒补判据）。
      // inactive/hidden 也落账：HyperOS 的下拉通知、分屏、悬浮窗都会让它们出现，
      // 那些时刻页面不再跟手，把静止期记到某一页头上会冤枉它。
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        ledger.sealSegment();
      case AppLifecycleState.resumed:
        // 回前台重新开段：路由观察者不会为「恢复」而触发，不开就没人记账。
        final last = _lastPageId;
        if (last != null) {
          ledger.beginPage(last);
        }
    }
  }

  /// 整份快照（页面排行 + 启动分段 + 汇总 + 元数据）。
  static Map<String, Object?> snapshotJson() => buildSnapshotJson(
    ledger: _ledger,
    startup: _startup,
    meta: _meta(),
  );

  /// 人读文本（启动 + 排行两段），导出与剪贴板共用。
  static String reportText() {
    final ledger = _ledger;
    if (ledger == null) {
      return '[perf-probe] not installed (release build without PERF_PROBE)\n';
    }
    final buffer = StringBuffer();
    buffer.write(_startup?.formatTextReport() ?? '');
    buffer.write(ledger.formatTextReport());
    final meta = _meta();
    buffer.writeln(
      '[perf-probe] meta app=${meta['appVersion']} host=${meta['deviceModel']} '
      'platform=${meta['platform']} kernel=${meta['osKernelVersion']} '
      'rateHz=${meta['refreshRateHz']}',
    );
    return buffer.toString();
  }

  /// 导出一份带时间戳的快照（人为触发：报表页按钮）。返回 txt 路径。
  ///
  /// 与自动落盘的区分：这一份**永远写**（用户点了就要有文件），并顺手清理
  /// 旧轮次；自动那份只在有新帧时覆盖同一个滚动文件。
  static Future<String?> exportSnapshot() async {
    if (!_installed) {
      return null;
    }
    try {
      final dir = await _reportDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _writeJson(File('${dir.path}/perf-export-$stamp.json'));
      final txt = File('${dir.path}/perf-export-$stamp.txt');
      await txt.writeAsString(reportText(), flush: true);
      unawaited(_pruneOldExports(dir));
      return txt.path;
    } catch (error) {
      debugPrint('[perf-probe] export failed: $error');
      return null;
    }
  }

  /// 读最近一次自动落盘的快照（报表页打开时读它，避免每次都重算）。
  static Future<String?> readLiveReport() async {
    try {
      final dir = await _reportDirectory();
      final file = File('${dir.path}/$_liveFileName');
      return file.existsSync() ? file.readAsString() : null;
    } catch (error) {
      debugPrint('[perf-probe] read live failed: $error');
      return null;
    }
  }

  static const String _liveJsonName = 'perf-live.json';
  static const String _liveFileName = 'perf-live.txt';

  static Future<void> _flushIfBusy() async {
    final ledger = _ledger;
    if (ledger == null) {
      return;
    }
    final frames = ledger.totalFrames;
    // 没新帧就不写盘：空闲时一个字节都不该动（常驻诊断件的自律线）。
    if (frames <= _framesAtLastFlush) {
      return;
    }
    _framesAtLastFlush = frames;
    try {
      final dir = await _reportDirectory();
      await _writeJson(File('${dir.path}/$_liveJsonName'));
      await File('${dir.path}/$_liveFileName')
          .writeAsString(reportText(), flush: true);
    } catch (error) {
      debugPrint('[perf-probe] flush failed: $error');
    }
  }

  static Future<void> _writeJson(File file) async {
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshotJson()),
      flush: true,
    );
  }

  /// 只保留最近 [_maxKeptExports] 轮导出。
  ///
  /// 用异步遍历 + **文件名里的时间戳**判断新旧，不用 `listSync`/`statSync`：
  /// 同步列目录同样是主线程阻塞，而这正是探针要排除的干扰源。
  static Future<void> _pruneOldExports(Directory dir) async {
    try {
      final keep = <String, int>{};
      await for (final entity in dir.list()) {
        if (entity is! File) {
          continue;
        }
        final match = RegExp(r'^perf-export-(\d+)\.').firstMatch(
          entity.uri.pathSegments.last,
        );
        if (match == null) {
          continue;
        }
        keep[entity.path] = int.tryParse(match.group(1) ?? '') ?? 0;
      }
      if (keep.length <= _maxKeptExports * 2) {
        return;
      }
      final sorted = keep.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted.skip(_maxKeptExports * 2)) {
        try {
          await File(entry.key).delete();
        } catch (_) {
          // 单个文件删不掉不影响其它。
        }
      }
    } catch (_) {
      // 清理失败无所谓：导出本身已经成功。
    }
  }

  /// 清空累计值（新一轮巡检开始前调用）。
  static void reset() {
    _ledger?.reset();
    _startup?.reset();
    _framesAtLastFlush = 0;
    _lastCpuMicros = -1;
    _lastRssKb = -1;
    _sampleCost();
  }

  /// 当前账本累计帧数（报表页显示「采集中」心跳用）。
  static int get observedFrames => _ledger?.totalFrames ?? 0;

  // ── 可纯测的接线逻辑（不依赖 Flutter 引擎）──────────────────────────

  /// 页面 id 归一化。
  ///
  /// 为什么必须由探针统一做：`RouteSettings.name` 在本仓**没有统一约定**——
  /// `/settings`（带前导斜杠，平台路由与深链那条）与 `settings` 混着用，
  /// 匿名路由压根没有 name。两版本差分表靠「同一页的行名对得上」成立，
  /// 不归一化就会把一页拆成两行、或把两页并成一行，得出「这页变慢了」的假结论。
  static String normalizePageId(String? raw, {String? widgetType}) {
    var value = (raw ?? '').trim();
    if (value.isEmpty) {
      value = (widgetType ?? '').trim();
    }
    if (value.isEmpty) {
      return unnamedPage;
    }
    // 去掉泛型参数：`Foo<Bar>` 里那层是 payload 类型，不是页面身份。
    final angle = value.indexOf('<');
    if (angle > 0) {
      value = value.substring(0, angle);
    }
    // 多级路径只留最后一段（深链 `settings/live/testing` 同理）。
    final slash = value.lastIndexOf('/');
    if (slash >= 0) {
      value = value.substring(slash + 1);
    }
    // 类型串可能带库前缀（`material.Foo`、`dart:_internal.Foo` 这类打印形态）。
    // 页面/路由名里不会有点，所以取最后一段是安全的；不剥的话同一个页面会
    // 因为「从哪个库打印的」被拆成两行，差分表就比不齐了。
    final dot = value.lastIndexOf('.');
    if (dot >= 0) {
      value = value.substring(dot + 1);
    }
    // 报表行按空白切 token，名字里带换行会把一行劈成两行。
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? unnamedPage : value;
  }

  /// 从路由信息推出页面 id，按「越具体越优先」兜底：
  /// name → 路由泛型参数 → 页面 widget 类型 → 路由类型名 → [unnamedPage]。
  static String pageIdFrom({
    String? routeName,
    String? routeTypeString,
    String? widgetType,
  }) {
    final name = normalizePageId(routeName);
    if (name != unnamedPage) {
      return name;
    }
    final generic = _genericArgumentOf(routeTypeString);
    if (generic != null) {
      return normalizePageId(generic);
    }
    final widget = normalizePageId(null, widgetType: widgetType);
    if (widget != unnamedPage) {
      return widget;
    }
    return normalizePageId(null, widgetType: routeTypeString);
  }

  /// 取类型串里尖括号的最后一个泛型参数（`Foo<Bar<Baz>>` 取 `Baz`：
  /// 载荷套载荷时最内层才是页面类型）。`void` / `dynamic` / `null` 不算名字。
  static String? _genericArgumentOf(String? typeString) {
    final value = (typeString ?? '').trim();
    final open = value.indexOf('<');
    final close = value.lastIndexOf('>');
    if (open <= 0 || close <= open) {
      return null;
    }
    var inner = value.substring(open + 1, close).trim();
    if (inner.isEmpty) {
      return null;
    }
    if (inner.contains(',')) {
      inner = inner.substring(inner.lastIndexOf(',') + 1).trim();
    }
    final lastAngle = inner.lastIndexOf('<');
    if (lastAngle > 0) {
      inner = inner.substring(lastAngle + 1);
    }
    final normalized = normalizePageId(inner.trim());
    if (normalized == unnamedPage ||
        const <String>{'void', 'dynamic', 'null'}.contains(normalized)) {
      return null;
    }
    return normalized;
  }

  /// 首页三视图的行名。
  ///
  /// 为什么必须单独映射：首页的周/日是 `TimetableScreen` 自己的 State 选择，
  /// 月视图是**底栏内嵌页**（`dockInlinePageId`），三种切换都不经过 Navigator，
  /// 路由观察者一个字都看不见。不显式标记，这三页的帧账就会全部并进
  /// 「上一次经路由打开的那一页」头上——而那正是本次要抓的最大嫌疑区
  /// （月视图收放、日/周卡片转场都是这一批新加的东西）。
  ///
  /// [kHomeViewPagePrefix] 前缀同时被 [canonicalPageId] 用作收敛点：首页既是
  /// MaterialApp 的 `home`（观察者会给它 `TimetableScreen` 这个名字），又有
  /// 三个视图名，两套写法若各留一半，同一页会在差分表里被拆成两行。
  static String viewPageId(String? modeName) => switch (modeName) {
    'day' => '$kHomeViewPagePrefix:day',
    'week' => '$kHomeViewPagePrefix:week',
    'month' => '$kHomeViewPagePrefix:month',
    // 新增枚举值不该凭空多出一行空账：落到父级名字上，
    // 排行仍可读，缺名字这件事由笔记与用例说明。
    _ => kHomeViewPagePrefix,
  };

  /// 首页统一行名（路由侧与视图侧收敛到同一个名字）。
  static const String kHomeViewPagePrefix = 'home';

  /// 把观察者取到的名字再收一次口径。
  ///
  /// 只处理**已知会与视图名重叠**的那一个：课表主页面。其它页面原样通过，
  /// 这张表多写一条就是多一处误伤风险（把两个真不同的页面并成一行，
  /// 比行名不统一更难查）。
  static String canonicalPageId(String pageId) {
    final normalized = normalizePageId(pageId);
    if (normalized == 'TimetableScreen' ||
        normalized == kHomeViewPagePrefix) {
      // 知道停在哪个视图就归到那一行；不知道（未接追踪器）才用父级名。
      // 不递归：viewPageId 产出 `home:day`，不匹配上面两个值。
      return viewPageId(_homeViewMode);
    }
    return normalized;
  }

  /// 把首页三视图的切换接进来。
  ///
  /// 为什么不在 `timetable_screen.dart` 里打点：那是全仓最大的热文件
  /// （2,815 行棘轮、并行会话常驻），往里插打点既顶棘轮又容易撞车。而
  /// 日/周/月三个视图**都会**把结果写进持久化的 `timetableHomeViewMode`
  /// （日走 `persistDayView`、周走 `persistWeekView`、月由内嵌页 setter 经
  /// `homeViewModeForInlinePage` 落盘），所以监听这一处就同时拿到三个视图，
  /// 不需要知道是谁改的。
  ///
  /// 参数给闭包而不是直接 import provider：探针保持不认识业务类型，才不被
  /// 分层守卫拦下，也才能在测试里用假 source 驱动。
  static void attachHomeViewTracker({
    required Listenable source,
    required String? Function() modeName,
  }) {
    if (!isInstalled) {
      return;
    }
    // 装好时用户可能已经停在日视图，先补记一次，否则那段帧全记到 boot 头上。
    _applyHomeView(modeName);
    source.addListener(() => _applyHomeView(modeName));
  }

  static void _applyHomeView(String? Function() modeName) {
    String? mode;
    try {
      mode = modeName();
    } catch (_) {
      // 读数失败保持现状：探针不参与业务故障，也不该凭空猜出一个新行名。
      return;
    }
    // 先记下视图再开段：canonicalPageId 靠它把「返回首页」并到同一行。
    _homeViewMode = mode;
    markPage(viewPageId(mode));
  }

  /// 快照结构。抽成静态方法是为了让「字段名与层级」可测——
  /// 差分脚本只认这份结构，字段漂了会静默少算而不是报错。
  static Map<String, Object?> buildSnapshotJson({
    required PerfPageLedger? ledger,
    required PerfStartup? startup,
    required Map<String, Object?> meta,
  }) {
    final pages = ledger?.toJsonRows() ?? const <Map<String, Object?>>[];
    var frames = 0;
    var janky = 0;
    for (final page in pages) {
      frames += page['frames'] as int? ?? 0;
      janky += page['janky'] as int? ?? 0;
    }
    return <String, Object?>{
      'schema': schemaVersion,
      ...meta,
      // 判据块与 startup/pages 三块都在**未安装时也建**：正式包里报表页
      // 仍可能被打开，结构缺字段会被差分脚本当成「解析失败」而不是
      // 「这个包没采到数」，那是最难归因的一类误报。
      'probe': ledger?.budgetJson() ?? const <String, Object?>{
        'budgetMs': '?',
        'nominalMs': '?',
        'observedVsyncMs': '?',
      },
      'startup': startup?.toJson() ?? const <Map<String, Object?>>[],
      'totals': <String, Object?>{
        'pages': pages.length,
        'frames': frames,
        'janky': janky,
        'jankyPct': frames == 0
            ? '0.0'
            : (janky * 100 / frames).toStringAsFixed(1),
      },
      'pages': pages,
    };
  }

  /// 由 `main()` 拿到 PackageInfo 后回填，省得探针自己去等异步。
  static String appVersionHint = 'unknown';

  static void noteAppVersion(String version, String build) {
    appVersionHint = version.isEmpty ? 'unknown' : '$version+$build';
  }

  /// release 下是否也装探针：构建时加 `--dart-define=PERF_PROBE=true` 才生效。
  static const bool _enabledInRelease = bool.fromEnvironment('PERF_PROBE');

  // ── 内部：读数与接线 ────────────────────────────────────────────

  /// 单调时钟。用 [Stopwatch] 而不是 [DateTime]：后者会被系统校时带偏，
  /// 而启动分段与页面跨度全靠差值，时间倒流会把账算成 0 或负数。
  static final Stopwatch _clock = Stopwatch()..start();

  static int _nowUs() => _clock.elapsedMicroseconds;

  static CostReading _currentCost() => CostReading(
    cpuMicros: _lastCpuMicros < 0 ? null : _lastCpuMicros,
    rssKb: _lastRssKb < 0 ? null : _lastRssKb,
  );

  /// `/proc/self/stat` 路径；读不到时 RSS 走 `ProcessInfo` 兜底。
  static const String _procStatPath = '/proc/self/stat';

  /// USER_HZ：Linux 传统 100，部分 Android 内核 128 或更高。
  /// 读错会让 CPU 时间整体按比例失真（两版本同错还能比，绝对值不可信），
  /// 所以随 meta 一起写进报表，读的人能核对。
  static const int _clockTicksPerSecond = 100;
  static const int _pageBytes = 4096;

  static void _sampleCost() {
    try {
      final lines = File(_procStatPath).readAsLinesSync();
      if (lines.isNotEmpty) {
        final reading = parseProcSelfStat(
          lines.first,
          clockTicksPerSecond: _clockTicksPerSecond,
          pageBytes: _pageBytes,
        );
        if (reading.cpuMicros != null) {
          _lastCpuMicros = reading.cpuMicros!;
        }
        if (reading.rssKb != null) {
          _lastRssKb = reading.rssKb!;
          return;
        }
      }
    } catch (_) {
      // 读不到 /proc（非 Android、SELinux 拦截）：落到 dart:io 的现成读数。
    }
    try {
      // RSS 有等价接口；CPU 没有，宁可留 null 也不猜——猜错会伪装成「这页费电」。
      _lastRssKb = ProcessInfo.currentRss ~/ 1024;
    } catch (_) {
      // 保持上一轮读数：探针不参与业务故障。
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    final ledger = _ledger;
    if (ledger == null) {
      return;
    }
    for (final timing in timings) {
      ledger.ingest(
        buildUs: timing.buildDuration.inMicroseconds,
        rasterUs: timing.rasterDuration.inMicroseconds,
        vsyncUs: _vsyncStampOf(timing),
      );
    }
  }

  /// 引擎给的该帧 vsync 时刻（引擎时间轴，单调）。拿不到给 null。
  static int? _vsyncStampOf(FrameTiming timing) {
    try {
      final stamp = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      return stamp > 0 ? stamp : null;
    } catch (_) {
      return null;
    }
  }

  static double _reportedRefreshRate() {
    try {
      final views = SchedulerBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        final rate = views.first.display.refreshRate;
        if (rate.isFinite && rate > 1) {
          return rate;
        }
      }
    } catch (_) {
      // 兜底 60Hz；账本自己还会用实测 vsync 收紧。
    }
    return 60;
  }

  /// 系统版本串缓存。
  ///
  /// Android 上 `Platform.operatingSystemVersion` 给的是 **Linux 内核版本串**
  /// （不是 Android SDK 号、也不是机型），所以别拿它去 split 出「API level」——
  /// 那只会得到内核修订号，而读日志的人会当成 Android 版本来比。
  /// 机型与 Android 版本由采集侧（adb 那份 manifest）配对提供，
  /// 这里只留「两次跑的是不是同一台内核」这个可比性凭据。
  static String? _osVersionCache;

  static Map<String, Object?> _meta() {
    // 设备标识是差分表的可比性凭据：换机型/换刷新率跑出的数不能互相比。
    // 只取公开系统信息，不落任何用户数据。
    // 刻意不调 `getprop`：那是**主线程起一个进程**（1~5ms），每 5 秒落盘读两条
    // 就是两次可感知卡顿——探针把自己要抓的东西造出来，是这类工具最坏的失效方式。
    return <String, Object?>{
      'capturedAt': DateTime.now().toIso8601String(),
      'isReleaseMode': kReleaseMode,
      'refreshRateHz': _reportedRefreshRate(),
      'platform': Platform.operatingSystem,
      'osKernelVersion': _osVersionCache ??= _safeOsVersion(),
      'deviceModel': Platform.localHostname,
      'clockTicksPerSecond': _clockTicksPerSecond,
      'pageBytes': _pageBytes,
      'appVersion': appVersionHint,
    };
  }

  static String? _safeOsVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory>? _dirFuture;

  /// 报告目录。缓存那个 Future：不缓存的话每次落盘都要走一遍平台通道问路径。
  static Future<Directory> _reportDirectory() => _dirFuture ??= _createReportDirectory();

  static Future<Directory> _createReportDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/perf_reports');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 测试专用安装：只建账本/观察者，**不注册录帧回调、不起计时器**。
  ///
  /// 沿用 `FramePerfProbe.debugInstall` 的纪律：诊断件一旦在测试里留下
  /// pending timer，用例会以「A Timer is still pending」失败，而失败的
  /// 文件取决于谁先跑到——那是最难查的一类 flaky。
  @visibleForTesting
  static void debugInstall({int minDwellUs = 150000}) {
    _installed = true;
    _ledger = PerfPageLedger(
      nowUs: _nowUs,
      readCost: _currentCost,
      refreshRateHz: () => 60,
      // 测试里喂帧是微秒级、真机页面停留是秒级：需要关掉短访问合并时
      // 由调用方显式传 0，而不是让生产默认值迁就测试。
      minDwellUs: minDwellUs,
    );
    _startup = PerfStartup();
    _observer = _PerfRouteObserver();
    _framesAtLastFlush = 0;
    _lastPageId = null;
  }

  /// 卸载探针（仅供测试与常驻开关的关闭路径）。可重复调用。
  @visibleForTesting
  static void debugUninstall() {
    if (_timingsRegistered) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _timingsRegistered = false;
    }
    _sampleTimer?.cancel();
    _flushTimer?.cancel();
    _sampleTimer = null;
    _flushTimer = null;
    final observer = _lifecycleObserver;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
    }
    _installed = false;
    _ledger = null;
    _startup = null;
    _observer = null;
    _lifecycleObserver = null;
    _framesAtLastFlush = 0;
    _lastPageId = null;
    _homeViewMode = null;
    _dirFuture = null;
  }

  // 同文件内部句柄（观察者/生命周期观察者用，不对外暴露账本本体）。
  static PerfPageLedger? get openLedger => _ledger;

  /// 匿名路由首帧之后回溯改名（见 [PerfPageLedger.retargetOpenSegment]）。
  ///
  /// [openedAs] 是观察者当初挂上的占位 id：只有「现在开着的还是那一段」才允许
  /// 改名。中途又推了新路由时那一段早已闭合，账属于别人。
  static void retargetPendingPage(String openedAs, String pageId) {
    final ledger = openLedger;
    if (ledger == null || ledger.openPageId != openedAs) {
      return;
    }
    ledger.retargetOpenSegment(pageId);
  }

  /// 在子树里找「页面根」的 widget 类型名，用来给匿名路由补名字。
  ///
  /// 为什么需要：本仓多数路由是匿名的 `HyperosPageRoute<T>`（`pushHomeMenuPage`
  /// 就是一条），泛型参数还常常是 `void`，于是观察者拿不到任何页面身份。
  /// 而真机日志里最慢的几趟历史上全叫 `unnamed`
  /// （`hyperos_navigation.dart:1276` 记过这条），认不出是哪一页就没法继续查。
  ///
  /// 代价被两件事压住：① 只在**帧之后**跑一次（不进逐帧路径）；② 命中即停，
  /// 页面根就在子树最上层，正常只走两三层，且有 [_resolveMaxDepth] 上界。
  static String? resolveWidgetPageId(Route<dynamic> route) {
    final modal = route is ModalRoute<dynamic> ? route : null;
    final context = modal?.subtreeContext;
    if (context is! Element) {
      return null;
    }
    String? found;
    void visit(Element element, int depth) {
      if (found != null || depth > _resolveMaxDepth) {
        return;
      }
      final name = element.widget.runtimeType.toString();
      if (_looksLikePageWidget(name)) {
        found = name;
        return;
      }
      element.visitChildren((child) => visit(child, depth + 1));
    }

    try {
      visit(context, 0);
    } catch (_) {
      return null;
    }
    return found;
  }

  /// 页面 widget 的命名约定：本仓 53 个屏幕全是 `XxxScreen`，少数容器是
  /// `XxxPage`。外壳（`HyperosPage` / `HyperosSubpage`）刻意**排除**——它是
  /// 页面**内部**的公共壳，拿它当行名会把十几个页面并成一行。
  static bool _looksLikePageWidget(String name) {
    if (name.startsWith('_')) {
      // 下划线开头的是框架私有包装类，不是页面。
      return false;
    }
    if (const <String>{
      'HyperosPage',
      'HyperosSubpage',
      'HyperosSubpageNoBack',
      'Scaffold',
    }.contains(name)) {
      return false;
    }
    return name.endsWith('Screen') || name.endsWith('Page');
  }
}

/// 路由观察者：每个被推入/弹出的页面自动归属。只读，不改任何路由行为。
class _PerfRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _open(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 弹掉当前页：账要落回下面那张重新露出的页。
    final reveal = previousRoute;
    if (reveal != null) {
      _open(reveal);
    } else {
      PerfProbe.openLedger?.sealSegment();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _open(newRoute);
    }
  }

  void _open(Route<dynamic> route) {
    final ledger = PerfProbe.openLedger;
    if (ledger == null) {
      return;
    }
    final known = PerfProbe.canonicalPageId(
      PerfProbe.pageIdFrom(
        routeName: route.settings.name,
        routeTypeString: route.runtimeType.toString(),
      ),
    );
    if (known != PerfProbe.unnamedPage) {
      PerfProbe.markPage(known);
      return;
    }
    // 认不出路：先挂占位名，等这一页首帧建完再回溯改名。
    PerfProbe.markPage(PerfProbe.pendingPage);
    final openedAs = ledger.openPageId;
    if (openedAs != PerfProbe.pendingPage) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final pageId = PerfProbe.resolveWidgetPageId(route);
      // 认不出来也留一行可读的名字（路由类型名），别让所有认不出的页面
      // 挤在同一行里——那是老探针踩过的坑。
      PerfProbe.retargetPendingPage(
        openedAs,
        PerfProbe.canonicalPageId(
          PerfProbe.normalizePageId(
            pageId,
            widgetType: route.runtimeType.toString(),
          ),
        ),
      );
    });
  }
}

/// 生命周期观察者：退后台落账、回前台重新开段。
class _PerfLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PerfProbe.handleLifecycle(state);
  }
}
