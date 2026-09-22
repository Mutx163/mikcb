import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import '../../utils/frame_perf_probe.dart';
import 'hyperos_motion.dart';

/// 「首页 → 外观编辑」的缩放转场：**首页整页连续缩进编辑页中间那块预览小屏
/// （卡片）的矩形里**，编辑页的界面在缩放结束之后才分层出场。
///
/// 由两半组成，经 [hyperosZoomTopAnimation]（进度）+ [hyperosZoomLanding]
/// （落点）两个静态源连接：
///
/// * [HyperosZoomShrinkScope] —— 首页那半边。包在首页根挂载点（`main.dart`
///   的 `RepaintBoundary(child: TimetableScreen())`）外，进场与退场全程用
///   **首页的静态快照**顶替活树：快照从整屏矩形按 [HyperosZoomLanding] 缩到
///   预览卡片矩形（缩放 + 平移 + 收圆角），随动画值倒放展开，动画完全落定后
///   才交还活首页——活玻璃在转场壳里的任何一帧绘制都可能被引擎烤成坏缓存并
///   在落定后冻结（真机：返回后右上角球错位到左上角、进场首帧玻璃闪一下），
///   快照顶替让它整场零绘制。
/// * [HyperosZoomPageRoute] —— 编辑页那半边。**路由本身不给页面做任何变换**
///   （曾经整页套 Transform+Clip+Opacity，那会把顶部的「取消/完成」和底部按钮
///   一起缩放，用户 2026-09-20 明确否掉）；页面按 `progress` 分层出场：暗底在
///   [HyperosZoomRoute.growT] 段淡入、chrome 更晚（[HyperosZoomRoute.chromeT]），
///   `opaque: true` 保证落定后引擎自动停画首页。
///
/// 时间线（两段，[HyperosZoomRoute.swapPoint] 分界）：
/// `[0, swap]` 首页缩进卡片 → `[swap, 1]` 编辑页暗底淡入、chrome 再淡入。
/// 退出 = 同一套随动画值倒放（chrome 先走、暗底再走、首页最后从卡片长回全屏）。
///
/// 硬约束（757d8e4d 的教训）：转场壳只有 Transform / ClipRRect / Opacity /
/// ColoredBox，**绝不加 BackdropFilter**——转场壳里的滤镜会被引擎按坏采样
/// 烤死进缓存，玻璃面永久透明。
abstract final class HyperosZoomRoute {
  /// 「首页缩到位」与「编辑页出场」两段的分界点（总进度）。
  ///
  /// 取 0.45：首页缩小段短一点（缩到位就停），把剩下的行程留给编辑页的出场
  /// 与 chrome 淡入，整场不出现"首页停在卡片上干等"的空档。
  static const double swapPoint = 0.45;

  /// 露底用的底色。
  ///
  /// ⚠️ **必须与外观编辑页的沉浸暗底同值**（`settings_appearance_editor.dart`
  /// 的 `_scrimColor`）：进场末尾编辑页暗底是瞬间接管这块背景的，两边不一致
  /// 就会看到一下轻微的提亮/压暗跳变。契约由测试钉住。
  static const Color backdropColor = Color(0xFF1A1A1A);

  /// 进场总时长基数。转场比单向推页多一段行程，基数比标准推页（300ms）
  /// 放长到 400ms；仍经 `scaledDuration` 跟随用户动效速度设置。
  static final Duration duration = HyperosMotionPlatform.scaledDuration(400);

  /// 进度曲线：对称 easeInOutCubic（首尾都慢，起手不跳、收尾不顿）。
  static const Curve progressCurve = Curves.easeInOutCubic;

  /// 原始动画值 → 总进度（0→1）。
  static double progress(double animationValue) =>
      progressCurve.transform(animationValue.clamp(0.0, 1.0));

  /// 首页缩小段进度（0→1，超过 [swapPoint] 后恒为 1 = 已落在卡片上）。
  ///
  /// 段内**再套一层 easeOutCubic 整形**：外层曲线在 [swapPoint] 处斜率接近最大，
  /// 不整形的话首页会在贴到卡片的那一帧急停（看得出的"顿一下"）；整形后速度在
  /// 落点归零，读起来是"滑进去停住"。
  static double shrinkT(double p) =>
      Curves.easeOutCubic.transform((p / swapPoint).clamp(0.0, 1.0));

  /// 编辑页出场段进度（0→1，[swapPoint] 之前恒为 0）。
  static double growT(double p) =>
      ((p - swapPoint) / (1.0 - swapPoint)).clamp(0.0, 1.0);

  /// 编辑页 chrome（顶部胶囊 / 底部按钮）的出场进度：比暗底晚一截开始 ——
  /// 用户口径「缩放结束以后，才显示页面上的按钮」。
  static double chromeT(double p) {
    const double start = 0.35;
    return ((growT(p) - start) / (1.0 - start)).clamp(0.0, 1.0);
  }
}

/// 缩放转场的**落点**：首页整页要缩进去的那个矩形（= 外观编辑页的预览卡片），
/// 以及那个矩形的圆角。
///
/// 由编辑页**实测上报**（它自己的 `LayoutBuilder` 算完卡片几何时写入），不是
/// 两端各算一份公式：上报值是唯一真源，落地时首页与卡片天生逐像素重合，公式
/// 漂移不可能发生。
@immutable
class HyperosZoomLanding {
  const HyperosZoomLanding({required this.rect, required this.radius});

  /// 目标矩形（屏幕坐标；编辑页本身不位移，页面局部坐标即屏幕坐标）。
  final Rect rect;

  /// 目标圆角。首页快照要按它收圆角，否则落地瞬间圆角会弹一下。
  final double radius;
}

/// 当前落点。null = 还没上报（进场首帧可能如此；此刻进度为 0、变换本就是
/// 恒等量，所以没有观感差）。
final ValueNotifier<HyperosZoomLanding?> hyperosZoomLanding =
    ValueNotifier(null);

/// 首页那一份快照，供编辑页的预览卡片在自家烤图就绪前顶替使用。
///
/// 为什么需要它：编辑页自己的烤图要等路由落定后才开始（`_routeSettled` 门控
/// + 首烤再延一帧），若等它，编辑页的界面出场就只能拖到转场结束之后，中间会
/// 出现一段"首页停在卡片上、什么都不动"的停顿。用首页快照顶替后，出场可以从
/// [HyperosZoomRoute.swapPoint] 就开始，而且**交接时是同一张图**，逐像素无感。
///
/// ⚠️ 释放纪律：`HyperosZoomShrinkScope` 释放快照前必须先把这里置 null
/// （否则编辑页可能引用到已经 dispose 的 `ui.Image`）。
final ValueNotifier<ui.Image?> hyperosZoomHomeSnapshot = ValueNotifier(null);

/// 退场用的**新观感**整屏图（由编辑页在「完成」退出前发布）。
///
/// 为什么需要第二张：进页时烤的 [hyperosZoomHomeSnapshot] 是**旧观感**（用户改之前
/// 的壁纸 / 材质），退场倒放沿用它的话，用户会先看到旧画面、落定那一刻才跳成新画面
/// （真机反馈 2026-09-22：「换完壁纸点击完成的时候，为什么会显示回原本的壁纸，然后
/// 又闪回来」）。编辑页里那份渲染源正好是"同一棵真首页 + 本页草稿设置"，**它才是
/// 用户此刻看到的东西**，把它作为退场源，退场放大出来的就是新观感。
///
/// 纪律：
/// * **所有权归编辑页**：它发布前先 `clone()` 一份自持，退出 dispose 时先摘发布、
///   帧末再释放（同 [HyperosZoomHomeSnapshot] 那套），本 scope 只读、从不释放它；
/// * **只在退场（reverse）时被采用**；进场仍用进页快照（那时草稿还没改，两者内容一致）；
/// * 编辑页里**切过日 / 周**（缩尺预览的视图与首页当前视图不一致）时编辑页**不发布** ——
///   两边内容本就不同，放大一张错的视图会在落定处跳，那种情况退回进页快照（老行为）。
final ValueNotifier<ui.Image?> hyperosZoomExitSource = ValueNotifier(null);

/// 全局缩放转场驱动源：栈顶 zoom 路由的**控制器**（真实进度）。
///
/// 由 [HyperosZoomPageRoute.install] / `dispose` 维护（`_active` 栈顶）；
/// [HyperosZoomShrinkScope] 监听它做缩小 / 还原。null = 没有在飞的 zoom
/// 路由。假设同时最多一条 zoom 路由（唯一推入口在首页菜单）。
///
/// ⚠️ 装进来的必须是控制器而不是路由的 `animation` —— 后者在进场首帧是恒 1.0
/// 的 offstage 占位动画，理由见 [HyperosZoomPageRoute._progressSourceOf]。
final ValueNotifier<Animation<double>?> hyperosZoomTopAnimation =
    ValueNotifier(null);

/// 「首页缩小进编辑页」的路由。唯一推入口：首页菜单里开了 `zoom` 的条目
/// （目前仅外观编辑，见 `home_menu_catalog.dart` 的 `_settingsSubpageEntry`）。
class HyperosZoomPageRoute<T> extends PageRouteBuilder<T> {
  HyperosZoomPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: HyperosZoomRoute.duration,
        reverseTransitionDuration: HyperosZoomRoute.duration,
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        // ⚠️ 路由**不给页面做任何变换**。这里曾经是 Transform.scale +
        // ClipRRect + Opacity 三层包住整页 —— 那会把顶部的「取消/完成」与
        // 底部一排按钮一起跟着缩放，用户 2026-09-20 明确否掉（口径：把主页
        // 缩进预览小屏，页面上的按钮在缩放结束后才出现）。
        // 页面改为**分层按进度出场**，见 `settings_appearance_editor.dart` 的
        // `revealT` / `chromeT`；`opaque: true` 仍保证落定后引擎停画下方首页。
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      );

  static final List<HyperosZoomPageRoute<dynamic>> _active = [];

  /// 对外发布的进度源：**控制器的动画，不是路由的 `animation`**。
  ///
  /// ⚠️ 不能用 `animation`（= `ModalRoute.animation`）。那是个代理动画，而
  /// **进场第一帧** Flutter 会把整条路由标成 offstage，并把代理的父级换成恒为
  /// 1.0/completed 的占位动画（`routes.dart` 的 `set offstage` 原话：
  /// `_animationProxy!.parent = _offstage ? kAlwaysCompleteAnimation : super.animation`；
  /// 该属性的文档也写着「On the first frame of a route's entrance transition, the
  /// route is built Offstage using an animation progress of 1.0」）。
  ///
  /// 后果（2026-09-20 真机 + 逐帧实测）：首页那半边照着这个 1.0 算，**首帧直接
  /// 画成终态** —— 缩到 0.85 并压上暗色（用户看到「缩小的黑影」），下一帧代理
  /// 换回真实控制器、值掉回 0，画面又跳成全屏（「放到最大的照片」），然后才开
  /// 始正常缩小。照 `animation` 算的那半边（编辑页自己的 transitionsBuilder）
  /// 反而没事：那一帧整条路由是 Offstage，根本不绘制；只有我们这半边在路由
  /// 机制之外自己读它，才会把这个占位值当真。
  ///
  /// 控制器不受这层代理影响，任何一帧都是真实进度（`syncTransitionDurations`
  /// 本来就是直接改控制器）。
  static Animation<double>? _progressSourceOf(HyperosZoomPageRoute<dynamic> r) =>
      r.controller ?? r.animation;

  /// 对外的**进度源**（= 控制器；理由见 [_progressSourceOf]）。给页面那半边用的：
  /// 它要靠进度做分层出场。
  ///
  /// 为什么不直接让调用方读 `ModalRoute.animation`（首帧是 offstage 占位 1.0），
  /// 也不让它读 `controller`（那是 `TransitionRoute` 的 protected 成员，跨类不可
  /// 用）—— 这里显式放一个口子，两个坑一起绕开。
  Animation<double>? get progressSource =>
      _progressSourceOf(this) ?? animation;

  @override
  void install() {
    super.install();
    _active.add(this);
    hyperosZoomTopAnimation.value = _progressSourceOf(this);
  }

  @override
  void dispose() {
    _active.remove(this);
    hyperosZoomTopAnimation.value = _active.isEmpty
        ? null
        : _progressSourceOf(_active.last);
    super.dispose();
  }

  @override
  TickerFuture didPush() {
    FramePerfProbe.mark('route:push:zoom');
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    FramePerfProbe.mark('route:pop:zoom');
    return super.didPop(result);
  }

  /// 用户动效速度变化时同步在飞路由（与 `HyperosPageRoute` 同构）。
  static void syncTransitionDurations() {
    for (final route in _active) {
      final controller = route.controller;
      if (controller == null) {
        continue;
      }
      controller.duration = HyperosZoomRoute.duration;
      controller.reverseDuration = HyperosZoomRoute.duration;
    }
  }
}

/// 首页根包装：进场与退场**全程**把**首页的静态快照**顶替在活树前面，快照
/// 从整屏矩形缩到 [hyperosZoomLanding] 上报的预览卡片矩形（缩放 + 平移 +
/// 收圆角），随动画值倒放展开；动画完全落定（dismissed）后才把画面交还活首页。
///
/// 为什么缩「快照」而不是活树（2026-09-19 真机反馈「闪了四五次然后飞速
/// 缩小」）：首页带着玻璃着色器与壁纸重采样，祖先缩放逐帧变化时玻璃按
/// **转场坐标**取值、捕获缓存反复失效——正是本仓反复踩过的「转场坐标
/// 玻璃」坑（见 appearance editor 笔记第四轮、757d8e4d）。快照是 tap
/// 瞬间的整屏位图（与屏幕 1:1、dpr 密度），缩放它是纯合成，零着色器零
/// 重采，绝对丝滑。
///
/// 为什么**全程**停绘活首页、落定才交还（2026-09-19 真机反馈「进场那一刻
/// 闪一下、返回后右上角球错位到左上角」）：转场壳内引擎对 backdrop 的采样
/// 不稳（757d8e4d 同款机制），活玻璃在壳里的任何一帧绘制都可能把坏结果烤
/// 进缓存；落定后壳撤、几何恢复，缓存却命中复用不再重绘——错位冻结。此前
/// 「退场首帧让活首页垫黑重绘一帧重烤新快照」正是踩在这一帧上：那一帧的
/// 绘制就发生在转场壳里。纪律由此收紧为：活首页在 zoom 转场的整个生命周期
/// 里零绘制——进场从 p=0 起就由快照顶替（p=0 时是整屏矩形、无圆角，与活画面
/// 逐像素等价，顶替无感），退场倒放沿用同一份快照，落定帧的完整重绘发生在
/// 壳撤之后。代价：编辑页里改过的外观要在落定切回的那一刻才在首页出现
/// （退出动画回放的是进页时的观感），一次静止时刻的内容更新。
///
/// ⚠️ **不压暗**（2026-09-20 起）：以前缩到底会压 0.18 黑。现在首页是真的
/// 落到预览卡片上，而卡片正图不压暗，压暗会在落地那一瞬跳亮。
class HyperosZoomShrinkScope extends StatefulWidget {
  const HyperosZoomShrinkScope({super.key, required this.child});

  final Widget child;

  @override
  State<HyperosZoomShrinkScope> createState() => _HyperosZoomShrinkScopeState();
}

class _HyperosZoomShrinkScopeState extends State<HyperosZoomShrinkScope> {
  final GlobalKey _homeBoundaryKey = GlobalKey();
  ui.Image? _snapshot;

  @override
  void dispose() {
    // 发布出去的那张图可能还被编辑页的卡片引用着：先摘掉再释放（同
    // [_releaseSnapshot] 的纪律）。
    if (identical(hyperosZoomHomeSnapshot.value, _snapshot)) {
      hyperosZoomHomeSnapshot.value = null;
    }
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  /// 把首页当前画面烤成快照（转场驱动出现的当帧同步执行；p=0 的首帧也
  /// 会走到——那一刻活首页还停在整屏的最后一帧上，烤出来就是用户 tap
  /// 时看到的画面）。
  ///
  /// `pixelRatio` 必须严格等于 dpr（与玻璃几何 uniform 同源的纪律，见
  /// [PreviewBakeBoundary] 类注释的同款警告）。
  ///
  /// 烤好后同时发布到 [hyperosZoomHomeSnapshot]：编辑页的预览卡片在自家烤图
  /// 就绪前用它顶替，交接时是同一张图，逐像素无感（理由见该 notifier 注释）。
  /// 发布走 [_publishSnapshot]（**帧末**，不能在 build 里直接写）。
  void _ensureSnapshot() {
    if (_snapshot != null) {
      return;
    }
    final boundary = _homeBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      return;
    }
    final ui.Image image;
    try {
      image = boundary.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (error) {
      // 烤不出来（极端时序）就退回活树缩放兜底，宁可偶发不完美不能黑屏。
      return;
    }
    _snapshot = image;
    _publishSnapshot(image);
  }

  /// 把快照发布给编辑页的预览卡片（[hyperosZoomHomeSnapshot]）。
  ///
  /// ⚠️ **必须帧末发，不能在 build 里直接写这个 notifier**：编辑页那张卡片是
  /// **另一条路由**里的 `AnimatedBuilder`（它监听这个 notifier），与首页这半边
  /// 不是父子关系 —— 在 build 里写会把它标脏，而它不在当前构建目标的后代里，
  /// 框架直接抛「setState() or markNeedsBuild() called during build」
  /// （用户 2026-09-20 报错原文；探针定位在**进场第 0 帧**，即 [_ensureSnapshot]
  /// 烤出头一张图的那一帧）。
  ///
  /// 本类自己的画面不受这一帧延迟影响：`_snapshot` 已当场赋值，当帧照旧拿它
  /// 缩放（build 里读的是字段，不是这个 notifier）。
  void _publishSnapshot(ui.Image image) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 帧末可能已经换代或释放（退出倒放落定 / dispose）：认准同一张图再发。
      if (!mounted || !identical(_snapshot, image)) {
        return;
      }
      hyperosZoomHomeSnapshot.value = image;
    });
  }

  /// 释放快照。当帧场景可能还引用着它，帧末再 dispose。
  ///
  /// ⚠️ 顺序是**先摘发布、再 dispose**：编辑页的卡片可能正拿这张图当图源，
  /// 先 dispose 会让它画到一张已释放的 `ui.Image`。
  void _releaseSnapshot() {
    final image = _snapshot;
    if (image == null) {
      return;
    }
    _snapshot = null;
    if (identical(hyperosZoomHomeSnapshot.value, image)) {
      hyperosZoomHomeSnapshot.value = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  Widget build(BuildContext context) {
    // 结构恒定：AnimatedBuilder **永远在树里**（无驱动时听哑动画），驱动
    // 出现/消失只换 listenable 不换树形——首页子树（GlobalKey 边界）不会
    // 经历重挂，烤图时元素必然 active。
    return ValueListenableBuilder<Animation<double>?>(
      valueListenable: hyperosZoomTopAnimation,
      child: RepaintBoundary(key: _homeBoundaryKey, child: widget.child),
      builder: (context, animation, child) {
        return AnimatedBuilder(
          animation: animation ?? kAlwaysDismissedAnimation,
          child: child,
          builder: (context, child) {
            final animation = hyperosZoomTopAnimation.value;
            if (animation == null) {
              _releaseSnapshot();
              return child!;
            }
            final status = animation.status;
            if (status == AnimationStatus.dismissed) {
              // 转场完全播完（pop 落定）：壳已撤、动画已停，活首页此帧的
              // 重绘发生在干净状态——这里才是交还画面的时刻（见类注释
              // 「全程停绘」段）。快照当场释放。
              _releaseSnapshot();
              return child!;
            }
            // 进场（forward，含 p=0 的头几帧）与退场（reverse 倒放）全程
            // 快照顶替活首页：活玻璃在转场壳里的任何一帧绘制都可能被烤成
            // 坏缓存并在落定后冻结（真机：右上角球错位到左上角），一次都
            // 不给。p=0 时快照铺满整屏、无圆角，与活画面逐像素等价。
            _ensureSnapshot();
            final p = HyperosZoomRoute.progress(animation.value);
            final landT = HyperosZoomRoute.shrinkT(p);
            // 退场优先用编辑页发布的**新观感**图（[hyperosZoomExitSource]）：没有
            // （没改过东西、取消、或编辑页切过预览视图）才退回进页那张旧快照。
            final reversed = animation.status == AnimationStatus.reverse;
            final snapshot =
                (reversed ? hyperosZoomExitSource.value : null) ?? _snapshot;

            final Rect screenRect = Offset.zero & MediaQuery.sizeOf(context);
            final landing = hyperosZoomLanding.value;
            // 整屏矩形 → 落点矩形按进度插值：位移与缩放一起走，`landT == 1`
            // 时与预览卡片四边重合（落点还没上报就退化成整屏 = 恒等量）。
            final Rect target = landing == null
                ? screenRect
                : Rect.lerp(screenRect, landing.rect, landT)!;
            final double radius = landing == null ? 0 : landing.radius * landT;
            final double sx = target.width / screenRect.width;
            final double sy = target.height / screenRect.height;
            // 写成矩阵而不是 Transform.scale：落点带位移，且这里是把
            // [0,0,w,h] 直接映到 target，不依赖 alignment/origin 的隐式居中。
            final Matrix4 transform = Matrix4.identity()
              ..translateByDouble(target.left, target.top, 0, 1)
              ..scaleByDouble(sx, sy, 1, 1);
            // ⚠️ ClipRRect 必须在 Transform **内层**：它裁的是整屏那张图，
            // 随后的变换把圆角一起带小。半径换算回变换前 = 落点半径 / sx。
            final BorderRadius clipRadius = BorderRadius.circular(
              sx == 0 ? 0 : radius / sx,
            );

            return ColoredBox(
              color: HyperosZoomRoute.backdropColor,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (snapshot != null) ...[
                    // 活首页：转场期间停止绘制（保状态 / 保布局 / 保动画），
                    // 画面由下面的快照接管；不隐藏的话活玻璃会在快照四周露馅。
                    Visibility(
                      maintainState: true,
                      maintainSize: true,
                      maintainAnimation: true,
                      visible: false,
                      child: child!,
                    ),
                    Transform(
                      transform: transform,
                      child: ClipRRect(
                        borderRadius: clipRadius,
                        // BoxFit.fill：整屏快照与整屏盒子同比例，铺满即精确
                        // 落位（不用 cover 以免留出亚像素裁切的余地）。
                        child: RawImage(image: snapshot, fit: BoxFit.fill),
                      ),
                    ),
                  ] else ...[
                    // 兜底：没有快照就缩活树（旧路径，几何同样跟着落点走）。
                    Transform(
                      transform: transform,
                      child: ClipRRect(
                        borderRadius: clipRadius,
                        child: child,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
