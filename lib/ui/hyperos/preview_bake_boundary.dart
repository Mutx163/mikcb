import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 出图节奏：**改动停下来这么久之后**才补拍一张（去抖，不是固定间隔）。
///
/// 每张图都是整屏 dpr 密度的离屏出图（约 14MB GPU 纹理），而且密度**不能降**
/// （降了玻璃形状整体位移出画面，见类注释）；也就是说每出一次图，显卡就要多画
/// 一整个首页。所以这个数字是「预览跟手」与「页面不卡」之间唯一的旋钮：
///
/// * 逐帧出图 = 2fps（2026-09-19 真机日志实锤：点日课表后 37 秒内只出 74 帧）；
/// * 固定间隔（曾经的 200ms = 5 张/秒）仍然明显吃帧 —— 用户 2026-09-22 反馈
///   「调整有一些延迟，不够跟随，感觉上有一秒延迟」，而**在此之前预览压根不重烤**
///   （玻璃面的重绘传不到本边界，见 [repaintSignal]），所以页面是顺的。
///   取舍就在于"拖动过程中要不要一直出图"。
///
/// 现在的口径：**拖动过程中不出图，停手 [settleBakeDelay] 后出一张**。于是
/// * 拖动跟手程度与"预览完全不动"那阵子一样（回到用户记得的顺滑）；
/// * 预览又不是死的 —— 每次调整停下来一张就到位（且比"最多等一个间隔"更快）。
///
/// 想让它拖动中也动起来，就在 [_RenderPreviewBakeBoundary._armSettleBake] 里
/// 补一条"最长等待"（连续改动超过 N 毫秒也出一张）——代价就是上面那条手感。
const Duration settleBakeDelay = Duration(milliseconds: 150);

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
/// * 调材质 / 切日周时首页子树照常重绘（外加内容源显式喊一声，见 [repaintSignal]），
///   本边界**在改动停下来之后**出图（见 [settleBakeDelay]）—— 卡片上看到的画面与
///   真实首页是同一份内容，只是要等你松手。拖动中它是上一张，这是刻意的：
///   真去逐次出图的代价见 [settleBakeDelay] 的说明。
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
/// ⚠️ **玻璃那一帧画的永远是上一帧的内容**（2026-09-19 起因，2026-09-22 复核）：
/// 玻璃面在 `paint` 里读的是**上一帧末**才落地的快照（捕获节点的 postFrame 排在本
/// 边界之前，而玻璃按新快照的重画要等下一帧）。所以"改动的同一帧就出图"必然烤到
/// 「上一帧的画面」—— 用户 2026-09-22 的读数就是「预览和实际差一帧，一直显示上一帧」。
///
/// 现在这个滞后被静默期盖住了，只有首烤需要单独处理：
///
/// * **首烤**：走"延一帧立刻出"（第一帧 layer 里的玻璃还停在「无快照退化态」，
///   烤上卡就是「球/底栏先歪一帧才跳正」，真机反馈「进入外观编辑页时球与底栏乱跑」）；
/// * **其余出图**：走 [settleBakeDelay]（150ms ≈ 9 帧），远大于这一帧的滞后，
///   不需要再为它做别的。
///
/// ⚠️ **靠子树重绘来触发重烤是不够的，必须给 [repaintSignal]**（2026-09-22
/// 真机实锤）：液态玻璃面与壁纸层各自带**重绘边界**，它们的内容变化只在边界
/// 内部重绘，**到不了本节点**——本节点没被标脏，`paint` 就不再被调到，重烤
/// 也就停了。真机现象是「外观编辑页整个定格」：拖材质滑杆上百次、调壁纸、
/// 切日视图，卡片上一直挂着进场那张图，而日志干净得没有任何异常（诊断计数
/// 恒为 `paints=7 bakes=7`）。所以内容源变了一定要**显式**喊一声，走
/// [repaintSignal] 把本节点标脏、强制整层重录。切「玻璃模式」之所以"看起来
/// 是好的"，只是因为它改了结构、整树重排顺带标脏了本节点。
class PreviewBakeBoundary extends SingleChildRenderObjectWidget {
  const PreviewBakeBoundary({
    super.key,
    required this.bakes,
    required this.pixelRatio,
    this.repaintSignal,
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

  /// 内容源「脏了」的显式信号：每次通知都强制整层重绘并重烤一张。
  ///
  /// 宿主把**所有会改变渲染源画面的东西**合成一个 [Listenable] 喂进来
  /// （编辑页：草稿 + 预览日周 + 看哪一天）。理由见类注释最后一条警告——
  /// 玻璃/壁纸的重绘被它们自己的重绘边界挡住，靠链条传到本节点是靠不住的。
  ///
  /// 传 null 就是「只靠子树重绘触发」的老行为（测试与不需要显式通知的宿主）。
  final Listenable? repaintSignal;

  /// 烤图门控：false 时不烤（已有图保持显示）。
  ///
  /// 给「宿主路由还在进场转场」用：从 false 翻 true 时整层重画一遍再烤，
  /// 玻璃/壁纸按落定坐标重录（见类注释的第二条警告）。
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPreviewBakeBoundary(bakes, pixelRatio, repaintSignal, enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    if (renderObject is! _RenderPreviewBakeBoundary) return;
    renderObject
      ..bakes = bakes
      ..pixelRatio = pixelRatio
      ..repaintSignal = repaintSignal
      ..enabled = enabled;
  }
}

class _RenderPreviewBakeBoundary extends RenderProxyBox {
  _RenderPreviewBakeBoundary(
    this._bakes,
    this._pixelRatio,
    this._repaintSignal,
    this._enabled,
  ) {
    _repaintSignal?.addListener(_onRepaintSignal);
  }

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

  Listenable? _repaintSignal;

  set repaintSignal(Listenable? value) {
    if (identical(_repaintSignal, value)) return;
    _repaintSignal?.removeListener(_onRepaintSignal);
    _repaintSignal = value;
    _repaintSignal?.addListener(_onRepaintSignal);
  }

  /// 内容源显式喊了一声「变了」：**只记一笔，等静默期出图**。
  ///
  /// ⚠️ **故意不 `markNeedsPaint`**（2026-09-22，为了拖动时每帧不留一点活）：
  /// 出图走的是 `toImageSync` —— 它**按图层树重建场景**，子级自己的重绘边界层是
  /// 保留的、里面已经是新画面，所以本节点这一帧重不重绘与烤出来的内容无关。
  /// 而一旦标脏，本节点那一帧就要把自己的非重绘边界子树**重新录一遍**（整页的
  /// 绘制指令：壁纸、网格、文字、卡片）——拖动时每帧都来一遍，正是"调整不跟手"
  /// 这类手感的来源，而它对结果毫无影响。
  ///
  /// 首烤之前仍走标脏那条路：那时还没有图，需要 [_scheduleBake] 的"延一帧"路径。
  void _onRepaintSignal() {
    if (_bakedOnce) {
      _armSettleBake();
      return;
    }
    markNeedsPaint();
  }

  bool _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    // 落定转正时要整层重画：转场帧里玻璃/壁纸记的是转场坐标，重画才能按
    // 落定坐标重录，紧接着的烤图才是正的（见类注释第二条警告）。
    if (_enabled) {
      markNeedsPaint();
      _scheduleNoImageCheck();
    } else {
      _noImageTimer?.cancel();
      _noImageTimer = null;
    }
  }

  /// 启用之后迟迟一张图都没出——这是最像「页面定格」的一种失败（卡片一直显示
  /// 进场那张转场快照），而它**不会**经过 [_reportBlocked] 的任何一步：`paint`
  /// 可能压根没被调到。给它一个兜底自白。
  void _scheduleNoImageCheck() {
    _noImageTimer?.cancel();
    _noImageTimer = Timer(const Duration(milliseconds: 1500), () {
      _noImageTimer = null;
      if (!attached || !_enabled || _bakes.value != null) {
        return;
      }
      _reportBlocked('启用 1.5s 后仍一张图都没出（paint 没被调到）');
    });
  }

  Timer? _noImageTimer;

  bool _bakeScheduled = false;

  /// 首烤是否已经出过图（首烤走"延一帧立刻出"，其余一律等静默期）。
  bool _bakedOnce = false;

  /// 静默期定时器：每次子树重绘都重置它（见 [settleBakeDelay]）。
  Timer? _settleTimer;

  bool _reportedBlocked = false;

  /// 烤图这条路径本来是**静默**的：出不了图就只是"这次没出"，卡片继续显示上一张
  /// （进场时甚至显示的是转场快照）。从外面看就是「整页定格、而且没有任何报错」
  /// —— 2026-09-22 真机上撞到过一次这种定格，日志干净得像没事发生，只能靠猜。
  /// 这里把"卡在哪一步"各打一条（同一原因只打一次，免得刷屏）。
  void _reportBlocked(String what) {
    if (_reportedBlocked) {
      return;
    }
    _reportedBlocked = true;
    debugPrint('[preview-bake] 出不了图：$what');
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // 挂载时就已启用（编辑器那条路：落定后才把本节点挂上去）→ 同样要兜底自白。
    if (_enabled) {
      _scheduleNoImageCheck();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_enabled) return;
    _scheduleBake();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _noImageTimer?.cancel();
    _noImageTimer = null;
    _repaintSignal?.removeListener(_onRepaintSignal);
    super.dispose();
  }

  void _scheduleBake() {
    if (!hasSize || size.isEmpty) {
      _reportBlocked('本节点没有尺寸（size=$size hasSize=$hasSize）');
      return;
    }
    if (_bakedOnce) {
      // 后续一律等静默期（见 [settleBakeDelay]）：每次重绘都重置定时器，所以
      // 一整串重绘（拖滑杆、日周开合动画）只挤出**停下来之后**的那一张。
      _armSettleBake();
      return;
    }
    if (_bakeScheduled) return;
    _bakeScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _bakeScheduled = false;
      if (!attached) return;
      // ⚠️ 首烤延一帧：首帧 layer 里的玻璃还停在「无快照退化态」，本帧出图就是
      // 「球/底栏先歪一帧才跳正」（见类注释最后一条警告）。
      _bakeDeferredOnce();
    });
  }

  /// 静默期到点就出图（去抖）。定时器在**帧外**触发，所以这里不碰帧时间戳。
  void _armSettleBake() {
    _settleTimer?.cancel();
    _settleTimer = Timer(settleBakeDelay, () {
      _settleTimer = null;
      _captureNow();
    });
  }

  /// 首烤：延一帧出图（理由见 [_scheduleBake]）。
  ///
  /// **出图不需要本节点在那一帧重绘**：`toImageSync` 是按图层树重建场景，子级
  /// 自己的重绘边界层是保留的、里面已经换成新画面。这里只要保证**那一帧真的会
  /// 来** —— 落定后若没有别的动画在跑，下一帧不会被调度，延一帧就永远等不到。
  void _bakeDeferredOnce() {
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached) return;
      _captureNow();
    });
  }

  void _captureNow() {
    if (!_enabled || !attached || !hasSize || size.isEmpty) return;
    final layer = this.layer;
    if (layer is! OffsetLayer) {
      _reportBlocked('this.layer 是 ${layer.runtimeType}（不是 OffsetLayer）');
      return;
    }
    ui.Image image;
    try {
      image = layer.toImageSync(
        Offset.zero & size,
        pixelRatio: _pixelRatio,
      );
    } catch (error, stackTrace) {
      // 不吞：让 FlutterError.onError 也记一份（App 内日志里能查到），
      // 同时打出上面那条便于对照是哪一步。
      _reportBlocked('toImageSync 抛异常：$error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'preview_bake_boundary',
          context: ErrorDescription('把预览源烤成一张图'),
        ),
      );
      return;
    }
    _bakedOnce = true;
    final old = _bakes.value;
    _bakes.value = image;
    old?.dispose();
  }
}
