// 页面性能账本：把「哪一页掉帧、哪一页费电」变成可排序的结构化读数。
//
// 与同目录 `frame_perf_probe.dart`（逐次交互的日志窗口）的分工：
// * 那个量「这一次动作」，一段一条、只进日志，读完就散；
// * 这个量「这一整页从头到尾」，按页面累计成一张可导出的排行表。
// 两者共用同一套判据口径（预算必须被实测 vsync 收紧），但互不调用，
// 以免其中一个被删掉时把另一个拖崩。
//
// 刻意保持**纯 Dart、零 Flutter 依赖**：账本的全部行为都能在不起引擎的前提下
// 被单元测试逐条判定（`test/utils/perf_page_ledger_test.dart`）。时钟与成本读数
// 都是注入的——真机接线在 `perf_probe.dart`，测试里换成可控时钟，于是
// 「页内 CPU 毫秒」这类期望值是人手算出来的，不是从实现里抄的。
//
// 能耗口径说明（为什么没有「毫瓦」）：未 root 的设备读不到
// `/sys/class/power_supply/*/current_now`（2026-10-24 在 25060RK16C 实测
// Permission denied），所以这里给的是**能耗代理指标**：进程 CPU 时间 +
// RSS 增量 + 帧成本。三者与耗电同源（都是「这页让硬件多干了多久」），
// 两版本差分表上可比；但它不是功率表，汇报与文档里都不许写成「功耗 mAh」。

/// 一次成本读数。任一字段读不到就是 null，**不能填 0**——
/// 0 会被读成「这一页不费电」，而真实含义是「这一页没量到」。
class CostReading {
  const CostReading({required this.cpuMicros, required this.rssKb});

  /// 进程累计 CPU 时间（用户态 + 内核态，微秒）。
  final int? cpuMicros;

  /// 常驻内存（KB）。
  final int? rssKb;
}

/// 一个页面的累计读数。报表的每一行就是它。
class PagePerfSample {
  const PagePerfSample({
    required this.pageId,
    required this.frames,
    required this.jankyFrames,
    required this.spanUs,
    required this.firstFrameLatencyUs,
    required this.worstBuildUs,
    required this.worstRasterUs,
    required this.avgBuildUs,
    required this.avgRasterUs,
    required this.cpuMicros,
    required this.rssDeltaKb,
    required this.budgetUs,
  });

  final String pageId;

  /// 落在这一页的帧数。
  final int frames;

  /// 其中 `build + raster > 预算 × 1.25` 的帧数。
  final int jankyFrames;

  /// 有帧的墙钟跨度之和（微秒）：只算这一页自己有帧的时间。
  /// 被别的页面占走的、静止无帧的都不记在它头上——否则「停在某页不动」
  /// 会伪装成「这页很慢」。
  final int spanUs;

  /// 「进入这一页 → 这一页第一帧」的延迟；没出过帧的页面不会出现在报表里。
  final int? firstFrameLatencyUs;

  final int worstBuildUs;
  final int worstRasterUs;
  final double avgBuildUs;
  final double avgRasterUs;

  /// 这一页期间进程烧掉的 CPU 时间（微秒）；读不到为 null。
  final int? cpuMicros;

  /// 这一页期间 RSS 的最大段内增量（KB）；读不到为 null。
  final int? rssDeltaKb;

  /// 结算时的单帧预算（微秒），让每行读数自带判据。
  final int budgetUs;

  double get jankyRatio => frames == 0 ? 0 : jankyFrames / frames;

  /// 等效帧率：`(帧数 - 1) ÷ 跨度`。
  ///
  /// 分子必须是**间隔数**：n 帧只覆盖 n-1 个间隔，用帧数会把 60Hz 的稳定
  /// 喂帧读成 72fps（写这条时差点把 60 的期望值改成 72，那是把口径错误
  /// 固化成基线）。跨度不足 1ms 或帧数 < 2 时给 null——引擎一次投递多帧时
  /// 「帧数 ÷ 时间」的分子分母都不可信，别报出天文数字。
  double? get fps =>
      (frames < 2 || spanUs < 1000) ? null : (frames - 1) * 1000000 / spanUs;

  /// 谁把这一页拖过预算：最差帧里 build / raster 占 1.3 倍以上才算单边。
  /// 另一栏为 0 也要判得出来（构建瓶颈页的 raster 常常就是 0）。
  String get verdict {
    if (worstBuildUs <= 0 && worstRasterUs <= 0) {
      return '-';
    }
    if (worstRasterUs == 0 || worstBuildUs >= worstRasterUs * 1.3) {
      return 'ui-bound';
    }
    if (worstBuildUs == 0 || worstRasterUs >= worstBuildUs * 1.3) {
      return 'raster-bound';
    }
    return 'both';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'page': pageId,
    'frames': frames,
    'janky': jankyFrames,
    'jankyPct': (jankyRatio * 100).toStringAsFixed(1),
    'spanMs': _ms(spanUs),
    'fps': fps?.toStringAsFixed(1),
    'firstFrameMs': firstFrameLatencyUs == null ? null : _ms(firstFrameLatencyUs!),
    'worstBuildMs': _ms(worstBuildUs),
    'worstRasterMs': _ms(worstRasterUs),
    'avgBuildMs': (avgBuildUs / 1000).toStringAsFixed(1),
    'avgRasterMs': (avgRasterUs / 1000).toStringAsFixed(1),
    'cpuMs': cpuMicros == null ? null : _ms(cpuMicros!),
    'rssDeltaKb': rssDeltaKb,
    'budgetMs': _ms(budgetUs),
    'verdict': verdict,
  };

  /// 一行文本读数（导出给人看、给差分脚本 grep）。
  String formatLine() {
    final fpsText = fps == null ? '?' : fps!.toStringAsFixed(0);
    final firstText = firstFrameLatencyUs == null ? '?' : _ms(firstFrameLatencyUs!);
    final cpuText = cpuMicros == null ? '?' : _ms(cpuMicros!);
    final rssText = rssDeltaKb == null ? '?' : '$rssDeltaKb';
    return 'page=$pageId frames=$frames janky=$jankyFrames(${_pct(jankyRatio)}) '
        'fps=$fpsText spanMs=${_ms(spanUs)} firstFrameMs=$firstText '
        'worstBuildMs=${_ms(worstBuildUs)} worstRasterMs=${_ms(worstRasterUs)} '
        'avgBuildMs=${(avgBuildUs / 1000).toStringAsFixed(1)} '
        'avgRasterMs=${(avgRasterUs / 1000).toStringAsFixed(1)} '
        'cpuMs=$cpuText rssDeltaKb=$rssText verdict=$verdict '
        'budgetMs=${_ms(budgetUs)}';
  }

  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  static String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(0)}%';
}

/// 页面账本。由 `perf_probe.dart` 在诊断包里实例化；
/// 正式版根本不构造它（零开销由那一侧的门控保证）。
class PerfPageLedger {
  PerfPageLedger({
    required int Function() nowUs,
    required CostReading Function() readCost,
    required double Function() refreshRateHz,
    this.minDwellUs = 150000,
  }) :
       // 三个读数源存成私有字段。`prefer_initializing_formals` 在这里无法满足：
       // Dart 不允许下划线开头的**具名**形参，改位置参反而更容易串位（三个
       // 同型 `int Function()`）。沿用仓内先例（`open_container.dart:161`）逐条
       // ignore。中文只写在**起行的注释**里：CJK 审计按行计数，代码行尾的中文
       // 会被算成硬编码（`}) : // 中文` 这种写法就中过一次）。
       // ignore: prefer_initializing_formals
       _nowUs = nowUs,
       // ignore: prefer_initializing_formals
       _readCost = readCost,
       // ignore: prefer_initializing_formals
       _refreshRateHz = refreshRateHz {
    _configuredBudgetUs = (1000000 / _safeRate()).round();
  }

  /// 「这一帧算卡」的容差倍数：真机帧耗时本来就在预算附近抖动。
  static const double _budgetTolerance = 1.25;

  /// 可信 vsync 间隔下限（微秒）：低于它不是面板节奏，是引擎一次投递多帧。
  static const int _minPlausibleGapUs = 4000;

  /// 可信 vsync 间隔上限（微秒）：高于它是卡顿或长空闲后的第一帧。
  static const int _maxPlausibleGapUs = 40000;

  /// 还没切过页时的归属：启动期的帧不该无处可去。
  static const String bootPage = 'boot';

  /// 一段访问短于这个时长就并进前一页（误触一下不该在排行里占一行）。
  ///
  /// 150ms 是转场时长量级：比一次正常跳转的动画还短，说明用户根本没停在
  /// 那一页。产品口径，不是某个用例的临时值（有用例专门钉它）。
  final int minDwellUs;

  final int Function() _nowUs;
  final CostReading Function() _readCost;
  final double Function() _refreshRateHz;

  /// 按上报刷新率算出的预算（微秒）——只会因实测节奏而**收紧**。
  int _configuredBudgetUs = 16667;

  /// 实测到的最小可信 vsync 间隔（微秒）；0 = 还没采到样本。
  int _observedMinGapUs = 0;
  int? _lastVsyncUs;

  int _framesAll = 0;

  /// 已结算页面的累计桶（按首次出现顺序）。
  final Map<String, _Accum> _closed = <String, _Accum>{};

  /// 当前正在计量的一段。
  _Seg _seg = _Seg();

  /// 上一个结算过的页面 id，用于「短访问并入前一页」。
  String? _prevPageId;

  /// 本次会话累计收下的帧数（跨所有页面，含未闭合段）。
  ///
  /// 门面的「这段时间有没有新东西」判据用它：空闲/挂机时账本不涨，就不该
  /// 写盘。一个常驻诊断件如果每 5 秒无条件写一次文件，等于给用户手机加了
  /// 一个周期性 I/O 任务——测功耗的工具自己费电，是最讽刺的失效方式。
  int get totalFrames => _framesAll;

  /// 判据读数：报表与差分脚本都要知道「这一轮是按什么阈值判的红」。
  ///
  /// 三栏必须并排，不能只给生效的那个：`budgetMs` 会被实测 vsync 收紧，
  /// 而收紧本身可能出错 —— 2026-09-16 首轮探针照显示上报的 60Hz 算预算，
  /// 把 120Hz 面板上的整段卡顿读成「全绿」。只有 `nominalMs`（上报值）与
  /// `observedVsyncMs`（实测值）同时在场，读的人才能判断这次收紧对不对。
  Map<String, Object?> budgetJson() => <String, Object?>{
    'budgetMs': _msFor(budgetUs),
    'nominalMs': _msFor(_configuredBudgetUs),
    // 没采到样本必须是 '?'：给 0 会被读成「这块屏的帧周期是 0 毫秒」，
    // 而真实含义是「还没量到」。
    'observedVsyncMs': _observedMinGapUs == 0
        ? '?'
        : _msFor(_observedMinGapUs),
  };

  static String _msFor(int micros) => (micros / 1000).toStringAsFixed(1);

  /// 单帧预算（微秒）：取「显示上报」与「实测最小帧间隔」里更紧的那个。
  ///
  /// 必须收紧是真机踩过的：面板空闲 60Hz / 交互 120Hz，启动时读到的往往是
  /// 空闲档，照它算会把预算放宽一倍，整段卡顿一帧都记不上。
  int get budgetUs {
    final observed = _observedMinGapUs;
    if (observed <= 0) {
      return _configuredBudgetUs;
    }
    return observed < _configuredBudgetUs ? observed : _configuredBudgetUs;
  }

  int get _jankyThresholdUs => (budgetUs * _budgetTolerance).round();

  double _safeRate() {
    final rate = _refreshRateHz();
    return (rate.isFinite && rate > 1) ? rate : 60;
  }

  /// 切页：结算上一段、开新段。重复 begin 同一页是空操作——
  /// 滚动、回前台这类「还在这一页」不该被当成换了一页。
  void beginPage(String pageId) {
    final nowUs = _nowUs();
    final current = _seg.pageId ?? bootPage;
    if (current == pageId) {
      return;
    }
    _closeSeg(nowUs);
    final cost = _readCost();
    _seg = _Seg(
      pageId: pageId,
      startUs: nowUs,
      cpuStart: cost.cpuMicros,
      rssStart: cost.rssKb,
    );
  }

  /// 收一帧。时刻由账本自己的时钟取（与 [beginPage] 同源，偏移才可比）。
  ///
  /// [vsyncUs] 是引擎给的该帧 vsync 时刻（引擎时间轴，单调），只用来估面板
  /// 节奏；不传等于这一帧没有该样本。
  void ingest({required int buildUs, required int rasterUs, int? vsyncUs}) {
    _sampleVsyncPeriod(vsyncUs);
    _framesAll++;
    _seg.ingest(
      atUs: _nowUs(),
      buildUs: buildUs,
      rasterUs: rasterUs,
      janky: buildUs + rasterUs > _jankyThresholdUs,
    );
  }

  /// 生命周期变化点（退后台 / 回前台）落一次账：否则整段静止时间会因为
  /// 「还挂着这一页」被算进它的跨度里（虽然跨度只算帧区间，但 CPU/RSS 增量
  /// 会把后台那一大段全记到最后一页头上）。
  void sealSegment() {
    if (_seg.frames > 0 || _seg.pageId != null) {
      _closeSeg(_nowUs());
    }
    _seg = _Seg();
  }

  /// 每页快照（含当前未结算的那一段），按页面首次出现顺序。
  ///
  /// 0 帧的页面不出现：它没有任何可报的读数，列出来只会稀释排行，
  /// 还会让「一帧都没画出来」看起来像「画得很快」。
  Map<String, PagePerfSample> samplesByName() {
    final result = <String, PagePerfSample>{};
    for (final entry in _closed.entries) {
      final agg = entry.value.toSnapshot();
      if (agg.frames > 0) {
        result[entry.key] = _sampleOf(entry.key, agg);
      }
    }
    final openId = _seg.pageId ?? (_seg.frames > 0 ? bootPage : null);
    if (openId != null && _seg.frames > 0) {
      // 并进**副本**再出读数：查报表不能把未结算段落进账本，否则报表页每
      // 刷新一次，这一页的 CPU / 帧账就多落一次（读数随读取次数漂移）。
      final agg = _closed[openId]?.toSnapshot() ?? _Accum();
      _seg.applyTo(agg, cost: _readCost());
      if (agg.frames > 0) {
        result[openId] = _sampleOf(openId, agg);
      }
    }
    return result;
  }

  /// 排行：掉帧数多的在前；同分按帧数多的在前，再按出现顺序（保证可复现，
  /// 差分表两次跑出来的行序必须一致）。
  List<PagePerfSample> rankedBy() {
    final samples = samplesByName().values.toList();
    final order = <String, int>{};
    var index = 0;
    for (final id in _closed.keys) {
      order[id] = index++;
    }
    final openId = _seg.pageId;
    if (openId != null && !order.containsKey(openId)) {
      order[openId] = index;
    }
    samples.sort((a, b) {
      if (a.jankyFrames != b.jankyFrames) {
        return b.jankyFrames.compareTo(a.jankyFrames);
      }
      if (a.frames != b.frames) {
        return b.frames.compareTo(a.frames);
      }
      return (order[a.pageId] ?? 0).compareTo(order[b.pageId] ?? 0);
    });
    return List<PagePerfSample>.unmodifiable(samples);
  }

  Map<String, Object?>? toJsonFor(String pageId) =>
      samplesByName()[pageId]?.toJson();

  /// 整表文本（导出用）。头部一行给出判据：读日志的人不必去翻代码，
  /// 也不知道该按哪个阈值判红。
  String formatTextReport() {
    final buffer = StringBuffer();
    buffer.writeln(
      '[perf-page] report budgetMs=${(budgetUs / 1000).toStringAsFixed(1)} '
      'nominalMs=${(_configuredBudgetUs / 1000).toStringAsFixed(1)} '
      'observedVsyncMs=${_observedMinGapUs == 0 ? '?' : (_observedMinGapUs / 1000).toStringAsFixed(1)}',
    );
    final ranked = rankedBy();
    if (ranked.isEmpty) {
      buffer.writeln('[perf-page] no page has rendered a frame yet');
      return buffer.toString();
    }
    for (final sample in ranked) {
      buffer.writeln('[perf-page] ${sample.formatLine()}');
    }
    return buffer.toString();
  }

  /// 整表 JSON（落盘用；两版本差分脚本读这一份）。
  List<Map<String, Object?>> toJsonRows() =>
      rankedBy().map((s) => s.toJson()).toList();

  /// 清空账本（新一轮巡检前调用），预算也重新按上报刷新率起算。
  void reset() {
    _closed.clear();
    _framesAll = 0;
    _seg = _Seg();
    _prevPageId = null;
    _observedMinGapUs = 0;
    _lastVsyncUs = null;
    _configuredBudgetUs = (1000000 / _safeRate()).round();
  }

  /// 当前未闭合段的页面 id（还没切过页时是 [bootPage]）。
  ///
  /// 门面靠它做**代际校验**：匿名路由的回溯改名要等首帧之后才认得出页面
  /// 类型，这期间可能又推了一层路由，那时开段已经属于别人，再改名就会
  /// 改错账。调用方比较「自己开的占位 id」与这个值，一致才动手。
  String get openPageId => _seg.pageId ?? bootPage;

  /// 给**当前未闭合段**换页面 id，已落的帧与耗时原样保留。
  ///
  /// 存在的理由：本仓大量路由是匿名的 `HyperosPageRoute<void>`，推入那一刻
  /// 认不出是哪一页，只能先挂占位 id；等首帧建完才拿得到页面类型。而那几帧
  /// 恰恰是「进这一页」最贵的账（首帧重建整棵子树），不改名的结果就是
  /// 占位行吃掉最贵的一段、真页面从第二帧才开始记账——排行会把最慢的首帧
  /// 藏在一个谁也不认识的名字下面。`hyperos_navigation.dart:1276` 记过同款坑
  /// （真机日志里最慢的几趟全叫 `unnamed`，认不出是哪个页面就没法继续查）。
  ///
  /// 已闭合的段一律不动（boot 段也拒绝）：改历史行名会让两次巡检的差分表
  /// 对不齐，那比少一行信息严重得多。
  bool retargetOpenSegment(String pageId) {
    final current = _seg.pageId;
    if (current == null) {
      // boot 段不存在「归属错了」：那会儿确实还没有任何页面上过屏。
      return false;
    }
    _seg.pageId = pageId;
    return true;
  }

  void _closeSeg(int nowUs) {
    // 段 id 为 null 时是 boot 段（还没切过页），照样有账要落。
    final id = _seg.pageId ?? bootPage;
    final agg = _closed.putIfAbsent(id, _Accum.new);
    final cost = _readCost();
    final short = nowUs - _seg.startUs < minDwellUs;
    if (short && _seg.frames > 0) {
      // 短访问并进前一页——但前一页必须真的上过屏（有帧）。否则等于把这一页
      // 的证据塞进一个空行，排行上只是换了个名字。
      final prev = _prevPageId;
      final prevAgg = prev == null ? null : _closed[prev];
      if (prevAgg != null && prevAgg.frames > 0) {
        _seg.applyTo(prevAgg, cost: cost);
        _prevPageId = prev;
        _seg = _Seg();
        return;
      }
    }
    _seg.applyTo(agg, cost: cost);
    _prevPageId = id;
    _seg = _Seg();
  }

  PagePerfSample _sampleOf(String pageId, _Accum agg) => PagePerfSample(
    pageId: pageId,
    frames: agg.frames,
    jankyFrames: agg.jankyFrames,
    spanUs: agg.spanUs,
    firstFrameLatencyUs: agg.firstFrameLatencyUs,
    worstBuildUs: agg.worstBuildUs,
    worstRasterUs: agg.worstRasterUs,
    avgBuildUs: agg.frames == 0 ? 0 : agg.sumBuildUs / agg.frames,
    avgRasterUs: agg.frames == 0 ? 0 : agg.sumRasterUs / agg.frames,
    cpuMicros: agg.cpuMicros,
    rssDeltaKb: agg.rssDeltaKb,
    budgetUs: budgetUs,
  );

  /// 采一个 vsync 周期样本。**必须是引擎给的每帧 vsync 时刻**，不能用回调
  /// 到达时间：UI 线程忙时引擎把积压的多帧一次性投递，同批到达时间几乎相同、
  /// 批次之间又隔得很远，「最小到达间隔」要么没有样本、要么自相矛盾。
  void _sampleVsyncPeriod(int? vsyncUs) {
    if (vsyncUs == null) {
      return;
    }
    final previous = _lastVsyncUs;
    _lastVsyncUs = vsyncUs;
    if (previous == null) {
      return;
    }
    // 相邻两帧的 vsync 相隔整数个刷新周期：取最小的可信值就是面板节奏
    // （掉 vsync 的帧给出 2 倍、3 倍周期，取最小自然被排除）。
    // 一次会话内只收紧不放宽：反复跳档会让 `over` 计数不可比。
    final gap = vsyncUs - previous;
    if (gap < _minPlausibleGapUs || gap > _maxPlausibleGapUs) {
      return;
    }
    if (_observedMinGapUs == 0 || gap < _observedMinGapUs) {
      _observedMinGapUs = gap;
    }
  }
}

/// 一个页面的累计桶（账本内部的可变状态）。
class _Accum {
  int frames = 0;
  int jankyFrames = 0;
  int spanUs = 0;
  int? firstFrameLatencyUs;
  int worstBuildUs = 0;
  int worstRasterUs = 0;
  int sumBuildUs = 0;
  int sumRasterUs = 0;
  int? cpuMicros;
  int? rssDeltaKb;

  /// 快照副本：查报表绝不能推进账本（报表页每 3 秒刷新一次，
  /// 若刷新会改动读数，排行就随读取次数漂移了）。
  _Accum toSnapshot() => _Accum()
    ..frames = frames
    ..jankyFrames = jankyFrames
    ..spanUs = spanUs
    ..firstFrameLatencyUs = firstFrameLatencyUs
    ..worstBuildUs = worstBuildUs
    ..worstRasterUs = worstRasterUs
    ..sumBuildUs = sumBuildUs
    ..sumRasterUs = sumRasterUs
    ..cpuMicros = cpuMicros
    ..rssDeltaKb = rssDeltaKb;
}

/// 一段「某个页面正在上屏」的窗口。
class _Seg {
  _Seg({this.pageId, this.startUs = 0, this.cpuStart, this.rssStart});

  /// null = 还没切过页（账落给 [PerfPageLedger.bootPage]）。
  ///
  /// 可写：[PerfPageLedger.retargetOpenSegment] 要给未闭合段换名。
  String? pageId;
  final int startUs;
  final int? cpuStart;
  final int? rssStart;

  int frames = 0;
  int jankyFrames = 0;
  int firstFrameUs = 0;
  int lastFrameUs = 0;
  int? firstFrameLatencyUs;
  int worstBuildUs = 0;
  int worstRasterUs = 0;
  int sumBuildUs = 0;
  int sumRasterUs = 0;

  void ingest({
    required int atUs,
    required int buildUs,
    required int rasterUs,
    required bool janky,
  }) {
    if (frames == 0) {
      firstFrameUs = atUs;
      lastFrameUs = atUs;
      firstFrameLatencyUs = atUs - startUs;
    } else {
      lastFrameUs = atUs;
    }
    frames++;
    if (janky) {
      jankyFrames++;
    }
    sumBuildUs += buildUs;
    sumRasterUs += rasterUs;
    if (buildUs > worstBuildUs) {
      worstBuildUs = buildUs;
    }
    if (rasterUs > worstRasterUs) {
      worstRasterUs = rasterUs;
    }
  }

  /// 把这段并进目标桶。一帧都没有的段不落账：它唯一的"信息"是
  /// 「这一页根本没画出来」，而那不是一行性能读数。
  void applyTo(_Accum agg, {required CostReading cost}) {
    if (frames == 0) {
      return;
    }
    agg.frames += frames;
    agg.jankyFrames += jankyFrames;
    agg.sumBuildUs += sumBuildUs;
    agg.sumRasterUs += sumRasterUs;
    if (worstBuildUs > agg.worstBuildUs) {
      agg.worstBuildUs = worstBuildUs;
    }
    if (worstRasterUs > agg.worstRasterUs) {
      agg.worstRasterUs = worstRasterUs;
    }
    agg.spanUs += lastFrameUs - firstFrameUs;
    agg.firstFrameLatencyUs ??= firstFrameLatencyUs;
    if (cpuStart != null && cost.cpuMicros != null) {
      agg.cpuMicros = (agg.cpuMicros ?? 0) + (cost.cpuMicros! - cpuStart!);
    }
    if (rssStart != null && cost.rssKb != null) {
      final delta = cost.rssKb! - rssStart!;
      final existing = agg.rssDeltaKb;
      if (existing == null || delta > existing) {
        agg.rssDeltaKb = delta;
      }
    }
  }
}
