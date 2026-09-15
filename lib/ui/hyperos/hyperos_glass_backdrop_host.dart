import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 屏级 OS4 玻璃采样源控制器。
///
/// 一个"屏"（页面 / 首页）持有一个：里面的玻璃表面（顶栏带、玻璃坞、卡片、弹层）
/// 都从它取 [backdrop]，并在挂载期间 [acquire] 请求录帧；被压在 modal 路由下面的
/// 页面则由 modal 里的玻璃通过 [HyperosGlassBackdropRegistry] 拿到它并代为请求。
///
/// 它本身是 [ChangeNotifier]：开关（有人要录帧 / 没人要）变化时通知宿主，宿主只重建
/// 那个捕获节点，不惊动页面子树。
/// 一块"玻璃背后"的采样区：捕获按这块矩形裁剪，相邻玻璃共用一个区。
///
/// 为什么要**分块**而不是整屏一块：玻璃可以两头都有（顶栏带 + 玻璃坞），取并集
/// 会退化成整屏，而整屏快照在 2.75x 的 1280×2772 上是 ~100MB 级离屏目标，每帧
/// 一次就烧掉一个核（真机实测 106~129% CPU、Mali 驱动线程满载）。分块后每块只覆盖
/// 自己那条窄带，同一块里的玻璃共享同一张图。
class HyperosGlassBackdropZone {
  /// 本块里的玻璃：采样源 → 它的渲染对象（用来现算矩形）。
  final Map<HyperosZoneBackdrop, RenderBox> members =
      <HyperosZoneBackdrop, RenderBox>{};

  ui.Image? image;
  Offset? origin;
  double pixelRatio = 1;

  bool get isEmpty => members.isEmpty;

  /// 换图：旧图由本块统一释放（多消费者共享同一张，不能各自 dispose）。
  void update(ui.Image next, Offset nextOrigin, double dpr) {
    final old = image;
    image = next;
    origin = nextOrigin;
    pixelRatio = dpr;
    if (old != null && !identical(old, next)) old.dispose();
  }

  void dispose() {
    image?.dispose();
    image = null;
  }
}

/// 玻璃自己持有的采样源：内容来自它所属的 [HyperosGlassBackdropZone]。
///
/// 不复用 `MiuixLayerBackdrop` 是为了**多块共享同一张图**：上层的
/// `updateSnapshot` 会在替换时释放旧图，多个消费者共享同一张图会被释放两次。
/// 这里图由 zone 统一持有与释放，各玻璃只做转发。
class HyperosZoneBackdrop extends MiuixBackdrop {
  HyperosGlassBackdropZone? _zone;

  void bind(HyperosGlassBackdropZone? zone) {
    if (identical(_zone, zone)) return;
    _zone = zone;
    notifyListeners();
  }

  /// 本块换图后通知这一块的玻璃重绘。
  void zoneUpdated() => notifyListeners();

  @override
  bool get isCoordinatesDependent => true;

  @override
  ui.Image? get snapshot => _zone?.image;

  @override
  Offset? get globalOffset => _zone?.origin;

  @override
  double get pixelRatio => _zone?.pixelRatio ?? 1;
}

/// 屏级 OS4 玻璃采样源控制器。
///
/// 一个"屏"（页面 / 首页）持有一个：里面的玻璃表面都在挂载时登记自己**占哪一块**
/// （[acquireZone]），modal 路由（sheet / dialog）里的玻璃则通过
/// [HyperosGlassBackdropRegistry] 拿到它并代为请求（[acquire]）。
class HyperosGlassBackdropController extends ChangeNotifier {
  final List<HyperosGlassBackdropZone> _zones = <HyperosGlassBackdropZone>[];

  /// 弹层 / modal 用的整层采样源（面板在 Overlay 里，拿不到"自己背后那块"）。
  final MiuixLayerBackdrop plainBackdrop = MiuixLayerBackdrop();

  /// 只要背景、给不出矩形的消费者（走**上游内置面板**的 OS4 弹层才需要）。
  int _plainConsumers = 0;

  /// 只要求"继续录帧"、**不要**整层快照的持有者（本仓弹层都走注入面，见
  /// [holdRecording]）。
  int _recordingHolds = 0;

  /// 是否有消费者在要"整层背景"（只有内置面板那条路读它）。
  bool get wantsPlainBackdrop => _plainConsumers > 0;

  /// 兼容旧读取点：整层采样源（弹层 / modal 用）。
  MiuixLayerBackdrop get backdrop => plainBackdrop;

  /// 采样余量（逻辑像素）：玻璃模糊要取邻域，快照贴边会渗出透明。
  static const double sampleMargin = 96;

  /// 分块上限：再多就退化成整屏，不如少录几次。
  static const int _maxZones = 4;

  /// 两块玻璃相隔多远还算同一块（逻辑像素）。
  static const double _joinGap = 2 * sampleMargin;

  List<HyperosGlassBackdropZone> get zones => _zones;

  /// 满员时"位置还量不到"而临时并入最后一块的成员，等首次录帧（已布局）再改判。
  ///
  /// 见 [resolveDeferredMerges]：分块满员的判断需要玻璃的全局矩形，而
  /// [acquireZone] 发生在 attach 阶段、那时还没布局，所以这个改判是必需的，
  /// 不是优化。
  final Map<HyperosZoneBackdrop, RenderBox> _deferredMerge =
      <HyperosZoneBackdrop, RenderBox>{};

  /// 当前是否有玻璃需要背景（有则开录帧；没有任何玻璃时零开销）。
  bool get capturing =>
      _zones.isNotEmpty || _plainConsumers > 0 || _recordingHolds > 0;

  /// 页内玻璃挂载：选/建一块采样区，并绑定它自己的采样源。
  void acquireZone(RenderBox box, HyperosZoneBackdrop backdrop) {
    // 宿主已释放（dispose 早于子节点 detach 的路径：热重载、非常规移除、
    // 测试里先 dispose 控制器再拆树）：不能再登记，也**不该通知** —— 对已释放的
    // `ChangeNotifier` 通知会命中 "used after being disposed" 断言。
    if (_disposed) return;
    // 本次是否**新开**了一块采样区（而不是并进已有的那块）。
    var openedZone = false;
    // attach 阶段还没布局，rect 往往取不到：先登记成员，位置在录帧时按成员现算
    //（与 globalOffset 同源），所以这里不依赖 rect。
    final rect = _globalRectOf(box);
    HyperosGlassBackdropZone? target;
    if (rect != null) {
      for (final zone in _zones) {
        if (zone.members.isEmpty) continue;
        final union = _unionOf(zone);
        if (union == null || union.inflate(_joinGap).overlaps(rect)) {
          target = zone;
          break;
        }
      }
    }
    if (target == null) {
      if (_zones.length >= _maxZones) {
        // 分块已满：并入「并集膨胀最小」的那一块。
        //
        // 不能取 `_zones.last` —— 那是"最后创建的"，不是"最近的"。第 5 块玻璃
        // 可能离它隔了整屏，并进去会把该块的采样矩形撑到接近整屏，恰好抵消
        // 分块要避免的那件事（整屏离屏目标每帧 ~100MB）。
        final best = _leastGrowingZoneFor(rect);
        if (best != null) {
          target = best;
        } else {
          // 此刻还没布局、量不到矩形，无从判断谁最近：先临时并入最后一块保证
          // 它有采样源，并记下来在首次录帧时改判（[resolveDeferredMerges]）。
          target = _zones.last;
          _deferredMerge[backdrop] = box;
        }
      } else {
        target = HyperosGlassBackdropZone();
        _zones.add(target);
        openedZone = true;
      }
    }
    target.members[backdrop] = box;
    backdrop.bind(target);
    // 判据同 [acquire]：不能只看 `capturing` 有没有从 false 变 true。页内通常
    // **已经**有一块玻璃（如设置页预览卡里的玻璃带）让 `capturing` 为 true，
    // 这时新挂载的玻璃会开出**新的**采样区；旧判据 `wasEmpty && capturing` 一次
    // 通知都不发 → 捕获节点没有任何理由重绘 → 这块新区的 `snapshot` 恒为 null
    // → 上游 `MiuixGlass.paint` 走「无背景兜底」分支画 `fill`（252 灰 @ 0.675，
    // 再被 mask 削到 ~0.32）→ 面板成了半透明空壳，底下的字像素级清晰地透出来。
    // 真机现象就是柔光档「打开预览面板」的弹窗看着透明（2026-09-13）。
    // 新块必须单独要一帧。
    if (openedZone) notifyListeners();
  }

  /// 玻璃自己动了（弹层滑入 / 版面变化）：采样带的位置跟着变，需要重录一帧。
  ///
  /// 捕获节点在**页面**里，而弹层动画只重绘 Overlay，它收不到任何重绘信号 ——
  /// 不主动要一帧的话，采样带会停在"玻璃还没进画面"那一帧上（录成一条几像素高的
  /// 细条，被玻璃拉伸铺满自己）。真机现象就是柔光档底部弹窗看着透明
  /// （`img=470x23` 对 668×283 逻辑像素的面板，2026-09-13）。位移停下就不再要，
  /// 不会自激：`_onDemandChanged` 只在几何真的变了时才被喊到。
  ///
  /// 同 [acquireZone]：宿主已释放就不再通知。本函数是从 `paint` 里排到帧末的
  /// post-frame 回调调用的，回调执行时宿主可能已经 dispose。
  void requestCapture() {
    if (_disposed) return;
    notifyListeners();
  }

  /// 页内玻璃卸载。
  void releaseZone(RenderBox box, HyperosZoneBackdrop backdrop) {
    // 宿主已释放（dispose 早于子节点 detach）：zone 的图已随宿主 dispose() 一起
    // 释放，这里只摘掉待改判队列里的登记，**不通知** —— 对已释放的
    // `ChangeNotifier` 通知会命中 "used after being disposed" 断言。
    if (_disposed) {
      _deferredMerge.remove(backdrop);
      return;
    }
    // 已卸载的成员不该再占着待改判队列（否则每帧都要为它白算一次矩形）。
    _deferredMerge.remove(backdrop);
    for (final zone in List<HyperosGlassBackdropZone>.of(_zones)) {
      if (!identical(zone.members[backdrop], box)) continue;
      zone.members.remove(backdrop);
      backdrop.bind(null);
      if (zone.isEmpty) {
        _zones.remove(zone);
        zone.dispose();
      }
      break;
    }
    if (!capturing) notifyListeners();
  }

  /// 弹层（拿不到自己背后矩形的那类）挂载 / 展开时调用。
  ///
  /// ⚠️ 它会额外请求**整层快照**：每帧一次全屏 `ui.Image`（按 dpr 约 6.7MB）。
  /// 只有走**上游内置面板**（`MiuixGlassPanel(backdrop: …)`）的弹层才读它。
  /// 本仓弹层全部传了 `surfaceBuilder`（注入面走"玻璃背后那条带"的采样区），
  /// 所以调用点用的是 [holdRecording] —— 只保持录帧、不要整层图。
  void acquire() {
    // 同 [acquireZone]：宿主已释放就不再受理，更不通知。
    if (_disposed) return;
    final hadPlain = wantsPlainBackdrop;
    _plainConsumers++;
    // 判据是「要不要整层背景」这一位有没有翻转，而不是 `capturing` 有没有从
    // false 变 true：页内玻璃通常已经让 `capturing` 为 true，那时新开弹层不会
    // 触发任何重绘，本帧就轮不到录整层图 —— 弹层玻璃拿到的是 null / 上一张
    // 快照，上游于是走"纯色轮廓"那条降级分支（实底）。
    if (!hadPlain) notifyListeners();
  }

  /// 弹层卸载 / 关闭时调用。
  void release() {
    if (_disposed) return;
    if (_plainConsumers == 0) return;
    _plainConsumers--;
    if (!capturing) notifyListeners();
  }

  /// 只请求"继续录帧"：刷新各采样区，**不**产生整层快照。
  ///
  /// 注入面弹层（本仓全部）只需要采样区一直在录 —— 它们读的是"玻璃背后那条带"，
  /// 从不读整层图。早先这类调用点走 [acquire]，于是**整个开合动画期间每帧都录
  /// 一张全屏**（`_capture` 里注释实测：每次打开瞬时分配 100~140MB，快速连开
  /// RSS 峰值 1.01GB）—— 那是这段动画最大的一笔每帧开销，而产出的图没人读。
  void holdRecording() {
    if (_disposed) return;
    _recordingHolds++;
    // 与 [acquire] 同理：判据不能用 `capturing` 有没有翻转 —— 页内玻璃通常已经
    // 让它为 true，而这一下通知才是"本帧末立刻录一次"的触发（弹层首帧要玻璃
    // 而不是兜底实底，靠的就是它）。
    notifyListeners();
  }

  /// 与 [holdRecording] 配对。
  void releaseRecording() {
    if (_disposed) return;
    if (_recordingHolds == 0) return;
    _recordingHolds--;
    if (!capturing) notifyListeners();
  }

  Rect? _globalRectOf(RenderBox box) {
    if (!box.attached || !box.hasSize || box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Rect? _unionOf(HyperosGlassBackdropZone zone) {
    Rect? union;
    for (final box in zone.members.values) {
      final rect = _globalRectOf(box);
      if (rect == null) continue;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    return union;
  }

  /// 本块要录的矩形（全局坐标，含采样余量）。
  Rect? captureRectOf(HyperosGlassBackdropZone zone) {
    final union = _unionOf(zone);
    return union?.inflate(sampleMargin);
  }

  /// 把 [rect] 并进哪一块最省（量不到矩形 / 没有可用块时返回 null）。
  ///
  /// 判据用**膨胀面积**而不是矩形间距：这里要避免的本来就是"采样矩形变大"，
  /// 面积增量就是这件事的直接度量；块数 ≤ [_maxZones]，开销可忽略。
  ///
  /// [excluding] 是"评估某成员该不该换块"时的那个成员：算每一块时先把它排除，
  /// 否则它当前所在那块算出来的增量恒为 0，永远选回原地。
  HyperosGlassBackdropZone? _leastGrowingZoneFor(
    Rect? rect, {
    RenderBox? excluding,
  }) {
    if (rect == null) return null;
    HyperosGlassBackdropZone? best;
    var leastGrowth = double.infinity;
    for (final zone in _zones) {
      Rect? union;
      for (final box in zone.members.values) {
        if (identical(box, excluding)) continue;
        final memberRect = _globalRectOf(box);
        if (memberRect == null) continue;
        union = union == null ? memberRect : union.expandToInclude(memberRect);
      }
      final merged = union == null ? rect : union.expandToInclude(rect);
      final growth =
          merged.width * merged.height -
          (union == null ? 0 : union.width * union.height);
      if (growth < leastGrowth) {
        leastGrowth = growth;
        best = zone;
      }
    }
    return best;
  }

  /// 首次录帧时，改判那些"满员且当时量不到位置"的成员（见 [_deferredMerge]）。
  ///
  /// 必须在录帧**之前**调用：录帧时已经布局，此刻才量得到全局矩形，
  /// 也才谈得上"谁离谁近"。不改判的话第 5 块玻璃会一直黏在"最后创建的那一块"
  /// 上，把它的采样矩形撑到接近整屏 —— 实测 2332 逻辑像素高（整屏 2600）。
  void resolveDeferredMerges() {
    if (_deferredMerge.isEmpty) return;
    final pending = Map<HyperosZoneBackdrop, RenderBox>.of(_deferredMerge);
    _deferredMerge.clear();
    for (final entry in pending.entries) {
      final backdrop = entry.key;
      final box = entry.value;
      final rect = _globalRectOf(box);
      if (rect == null) {
        // 本帧仍未布局：留到下一次录帧再试。
        _deferredMerge[backdrop] = box;
        continue;
      }
      HyperosGlassBackdropZone? current;
      for (final zone in _zones) {
        if (identical(zone.members[backdrop], box)) {
          current = zone;
          break;
        }
      }
      if (current == null) continue;
      final better = _leastGrowingZoneFor(rect, excluding: box);
      if (better == null || identical(better, current)) continue;
      current.members.remove(backdrop);
      better.members[backdrop] = box;
      backdrop.bind(better);
      if (current.isEmpty) {
        _zones.remove(current);
        current.dispose();
      }
    }
  }

  bool _disposed = false;

  /// 是否已释放。
  ///
  /// 宿主在 `dispose()` 里会 [HyperosGlassBackdropRegistry.unregister]，正常路径
  /// 不会留下悬空引用；但热重载、构建异常、页面被非常规移除等路径可能让
  /// `unregister` 跑不到 —— 那时注册表栈顶会指着一个 **backdrop 已释放** 的
  /// 控制器，下一个打开弹层的页面就会拿它去采样。注册表用这个标志把这类
  /// "僵尸"挡在栈顶之外。
  bool get disposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    for (final zone in _zones) {
      zone.dispose();
    }
    _zones.clear();
    plainBackdrop.dispose();
    super.dispose();
  }
}

/// 屏级采样源注册表。
///
/// 路由栈里被压在下面的页面仍然挂载，modal 路由（sheet / dialog / 弹层）里的玻璃
/// 看不到它的 `InheritedWidget`，只能从这里取"当前最上面那一屏"的采样源 —— 那正是
/// 压在 modal 下面、应该被采样的画面。[_screens] 按挂载顺序入栈：push 的页面后
/// 挂载、pop 时先销毁，因此 `last` 恒等于栈顶那一屏。
abstract final class HyperosGlassBackdropRegistry {
  static final List<HyperosGlassBackdropController> _screens =
      <HyperosGlassBackdropController>[];

  /// 栈顶那一屏的采样源（没有屏时为 null）。
  ///
  /// 从栈顶往下找第一个**还活着**的控制器，顺手清掉路上遇到的僵尸条目
  /// （见 [HyperosGlassBackdropController.disposed]）。正常路径下第一个就是，
  /// 不会有多余开销。
  static HyperosGlassBackdropController? get active {
    for (var i = _screens.length - 1; i >= 0; i--) {
      final controller = _screens[i];
      if (controller.disposed) {
        _screens.removeAt(i);
        continue;
      }
      return controller;
    }
    return null;
  }

  static void register(HyperosGlassBackdropController controller) {
    _screens.remove(controller);
    if (controller.disposed) {
      return;
    }
    _screens.add(controller);
  }

  static void unregister(HyperosGlassBackdropController controller) {
    _screens.remove(controller);
  }

  /// 取"离 [context] 最近的"采样源：页内优先用本页作用域，modal 路由回落到注册表。
  static HyperosGlassBackdropController? resolve(BuildContext context) =>
      HyperosGlassBackdropScope.maybeOf(context)?.controller ?? active;
}

/// 屏级 OS4 玻璃采样源宿主。
///
/// 上游玻璃（`MiuixGlass*`）不自己抓背景：它从 [MiuixLayerBackdrop] 取一张由
/// `MiuixLayerBackdropCapture` 录制的图层快照。捕获必须包住「玻璃之下的页面
/// 内容」，且**不能包含玻璃自身**（上游要求：防反馈采样）。本组件把三件事收在一处：
///
/// 1. 给屏内所有玻璃下发**本屏专属**的 [MiuixLayerBackdrop]（经
///    [HyperosGlassBackdropScope]）。不能用全局那一份：路由栈里被压在下面的页面
///    仍然挂载着，两个宿主会往同一个 backdrop 里互相覆盖快照。
/// 2. 注册进 [HyperosGlassBackdropRegistry]，让 modal 路由（sheet / dialog）里的
///    玻璃也能采到本屏画面。
/// 3. **有玻璃要采样时才真正录帧**。捕获节点是重绘边界，开启期间页面每次重绘
///    （滚动、动画）都要多做一次全页 `toImageSync`；没有任何玻璃时不录。开关只改
///    绘制行为、不改控件树形态，因此不会重建页面子树（不丢滚动位置、不 relayout）。
class HyperosGlassBackdropHost extends StatefulWidget {
  const HyperosGlassBackdropHost({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;

  /// 外部持有的采样源（首页要自己按「按下更多按钮」预热录帧，并把同一份传给
  /// 弹层）。为空则自建、并随宿主一起释放。
  final HyperosGlassBackdropController? controller;

  @override
  State<HyperosGlassBackdropHost> createState() =>
      _HyperosGlassBackdropHostState();
}

class _HyperosGlassBackdropHostState extends State<HyperosGlassBackdropHost> {
  late final HyperosGlassBackdropController _controller =
      widget.controller ?? HyperosGlassBackdropController();

  bool _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  /// 只有"整屏最外层、且在跑"的宿主才占注册表栈顶。两条门槛都不能少：
  ///
  /// * **最外层**（上面没有别的屏级作用域）：屏里可以套屏 —— 首页的
  ///   `HyperosRootPage` 自带一层，玻璃坞的内嵌设置页也自带一层。它们都采不到外层
  ///   背景（**壁纸**），一旦登记就顶掉外层：菜单 / 弹层按栈顶取采样源时拿到一张
  ///   不含壁纸的快照 → 面板画的是透明图 → 底下的字直接透出来（真机现象：
  ///   "开了内置壁纸，首页右上角菜单变透明"）。
  /// * **在跑**（`TickerMode` 为真）：被 `Visibility` 盖住、节拍已停的那一屏不再
  ///   绘制，它的 backdrop 永远没有新快照。
  void _syncRegistration() {
    final outermost = HyperosGlassBackdropScope.maybeOf(context) == null;
    final live = outermost && TickerMode.valuesOf(context).enabled;
    if (live == _registered) return;
    _registered = live;
    if (live) {
      HyperosGlassBackdropRegistry.register(_controller);
    } else {
      HyperosGlassBackdropRegistry.unregister(_controller);
    }
  }

  @override
  void dispose() {
    HyperosGlassBackdropRegistry.unregister(_controller);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HyperosGlassBackdropScope(
      controller: _controller,
      // 捕获节点自己订阅控制器（见 HyperosLayerBackdropCapture）：开关只触发
      // `markNeedsPaint`，**不重建任何 widget** —— 玻璃表面是在自己的
      // didChangeDependencies 里 acquire 的，那时若 markNeedsBuild 一个不在
      // 当前构建链上的祖先，会直接抛 "setState() called during build"。
      child: HyperosLayerBackdropCapture(
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}

/// 屏内玻璃表面拿采样源的作用域。
///
/// 用 [maybeOf] 读取（`getInheritedWidgetOfExactType`，不建立依赖）：宿主页是
/// 页面级常量，页面中途不会换采样源，所以玻璃不需要跟着它重建。
class HyperosGlassBackdropScope extends InheritedWidget {
  const HyperosGlassBackdropScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// 本屏的采样源与"按需录帧"开关。
  final HyperosGlassBackdropController controller;

  /// 兼容旧读取点：本屏"整层"采样源（弹层 / modal 用；页内玻璃各自按区域取）。
  MiuixLayerBackdrop get backdrop => controller.plainBackdrop;

  /// 请求 / 归还"继续录帧"（只刷采样区，**不要**整层图）。
  ///
  /// 本仓弹层都走注入面（读"玻璃背后那条带"），整层图没人读 —— 而
  /// [acquire] 会在开合动画期间每帧录一张全屏。所以调用点一律用这两个。
  VoidCallback get holdRecording => controller.holdRecording;

  VoidCallback get releaseRecording => controller.releaseRecording;

  /// 走上游内置面板（`MiuixGlassPanel(backdrop: …)`）的弹层才用；本仓暂无调用点。
  VoidCallback get acquire => controller.acquire;

  VoidCallback get release => controller.release;

  static HyperosGlassBackdropScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HyperosGlassBackdropScope>();

  @override
  bool updateShouldNotify(HyperosGlassBackdropScope oldWidget) =>
      !identical(oldWidget.controller, controller);
}

/// [MiuixLayerBackdropCapture] 的可开关版本（上游同名类没有 `enabled`）。
///
/// 上游实现（`flutter_miuix` 1.2.0，
/// `lib/src/theme/miuix/blur/miuix_layer_backdrop.dart`，Apache-2.0）：本节点是
/// 独立重绘边界，帧绘制结束后对自己的真实图层做一次 `toImageSync` 快照写回
/// backdrop。这里只加一条：`enabled == false` 时不排期快照；节点与图层照旧
/// 存在，所以开关不改控件树形态。
class HyperosLayerBackdropCapture extends SingleChildRenderObjectWidget {
  const HyperosLayerBackdropCapture({
    super.key,
    required this.controller,
    required Widget super.child,
  });

  /// 采样源 + 录帧开关的持有者。渲染对象订阅它：开关变化只 `markNeedsPaint`。
  final HyperosGlassBackdropController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHyperosLayerBackdropCapture(
      controller,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHyperosLayerBackdropCapture)
      ..controller = controller
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderHyperosLayerBackdropCapture extends RenderProxyBox {
  _RenderHyperosLayerBackdropCapture(
    this._controller,
    this._devicePixelRatio,
  ) {
    _controller.addListener(_onDemandChanged);
  }

  HyperosGlassBackdropController _controller;
  HyperosGlassBackdropController get controller => _controller;
  set controller(HyperosGlassBackdropController value) {
    if (identical(_controller, value)) return;
    _controller.removeListener(_onDemandChanged);
    final previousBackdrop = _controller.backdrop;
    _controller = value..addListener(_onDemandChanged);
    if (attached) {
      previousBackdrop.unregisterCapture(this);
      _controller.backdrop.registerCapture(this);
    }
    markNeedsPaint();
  }

  /// "有没有玻璃在采样"变了：只重绘本节点（当帧末补一次快照）。
  ///
  /// 这里刻意不 `markNeedsBuild`：玻璃表面是在自己的 `didChangeDependencies`
  /// （构建期）里 acquire 的，此刻标脏一个不在当前构建链上的祖先会抛
  /// `setState() called during build`；而录帧本来就只是绘制行为。
  ///
  /// 同时清掉 [_notifiedSinceCapture]：那个标志的语义是「这一帧是被上一次录帧的
  /// 通知带出来的」，而「采样需求本身变了」（开合弹层、玻璃上下线）恰恰相反 ——
  /// 这一帧**必须**录，否则弹层打开时整层图会停在上一张、甚至一张都没有。自激
  /// 循环走的是 backdrop 的通知、不经过这里，所以重置它不会削弱那道守卫。
  void _onDemandChanged() {
    if (!attached) return;
    _notifiedSinceCapture = false;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// 只有还有玻璃需要背景时才录帧。
  bool get recording => _controller.capturing;

  // 独立重绘边界：子树绘制进本节点的 OffsetLayer，快照直接对真实图层出图，
  // 避免重录子树带来的图层重入。
  @override
  bool get isRepaintBoundary => true;

  // 本节点是重绘边界，位置变化不触发 paint，录制时记下的坐标会过期；因此登记
  // 自身，让 backdrop 在采样时实时取全局坐标。
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.backdrop.registerCapture(this);
  }

  @override
  void detach() {
    _controller.backdrop.unregisterCapture(this);
    super.detach();
  }

  /// 上一次录帧后是否已经通知过消费者（玻璃）。
  ///
  /// 玻璃就在本捕获子树里时（页内玻璃都是），`updateSnapshot` 的通知会让它
  /// `markNeedsPaint`，进而把本节点也标脏 → 又录一次 → 又通知…… 变成 60fps 的
  /// 自激重绘：真机实测「外观与配色」页静止也吃满一个核、整机发烫掉帧。
  ///
  /// 录帧只应在**内容变了**时发生，所以这一帧若是被自己的通知带出来的，直接跳过，
  /// 循环即止（代价：连续滚动时最多两帧的采样延迟）。
  bool _notifiedSinceCapture = false;

  /// 本帧有没有「还没有图」的采样块（刚挂载、或刚从别的屏换过来的玻璃）。
  bool get _hasPendingZones {
    for (final zone in _controller.zones) {
      if (zone.image == null) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_notifiedSinceCapture) {
      _notifiedSinceCapture = false;
      return;
    }
    if (!recording || !hasSize || size.isEmpty) return;
    // 首次采样必须**本帧**就写完，不能只排到帧末 —— 这是「柔光档刚进壁纸位置
    // 选择页时，三个悬浮按钮先冒一块平的、再变玻璃」（2026-09-15 真机）的根因。
    //
    // 上游玻璃是在 **paint** 里读快照的（`miuix_glass.dart` 的 `_RenderGlass.paint`：
    // `backdrop.snapshot != null && globalOffset != null` 才画材质，否则退回 `fill`
    // 兜底实底），而本节点排在这块玻璃**之前**画（采样宿主包的一定是背景层）。
    // 第一次采样只放到帧末时，玻璃的头几帧必然读到 null → 画实底 → 帧末那次采完、
    // 下一帧才「变成玻璃」；真机上页面首帧偏慢，这段空白能拖到 80~120ms（实测）。
    // 同帧补采把这段窗口压到一帧都看不到。
    //
    // 只补 `image == null` 的块：有旧图的块换了图要释放旧图，而玻璃可能正在用旧图
    // ——那一路继续留在帧末（与今天完全一致）；稳态（块块有图）也不在这里录，
    // 连续滚动 / 转场时把同步出图搬进 paint 相位没有收益。
    //
    // 这里**只写图、不发通知**（`notify: false`）：通知会让玻璃 `markNeedsPaint`，
    // 在 paint 相位改绘制状态没必要 —— 帧末那次照旧会通知，同一帧、同一份内容。
    if (_hasPendingZones) {
      // 停在画了一半的图上出图会丢内容：先把本帧已画的像素收成 picture。
      // `stopRecordingIfNeeded` 标了 `@protected`，但它本来就是干这件事的
      // （`pushLayer` 内部也先调它），只是词法上不在 `PaintingContext` 子类里。
      // ignore: invalid_use_of_protected_member
      context.stopRecordingIfNeeded();
      _capture(pendingOnly: true, notify: false);
    }
    _scheduleCapture();
  }

  bool _captureScheduled = false;

  void _scheduleCapture() {
    if (!recording || _captureScheduled || !hasSize || size.isEmpty) return;
    _captureScheduled = true;
    // 帧结束后再快照，避免在 paint 阶段改状态触发同帧重入。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!attached || !hasSize || size.isEmpty || !recording) return;
      _capture();
    });
  }

  /// 录帧：每块采样区按自己的矩形各录一张窄带快照。
  ///
  /// [pendingOnly] 只补「还没有图」的块，且**不释放任何旧图** —— 供 [paint] 里的
  /// 同帧补采用（那时玻璃可能正拿着旧图在画）。[notify] 为 false 时不通知玻璃
  /// 重绘，同样是为了同帧补采（见 [paint]）：写入本身就已经能让**后画的**玻璃读到
  /// 新图，通知则留给帧末那次全量录帧去做。
  void _capture({bool pendingOnly = false, bool notify = true}) {
    final offsetLayer = layer;
    if (offsetLayer is! OffsetLayer) return;
    // 采样比例与上游模糊源同档（见 [_samplePixelRatio]）：上游拿到快照后一律
    // 缩到 `(dpr / 4).clamp(.5, 1.0)` 才开始模糊，多录的像素只抬高每帧的离屏
    // 目标，进不了最终画面。
    final ratio = _samplePixelRatio(_devicePixelRatio);
    final mine = Offset.zero & size;
    var wrote = false;
    // 先改判"满员时量不到位置"的成员：录帧时已布局，才量得到矩形、才谈得上远近。
    // 同帧补采不做这步：它只补空块，改判留给帧末的全量录帧。
    if (!pendingOnly) _controller.resolveDeferredMerges();
    // 每块玻璃背后那条窄带各录一张：整屏快照是 ~100MB 级离屏目标，每帧一次
    // 等于烧掉一个核（真机实测 106~129% CPU、Mali 驱动线程满载）。
    for (final zone in _controller.zones) {
      if (pendingOnly && zone.image != null) continue;
      final global = _controller.captureRectOf(zone);
      if (global == null) continue;
      final target = Rect.fromPoints(
        globalToLocal(global.topLeft),
        globalToLocal(global.bottomRight),
      ).intersect(mine);
      if (target.isEmpty) continue;
      final image = offsetLayer.toImageSync(target, pixelRatio: ratio);
      zone.update(image, localToGlobal(target.topLeft), ratio);
      wrote = true;
      if (!notify) continue;
      for (final backdrop in zone.members.keys) {
        backdrop.zoneUpdated();
      }
    }
    if (pendingOnly) return;
    // 另有弹层（Overlay 里的面板，拿不到自己背后的矩形）在要背景时，补一张整层图。
    // 只在弹层打开期间发生，页内玻璃仍按窄带录。整层是这里最大的一笔：2.75x 的
    // 1280×2772 = 26.8M 像素，按 dpr 录 ≈ 107MB／帧（真机实测每次打开弹层瞬时分配
    // 100~140MB、快速连开 RSS 峰值 1.01GB），按 [ratio] 录 ≈ 6.7MB。
    if (_controller.wantsPlainBackdrop) {
      final image = offsetLayer.toImageSync(mine, pixelRatio: ratio);
      _controller.plainBackdrop.updateSnapshot(
        image,
        localToGlobal(Offset.zero),
        ratio,
      );
      wrote = true;
    }
    // 同帧补采（`notify: false`）不置这个标志：它没通知任何人，也就谈不上
    // 「这一帧是被自己的通知带出来的」——帧末那次全量录帧还要照常跑。
    if (wrote && notify) _notifiedSinceCapture = true;
  }
}

/// 玻璃采样快照的录制比例：与上游模糊源同档 `(dpr / 4).clamp(.5, 1.0)`。
///
/// 上游 `MiuixGlass.prepare`（`flutter_miuix` 1.2.0，`miuix_glass.dart`）里先取
/// `final ratio = (dpr / 4).clamp(.5, 1.0)`，把快照 `canvas.scale(ratio)` 之后才做
/// 高斯模糊 —— 喂给它的像素超过这个分辨率**没有任何视觉贡献**，只把离屏目标
/// 放大到用不上的尺寸：
///
/// * 2.75x 的 1280×2772 整屏 = 26.8M 像素 ≈ **107MB**，弹层打开期间每帧一次；
/// * 按同一比例录制后同一张图 ≈ **6.7MB**（16 倍），而且 `drawImageRect` 从
///   "缩小"变成 1:1，少一次重采样 —— 上游侧看到的逻辑尺寸与像素内容都不变
///   （上游用 `image.width / backdrop.pixelRatio` 还原逻辑宽度，两者同时改，
///   比值不变）。
///
/// 下限 0.5 与上游保持一致，避免低 dpr 设备录出过小的图。
double _samplePixelRatio(double devicePixelRatio) =>
    (devicePixelRatio / 4).clamp(.5, 1.0);

/// 给屏级捕获报告"玻璃自己占哪一块"的透明包装。
///
/// 屏级捕获只录这块矩形（并集 + 采样余量），把每帧离屏目标从整屏（2.75x 的
/// 1280×2772 ≈ 100MB）降到玻璃背后那条窄带。位置每帧实时读（与 `globalOffset`
/// 同源），所以滚动/转场都不会错位。
class HyperosGlassBackdropReporter extends SingleChildRenderObjectWidget {
  const HyperosGlassBackdropReporter({
    super.key,
    required this.controller,
    required this.backdrop,
    required Widget super.child,
  });

  /// 归属的屏级采样源；null = 不登记、不录帧（模糊总开关关闭时）。
  final HyperosGlassBackdropController? controller;

  /// 这块玻璃自己的采样源（内容由控制器按区域写入）。
  final HyperosZoneBackdrop? backdrop;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHyperosGlassBackdropReporter(controller, backdrop);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHyperosGlassBackdropReporter)
      ..controller = controller
      ..backdrop = backdrop;
  }
}

class _RenderHyperosGlassBackdropReporter extends RenderProxyBox {
  _RenderHyperosGlassBackdropReporter(this._controller, this._backdrop);

  HyperosGlassBackdropController? _controller;
  HyperosGlassBackdropController? get controller => _controller;
  set controller(HyperosGlassBackdropController? value) {
    if (identical(_controller, value)) return;
    if (attached) _unregister();
    _controller = value;
    if (attached) _register();
  }

  HyperosZoneBackdrop? _backdrop;
  HyperosZoneBackdrop? get backdrop => _backdrop;
  set backdrop(HyperosZoneBackdrop? value) {
    if (identical(_backdrop, value)) return;
    if (attached) _unregister();
    _backdrop = value;
    if (attached) _register();
  }

  void _register() {
    final controller = _controller;
    final backdrop = _backdrop;
    if (controller == null || backdrop == null) return;
    controller.acquireZone(this, backdrop);
  }

  void _unregister() {
    final controller = _controller;
    final backdrop = _backdrop;
    if (controller == null || backdrop == null) return;
    controller.releaseZone(this, backdrop);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  /// 上一次绘制时自己的全局矩形，用来发现"玻璃在动"。
  Rect? _lastPaintRect;

  /// 玻璃自己动（弹层滑入、版面变化）时向控制器要一帧重录。
  ///
  /// 采样带是按"玻璃在哪"实时算的，但**捕获节点在页面里** —— 弹层（画在 Overlay
  /// 上）的滑入动画只重绘 Overlay，页面不会重绘，捕获节点也就没有理由重录：采样带
  /// 会永远停在"玻璃还压在屏幕下沿之外"那一帧上，与视口求交只剩一条边，录出来的
  /// 是一条几像素高的细条。玻璃把这条细条拉伸铺满自己 → 观感是一层平的淡色纱，
  /// 底下的内容清晰透出（真机现象：柔光档底部弹窗看着透明）。
  ///
  /// 位移停下后 `rect` 不再变，这里就不再要帧，所以不会自激；而页面滚动本来就
  /// 每帧重绘，标记重绘是空操作，不额外增加录制。
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = localToGlobal(Offset.zero) & size;
    if (rect == _lastPaintRect) return;
    _lastPaintRect = rect;
    final controller = _controller;
    if (controller == null) return;
    // paint 阶段不去改绘制状态：排到本帧末由控制器通知捕获节点重绘一次。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) controller.requestCapture();
    });
  }
}
