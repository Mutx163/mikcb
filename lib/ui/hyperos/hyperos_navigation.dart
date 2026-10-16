import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  /// Whether the primary route animation is still running (not settled).
  ///
  /// Prefer this over raw progress for clip decisions: floating-point values
  /// near 0/1 can leave a tiny radius that shows as a half-rounded edge in
  /// screenshots after the page has visually finished sliding.
  @visibleForTesting
  static bool isPrimaryTransitionActive(AnimationStatus status) {
    return status == AnimationStatus.forward ||
        status == AnimationStatus.reverse;
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
  /// 严格跨越前缘 `-1 < d < 0` 才裁）。二值在真机上会「闪」：切口里露的是被压暗的
  /// 旧页，页面一停稳这块一帧之内换成新页背景，对比很强。这里把它换成连续收束，
  /// 半径在末段平滑收到 0 —— 圆角是「锁进屏幕边缘」，不是「啪一下没了」。
  ///
  /// 参数按**缓动后**的进度算（与位移同一条曲线），因为要跟「离落点还有多远」
  /// 对齐：0.03 的带宽对应 500ms 里的最后约 185ms。
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

  /// 前缘圆角切口（上层页面被裁掉的那两个角方块）在本页本地坐标里的左边界。
  ///
  /// 上层页面的前缘 = 它滑动方向那一侧：LTR 是左缘（`leadingSlidePx` 即它的
  /// 位移），RTL 是右缘（位移 + 页宽 - 半径）。参数里给的已经是**本页坐标系**里
  /// 的位置，被覆盖页自己的视差不需要在这里再减一次。
  @visibleForTesting
  static double cornerNotchLeft({
    required double leadingSlidePx,
    required double width,
    required double radius,
    required bool isRtl,
  }) {
    return isRtl ? leadingSlidePx + width - radius : leadingSlidePx;
  }

  /// 官方 miuix-nav `NavTransitions.MiuixDefault` + `NavDisplayEffects.Default`
  /// 的 Flutter 版。2026-10-16 换装，替换掉此前自研的「四角 40 圆角 + 投影」
  /// 卡片式转场（那套的常量与辅助函数一并撤掉）。
  ///
  /// 几何（官方转场层，全部线性于进度）：
  /// * 栈顶那一页整屏宽位移 `+width → 0`，**按整设备像素对齐**——官方为防
  ///   「被裁圆角 + 小数位移」在移动中闪出一条细线而做；
  /// * 被覆盖页向 leading 方向视差 1/4 屏宽，并衰减到 0.9 透明度。
  ///
  /// 正交效果（官方 `NavDisplayEffects`）：
  /// * 前缘圆角裁切：只裁**前缘两角**（LTR = 左，官方 `NavCornerClipMode.Leading`），
  ///   半径取设备屏幕圆角；与官方唯一不同的一点是**半径在末段连续收到 0**
  ///   （见 [transitionCornerRadiusFactor]），因为二值撤裁切在真机上会闪。
  /// * 切口补底色：被覆盖页那一层里，在上层页面被裁掉的两个角方块处补一块
  ///   **页面底色**、且画在压暗遮罩之下（见
  ///   [HyperosMiuixNavigation.fillCornerNotchWhileMoving]），免得切口变成
  ///   「旧页内容一直滑过」的窗口。
  /// * 全屏压暗：位于本层之上、上层页面之下，最深 0.5，随覆盖程度线性加深。
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

/// 官方默认预设驱动的一页：位移 + 前缘圆角 + 切口补底色 + 覆盖衰减 + 压暗蒙层。
///
/// 同一个 widget 伺服两种角色（框架对进出两页都调 `buildTransitions`）：
/// * 作为**栈顶那一页**（正在进或正在退）：`enter` 在 0..1 之间走，`cover == 0`；
/// * 作为**被盖住的那一页**：`enter == 1`（停在自己位置），`cover` 在 0..1 之间走。
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
        // 2) 被覆盖页：向 leading 方向视差 1/4 屏宽。
        final parallaxPx =
            -directionSign *
            HyperosMiuixNavigation.coveredParallaxFraction *
            width *
            coverValue;
        // 3) 被覆盖页的透明度衰减：官方 1 - 0.1 × 覆盖度。
        final coveredAlpha =
            1 - HyperosMiuixNavigation.coveredAlphaFalloff * coverValue;
        // 4) 压暗蒙层：官方曲线随深度线性，等价于「随覆盖程度线性加深」。
        final scrimAlpha = HyperosMiuixNavigation.dimAmount * coverValue;

        final page = _MiuixNavClippedPage(
          progress: enter,
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

        // 只有被覆盖时才需要视差补底（页面右侧 bleed 出去那一条，防止视差
        // 滑出后露出 Navigator 里更下一层的路由）；也只有那时才有压暗蒙层。
        final content = coverValue > 0.001
            ? _MiuixNavParallaxBleed(
                width: width,
                bleedWidth: bleedWidth,
                surface: surface,
                child: page,
              )
            : page;

        final translated = Transform.translate(
          offset: Offset(slidePx + parallaxPx, 0),
          child: content,
        );

        if (scrimAlpha <= 0.001) {
          // 纯位移不要外套 Stack：Stack 会把路由给的紧约束放宽成 0..max，
          // 根节点是「Stack + 零尺寸常驻子级」的页面会塌成高度 0。
          return translated;
        }

        // 上层页面被裁掉的前缘两个角方块里补一块**页面底色**（见
        // [HyperosMiuixNavigation.fillCornerNotchWhileMoving]）：不补的话切口
        // 就是个 28dp 的窗口，被压暗的旧页在视差平移，内容一直在窗口里滑过 ——
        // 真机上读作「左上/左下两个圆角一直在闪」。
        //
        // 位置直接由 cover 的缓动值推出上层页面的位移（两页共用同一条曲线，
        // 被覆盖页的 cover 值恒等于上层页面的 enter 值），所以不需要跨路由通信。
        final enteringSlidePx = _snapToDevicePixels(
          directionSign * (1 - coverValue) * width,
          devicePixelRatio,
        );
        final notchRadius =
            clipRadius *
            HyperosNavigation.transitionCornerRadiusFactor(coverValue);
        final showNotch =
            HyperosMiuixNavigation.fillCornerNotchWhileMoving &&
            clipRadius > 0.5 &&
            notchRadius > 0.5 &&
            coverValue < 0.999; // 停稳后上层页面不再裁圆角，补色全被它盖住。
        final notchLeft = HyperosNavigation.cornerNotchLeft(
          leadingSlidePx: enteringSlidePx,
          width: width,
          radius: clipRadius,
          isRtl: isRtl,
        );

        // 补色画在**压暗遮罩之下**：遮罩会像给页面背景一样给它压暗，切口与被
        // 覆盖页背景逐帧同色。画在遮罩之上当「角阴影」试过一版，真机上读成
        // 「黑色的方角」（圆角像没了），见常量处说明。
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topLeft,
          children: [
            translated,
            if (showNotch) ...[
              Positioned(
                left: notchLeft,
                top: 0,
                width: clipRadius,
                height: clipRadius,
                child: ColoredBox(color: surface),
              ),
              Positioned(
                left: notchLeft,
                bottom: 0,
                width: clipRadius,
                height: clipRadius,
                child: ColoredBox(color: surface),
              ),
            ],
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: scrimAlpha),
              ),
            ),
          ],
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
class _MiuixNavParallaxBleed extends StatelessWidget {
  const _MiuixNavParallaxBleed({
    required this.width,
    required this.bleedWidth,
    required this.surface,
    required this.child,
  });

  final double width;
  final double bleedWidth;
  final Color surface;
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
        ],
      ),
    );
  }
}

/// 前缘圆角裁切 + 被覆盖页的透明度衰减，都只在需要时挂上。
///
/// 传进来的 [radius] 已经过末段收束，两端精确是 0，所以静止态不可能残留圆角缺口；
/// [progress] 的状态再兜一道：只有栈顶真的还在动（forward / reverse）才裁。
class _MiuixNavClippedPage extends StatelessWidget {
  const _MiuixNavClippedPage({
    required this.progress,
    required this.radius,
    required this.alpha,
    required this.child,
  });

  /// 本页作为栈顶的运动进度，只用来判「还在动吗」。
  final Animation<double> progress;

  /// 裁切半径（已按 [HyperosNavigation.transitionCornerRadiusFactor] 收束过）；
  /// `<= 0.5` 视为不裁（两端精确为 0，所以静止态不挂 [ClipRRect]）。
  final double radius;

  /// 被覆盖页的透明度（1 = 不透明，此时不挂 [Opacity]，不起离屏层）。
  final double alpha;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final moving = HyperosNavigation.isPrimaryTransitionActive(
      progress.status,
    );
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    Widget page = child;
    if (moving && radius > 0.5) {
      // 只裁前缘两角（LTR = 左）：整页滑入时贴屏幕边缘那两个角不该被裁。
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
    if (alpha < 1) {
      page = Opacity(opacity: alpha, child: page);
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
