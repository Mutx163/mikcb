import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../utils/first_frame_probe.dart';
import '../../utils/frame_perf_probe.dart';
import 'hyperos_motion.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// Observes route cover/pop so frosted headers restore blur after pop.
final RouteObserver<ModalRoute<void>> hyperosRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// HyperOS / MIUI system-settings style page navigation.
///
/// Use [push] / [route] instead of [MaterialPageRoute] so every sub-page gets
/// the same opaque horizontal shared-axis transition and respects Android
/// `Transition animation scale`.
abstract final class HyperosNavigation {
  /// 页面转场的缓动：官方 miuix-nav 的程序化曲线（`NavProgrammaticEasing`）。
  ///
  /// 2026-10-16 起不再是 AOSP「设置」那条 `fast_out_extra_slow_in`
  /// （[HyperosMiuixNavigation.transitionCurve]，现在只留给启动画面）。
  static const Curve transitionCurve = HyperosMiuixNavProgrammaticCurve();

  static Duration transitionDurationOf(BuildContext context) =>
      HyperosMotionScope.of(
        context,
      ).scaledDuration(HyperosMiuixNavigation.programmaticDurationMs);

  static Duration get transitionDuration =>
      HyperosMotionPlatform.transitionDuration;

  /// Persists user speed preference and refreshes active route controllers.
  static void applyUserTransitionSpeed(BuildContext context, double speed) {
    HyperosMotionScope.of(context).applyUserTransitionSpeed(speed);
  }

  /// Theme hook for apps that still construct [MaterialPageRoute] somewhere.
  ///
  /// Duration still comes from [HyperosPageRoute]; prefer [route] directly.
  static PageTransitionsTheme get pageTransitionsTheme {
    return PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const HyperosPageTransitionsBuilder(),
      },
    );
  }

  /// Builds a [HyperosPageRoute] for [Navigator.push] call sites.
  static Route<T> route<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return HyperosPageRoute<T>(settings: settings, builder: builder);
  }

  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return Navigator.of(
      context,
    ).push<T>(route<T>(builder: builder, settings: settings));
  }

  static Future<T?> pushWidget<T>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
  }) {
    return push<T>(context, builder: (_) => page, settings: settings);
  }

  static Future<T?> pushReplacement<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return Navigator.of(context).pushReplacement<T, dynamic>(
      route<T>(builder: builder, settings: settings),
    );
  }

  /// Viewport width plus right-side bleed so parallax exit never exposes routes
  /// below in the [Navigator] stack.
  @visibleForTesting
  static double parallaxBleedWidth(double viewportWidth) {
    return viewportWidth * (1 + HyperosMiuixNavigation.exitSlideFraction);
  }

  /// 前缘圆角的收束因子（0 = 不裁，1 = 满半径），两端为 0、中段满半径。
  ///
  /// 官方对这条效果是二值开关（`NavDisplayEffects.shouldClipCornersAt`：只有
  /// 严格跨越前缘 `-1 < d < 0` 才裁）。二值在真机上会「闪」：切口里露的是旧页，
  /// 页面一停稳这块一帧之内换成新页背景，对比很强。这里把它换成连续收束，
  /// 半径在末段平滑收到 0 —— 圆角是「锁进屏幕边缘」，不是「啪一下没了」。
  ///
  /// 参数按**缓动后**的进度算（与位移同一条曲线），所以「离落点还有多远」= `band`
  /// 倍的屏宽（见 [HyperosMiuixNavigation.cornerClipSettleBand]，那里有取值推导）。
  @visibleForTesting
  static double transitionCornerRadiusFactor(double progress) {
    const band = HyperosMiuixNavigation.cornerClipSettleBand;
    final clamped = progress.clamp(0.0, 1.0);
    final distanceToEndpoint = math.min(clamped, 1 - clamped);
    if (band <= 0) {
      // 带宽为 0 = 官方那套二值开关（只在端点收掉）。
      return distanceToEndpoint <= 0 ? 0 : 1;
    }
    return (distanceToEndpoint / band).clamp(0.0, 1.0);
  }

  /// 被覆盖页的透明度（1 = 不透明）：官方 `1 - 0.1 × 覆盖度`，末段按
  /// [HyperosMiuixNavigation.coveredReleaseBand] 释放回 1。
  @visibleForTesting
  static double coveredAlphaFor(double coverValue) {
    return 1 -
        HyperosMiuixNavigation.coveredAlphaFalloff *
            coverValue *
            transitionCornerRadiusFactor(coverValue);
  }

  /// 压暗蒙层的 alpha：官方 `0.5 × 覆盖度`，末段按
  /// [HyperosMiuixNavigation.coveredReleaseBand] 释放回 0（与圆角收束同一段）。
  ///
  /// 2026-10-17 第三轮曾在这里插入 `scrimRampExponent`（平方根提前起势），想治
  /// 「圆角读不出来」；当晚用户第四轮反馈「跟底色都没有任何关系，就是新页面的圆角，
  /// 频繁的消失，变成无圆角状态」，把那条机理否掉，本函数回到官方线性。那一轮留下的
  /// 唯一结论是「切口里从不缺上层页的像素」（逐像素探针整场 leak = 0），见
  /// `.agents/notes/implemented/bug-fix/2026-10-17-nav-corner-notch-flicker.md`。
  @visibleForTesting
  static double scrimAlphaFor(double coverValue) {
    return HyperosMiuixNavigation.dimAmount *
        coverValue *
        transitionCornerRadiusFactor(coverValue);
  }

  /// 官方 miuix-nav `NavTransitions.MiuixDefault` + `NavDisplayEffects.Default`
  /// 的 Flutter 版。2026-10-16 换装，替换掉此前自研的「四角 40 圆角 + 投影」
  /// 卡片式转场（那套的常量与辅助函数一并撤掉）。
  ///
  /// 几何（官方转场层，全部线性于进度）：
  /// * 栈顶那一页整屏宽位移 `+width → 0`，**按整设备像素对齐**——官方为防
  ///   「被裁圆角 + 小数位移」在移动中闪出一条细线而做；
  /// * 被覆盖页并衰减到 0.9 透明度；官方的 1/4 屏宽视差**有意关掉**（取 0），
  ///   原因见 [HyperosMiuixNavigation.coveredParallaxFraction]：视差让圆角切口里
  ///   的内容相对切口反向流动，在小窗口里读作「闪」。
  ///
  /// 正交效果（官方 `NavDisplayEffects`）：
  /// * 前缘圆角裁切：只裁**前缘两角**（LTR = 左，官方 `NavCornerClipMode.Leading`），
  ///   半径取设备屏幕圆角；与官方唯一不同的一点是**半径在末段连续收到 0**
  ///   （见 [transitionCornerRadiusFactor]），因为二值撤裁切在真机上会闪。
  /// * 切口里**不补任何颜色**（曾经的 `fillCornerNotchWhileMoving` 已撤）：
  ///   圆角切口是页面之外的一小块，露出来的就是**被覆盖页自己的像素** ——
  ///   同一层、同一条压暗公式，颜色与旁边绝无可能不一致。往那里补一块纯色
  ///   试过两版、都被真机否掉，见 `clipLeadingCornersWhileMoving` 的说明。
  /// * 全屏压暗：位于本层之上、上层页面之下，最深 0.5，随覆盖程度线性加深。
  ///
  /// **结构性红线（2026-10-16 真机卡顿/闪烁定案后加的）**：本函数的返回树在
  /// 整场动画里必须**形状恒定** —— 只许改属性（位移、半径、alpha、颜色 alpha），
  /// 不许增删 widget 类型。元素复用按 runtimeType 匹配，增删任何一层包装
  /// （根 `Transform↔Stack`、视差补底、`ClipRRect`、`Opacity`）都会把其下的
  /// `_page`（GlobalKey 锚定的整棵页面子树）deactivate 再复挂：依赖
  /// InheritedWidget 的全部节点 `didChangeDependencies` + 整页强制重排，
  /// 重页面上就是动画中途一次 100~300ms 的全额重排帧 —— 真机读作「滑到一半
  /// 冻一下」「返回时闪一下」。此前 push/pop 各在起步与收尾有 2~3 次这样的
  /// 翻转，全部改为常挂 + 属性驱动。
  static Widget buildSharedAxisTransition({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    return _MiuixNavPageTransition(
      enter: CurvedAnimation(
        parent: animation,
        curve: transitionCurve,
        reverseCurve: transitionCurve,
      ),
      cover: CurvedAnimation(
        parent: secondaryAnimation,
        curve: transitionCurve,
        reverseCurve: transitionCurve,
      ),
      child: child,
    );
  }
}

/// 官方默认预设驱动的一页：位移 + 前缘圆角（切口不补色）+ 覆盖衰减 + 压暗蒙层
/// （后两者末段有一条「释放」包络，见 [HyperosMiuixNavigation.coveredReleaseBand]）。
///
/// 同一个 widget 伺服两种角色（框架对进出两页都调 `buildTransitions`）：
/// * 作为**栈顶那一页**（正在进或正在退）：`enter` 在 0..1 之间走，`cover == 0`；
/// * 作为**被盖住的那一页**：`enter == 1`（停在自己位置），`cover` 在 0..1 之间走。
///
/// 返回树恒定（见 [HyperosNavigation.buildSharedAxisTransition] 的红线说明）：
/// `Transform.translate(视差补底[裁切页, 垫底条, 压暗层])`，所有效果走属性。
class _MiuixNavPageTransition extends StatelessWidget {
  const _MiuixNavPageTransition({
    required this.enter,
    required this.cover,
    required this.child,
  });

  /// 本页作为栈顶的运动进度：0 = 完全移出（贴在 trailing 侧），1 = 到位。
  final Animation<double> enter;

  /// 本页被上层覆盖的程度：0 = 完全显露，1 = 完全被盖住。
  final Animation<double> cover;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    if (width <= 0) {
      return child;
    }
    final devicePixelRatio = media.devicePixelRatio;
    // 前缘圆角半径：按设备屏幕圆角（官方 rememberNavSystemCornerRadius 口径）。
    final clipRadius = HyperosMiuixNavigation.clipLeadingCornersWhileMoving
        ? HyperosMotionScope.of(context).displayCornerRadiusDp
        : 0.0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final bleedWidth = HyperosNavigation.parallaxBleedWidth(width);
    final surface = HyperosColors.scaffoldBackground(context);

    return AnimatedBuilder(
      animation: Listenable.merge([enter, cover]),
      builder: (context, _) {
        final enterValue = enter.value.clamp(0.0, 1.0);
        final coverValue = cover.value.clamp(0.0, 1.0);
        // LTR：进页从右侧进来、被覆盖页向左退；RTL 整体镜像（官方同款处理）。
        final directionSign = isRtl ? -1.0 : 1.0;

        // 1) 栈顶位移：整屏宽 → 0，对齐到整设备像素。
        final slidePx = _snapToDevicePixels(
          directionSign * (1 - enterValue) * width,
          devicePixelRatio,
        );
        // 2) 被覆盖页视差：官方 1/4 屏宽，mikcb 取 0（见 coveredParallaxFraction
        //    的说明：视差会让圆角切口里的内容相对切口反向流动 = 读作闪烁）。
        final parallaxPx =
            -directionSign *
            HyperosMiuixNavigation.coveredParallaxFraction *
            width *
            coverValue;
        // 3) 被覆盖页的透明度衰减：官方 1 - 0.1 × 覆盖度。
        // 4) 压暗蒙层：官方曲线随深度线性，等价于「随覆盖程度线性加深」。
        //
        // 两者都带一个「末段释放」包络（与圆角收束同一条带宽，见
        // [HyperosMiuixNavigation.coveredReleaseBand]）：切口最后一段是在**屏幕
        // 圆角那一小块里**收掉的，露的正是被覆盖页的像素 —— 若这层还压着 0.5 的
        // 暗，收的过程读作「一块深色月牙缩没 = 圆角闪成无圆角」。放掉压暗后，
        // 洞里是被覆盖页的原色（同套页面底色本就一致），形状收掉时看不出来。
        // 中段包络恒为 1，官方 0.1 / 0.5 的数值不变。
        final coveredAlpha = HyperosNavigation.coveredAlphaFor(coverValue);
        final scrimAlpha = HyperosNavigation.scrimAlphaFor(coverValue);

        final page = _MiuixNavClippedPage(
          // 存在性由设备圆角读数决定（转场全程恒定，不随动画翻转）；
          clipEnabled: clipRadius > 0,
          // 前缘圆角：满半径滑入，末段按 transitionCornerRadiusFactor 平滑收到 0
          //（两端都精确是 0，静止态不可能残留圆角缺口）。
          radius:
              clipRadius *
              HyperosNavigation.transitionCornerRadiusFactor(enterValue),
          alpha: coveredAlpha,
          // 帧缓存边界：转场期间只重新合成「圆角裁切 + 透明度 + 位移」，
          // 页面像素直接复用，不再逐帧重栅格化整页。
          child: RepaintBoundary(child: child),
        );

        // 视差补底**恒挂**（红线：不许按 cover 增删包装）：页面右侧 bleed 出去
        // 那一条，防止被覆盖页视差滑出后露出 Navigator 里更下一层的路由。
        // 栈顶页 cover == 0 时它也在树上，但垫底条与蒙层都在页面右侧屏外
        // （位移 ≥ 0），画了也被裁掉，成本 ≈ 0。视差取 0 之后这条垫底实际上
        // 永远露不出来，保留只是遵守形状恒定红线、不做「值变了就删结构」的优化。
        final content = _MiuixNavParallaxBleed(
          width: width,
          bleedWidth: bleedWidth,
          surface: surface,
          scrimAlpha: scrimAlpha,
          child: page,
        );

        // 根恒为 Transform.translate：压暗蒙层画在 bleed 层内部（其下的垫底
        // Stack 之上、页面之下没有采样关系，视觉等价于此前盖在整个页面上）。
        return Transform.translate(
          offset: Offset(slidePx + parallaxPx, 0),
          child: content,
        );
      },
    );
  }

  /// 把逻辑像素位移对齐到整物理像素。
  ///
  /// 官方理由：被前缘圆角裁切的页面在**小数位移**下，边缘的抗锯齿会闪出一条
  /// 细线（≤0.5px）；对齐不影响位移与进度的线性关系。
  static double _snapToDevicePixels(double logicalPx, double devicePixelRatio) {
    if (devicePixelRatio <= 0) {
      return logicalPx;
    }
    return (logicalPx * devicePixelRatio).roundToDouble() / devicePixelRatio;
  }
}

/// 被覆盖页的视差补底：把路由表面向右延长 1.25 屏宽，视差滑出后不露出
/// [Navigator] 里更下一层的路由。
///
/// 恒挂（结构恒定红线）：栈顶页静止时同样在树上，只是垫底条/蒙层的绘制由
/// alpha 属性驱动（0 时 [ColoredBox] 照画，但完全透明，GPU 合成近乎免费）。
class _MiuixNavParallaxBleed extends StatelessWidget {
  const _MiuixNavParallaxBleed({
    required this.width,
    required this.bleedWidth,
    required this.surface,
    required this.scrimAlpha,
    required this.child,
  });

  final double width;
  final double bleedWidth;
  final Color surface;

  /// 压暗蒙层的 alpha（0 = 完全透明）。画在页面之下、垫底条之上：页面不透明
  /// 时根本看不到它；被覆盖页视差滑出后露出的那条正是这一层。
  final double scrimAlpha;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bleedWidth,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // 补底只铺**会被露出的那一条**（页面右侧 bleed 出来的部分）：
          // 整块 1.25× 视口铺底里，[0, width] 这一段始终被不透明页面盖住，
          // 铺它是每帧白填一整屏。补底本身不能省 —— 它负责让视差滑出后
          // 不露出 Navigator 里更下一层的路由。
          Positioned(
            left: width,
            top: 0,
            bottom: 0,
            width: bleedWidth - width,
            child: ColoredBox(color: surface),
          ),
          // 高度必须顶死：外层 Stack 给非定位子级的是**放宽后**的约束
          // （min=0）。路由静止时给页面的是撑满视口的紧约束；这里若只锁
          // 宽不锁高，根节点是「Stack + 零尺寸常驻子级（挂载态弹层）」的
          // 页面（如教务仓库页）会按子级塌成高度 0 —— 整页不画，
          // 转场露出的那条就是黑带（2026-09-28 真机现象）。∞ 经 enforce
          // 收成 incoming 的 max，正好还原静止时的紧约束。
          SizedBox(width: width, height: double.infinity, child: child),
          // 压暗蒙层：恒挂，alpha 属性驱动。只盖 [0, width] 视口段 ——
          // bleed 条不压暗（它露出的时刻上层页面已经盖住了 [width, +∞) 侧，
          // 且官方口径压暗的就是「底下的页面」）。位置恒定不随动画改约束。
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: width,
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: scrimAlpha),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 前缘圆角裁切 + 被覆盖页的透明度衰减。
///
/// **结构恒定（红线）**：`ClipRRect`（设备圆角 > 0 时）与 `Opacity` **常挂**，
/// 半径 / alpha 全走属性。理由见 [HyperosNavigation.buildSharedAxisTransition]：
/// 按动画值增删包装会在转场起步与收尾各触发一次整页子树 deactivate →
/// GlobalKey 复挂（Inherited 依赖全量重算 + 整页强制重排），重页面上就是
/// 动画中途的重排帧 —— 真机读作「滑到一半冻一下」「返回时闪一下」。
///
/// 注意存在性判据是**设备圆角读数**（本帧恒定），不是动画中的半径：半径在
/// 两端精确为 0，若按它判存在，起步/收尾仍会翻转。半径为 0 的 `RRect`
/// 视觉上等价于不裁；静止成本：`RenderOpacity` alpha==1 直绘不建层，
/// `RenderClipRRect` 退化为一次矩形裁切。
class _MiuixNavClippedPage extends StatelessWidget {
  const _MiuixNavClippedPage({
    required this.clipEnabled,
    required this.radius,
    required this.alpha,
    required this.child,
  });

  /// 是否挂圆角裁切层 —— 只由**设备圆角读数**决定（转场全程恒定）。
  final bool clipEnabled;

  /// 动画中的裁切半径（已按 [HyperosNavigation.transitionCornerRadiusFactor]
  /// 收束过）；两端精确为 0，静止态没有可见裁切。
  final double radius;

  /// 被覆盖页的透明度（1 = 不透明，`RenderOpacity` 直绘）。
  final double alpha;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    Widget page = Opacity(
      opacity: alpha,
      child: child,
    );
    // 只裁前缘两角（LTR = 左）：整页滑入时贴屏幕边缘那两个角不该被裁。
    if (clipEnabled) {
      page = ClipRRect(
        borderRadius: isRtl
            ? BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              )
            : BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              ),
        child: page,
      );
    }
    return page;
  }
}

/// Standard sub-page route for mikcb (settings, import, about, etc.).
class HyperosPageRoute<T> extends PageRoute<T> {
  static final Set<HyperosPageRoute<dynamic>> _activeRoutes = {};

  HyperosPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  });

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => HyperosNavigation.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      HyperosNavigation.transitionDuration;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  void install() {
    super.install();
    _activeRoutes.add(this);
  }

  /// 转场打点：把「这一次 push / pop」交给帧探针开一个读数窗口。
  ///
  /// 存在的理由：转场此前没有任何标记，卡顿只能从每 2 秒的 `steady` 基线和无标记的
  /// `burst` 里猜，无法把某一次跳转单独拎出来归因。而「新页面整棵树的首次构建」
  /// 与「转场第一帧」在框架里是同一帧（`routes.dart` 的 `_page ??=` 只调一次
  /// `buildPage`），首帧一重就整段动画掉帧 —— 有标记才分得清是首帧的账还是
  /// 整段动画每帧的账。
  ///
  /// 标记用 route name（未命名路由给 `unnamed`），与 `[frame-perf] mark` 行配套读。
  /// [FramePerfProbe] 在未安装时是空操作，release 里更是一行都不输出。
  String get _probeLabel => settings.name ?? 'unnamed';

  @override
  TickerFuture didPush() {
    FramePerfProbe.mark('route:push:$_probeLabel');
    // 首帧拆解（临时诊断件）：这一帧就是「新页面第一次被建出来」的那一帧。
    FirstFrameProbe.begin('push:$_probeLabel');
    return super.didPush();
  }

  /// [Navigator.pushReplacement] 走这条（`didPush` 不会被调），同样要打点。
  @override
  void didReplace(Route<dynamic>? oldRoute) {
    super.didReplace(oldRoute);
    FramePerfProbe.mark('route:replace:$_probeLabel');
  }

  @override
  bool didPop(T? result) {
    FramePerfProbe.mark('route:pop:$_probeLabel');
    return super.didPop(result);
  }

  @override
  void dispose() {
    _activeRoutes.remove(this);
    super.dispose();
  }

  /// 首帧门槛：push 方向改用「新页首帧画完之前进度锁 0」的模拟器
  /// （见 [_HyperosFirstFrameGateSimulation]）。pop 不动 —— 返回首帧只有
  /// 2~19ms（探针口径），且 pop 首帧的新页早已构建过，没有门槛的必要。
  ///
  /// 走 [createSimulation] 而不是 stop/重启 ticker：`TransitionRoute.didPush`
  /// 返回的 TickerFuture 被 Navigator 挂了路由状态机钩子（framework
  /// `navigator.dart` handlePush 里的 `whenCompleteOrCancel`），中途 stop 会让
  /// 状态机提前翻页，契约不允许。模拟器这条路 ticker 照常启停，状态机、状态
  /// 监听（`_handleStatusChanged` 的 opaque 翻转、latency 模式申请）全按原时序。
  ///
  /// 时长显式传给模拟器：`animateWith` 模式下框架会忽略 `controller.duration`
  /// （框架文档原文「curve and transitionDuration are ignored」），用户倍速与
  /// 系统动画缩放都在 [transitionDuration] 里，必须自己带进来。
  @override
  Simulation? createSimulation({required bool forward}) {
    if (!forward || !HyperosMiuixNavigation.firstFrameGateEnabled) {
      return null;
    }
    return _HyperosFirstFrameGateSimulation(
      durationSeconds: transitionDuration.inMicroseconds /
          Duration.microsecondsPerSecond,
    );
  }

  /// Re-applies the current user/system transition speed to routes still on
  /// the navigator stack (their controllers are created once in [install]).
  static void syncTransitionDurations() {
    final duration = HyperosNavigation.transitionDuration;
    for (final route in _activeRoutes) {
      final controller = route.controller;
      if (controller == null) {
        continue;
      }
      controller.duration = duration;
      controller.reverseDuration = duration;
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // 首帧拆解采样点（临时诊断件）：整页子树的构建 / 布局 / 绘制时刻。
    return FirstFrameProbeNode(nodeTag: 'page', child: builder(context));
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return HyperosNavigation.buildSharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// [PageTransitionsTheme] adapter sharing [HyperosNavigation.buildSharedAxisTransition].
class HyperosPageTransitionsBuilder extends PageTransitionsBuilder {
  const HyperosPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return HyperosNavigation.buildSharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// push 动画的「首帧门槛」模拟器：进度在新页第一帧画完之前恒为 0，
/// 画完后从那一刻起按线性时间走完整个转场。
///
/// 为什么存在：`TransitionRoute.didPush` 起跑动画的同一帧就是新页的首次构建帧。
/// 重页面（设置首页、课程卡样式等）这一帧 200~500ms，ticker 的耗时计入了动画
/// 时间 —— 恢复时进度 = 重活真实耗时 ÷ 转场时长，直接跳到中段，观感是
/// 「滑到一半冻住然后瞬移」。本模拟器把 x(t) 在首帧画完前钉在 0：重活耗的
/// 时间不计入进度，动画从「第一帧已经画出来」之后才起步，全程按 500ms 播完。
///
/// 「首帧画完」的判定：首帧的构建发生在 `WidgetsBinding.drawFrame` 的 build 阶段，
/// 而模拟器只在每帧的 transient callbacks（ticker）阶段被查询 —— 第一次被查询
/// 时首帧的绘制还没发生，此刻必须返回 0 并**登记一个帧末回调**。帧末回调跑在
/// paint 之后，那时首帧已出画，于是解锁。解锁前的整段时间（含首帧重活与中间
/// 掉的帧）进度一律是 0，解锁后 t 归零重计，保证整段时长足额。
///
/// x(t) 解锁后线性到 1：官方 `NavDriverSpec` 的程序化档本来就是「固定时长 + 程序化
/// 曲线」，曲线由 `HyperosNavigation.transitionCurve` 在 `CurvedAnimation` 一侧
/// 施加（`buildSharedAxisTransition`），模拟器只负责时间轴 —— 与不装模拟器时
/// `AnimationController.forward` 的线性时间轴完全同构，曲线、时长、几何都不变。
class _HyperosFirstFrameGateSimulation extends Simulation {
  _HyperosFirstFrameGateSimulation({required this.durationSeconds});

  /// 转场整步时长（秒）。已在构造处按系统动画缩放与用户速度折算过
  /// （`animateWith` 模式下框架忽略 controller.duration，必须自带）。
  final double durationSeconds;

  /// 门槛还锁着吗。模拟器实例是每次 push 新建的（[HyperosPageRoute.createSimulation]），
  /// 所以一个实例管一次转场，无需复位逻辑。
  bool _gateOpen = false;

  /// 已在第一个解锁帧上锚定动画起点。
  bool _anchored = false;

  /// 动画时间轴的零点 = 第一个解锁 tick 的时钟读数。
  ///
  /// 锚点必须取**解锁后第一次被查询**的时刻，不能取锁定期间任何一帧：
  /// 锁定期与解锁后第一次查询之间隔着的正是重活那一帧（200~500ms），
  /// 锚在锁定帧上等于把重活时间又计回进度 —— 与不装门槛无异。
  double _startTime = 0;

  /// 帧末回调已登记（只登一次；锁定期间每帧的 ticker 查询都会进来）。
  bool _openScheduled = false;

  @override
  double x(double time) {
    if (!_gateOpen) {
      _scheduleOpen();
      return 0;
    }
    if (!_anchored) {
      _anchored = true;
      _startTime = time;
      return 0;
    }
    if (durationSeconds <= 0) {
      return 1;
    }
    final progress = (time - _startTime) / durationSeconds;
    return progress.clamp(0.0, 1.0);
  }

  /// 位移对时间的导数：解锁且未到终点时是匀速 1/时长，其余为 0。
  @override
  double dx(double time) {
    if (!_gateOpen || !_anchored || durationSeconds <= 0) {
      return 0;
    }
    final elapsed = time - _startTime;
    if (elapsed < 0 || elapsed >= durationSeconds) {
      return 0;
    }
    return 1 / durationSeconds;
  }

  @override
  bool isDone(double time) {
    // 锁定期 / 未锚定（x 还没被解锁后第一次调用过）一律「没完」，
    // 否则 Navigator 的状态机会在动画真正起步前就翻页。
    if (!_gateOpen || !_anchored) {
      return false;
    }
    return durationSeconds <= 0 || (time - _startTime) >= durationSeconds;
  }

  /// 登记解锁：跑在**本帧** paint 之后。本帧就是新页的首次构建帧，它画完
  /// （帧末回调阶段）即视为「首帧已出画」，下一次 ticker 查询（下一帧）解锁。
  ///
  /// 不主动 `scheduleFrame`：首次查询发生时 ticker 已在跑，本来就有下一帧。
  void _scheduleOpen() {
    if (_openScheduled) {
      return;
    }
    _openScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _gateOpen = true;
    });
  }
}
