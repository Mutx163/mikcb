import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 烤图节流：两次出图的最小间隔。
///
/// 每张图都是整屏 dpr 密度的离屏出图（约 14MB GPU 纹理），`toImageSync`
/// 会同步等 GPU 完成——重绘成串时（切日视图的展开动画、拖滑杆）逐帧出图会
/// 把 UI 线程堵到 2fps（2026-09-19 真机日志实锤：点日课表后 37 秒内只出 74
/// 帧）。节流把连续重绘合并成至多每 200ms 一张，且**收尾必补一张最新帧**
/// （拖动的最终状态不丢）。
const Duration _minBakeInterval = Duration(milliseconds: 200);

/// 「按帧快照」边界：子树每次重绘完成后，把它的整层内容出成一张 [ui.Image]，
/// 写进 [bakes] 交给订阅者显示。
///
/// 「外观编辑」页用它把**整屏 1:1 渲染的真首页**烤成图，卡片里显示烤出来的
/// 缩尺图（机制就是「录一帧真实内容树 → 按比例显示那张位图」）。显示路径与
/// 渲染路径就此解耦：
///
/// * 卡片上的每个像素，来自首页自己画出来的画面 —— 玻璃（采样带快照、
///   BackdropFilter + 片段着色器）、按屏幕摆位的浮动层，全部工作在**原生尺度**
///   与**原生密度**上，「祖先缩放下采样坐标错位」这一类问题从根上不存在；
/// * 调材质 / 切日周时首页子树照常重绘，本边界跟着重绘、帧末烤图（**节流**，
///   见 [_minBakeInterval]）——与活树同源的「实时」（改动到可见隔一帧）。
///
/// 工程纪律（与 `HyperosLayerBackdropCapture` 同源）：
///
/// * 本节点是独立重绘边界；烤图在 post-frame 回调里做，attach 已断（dispose
///   早于回调的路径）就放弃本次；
/// * 烤图不会让子树再重绘，订阅者（卡片 RawImage）在本节点**之外**的另一条
///   绘制分支上 —— 「烤 → 通知 → 卡片重绘」不会绕回本节点，无自激回路；
/// * 换图时旧图由本边界立即释放（订阅者经 ValueNotifier 重建，重建先于下一帧
///   绘制，旧图不会再被画到），最后一张由宿主在 dispose 时释放。
///
/// ⚠️ **[pixelRatio] 必须传设备密度 `dpr` 本身，不能乘显示缩放**（2026-09-19
/// 真机实锤）：`toImageSync` 的离屏回放按 `pixelRatio` 的密度重新执行整层，
/// 而液态玻璃着色器的几何 uniform（`u_area_origin` / `u_area_size` / 长度）按
/// `dpr` 折算、着色器内 `FlutterFragCoord()` 读的是**当次执行目标**的物理像素。
/// 两个密度不一致时玻璃形状整体位移/缩放出画面 —— 真机现象是底栏玻璃整条
/// 消失（只剩文字）玻璃球错位。想省内存把比例乘卡片缩放（0.653）必然踩雷。
///
/// ⚠️ **[enabled] 要在宿主路由落定后才置 true**（2026-09-19 真机实锤）：进页
/// 转场期间页面带着位移/缩放，玻璃着色器与壁纸对齐这类**按屏幕坐标取值**的
/// 绘制在第一帧取到的是转场坐标，烤出来的图里玻璃圈/壁纸整体偏在一侧（真机
/// 现象：右上角玻璃圈先在卡片左边闪一下才跳回右边、底栏玻璃闪一下）。落定后
/// 再烤，第一张就是正的。
///
/// ⚠️ **首张出图延一帧**（2026-09-19）：首次出图的那一帧，捕获链路的 zone
/// 快照要到**本帧末**才落地（捕获的 postFrame 排在本边界之前）、玻璃面按快照
/// 的重画要等下一帧——此刻 layer 里的玻璃还是「无快照退化态」，烤上卡就是
/// 「球/底栏先歪一帧才跳正」的观感来源（真机反馈「进入外观编辑页时球与底栏
/// 乱跑」的候选机制）。首次出图延到下一帧末，第一张上卡的就是玻璃就绪态。
class PreviewBakeBoundary extends SingleChildRenderObjectWidget {
  const PreviewBakeBoundary({
    super.key,
    required this.bakes,
    required this.pixelRatio,
    this.enabled = true,
    required super.child,
  });

  /// 烤图出口：每次子树重绘完成后写入新图（旧图随之释放）。
  ///
  /// 初次挂载后第一帧就会写入（节流放行）；宿主释放时负责把最后一张 dispose。
  final ValueNotifier<ui.Image?> bakes;

  /// 出图像素密度。见类注释：**必须等于设备 dpr**，与玻璃着色器的坐标折算
  /// 一一对齐，不能为了省内存乘任何缩放。
  final double pixelRatio;

  /// 烤图门控：false 时不烤（已有图保持显示）。
  ///
  /// 给「宿主路由还在进场转场」用：从 false 翻 true 时整层重画一遍再烤，
  /// 玻璃/壁纸按落定坐标重录（见类注释的第二条警告）。
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPreviewBakeBoundary(bakes, pixelRatio, enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    if (renderObject is! _RenderPreviewBakeBoundary) return;
    renderObject
      ..bakes = bakes
      ..pixelRatio = pixelRatio
      ..enabled = enabled;
  }
}

class _RenderPreviewBakeBoundary extends RenderProxyBox {
  _RenderPreviewBakeBoundary(this._bakes, this._pixelRatio, this._enabled);

  ValueNotifier<ui.Image?> _bakes;

  set bakes(ValueNotifier<ui.Image?> value) {
    if (identical(_bakes, value)) return;
    _bakes = value;
    markNeedsPaint();
  }

  double _pixelRatio;

  set pixelRatio(double value) {
    if (_pixelRatio == value) return;
    _pixelRatio = value;
    markNeedsPaint();
  }

  bool _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    // 落定转正时要整层重画：转场帧里玻璃/壁纸记的是转场坐标，重画才能按
    // 落定坐标重录，紧接着的烤图才是正的（见类注释第二条警告）。
    if (_enabled) markNeedsPaint();
  }

  bool _bakeScheduled = false;

  /// 上次出图所在的帧时间戳与节流补拍的定时器（见 [_minBakeInterval]）。
  /// 用帧时间戳而不是 DateTime：测试环境的假时钟才能推进节流间隔。
  Duration? _lastBakeFrameTs;
  Timer? _throttleTimer;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_enabled) return;
    _scheduleBake();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    super.dispose();
  }

  void _scheduleBake() {
    if (_bakeScheduled || !hasSize || size.isEmpty) return;
    _bakeScheduled = true;
    final bool firstBake = _lastBakeFrameTs == null;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _bakeScheduled = false;
      if (!attached) return;
      if (firstBake) {
        _deferFirstBake();
        return;
      }
      // 帧时间戳只在帧回调里取（补拍定时器触发时它是空的，会踩断言）。
      _captureNow(frameTs: SchedulerBinding.instance.currentFrameTimeStamp);
    });
  }

  /// 首烤延一帧（理由见类注释最后一条警告）。保底 scheduleFrame：落定后若
  /// 没有别的动画在跑，下一帧不会被调度，延一帧就永远等不到。
  void _deferFirstBake() {
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached) return;
      // force 绕开节流：首烤时 _lastBakeFrameTs 还是空，本来也不会被节流拦，
      // 但同帧玻璃若已自行触发过一次常规出图，这里若不 force 会再排一轮
      // 补拍定时器——首烤路径明确只出这一张。
      _captureNow(frameTs: SchedulerBinding.instance.currentFrameTimeStamp, force: true);
    });
  }

  void _captureNow({required Duration frameTs, bool force = false}) {
    if (!_enabled || !attached || !hasSize || size.isEmpty) return;
    // 节流：距上次出图不足间隔时改为补拍（trailing）——重绘串再密，出图
    // 也至多每 [_minBakeInterval] 一张，收尾必是最新内容。
    final last = _lastBakeFrameTs;
    if (!force && last != null && frameTs - last < _minBakeInterval) {
      final remaining = _minBakeInterval - (frameTs - last);
      _throttleTimer ??= Timer(remaining, () {
        _throttleTimer = null;
        _captureNow(frameTs: frameTs + remaining, force: true);
      });
      return;
    }
    final layer = this.layer;
    if (layer is! OffsetLayer) return;
    _lastBakeFrameTs = frameTs;
    final image = layer.toImageSync(
      Offset.zero & size,
      pixelRatio: _pixelRatio,
    );
    final old = _bakes.value;
    _bakes.value = image;
    old?.dispose();
  }
}
