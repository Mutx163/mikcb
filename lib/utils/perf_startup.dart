// 启动分段探针：把「点开 → 首页出来」切成有序阶段，每段给出两个耗时。
//
// 为什么需要它：旧的首帧探针只回答「进页面那一帧贵在哪一段」，而「启动慢」
// 的账分布在**帧之外**——存储初始化、课表读取、shader 预热、首页换入的
// 最短展示时长。这些不是某一帧的事，只给一个总时长就改不动任何东西。
//
// 两栏耗时的分工（别只看一个数）：
// * `stepMs`：距上一个阶段多久 —— 定位「哪一段在吃时间」。
// * `totalMs`：距起点多久 —— 看「到这一刻为止总共花了多少」。
//
// [mark] 收**显式时间戳**而不是内部读表：调用点在 `main()` 的各个锚点，
// 基准必须同源可比；测试里于是可以把每段耗时写成手推的数字。
//
// 纪律：只记不报，不持有计时器（否则 widget 测试会被 pending timer 打挂），
// 输出串全英文（CJK 硬编码棘轮按行计数，诊断日志不该混进去）。
library;

/// 一个启动阶段。
class StartupPhase {
  const StartupPhase({
    required this.label,
    required this.atUs,
    required this.stepUs,
    required this.totalUs,
  });

  /// 阶段名（`mainEnter` / `runApp` / `firstFrame` / `homeRevealed` …）。
  final String label;

  /// 该阶段的绝对时间戳（与 [PerfStartup.mark] 传入的同源时钟）。
  final int atUs;

  /// 距上一个阶段多久（微秒）。第一段为 0。
  final int stepUs;

  /// 距第一个阶段多久（微秒）。第一段为 0。
  final int totalUs;

  Map<String, Object?> toJson() => <String, Object?>{
    'phase': label,
    'stepMs': _ms(stepUs),
    'totalMs': _ms(totalUs),
  };

  String formatLine() =>
      'phase=$label stepMs=${_ms(stepUs)} totalMs=${_ms(totalUs)}';

  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);
}

/// 启动阶段记录器。
class PerfStartup {
  /// 记一个阶段。[atUs] 是调用方时钟上的绝对时刻（微秒，单调）。
  ///
  /// 同名阶段**只记第一次**：回前台、深链唤起都会重跑部分启动路径，
  /// 第二次落进来会把总时长改成一个「不像启动」的数。
  void mark(String label, int atUs) {
    if (_indexByLabel.containsKey(label)) {
      return;
    }
    final first = _baseUs;
    if (first == null) {
      // 第一个 mark 锚定基准：耗时都是 0。
      _baseUs = atUs;
      _lastUs = atUs;
      _indexByLabel[label] = _phases.length;
      _phases.add(
        StartupPhase(label: label, atUs: atUs, stepUs: 0, totalUs: 0),
      );
      return;
    }
    // 时钟被系统校时回拨时（`DateTime.now()` 类时钟常见，单调时钟不会）
    // 间隔夹到 0：负数会把总账算短，比"看不出这段花了多久"更糟。
    final stepUs = atUs - (_lastUs ?? first);
    final clampedStep = stepUs > 0 ? stepUs : 0;
    _indexByLabel[label] = _phases.length;
    _phases.add(
      StartupPhase(
        label: label,
        atUs: atUs,
        stepUs: clampedStep,
        totalUs: _accumulatedUs + clampedStep,
      ),
    );
    _lastUs = atUs;
    _accumulatedUs += clampedStep;
  }

  final List<StartupPhase> _phases = <StartupPhase>[];
  final Map<String, int> _indexByLabel = <String, int>{};
  int? _baseUs;
  int? _lastUs;
  int _accumulatedUs = 0;

  /// 已记录阶段（按记录顺序）。
  List<StartupPhase> get phases => List<StartupPhase>.unmodifiable(_phases);

  /// 最后一段的总耗时；没记录过为 0。
  int get totalUs => _phases.isEmpty ? 0 : _accumulatedUs;

  /// 某阶段距起点的耗时；没记过这个label给 null（不猜）。
  int? elapsedUs(String label) {
    final index = _indexByLabel[label];
    return index == null ? null : _phases[index].totalUs;
  }

  /// 某阶段距上一阶段的耗时；没记过给 null。
  int? sincePreviousUs(String label) {
    final index = _indexByLabel[label];
    return index == null ? null : _phases[index].stepUs;
  }

  List<Map<String, Object?>> toJson() =>
      _phases.map((p) => p.toJson()).toList();

  /// 文本报告（落盘与导出共用一份口径，差分脚本 grep `phase=`）。
  String formatTextReport() {
    if (_phases.isEmpty) {
      return '[perf-startup] no startup phase recorded\n';
    }
    final buffer = StringBuffer();
    for (final phase in _phases) {
      buffer.writeln('[perf-startup] ${phase.formatLine()}');
    }
    return buffer.toString();
  }

  void reset() {
    _phases.clear();
    _indexByLabel.clear();
    _baseUs = null;
    _lastUs = null;
    _accumulatedUs = 0;
  }
}
