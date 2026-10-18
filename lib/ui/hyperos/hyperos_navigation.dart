import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  /// **2026-10-18 起不再用于前缘裁切本身**：滑动转场的前缘圆角改为**半径全程
  /// 恒定**（见 `_MiuixNavClippedPage` 的补片方案 —— 任何一次几何变化都会被重页面的
  /// 掉帧放大成「圆角闪现消失」）。保留这个因子只服务非几何用途：被覆盖页压暗 /
  /// 透明度衰减的末段释放（[coveredAlphaFor] / [scrimAlphaFor]）。
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

  /// 形变类转场的圆角收束因子（0 = 平角，1 = 满半径）：**只收尾、不起头**。
  ///
  /// 与 [transitionCornerRadiusFactor] 的区别在起点。滑动转场两端都要收：页在屏幕
  /// 外时没有前缘切口可言，到站后圆角「锁进屏幕边缘」（那块被机身圆角盖住），
  /// 所以两端为 0。形变类转场相反 —— 起手那一下是一张**小卡片**（卡片形变的源按钮、
  /// 锚点展开的种子面板），圆角必须保持满值；收平只发生在「页面/面板已经长到贴边」
  /// 之后，也就是只有终点一侧收。
  ///
  /// 反面教材（2026-10-17 真机）：这两条转场此前都**从 0 起就按进度线性收**
  /// （`22 × (1 - p)` / `28 × (1 - p)`）—— 进度过半半径就少一半、到 0.8 时只剩
  /// 4.4dp / 5.6dp，而页面还差十分之一屏宽没贴边。用户原话：「页面还没有完全贴边，
  /// 没有完全打开的时候，圆角就已经消失变成直角了，时机比其他页面早多了」。
  ///
  /// [band] 按**缓动后**进度算，语义与 [HyperosMiuixNavigation.cornerClipSettleBand]
  /// 对齐（带宽 = 起步收束时「离贴边还剩多少」的比例）。各条转场的边缘内缩几何
  /// 不同，所以带宽分别取值：见 [HyperosMiuixNavigation.morphCornerSettleBand] 与
  /// [HyperosMiuixNavigation.anchorExpandCornerSettleBand]。
  static double morphCornerRadiusFactor(
    double progress, {
    double band = HyperosMiuixNavigation.morphCornerSettleBand,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    if (band <= 0) {
      // 带宽为 0 = 官方那套二值开关的形变版：只在终点收平。
      return clamped >= 1 ? 0 : 1;
    }
    return ((1 - clamped) / band).clamp(0.0, 1.0);
  }

  /// 卡片形变转场（`_OpenOnlyContainerPageRoute`）的整条圆角：起手是源按钮那张
  /// [sourceRadius] 圆角卡片（22dp），长出整屏的过程中保持它，贴边后才收平。
  ///
  /// 落点在这里而不是调用点，是因为 `timetable_screen.dart` 有行数棘
  /// （`test/architecture/timetable_screen_size_guard_test.dart`，只减不增）——
  /// 调用点必须是一行；机理与取值推导见 [morphCornerRadiusFactor] 的注释。
  static BorderRadius morphRadius(double progress, double sourceRadius) =>
      BorderRadius.circular(sourceRadius * morphCornerRadiusFactor(progress));

  /// 日视图锚点展开（`_buildAnchoredDayViewOverlay`）的整条圆角：种子面板 28dp，
  /// 长到贴边后才收平；带宽按那条转场的几何单独取（`(1 - 进度) × 屏高`，
  /// 见 [HyperosMiuixNavigation.anchorExpandCornerSettleBand]）。
  ///
  /// 同样为 `timetable_screen.dart` 的行数棘而落在这里（调用点一行）。
  static BorderRadius anchorExpandRadius(double progress) =>
      BorderRadius.circular(
        28 *
            morphCornerRadiusFactor(
              progress,
              band: HyperosMiuixNavigation.anchorExpandCornerSettleBand,
            ),
      );

  /// 被覆盖页的透明度（1 = 不透明）：官方 `1 - 0.1 × 覆盖度`。
  ///
  /// 2026-10-18 起**不再有末段释放**：圆角切口里露出来的就是这层被压暗/降透明度
  /// 的旧页，而「圆角看得见」靠的正是它与新页的**对比**。末段一释放，切口里的
  /// 颜色跟新页拉平 → 圆角在贴边前就肉眼消失（用户第十三轮：「左上角接近边缘时
  /// 一直是直角，能看到圆角转变的过程」）。释放包络本来是为了让「缩小的月牙」
  /// 不显眼；现在半径恒定、月牙根本不缩，它只剩副作用。
  @visibleForTesting
  static double coveredAlphaFor(double coverValue) {
    return 1 - HyperosMiuixNavigation.coveredAlphaFalloff * coverValue;
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
    return HyperosMiuixNavigation.dimAmount * coverValue;
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
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final moving = enter.status == AnimationStatus.forward ||
        enter.status == AnimationStatus.reverse;
    final leadingCornerActive = isTopRoute || moving;
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
          // 裁切层的**存在**恒定（结构恒定红线），半径按「是不是栈顶那一页」取：
          // 被覆盖页也裁会把两层洞对齐，直接看穿到窗口黑底（第十轮用户截图里的
          // 黑圆角）。判据用 `isCurrent` —— 本仓转场壳是裸 `PageRoute`，被覆盖页
          // 的 `secondaryAnimation` 根本不会被驱动，拿 `coverValue` 判会恒为 0。
          clipEnabled: clipRadius > 0,
          radius: leadingCornerActive ? clipRadius : 0,

          // 前缘圆角：**恒定半径，全程不随进度变**（2026-10-18 定案）。
          //
          // 以前这里在末段按 `transitionCornerRadiusFactor` 平滑收到 0。那不是
          // 「更平滑」，而是把一次**不可控的几何变化**压进最后 ~85ms：重页面上
          // 那一段只有 1~2 帧，收的过程读作「圆角闪现消失」（真机连续四轮）。
          // 现在半径不动 —— 圆角从滑入第一步就在，一直走到页面贴边、和机身圆角
          // 重合（该处被机身圆角盖住，静止态看不出来），转场自始至终没有一次
          // 「圆角形状变化」可供掉帧放大。读数取上下两角的较小值、读不到则不裁。
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
        // 前缘「自己的一条边」（2026-10-18 第十四轮，用户选 A）：圆角是挖出来的
        // 洞，洞的可见性取决于洞里露出的那层与页面的对比 —— 页面顶部是纯色标题
        // 区时，洞底也是同一片纯色，圆角在视觉上不存在（用户口径：只有桌面小组件
        // / 数据备份这类页面是直角，通用 / 课程卡 / 天气正常）。
        // 这里在页面左上/左下圆角 + 左侧边缘描一条**极细的半透明线**，让轮廓
        // 不依赖背景；只在「页面正在动」时画，落定后一个像素都不画（静止态零变化）。
        final edged = page;

        // === 临时诊断（2026-10-18）：把「缺口区域」涂成洋红，用来判断左上角那块
        // 到底是「没被裁开」还是「裁开了但洞里同色」。看完即撤。
        final diagnosed = CustomPaint(
          foregroundPainter: _DebugNotchPainter(
            radius: leadingCornerActive ? clipRadius : 0,
            rtl: isRtl,
          ),
          child: edged,
        );

        final content = _MiuixNavParallaxBleed(
          width: width,
          bleedWidth: bleedWidth,
          surface: surface,
          scrimAlpha: scrimAlpha,
          child: diagnosed,
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

  /// 是否画前缘圆角 —— 只由**设备圆角读数**决定（转场全程恒定）。
  final bool clipEnabled;

  /// 圆角半径：**设备圆角读数，全程恒定**。贴边后该区域被机身圆角盖住。
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
    if (clipEnabled) {
      // 2026-10-18 定案（第十一轮真机 + 截图）：圆角**保留**（用户明确否掉
      // 「不要圆角」的版本），但两件事一起改：
      //
      // 1. 半径**恒定**：不再在末段收窄。收窄那一下在重页面上只有 1~2 帧，
      //    读作「圆角闪现成直角」——十轮反馈的根。
      // 2. 只裁**正在滑入的那一页**（`coverValue == 0`，见调用点）：被覆盖页
      //    也一起裁是第十轮的黑角来源 —— 两层洞在同一位置对齐，直接看穿到
      //    窗口黑底（用户截图左下角那块纯黑四分之一圆）。
      //
      // 于是滑入全程的观感与旧版一致（洞里露出被覆盖页，只是它被压暗着），
      // 但页面贴边时没有任何一帧去改圆角形状：洞不用补，闪的机会不存在。
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
    }    return page;
  }
}

/// 前缘圆角的**内层**切口：把同半径的圆角烘进页面自己的绘制结果里。
///
/// 为什么需要两层（2026-10-17 真机第四轮 + 2026-10-18 第十一轮复现）：
/// 外壳那层 `ClipRRect` 是**合成期**裁切，真机上会丢帧；丢的那几帧里页面像素
/// 本来就是方的 → 圆角「消失又回来」。用户第十一轮的原话是「左上角一直闪现
/// 恢复直角，极其快速的闪现，一秒可能七八次，左下角是正常的不闪」—— 正是这个
/// 现象（左下角那块底下同色，丢了也看不出来）。把同一条切口放进
/// `buildPage` 的返回值（框架缓存边界之内），页面栅格本身就缺角，丢帧也露不出
/// 方角。
///
/// 半径与外壳**同值、全程恒定**；结构常挂（非活动时半径 0），不按动画状态增删。
class _MiuixNavLeadingCornerCut extends StatelessWidget {
  const _MiuixNavLeadingCornerCut({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!HyperosMiuixNavigation.clipLeadingCornersWhileMoving) {
      return child;
    }
    final radius = HyperosMotionScope.of(context).displayCornerRadiusDp;
    if (radius <= 0) {
      return child;
    }
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isTop = ModalRoute.of(context)?.isCurrent ?? true;
    final moving = animation.status == AnimationStatus.forward ||
        animation.status == AnimationStatus.reverse;
    final effective = (isTop || moving) ? radius : 0.0;
    final corner = Radius.circular(effective);
    return ClipRRect(
      borderRadius: isRtl
          ? BorderRadius.only(topRight: corner, bottomRight: corner)
          : BorderRadius.only(topLeft: corner, bottomLeft: corner),
      child: child,
    );
  }
}
/// 转场期间的「重页快照滑入」闸门（2026-10-17；2026-10-18 两段式退休：
/// 预热 0.99 → 收束带撤快照）。
///
/// 机理（为什么这能治「半路冻住 → 跳到位 + 提前变直角」）：转场中页面像素由
/// 框架 `_subtreeKey` 缓存，**缓存只在页面没重绘时有效** —— 新页异步内容到位
/// / 列表填充 / 预览卡出图的每一帧都把缓存作废、逼引擎重栅格化整页并重新
/// 合成。重页面这些帧要 50~80ms，屏幕停在旧画面上，动画读作「半路冻住」；
/// 下一帧画完直接跳到当前进度 + 圆角收平，用户读作「还没贴边就变直角」。
/// 首帧门槛只锁了起步那一帧，治不了中段这些帧。
///
/// 做法：页面首帧出画后把那一帧拷成一张 `ui.Image` 快照；快照模式下**真页
/// 整体离屏不画**（`Offstage`：build / 照常、布局照常 —— 异步内容照常到位，
/// 但 paint 完全跳过），屏上是 [RawImage] —— 每帧的动画成本只剩「合成一张
/// 图 + 位移」，与页面轻重无关。
///
/// **两段式退休**（2026-10-18 两轮真机反馈定案）：
///
/// 1. **预热**（进度 ≥ [HyperosMiuixNavigation.snapshotWarmupProgress] = 0.99，
///    页面离终点 ~4dp、视觉速度已近零）：真页放回屏下画 —— 快照仍盖在上层
///    屏蔽一切可见变化，真页那次整机绘制（重页面 50~80ms）落在「画面几乎
///    不动」的时刻 = 不可见；栅格缓存在此建立。快照期间攒下的内容在此显形
///    （被盖住），读作「内容就位」预备。
/// 2. **撤快照**（进度 ≥ `1 - cornerClipSettleBand`，即圆角收束带起点）：换层
///    只是「去掉一张图」的纯合成操作 —— 便宜，不产生任何重绘；之后 85ms 的
///    圆角收平在**已预热**的活像素上逐帧连续播放，与其他所有页面同一条
///    时间线。
///
/// 单段退休的两个真机失败案例（都已被上面的两段式吸收）：
/// * 退休在 `completed`：烤死的满值切口顶住末段收束，停稳一帧蹦直角
///   （第一轮反馈「圆角比别的页早收」）；
/// * 退休在收束带起点但没预热：换层帧 = 真页第一次整机绘制（重页面
///   50~80ms）卡进收平段，收平被压成一步蹦变（第二轮反馈「圆角闪现消失」）。
///
/// 关键：只把快照**叠**在真页上面是不够的 —— 页面层照样每帧重栅格化、照样
/// 被合成（被盖住不等于不被画），一分钱都省不下来。省钱的唯一方式就是让
/// 真页在快照模式里整个不进 paint。
///
/// 结构恒定（红线）：页面与快照层两层 `Offstage` + `RawImage` **恒挂**，只翻
/// 两个 `offstage` 布尔；页面子树不被增删包装、不重建。
///
/// 已知代价：
/// * 快照期间滑入画面里是「静止的照片」：页面自己的入场动画（骨架屏、
///   loading 转圈）在滑动画面里冻结，预热即接上 —— 重页面在滑动画面里本来
///   也播不动（每帧都掉），这是把「冻结但占着成本」换成「冻结且零成本」；
/// * pop 本页离场（`reverse`）期间快照若还在，离场画面同样保持快照（内容
///   = 滑入时用户看到的那一帧，视觉自洽），路由销毁时随 [dispose] 释放；
/// * 平台视图（WebView / 相机预览）拍不进 `toImage`，会拍成黑块 —— 这类
///   路由必须在推入点传 `snapshotTransition: false` 豁免（见
///   [HyperosPageRoute.snapshotTransition]）。
class _MiuixNavSnapshotGate extends StatefulWidget {
  const _MiuixNavSnapshotGate({
    required this.animation,
    required this.onAttached,
    required this.child,
  });

  /// 本页自己的路由动画。判据只认 [AnimationStatus]（与圆角切口同口径）：
  /// `forward` = push 滑入中（快照模式）；离开 forward（completed）= 换回
  /// 真页。
  final Animation<double> animation;

  /// 挂载时把 State 交给路由（[HyperosPageRoute] 借它把「快照已就绪」接进
  /// 首帧门槛的解锁判据）；dispose 时路由侧自行置空。
  final ValueChanged<_MiuixNavSnapshotGateState> onAttached;

  final Widget child;

  @override
  State<_MiuixNavSnapshotGate> createState() => _MiuixNavSnapshotGateState();
}

class _MiuixNavSnapshotGateState extends State<_MiuixNavSnapshotGate> {
  /// 页面首帧出画那一帧的拷贝。非空即「快照模式」：真页整体离屏不画、
  /// 屏上是这张图。null = 还没拍到（首帧出画前）/ 已释放（停稳或本页未启用）。
  ui.Image? _snapshot;

  /// 页面自己的栅格边界（[_buildStack] 里那层）。拍照取它：拍出来的是**页面
  /// 像素、不带切口** —— 滑入中的圆角由 `_MiuixNavClippedPage` 的补片现画，
  /// 照片里不能再烤死一个缺口（烤死的缺口不跟着收，收尾会露月牙）。
  final GlobalKey _pageBoundaryKey = GlobalKey();

  /// 快照拍照流程是否已了结（成功 / 失败都算）。首帧门槛的解锁判据读它：
  /// 了结之前动画锁在 0，拍照的时间落在「点下去 → 半拍停顿」里。
  bool _captureSettled = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
    widget.onAttached(this);
    // 首帧出画后拍快照：postFrameCallback 跑在本帧 paint 之后，页面刚画完
    // 第一次 —— 拍的就是首帧内容。此刻动画还被门槛锁在 0，拍照不占滑动。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _captureAfterFirstFrame(),
    );
  }

  void _captureAfterFirstFrame() {
    if (!mounted || _captureSettled) {
      return;
    }
    // 门槛判据此刻就置位（拍照流程已启动 = 对门槛而言已了结）：动画从下一帧
    // 起步，拍照的读图时间仍全部落在「点下去 → 半拍停顿」里。
    _captureSettled = true;
    // 拍照推迟到**下一帧末**：首帧末边界刚画完，但同一帧内仍可能被标脏
    // （toImageSync 断言 !debugNeedsPaint，实测会撞）；第二帧末必然干净，
    // 且异步内容又多涨了一帧，快照更完整。第二帧本来就在跑（ticker 在动），
    // 不用自己 scheduleFrame。
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureNow());
  }

  void _captureNow() {
    if (!mounted) {
      return;
    }
    // 拍**页面自己的栅格边界**（闸门里那层，见 [_buildStack]）：
    //
    // 2026-10-18 真机第三轮改口径：以前拍框架的 `_subtreeKey`（包着「页面 +
    // 内层圆角切口」），想让快照自带切口。但切口现在改成与外层同步**连续收**
    // （见 `_MiuixNavClippedPage`），烘死在照片里的缺口不会跟着收 —— 照片里
    // 留下一个恒定的满值缺口，外层的裁切只能削像素、填不回来。拍页面自己则
    // 天然不带缺口：滑入中的圆角由每帧现算的切口负责（切口仍在框架缓存边界
    // 之内，掉帧兜底的性质没变）。
    final node = _pageBoundaryKey.currentContext?.findRenderObject();
    if (node is! RenderRepaintBoundary ||
        !node.attached ||
        node.debugNeedsPaint) {
      // 拍不到（未布局 / 已离场 / 待重画）：留在真页模式 —— 等于本页没装
      // 快照门，退化为现状，不炸转场。
      return;
    }
    try {
      final image = node.toImageSync(
        pixelRatio: View.of(context).devicePixelRatio,
      );
      if (!mounted || widget.animation.status != AnimationStatus.forward) {
        image.dispose();
        return;
      }
      setState(() => _snapshot = image);
    } on Object {
      // 拍照失败（引擎拒绝 / 已离场）就留在真页模式 —— 等于本页没装快照门，
      // 退化为现状，不炸转场。
    }
  }

  /// 首帧门槛的解锁判据：快照拍照流程了结（成功或失败）才放行动画。
  @visibleForTesting
  bool get captureSettled => _captureSettled;

  /// 预热是否已排（0.99 进带后排一次帧末把真页放回屏下）。
  bool _warmupScheduled = false;

  /// 真页已放回屏下（预热完成 / 已退休）——快照还盖在上面时它照常画，
  /// 栅格缓存在这个「画面几乎不动」的时刻建立。
  bool _warmedUp = false;

  /// 判据用的进度：**缓动后**（与位移、圆角、压暗同一条曲线）。
  ///
  /// 路由动画本身的时间轴是线性的 —— 曲线挂在转场壳那一侧
  /// （`buildSharedAxisTransition` 里的 `CurvedAnimation`）。本闸门拿到的是
  /// 路由的原始动画，若直接读 `animation.value`，下面两个阈值会被解释成
  /// 线性时间：0.99 → 495ms、0.996 → 498ms；而视觉上的收束带在缓动时间轴
  /// 的 **415ms** 就开始了（0.996 对应 t=0.83），预热点 0.99 在 **371ms**。
  /// 差出来的这 80~125ms 正好把「照片顶着满值圆角撑过整段收平、最后一步蹦成
  /// 直角」—— 2026-10-18 真机第三轮反馈（「还是能明显看到圆角闪现消失」）的
  /// 根因之一。判据换算到与视觉同一条时间轴后，退休就落在收束带起点、预热
  /// 落在页面几乎不动的尾段，两段式退休才真正成立。
  double get _easedProgress => HyperosNavigation.transitionCurve.transform(
        widget.animation.value.clamp(0.0, 1.0),
      );

  /// 快照退休判据（每帧由 [build] 的 AnimatedBuilder 现读）。
  ///
  /// 收束带起点（缓动进度 ≥ `1 - cornerClipSettleBand`）或动画离开 forward
  /// （停稳 / 被打断）都退休 —— 只要「烤死的满值切口」还能被看出来是错的，
  /// 就把活页换回屏上。判据与 [HyperosNavigation.transitionCornerRadiusFactor]
  /// 用同一个带宽常量**和同一条曲线**，两条时间线必然重合。**退休前必须先
  /// 预热**（见 [HyperosMiuixNavigation.snapshotWarmupProgress]）：没预热就
  /// 撤快照，换层帧是真页的第一次整机绘制，会卡在收平段里读作蹦变。
  bool get _snapshotShouldRetire {
    final animation = widget.animation;
    final status = animation.status;
    if (status != AnimationStatus.forward) {
      return true;
    }
    // 2026-10-18 第十五轮真机：**接近屏幕边缘时圆角提前变直角**，而且就发生在
    // 快照退休那一刻（缓动 0.996 ≈ 离贴边 1.6px）。照片是「页面像素」的拷贝，
    // 换回真页那一帧如果真页的栅格/合成路径不同，圆角就会先一步变方 —— 现在
    // 有前缘轮廓线把这处差异放大了：线还圆着、底下页面已经方了。
    // 对策：照片撑到动画**结束**再撤（收平段全程在照片上，照片由前缘轮廓 +
    // 同一层裁切共同决定形状），换层发生在落定之后、屏幕边缘之外。
    return false;
  }

  /// 预热判据：缓动进度到达 [HyperosMiuixNavigation.snapshotWarmupProgress]
  /// （或动画离开 forward 的兜底）就把真页放回屏下画。
  bool get _shouldWarmUp {
    final animation = widget.animation;
    if (animation.status != AnimationStatus.forward) {
      return true;
    }
    return _easedProgress >=
        HyperosMiuixNavigation.snapshotWarmupProgress;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.forward && _snapshot != null) {
      // 兜底：动画被打断（interactive pop / 状态机跳变）时也退休，别把
      // 快照留在树上。正常路径的退休在 build 的 AnimatedBuilder 里按帧判。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _snapshot == null) {
          return;
        }
        _disposeSnapshot();
        _warmedUp = true;
        setState(() {});
      });
    }
  }

  /// 逐帧判据（build 的 AnimatedBuilder 里调）：
  ///
  /// * 进度到预热点（或动画状态异常）→ 帧末把真页放回屏下（快照仍盖着，
  ///   真页那次整机绘制落在「画面几乎不动」的时刻，不可见）；
  /// * 进度到收束带（且已预热）→ 帧末撤快照 —— 换层是纯合成操作，之后
  ///   圆角收平在**已预热**的活像素上逐帧连续播放。
  void _advancePhasesIfNeeded() {
    if (_snapshot == null) {
      return;
    }
    if (!_warmedUp && !_warmupScheduled && _shouldWarmUp) {
      _warmupScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _snapshot == null) {
          return;
        }
        setState(() => _warmedUp = true);
      });
      return;
    }
    if (_warmedUp && _snapshotShouldRetire) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _snapshot == null) {
          return;
        }
        _disposeSnapshot();
        setState(() {});
      });
    }
  }

  void _disposeSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!HyperosMiuixNavigation.snapshotTransitionEnabled) {
      return widget.child;
    }
    // `fit: StackFit.expand` 是硬约束：Stack 默认给子级**松**约束（min=0），
    // 会把外面好不容易还原的紧高度再次放松 —— 「根 Stack + Positioned.fill」
    // 形态的页面（教务仓库列表页）立刻塌成 0 高，整页不画（2026-09-28 露黑带
    // 的同款机理，test/screens/warehouse_transition_black_test.dart 守着）。
    // expand 把进入本闸门的紧约束原样传给两层子级。
    //
    // AnimatedBuilder 每帧现读两段判据（预热 0.99 → 退休收束带）：快照只管
    // 「中段重绘贵」的那一段；末段收平必须发生在**已预热**的活像素上 ——
    // 没预热就撤快照，换层帧的真页整机绘制会卡进收平段读作蹦变
    // （2026-10-18 真机第二轮反馈）。
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        _advancePhasesIfNeeded();
        return _buildStack(context);
      },
    );
  }

  Widget _buildStack(BuildContext context) {
    final pageOffstage = _snapshot != null && !_warmedUp;
    // `fit: StackFit.expand` 的硬约束理由见 build() 里的注释（松约束会把
    // 「根 Stack + Positioned.fill」页面塌成 0 高露黑带）。
    return Stack(
      fit: StackFit.expand,
      textDirection: Directionality.of(context),
      children: [
        // 真页：快照模式下整体离屏**不画**（build / 布局照常 —— 异步内容
        // 照常到位），paint 与语义完全跳过；这是省下每帧重栅格化的唯一
        // 方式。预热后放回屏下（被快照盖住，内容显形但不可见）；快照撤除
        // 后它就是普通页面。
        //
        // 页面外面这层 `RepaintBoundary` 是「换层必须便宜」的实体（2026-10-18
        // 真机第三轮）：撤快照那一帧只翻 `Offstage` 布尔，Stack 会重画 ——
        // 若真页没有自己的栅格边界，`paint` 会把整棵页面子树再跑一遍
        // （重页面 50~80ms），正好压在圆角收平段的起点。有了这层，预热帧建好
        // 的栅格在退休帧被直接复用，换层退化成纯合成操作。
        Offstage(
          offstage: pageOffstage,
          child: RepaintBoundary(
            key: _pageBoundaryKey,
            child: widget.child,
          ),
        ),
        // 快照层：恒挂（红线），offstage 布尔驱动。快照模式下它就是屏上
        // 参与滑动的那张图；真页模式下不可见、不占合成。
        Offstage(
          offstage: _snapshot == null,
          child: RawImage(image: _snapshot, fit: BoxFit.fill),
        ),
      ],
    );
  }
}


/// === 临时诊断（2026-10-18）===：把「缺口区域」（页面矩形减去同半径圆角矩形）
/// 涂成洋红。用途：判断左上角那块是「裁切没生效」还是「裁开了但洞里同色」。
/// 看完即撤。
class _DebugNotchPainter extends CustomPainter {
  const _DebugNotchPainter({required this.radius, required this.rtl});

  final double radius;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || size.isEmpty) {
      return;
    }
    final leading = Radius.circular(radius);
    final outer = Path()..addRect(Offset.zero & size);
    final rounded = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: rtl ? Radius.zero : leading,
          bottomLeft: rtl ? Radius.zero : leading,
          topRight: rtl ? leading : Radius.zero,
          bottomRight: rtl ? leading : Radius.zero,
        ),
      );
    final notch = Path.combine(PathOperation.difference, outer, rounded);
    canvas.drawPath(notch, Paint()..color = const Color(0xFFFF00FF));
  }

  @override
  bool shouldRepaint(covariant _DebugNotchPainter old) =>
      old.radius != radius || old.rtl != rtl;
}
/// Standard sub-page route for mikcb (settings, import, about, etc.).
class HyperosPageRoute<T> extends PageRoute<T> {
  static final Set<HyperosPageRoute<dynamic>> _activeRoutes = {};

  HyperosPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    this.snapshotTransition = true,
  });

  final WidgetBuilder builder;

  /// 本页是否允许「转场拿快照滑、落定换真页」（[_MiuixNavSnapshotGate]）。
  ///
  /// 唯一要关它的场景：页面里有**平台视图**（WebView / 相机预览等真实
  /// Android 视图）。平台视图不在 Flutter 图层树里，`toImageSync` 拍不到
  /// 它 —— 拍出来的快照里那块是黑的。默认开； WebView 登录页等宿主在
  /// 各自推入点显式传 false。
  final bool snapshotTransition;

  /// 本页快照闸门的 State（buildPage 挂闸门时注册）。null = 未启用快照
  /// （全局开关关 / 本页豁免 / 闸门未挂载）。
  _MiuixNavSnapshotGateState? _snapshotGate;

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
    _snapshotGate = null;
    super.dispose();
  }

  /// 首帧门槛：push 方向改用「新页首帧画完之前进度锁 0」的模拟器
  /// （见 [_HyperosFirstFrameGateSimulation]）。pop 不动 —— 返回首帧只有
  /// 2~19ms（探针口径），且 pop 首帧的新页早已构建过，没有门槛的必要。
  ///
  /// 启用快照时门槛再等一步：快照拍照流程了结（[_MiuixNavSnapshotGateState]
  /// 的 `captureSettled`，帧末同步完成）才解锁 —— 拍照的时间落在「点下去 →
  /// 半拍停顿」里，不占滑动时间轴。闸门还没挂上（本页豁免 / 全局关）时
  /// 退化为只等首帧，与原行为一致。
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
      snapshotReady: _snapshotSettled,
    );
  }

  /// 快照闸门是否已就绪（或本页根本没有快照可等）。
  ///
  /// 判据取「闸门不存在 = 已就绪」：豁免页 / 全局关时不给门槛加时间；
  /// 闸门存在时等它的帧末拍照了结（成功或失败都算了结）。
  bool _snapshotSettled() {
    final gate = _snapshotGate;
    return gate == null || gate.captureSettled;
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
    return FirstFrameProbeNode(
      nodeTag: 'page',
      // 切口必须落在框架的页面缓存边界（`_ModalScopeState` 的
      // `RepaintBoundary(key: _subtreeKey)`）**之内**，只能从 `buildPage` 挂
      //（见 `_MiuixNavClippedPage` 的说明）。快照闸门同样只能在 `buildPage`
      // 挂（它要包住页面本体），且在切口内侧：快照拍的是**页面像素本身**
      // （不带切口），滑入中的圆角由这层切口每帧现算 —— 烤死在照片里的缺口
      // 不会跟着收，收尾会露月牙（2026-10-18 真机第三轮）。
      child: _MiuixNavLeadingCornerCut(
        animation: animation,
        child: snapshotTransition
            ? _MiuixNavSnapshotGate(
                animation: animation,
                onAttached: (gate) => _snapshotGate = gate,
                child: builder(context),
              )
            : builder(context),
      ),
    );
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
///
/// 启用快照时（2026-10-17），解锁判据从「首帧已出画」扩成「首帧已出画 **且**
/// 快照拍照已了结」：`snapshotReady` 每次被查询时现读（闸门的拍照跑在帧末
/// 回调里，与首帧解锁同一时刻就位），没就绪就继续锁 0 —— 拍照的时间落在
/// 「点下去 → 半拍停顿」里，不占滑动时间轴。快照就绪后屏上是那张图，滑动
/// 全程每帧只剩「合成一张图 + 位移」。
class _HyperosFirstFrameGateSimulation extends Simulation {
  _HyperosFirstFrameGateSimulation({
    required this.durationSeconds,
    this.snapshotReady,
  });

  /// 转场整步时长（秒）。已在构造处按系统动画缩放与用户速度折算过
  /// （`animateWith` 模式下框架忽略 controller.duration，必须自带）。
  final double durationSeconds;

  /// 快照就绪判据（现读，可为 null = 不等快照）。
  final bool Function()? snapshotReady;

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
      if (snapshotReady?.call() ?? true) {
        _scheduleOpen();
      }
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
