/// 首帧拆解探针（**临时诊断件**，只在非 release 且显式 [FirstFrameProbe.install]
/// 之后生效）。
///
/// 存在的理由：`[frame-perf]` 已经证明「进页面」的 UI 线程尖峰在 42~187ms，而
/// 「返回」只有 2~19ms —— 也就是说钱花在**新页面第一次被建出来那一帧**上。但
/// `FrameTiming.buildDuration` 把 build / layout / paint 三段合成一个数，指不出
/// 该改哪一段：改「少建几个 widget」和改「布局更便宜」是完全不同的两件事。
///
/// 这里把那一帧切成四段，外加若干个**命名采样点**：
///
/// | 字段 | 含义 |
/// |---|---|
/// | `waitMs` | 路由装上去 → 这一帧开始（主 isolate 在手势回调里还干了什么） |
/// | `preLayoutMs` | 帧开始 → 第一个采样点进入布局。**build 基本都在这一段** |
/// | `layoutMs` | 布局（所有采样点的并集） |
/// | `paintMs` | 绘制（记录 picture，不含 GPU） |
/// | `tailMs` | 绘制完 → 帧结束 |
///
/// 采样点（`node=` 行）用来把 `preLayoutMs` 那一段再分下去：每个点记下自己**第一次
/// 构建**的时刻，于是「A 点到 B 点之间」= A 到 B 之间那层子树的构建耗时。差值就是
/// 答案，不需要在读代码时猜哪棵子树重。
///
/// ## 纪律
///
/// - `install()` 之前全是空操作 —— 测试里推路由不会多出帧回调。
/// - 只 `debugPrint`：不落盘、不上报、不改任何绘制行为、不持有计时器。
/// - 消息一律英文（同 `[frame-perf]` / `[glass-cap]` 的口径：中文硬编码审计按行
///   计数，诊断日志串不该混进去）；中文只出现在注释里。
/// - 问题收敛后，本文件与全部 `FirstFrameProbe.begin(...)` / `FirstFrameProbeNode(...)`
///   调用点一起删（清单见 `.agents/notes/implemented/process/` 下本次的笔记）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract final class FirstFrameProbe {
  /// 日志前缀，搜这一个词就能捞出全部输出。
  static const String tag = '[first-frame]';

  static bool _installed = false;

  /// 探针自己的单调时钟。标记与采样点共用它，偏移才有意义。
  static final Stopwatch _clock = Stopwatch();

  static _Record? _active;

  static int get _nowUs => _clock.elapsedMicroseconds;

  /// 输出落点；测试可替换成自己的收集器。
  ///
  /// 默认实现传 `wrapWidth: null`：几十个字段的一行会被默认折行，折出来的续行
  /// 没有前缀，grep 时只捞到第一行。
  static void Function(String line) _emit = _defaultEmit;

  static void _defaultEmit(String line) => debugPrint(line, wrapWidth: null);

  /// 安装探针。[kReleaseMode] 下是空壳。由 `main()` 调用一次。
  static void install() {
    if (_installed || kReleaseMode) {
      return;
    }
    _installed = true;
    _clock.start();
    debugPrint('$tag installed (route first-frame breakdown)');
  }

  /// 测试专用安装：不依赖 `main()`，输出收到 [emit]。
  @visibleForTesting
  static void debugInstall({required void Function(String line) emit}) {
    _installed = true;
    _emit = emit;
    _clock
      ..reset()
      ..start();
    _active = null;
  }

  /// 测试专用复位。
  @visibleForTesting
  static void debugReset() {
    _installed = false;
    _emit = _defaultEmit;
    _active = null;
  }

  /// 一条路由被推上来了：开一条记录，等这一帧结束再结算。
  ///
  /// 必须在**帧开始之前**调用（`didPush` 里就是），那时这一帧已经因为 push
  /// 被排定，所以 `scheduleFrameCallback` 抓到的一定是转场的第一帧。
  static void begin(String routeLabel) {
    if (!_installed) {
      return;
    }
    // 上一条没结算完（连续 push、或那一帧没来）就先丢掉，不让它污染这一条。
    _active = null;
    final record = _Record(routeLabel, _nowUs);
    _active = record;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!identical(_active, record) || record.frameStartUs != null) {
        return;
      }
      record.frameStartUs = _nowUs;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!identical(_active, record)) {
        return;
      }
      record.frameEndUs = _nowUs;
      _flush();
    });
  }

  /// 采样点第一次被构建时登记自己。没有正在记录的帧时返回 null（该点静默）。
  static _NodeSpan? _registerNode(String nodeTag) {
    final record = _active;
    if (record == null) {
      return null;
    }
    final span = _NodeSpan(record, nodeTag, _nowUs);
    record.nodes.add(span);
    return span;
  }

  static void _flush() {
    final record = _active;
    _active = null;
    if (record == null || record.frameStartUs == null) {
      return;
    }
    final frameStart = record.frameStartUs!;
    final frameEnd = record.frameEndUs ?? _nowUs;
    final layoutStart = record.layoutStartUs;
    final preLayoutUs = layoutStart == null
        ? frameEnd - frameStart
        : layoutStart - frameStart;
    _emit(
      '$tag route=${record.label} '
      'waitMs=${_ms(record.frameStartUs! - record.pushUs)} '
      'uiMs=${_ms(frameEnd - frameStart)} '
      'preLayoutMs=${_ms(preLayoutUs)} '
      'layoutMs=${_spanMs(record.layoutStartUs, record.layoutEndUs)} '
      'paintMs=${_spanMs(record.paintStartUs, record.paintEndUs)} '
      'tailMs=${record.paintEndUs == null ? '-' : _ms(frameEnd - record.paintEndUs!)} '
      'nodes=${record.nodes.length} '
      // 布局/绘制各自从哪一刻开始，便于把 preLayout 那一大段钉死。
      'layoutAt=${_at(record.layoutStartUs, frameStart)} '
      'paintAt=${_at(record.paintStartUs, frameStart)}',
    );
    for (final span in record.nodes) {
      _emit(
        '$tag   route=${record.label} node=${span.tag} '
        'buildAt=${_at(span.buildUs, frameStart)} '
        'layoutAt=${_at(span.layoutStartUs, frameStart)} '
        'layoutMs=${_spanMs(span.layoutStartUs, span.layoutEndUs)} '
        'paintAt=${_at(span.paintStartUs, frameStart)} '
        'paintMs=${_spanMs(span.paintStartUs, span.paintEndUs)}',
      );
    }
  }

  /// 相对帧开始的毫秒偏移；样本缺失给 `-`。
  ///
  /// 「没走到这一步」与「一步只花了 0 毫秒」必须能分开：本探针就是用来判
  /// 「钱花在哪一段」的，把前者显示成 0.0 会让下一轮读日志的人以为那一段跑过了。
  static String _at(int? stampUs, int frameStartUs) =>
      stampUs == null ? '-' : _ms(stampUs - frameStartUs);

  static String _spanMs(int? fromUs, int? toUs) =>
      (fromUs == null || toUs == null) ? '-' : _ms(toUs - fromUs);

  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);
}

/// 一个命名采样点：包住一棵子树，记下它第一次构建 / 布局 / 绘制的时刻。
///
/// 包装物是透明的 `RenderProxyBox`——不改约束、不改尺寸、不成层，只报时刻。
/// 没有正在记录的帧（或 release）时它就是个普通透传节点。
class FirstFrameProbeNode extends StatefulWidget {
  const FirstFrameProbeNode({
    super.key,
    required this.nodeTag,
    required this.child,
  });

  /// 日志里的 `node=` 值。用「这棵子树是什么」命名（`page` / `header` / `body`）。
  final String nodeTag;

  final Widget child;

  @override
  State<FirstFrameProbeNode> createState() => _FirstFrameProbeNodeState();
}

class _FirstFrameProbeNodeState extends State<FirstFrameProbeNode> {
  _NodeSpan? _span;

  @override
  void initState() {
    super.initState();
    // initState 跑在「父节点正在构建本节点」这一刻：这就是本子树构建的起点。
    _span = FirstFrameProbe._registerNode(widget.nodeTag);
  }

  @override
  Widget build(BuildContext context) {
    final span = _span;
    if (span == null) {
      return widget.child;
    }
    return _FirstFrameProbeBox(span: span, child: widget.child);
  }
}

class _FirstFrameProbeBox extends SingleChildRenderObjectWidget {
  const _FirstFrameProbeBox({required this.span, required Widget super.child});

  final _NodeSpan span;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFirstFrameProbe(span);
}

class _RenderFirstFrameProbe extends RenderProxyBox {
  _RenderFirstFrameProbe(this._span);

  final _NodeSpan _span;

  @override
  void performLayout() {
    // 只记第一次：本节点在转场里每帧都会重新布局，第二次之后的耗时属于稳态成本。
    final first = _span.layoutStartUs == null;
    if (first) {
      _span.markLayoutStart(FirstFrameProbe._nowUs);
    }
    super.performLayout();
    if (first) {
      _span.markLayoutEnd(FirstFrameProbe._nowUs);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final first = _span.paintStartUs == null;
    if (first) {
      _span.markPaintStart(FirstFrameProbe._nowUs);
    }
    super.paint(context, offset);
    if (first) {
      _span.markPaintEnd(FirstFrameProbe._nowUs);
    }
  }
}

class _Record {
  _Record(this.label, this.pushUs);

  final String label;

  /// 路由装上的时刻（`begin` 被调的那一刻）。
  final int pushUs;

  int? frameStartUs;
  int? frameEndUs;

  /// 所有采样点的并集：最早的进入 / 最晚的离开。
  int? layoutStartUs;
  int? layoutEndUs;
  int? paintStartUs;
  int? paintEndUs;

  final List<_NodeSpan> nodes = <_NodeSpan>[];

  /// 采样点来报到了：更新并集。
  void noteLayoutStart(int atUs) {
    if (layoutStartUs == null || atUs < layoutStartUs!) {
      layoutStartUs = atUs;
    }
  }

  void noteLayoutEnd(int atUs) {
    if (layoutEndUs == null || atUs > layoutEndUs!) {
      layoutEndUs = atUs;
    }
  }

  void notePaintStart(int atUs) {
    if (paintStartUs == null || atUs < paintStartUs!) {
      paintStartUs = atUs;
    }
  }

  void notePaintEnd(int atUs) {
    if (paintEndUs == null || atUs > paintEndUs!) {
      paintEndUs = atUs;
    }
  }
}

class _NodeSpan {
  _NodeSpan(this.record, this.tag, this.buildUs);

  /// 归属的那一帧；采样点每次报时刻都要顺带更新帧级的并集。
  final _Record record;

  final String tag;

  /// 本子树开始构建的时刻（`initState` 里读到）。
  final int buildUs;

  int? layoutStartUs;
  int? layoutEndUs;
  int? paintStartUs;
  int? paintEndUs;

  void markLayoutStart(int atUs) {
    layoutStartUs = atUs;
    record.noteLayoutStart(atUs);
  }

  void markLayoutEnd(int atUs) {
    layoutEndUs = atUs;
    record.noteLayoutEnd(atUs);
  }

  void markPaintStart(int atUs) {
    paintStartUs = atUs;
    record.notePaintStart(atUs);
  }

  void markPaintEnd(int atUs) {
    paintEndUs = atUs;
    record.notePaintEnd(atUs);
  }
}
