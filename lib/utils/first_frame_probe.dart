/// 首帧拆解探针（**临时诊断件**，只在非 release 且显式 [FirstFrameProbe.install]
/// 之后生效）。
///
/// 存在的理由：`[frame-perf]` 已经证明「进页面」的 UI 线程尖峰在 42~187ms，而
/// 「返回」只有 2~19ms —— 钱花在**新页面第一次被建出来**那一下。但
/// `FrameTiming.buildDuration` 把 build / layout / paint 合成一个数，指不出该改
/// 哪一段：改「少建几个 widget」和改「布局更便宜」是完全不同的两件事。
///
/// 这里把首帧切成几段，外加若干**命名采样点**：
///
/// | 字段 | 含义 |
/// |---|---|
/// | `waitMs` | 路由装上 → 第一帧开始（手势回调里还干了什么） |
/// | `uiMs` | 第一帧的墙钟跨度 |
/// | `preLayoutMs` | 第一帧开始 → 第一个采样点进入布局。**构建基本都在这一段** |
/// | `layoutMs` | 布局（第一趟，所有采样点的并集） |
/// | `paintMs` | 绘制（记录 picture，不含 GPU） |
/// | `paintFrame` | 绘制发生在第几帧 |
///
/// 三条踩出来的口径（**改之前先读这三条**）：
///
/// 1. **`paintFrame` 不是 1。** 真 `Navigator.push` 的第一帧只做构建与布局，
///    绘制落在第二帧（`test/utils/first_frame_probe_test.dart` 里有可复现的用例
///    盯着）—— 所以「首帧」这个词要小心，它是「首次构建的那一帧」，绘制与光栅化
///    在后面。
/// 2. **`passes` 是必要的。** 采样点只报**第一趟**的跨度，另给一个趟数：布局因此
///    变贵有两种完全不同的成因 ——「一趟特别慢」与「来回跑好几趟」，只看跨度分不开。
/// 3. **采样点必须挂在「真正会被构建」的那条分支上。** 第一版把顶栏采样点挂在
///    `HyperosSubpage` 传出去的 `header` 入参上，而默认走折叠大标题时那条分支根本
///    不碰它 —— 永远不挂载，真机跑一轮才发现白跑。那条挂载守卫用例就是为此留的。
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

  /// 最多观察几帧。绘制迟到是常态（见类文档），但要有个上界：绘制一直不来
  /// （页面被盖住之类）时不能把记录永远挂着。
  static const int _maxFrames = 4;

  static bool _installed = false;

  /// 探针自己的单调时钟。标记与采样点共用它，偏移才有意义。
  static final Stopwatch _clock = Stopwatch();

  static _Record? _active;

  /// 输出落点；测试可替换成自己的收集器。
  ///
  /// 默认实现传 `wrapWidth: null`：几十个字段的一行会被默认折行，折出来的续行
  /// 没有前缀，grep 时只捞到第一行。
  static void Function(String line) _emit = _defaultEmit;

  static void _defaultEmit(String line) => debugPrint(line, wrapWidth: null);

  static int get _nowUs => _clock.elapsedMicroseconds;

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

  /// 一条路由被推上来了：开一条记录，盯住接下来的几帧。
  ///
  /// 必须在**帧开始之前**调用（`didPush` 里就是），那时这一帧已经因为 push
  /// 被排定，所以下一帧一定是转场的第一帧。
  static void begin(String routeLabel) {
    if (!_installed) {
      return;
    }
    _flush();
    final record = _Record(routeLabel, _nowUs);
    _active = record;
    _watchNextFrame(record);
  }

  /// 逐帧跟进，直到绘制出现或看满 [_maxFrames] 帧。
  ///
  /// 用**一次性**的 `scheduleFrameCallback` 自链，不用 `addPersistentFrameCallback`：
  /// 后者只有添加、没有移除的 API，注册上就摘不掉了。代价是 `scheduleFrameCallback`
  /// 会顺带请求一帧 —— 但次数有上界（最多 [_maxFrames]），不会变成常驻帧源。
  static void _watchNextFrame(_Record record) {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!identical(_active, record)) {
        return;
      }
      final frame = record.openFrame(_nowUs);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!identical(_active, record)) {
          return;
        }
        frame.endUs = _nowUs;
        // 绘制一到就结算（那才是这条记录真正想量的那一帧）；否则看满上界帧数收手。
        if (record.firstPaintFrameIndex != null ||
            record.frames.length >= _maxFrames) {
          _flush();
          return;
        }
        _watchNextFrame(record);
      });
    });
  }

  /// 采样点第一次被构建时登记自己。没有正在记录的帧时返回 null（该点静默）。
  static _NodeSpan? _registerNode(String nodeTag) {
    final record = _active;
    final frame = record?.currentFrame;
    if (record == null || frame == null) {
      return null;
    }
    final span = _NodeSpan(record, nodeTag, _nowUs, frame.index);
    record.nodes.add(span);
    return span;
  }

  static void _flush() {
    final record = _active;
    _active = null;
    if (record == null || record.frames.isEmpty) {
      return;
    }
    final first = record.frames.first;
    final firstEnd = first.endUs ?? _nowUs;
    _emit(
      '$tag route=${record.label} '
      'waitMs=${_ms(first.startUs - record.pushUs)} '
      'uiMs=${_ms(firstEnd - first.startUs)} '
      'preLayoutMs=${_at(record.firstLayoutStartUs, first.startUs)} '
      'layoutMs=${_spanMs(record.firstLayoutStartUs, record.firstLayoutEndUs)} '
      'paintMs=${_spanMs(record.firstPaintStartUs, record.firstPaintEndUs)} '
      'paintFrame=${record.firstPaintFrameIndex ?? '-'} '
      'frames=${record.frames.length} '
      'nodes=${record.nodes.length}',
    );
    for (final frame in record.frames) {
      _emit(
        '$tag   route=${record.label} frame=${frame.index} '
        'uiMs=${_ms((frame.endUs ?? _nowUs) - frame.startUs)} '
        'layoutAt=${_at(frame.layoutStartUs, frame.startUs)} '
        'layoutMs=${_spanMs(frame.layoutStartUs, frame.layoutEndUs)} '
        'paintAt=${_at(frame.paintStartUs, frame.startUs)} '
        'paintMs=${_spanMs(frame.paintStartUs, frame.paintEndUs)}',
      );
    }
    for (final span in record.nodes) {
      _emit(
        '$tag   route=${record.label} node=${span.tag} '
        'buildFrame=${span.buildFrameIndex} '
        'buildAt=${_at(span.buildUs, first.startUs)} '
        'layoutFrame=${span.firstLayoutFrameIndex ?? '-'} '
        'layoutAt=${_at(span.firstLayoutStartUs, first.startUs)} '
        'layoutMs=${_spanMs(span.firstLayoutStartUs, span.firstLayoutEndUs)} '
        'layoutPasses=${span.layoutPasses} '
        'paintFrame=${span.firstPaintFrameIndex ?? '-'} '
        'paintPasses=${span.paintPasses}',
      );
    }
  }

  /// 相对基准时刻的毫秒偏移；样本缺失给 `-`。
  ///
  /// 「没走到这一步」与「一步只花了 0 毫秒」必须能分开：本探针就是用来判
  /// 「钱花在哪一段」的，把前者显示成 0.0 会让下一轮读日志的人以为那一段跑过了。
  static String _at(int? stampUs, int baseUs) =>
      stampUs == null ? '-' : _ms(stampUs - baseUs);

  static String _spanMs(int? fromUs, int? toUs) =>
      (fromUs == null || toUs == null) ? '-' : _ms(toUs - fromUs);

  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);
}

/// 一个命名采样点：包住一棵子树，记下它第一次构建 / 布局 / 绘制的时刻。
///
/// 包装物是透明的 `RenderProxyBox` —— 不改约束、不改尺寸、不成层，只报时刻。
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
    _span.noteLayoutStart(FirstFrameProbe._nowUs);
    super.performLayout();
    _span.noteLayoutEnd(FirstFrameProbe._nowUs);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _span.notePaintStart(FirstFrameProbe._nowUs);
    super.paint(context, offset);
    _span.notePaintEnd(FirstFrameProbe._nowUs);
  }
}

class _Record {
  _Record(this.label, this.pushUs);

  final String label;

  /// 路由装上的时刻（`begin` 被调的那一刻）。
  final int pushUs;

  final List<_Frame> frames = <_Frame>[];
  final List<_NodeSpan> nodes = <_NodeSpan>[];

  int? firstLayoutStartUs;
  int? firstLayoutEndUs;
  int? firstPaintStartUs;
  int? firstPaintEndUs;
  int? firstPaintFrameIndex;

  _Frame? get currentFrame => frames.isEmpty ? null : frames.last;

  _Frame openFrame(int startUs) {
    final frame = _Frame(frames.length + 1, startUs);
    frames.add(frame);
    return frame;
  }

  /// 采样点报时刻：更新本帧与整条记录的并集，都只记第一次。
  void noteLayoutStart(int atUs) {
    final frame = currentFrame;
    if (frame == null) {
      return;
    }
    frame.layoutStartUs ??= atUs;
    firstLayoutStartUs ??= atUs;
  }

  void noteLayoutEnd(int atUs) {
    currentFrame?.layoutEndUs ??= atUs;
    firstLayoutEndUs ??= atUs;
  }

  void notePaintStart(int atUs) {
    final frame = currentFrame;
    if (frame == null) {
      return;
    }
    frame.paintStartUs ??= atUs;
    firstPaintStartUs ??= atUs;
    firstPaintFrameIndex ??= frame.index;
  }

  void notePaintEnd(int atUs) {
    currentFrame?.paintEndUs ??= atUs;
    firstPaintEndUs ??= atUs;
  }
}

class _Frame {
  _Frame(this.index, this.startUs);

  final int index;
  final int startUs;
  int? endUs;

  int? layoutStartUs;
  int? layoutEndUs;
  int? paintStartUs;
  int? paintEndUs;
}

class _NodeSpan {
  _NodeSpan(this.record, this.tag, this.buildUs, this.buildFrameIndex);

  /// 归属的那条记录；采样点每次报时刻都要顺带更新帧级与记录级的并集。
  final _Record record;

  final String tag;

  /// 本子树开始构建的时刻（`initState` 里读到）与所在帧。
  final int buildUs;
  final int buildFrameIndex;

  int layoutPasses = 0;
  int paintPasses = 0;
  int? firstLayoutFrameIndex;
  int? firstLayoutStartUs;
  int? firstLayoutEndUs;
  int? firstPaintFrameIndex;
  int? firstPaintStartUs;
  int? firstPaintEndUs;

  void noteLayoutStart(int atUs) {
    layoutPasses++;
    record.noteLayoutStart(atUs);
    if (layoutPasses > 1) {
      return;
    }
    firstLayoutFrameIndex ??= record.currentFrame?.index;
    firstLayoutStartUs ??= atUs;
  }

  void noteLayoutEnd(int atUs) {
    record.noteLayoutEnd(atUs);
    if (layoutPasses > 1) {
      return;
    }
    firstLayoutEndUs ??= atUs;
  }

  void notePaintStart(int atUs) {
    paintPasses++;
    record.notePaintStart(atUs);
    if (paintPasses > 1) {
      return;
    }
    firstPaintFrameIndex ??= record.currentFrame?.index;
    firstPaintStartUs ??= atUs;
  }

  void notePaintEnd(int atUs) {
    record.notePaintEnd(atUs);
    if (paintPasses > 1) {
      return;
    }
    firstPaintEndUs ??= atUs;
  }
}
