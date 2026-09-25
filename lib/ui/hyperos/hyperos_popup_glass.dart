/// 弹层玻璃面（[HyperosSelectPopupGlass] / [HyperosSolidPopupSurface]）——**叶子文件**。
///
/// 为什么单独一个文件：这两个类是「按全局玻璃档位分派弹层材质」的唯一定义处，
/// 同时被两边消费 —— 本仓的选择弹层（`hyperos_select.dart`）与上游 OS4 弹层的
/// 注入面（`os4_glass_popup_surface.dart`）。注入面原先直接从
/// `hyperos_select.dart` 取这个类，而 `hyperos_select.dart` 又要反过来取注入面
/// 提供的 `hyperosGlassPopupSurface`，于是两个文件互相 import。
/// Dart 允许循环 import，但一旦有人再往这两条边上挂东西（历史上就发生过），
/// 依赖方向就没法从文件头看出来。这里把被共享的那个类下沉到叶子，依赖变成单向：
///
/// ```text
/// hyperos_popup_glass.dart  (叶子：材质分派)
///       ↑                 ↑
/// hyperos_select.dart   os4_glass_popup_surface.dart  (注入面)
/// ```
///
/// 同 `b434acdd` 的「弹窗页面捕获作用域下沉」是同一种处理，**不要再把这两个类
/// 搬回 `hyperos_select.dart`**。
library;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixGlassEdgeFade;

import 'hyperos_blurred_header.dart';
import 'hyperos_theme.dart';
import 'frosted/liquid_glass_degradation.dart';
import 'liquid/liquid_glass_surface.dart';
import 'soft_glass/stable_frosted_surface.dart';

/// 玻璃面外浮影的共享参数：弹层、首页常驻圆球、设置页返回圆钮与玻璃坞药丸都从这里取。
///
/// 为什么必须只有一处定义：首页那两颗球（「更多」「爱心」）不是按钮自己画的，
/// 而是"弹窗先画、再交接给常驻球"——上游形变动画的终点就是锚点大小的一块玻璃。
/// 两侧的阴影只要不一致，交接那一瞬就会跳：真机反馈「阴影在弹窗收回后一秒突然
/// 出现」，根因正是常驻球有阴影而弹窗那颗没有（上游 `MiuixGlassPanel` 默认带
/// `stroke` + `floating` 阴影，本仓的注入面把整块面板换掉时把这两层丢了）。
///
/// **组件自己那道 0.75 发丝轮廓线已按用户要求下线**（2026-09-19）：球的边界改由
/// 玻璃材质自己交代（液态玻璃的受光边缘高光），不再在材质之外叠一层描边。浮影
/// 保留 —— 它是上面那条交接一致性的载体，与「描边」是两回事。
///
/// 用法：弹层侧传 [HyperosSelectPopupGlass.surfaceShadow]，球侧用这里的常量自己搭。
abstract final class HyperosGlassShadow {
  /// 外浮影。数值与 [HyperosSolidPopupSurface] 既有的那层一致：实底分支本来就
  /// 有阴影，两边同值才谈得上"同源"。
  static const shadow = BoxShadow(color: Color(0x24000000), blurRadius: 20);

  /// 设置页返回圆钮与首页玻璃坞药丸共用的紧凑外浮影。
  ///
  /// 数值刻意比 [shadow] 小得多。两处都需要在浅色 / 无壁纸背景上轻轻分开边界，
  /// 但不能把大范围阴影铺到旁边的模糊区里。
  static const compactShadow = BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 1.5),
    blurRadius: 4,
  );

  /// 把一块玻璃面按同源参数衬上外浮影。
  ///
  /// - [withShadow] 只在面**自带了同值阴影**时关掉（实底分支），否则会叠两层。
  /// - [shadowOverride] 指定另一份共享浮影；缺省用 [shadow]。
  /// - [borderRadius] 只用来给浮影定形状 —— 少了它阴影会是个方块。
  /// - [clipBehavior] 必须 `none`，否则 Stack 默认会把外浮影裁掉。
  /// - [opacity] 0..1：二级开合时随 [MiuixGlassEdgeFade] 渐变，阴影深浅与
  ///   边缘高光同节奏（1 = 全量，静止态不变）。
  static Widget wrap({
    required BorderRadius borderRadius,
    required Widget child,
    bool withShadow = true,
    double opacity = 1.0,
    BoxShadow? shadowOverride,
  }) {
    if (!withShadow || opacity <= 0.01) {
      return child;
    }
    final o = opacity.clamp(0.0, 1.0);
    final source = shadowOverride ?? shadow;
    final shadowColor = source.color.withValues(
      alpha: source.color.a * o,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: source.blurRadius,
                  spreadRadius: source.spreadRadius,
                  offset: source.offset,
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 一级面板是否正在「让位」（二级已展开）——**全局信号**。
///
/// 为什么不能用 InheritedWidget：OS4 弹层经 `OverlayPortal(rootOverlay)` 挂到
/// 全局 Overlay，注入面 `surfaceBuilder` 的 context **不在**宿主（首页菜单）
/// 子树下，`dependOnInheritedWidget` 永远读到 false。真机上表现为：让位时底板
/// 材质切换靠不住，关掉二级后一级也容易「样子/位置回不去」。
///
/// 宿主在 `_secondaryOpen` 变化时写 [yielding]；开了
/// 一级面板是否在二级展开时用 [AnimatedScale] 让玻璃一起缩（见 [HyperosPopupYieldBus]）。
/// `ListenableBuilder` 听它，让位期间强制 canvas 板，结束立刻切回液态玻璃。
class HyperosPopupYieldBus {
  HyperosPopupYieldBus._();

  static final ValueNotifier<bool> yielding = ValueNotifier(false);
}

/// Glass background for the select popup.
///
/// Renders the appropriate surface based on [FrostedGlassMode]:
/// - **liquidGlass**: [LiquidGlassSurface] with the shared modal material.
/// - **frosted / gaussian**: [BackdropFilter] blur + tint scrim.
/// - **translucent**: lighter blur + minimal tint.
/// - **blur disabled**: solid [HyperosColors.surfaceContainer].
class HyperosSelectPopupGlass extends StatelessWidget {
  const HyperosSelectPopupGlass({
    super.key,
    required this.cornerRadius,
    required this.child,
    this.useAncestorGroupCapture = false,
    this.thicknessFactor,
    this.maxRefraction,
    this.surfaceShadow = false,
  });

  final double cornerRadius;
  final Widget child;

  /// 折射位移上限（逻辑 px）。null = 不压，用材质里那一份。
  ///
  /// 与 [LiquidGlassSurface.maxRefraction] 同一性质：**几何适配**，只允许往下压。
  /// 目前在弹层族里只有一处用到 —— 贴底通栏弹窗传 0（理由见
  /// `miuix_bottom_sheet.dart` 的 `hyperosMiuixBottomSheetSurface`：它的上沿正好压在
  /// 自己那层裁剪线上，朝外推的位移第一步就出了可采范围、读成一条暗线）。
  /// 右上角菜单弹窗 / 列表弹窗这类**有自由周边**的浮起卡片不传 —— 它们的边缘折射
  /// 落在画面里，是正常的透镜边，要留着。
  final double? maxRefraction;

  /// 面上再衬一层同源浮影（见 [HyperosGlassShadow]）。
  ///
  /// 默认关：其余弹层（选择弹窗、列表弹窗）保持原观感，那些弹层没有"要交接给
  /// 常驻球"的终点。**OS4 注入面必须开**（`os4_glass_popup_surface.dart`）——
  /// 首页菜单收起时那颗球就是这块面缩到锚点大小，两侧阴影不一致就会在交接瞬间跳。
  ///
  /// 曾经它还带一圈 0.75 的发丝轮廓线，2026-09-19 按用户要求下线：球的边界改由
  /// 玻璃材质自己交代，组件不再叠描边。
  final bool surfaceShadow;

  /// 折射厚度缩放（0..1）：液态面按完整厚度的该比例渲染。二级子卡揭示
  /// 期间传揭示进度——厚度从近零生长到满值，顶缘折射对上方面板文字的
  /// 镜像随揭示减弱直至压暗接管，消除「字体反射」闪动。null/1 = 完整
  /// 厚度。
  final double? thicknessFactor;

  /// 浮在同一块玻璃面之上的弹层（如列表弹窗的二级子卡）置 true。
  ///
  /// 置真时液态面进祖先 `BackdropGroup` 的共享捕获点（`grouped: true`）：
  /// 组内所有玻璃采到的是**同一个**捕获点处的背景，于是二级子卡折射的是
  /// 「遮罩下的页面」，而不是排在它前面的主面板玻璃的输出——玻璃叠玻璃再
  /// 折射一遍，读感浑浊。
  ///
  /// 历史教训：这里一度垫的是宿主页面的**整页同步快照**（ui.Image），
  /// 结果展开时是一张静态照片跟着卡片走（用户口径：「就好携带一个有
  /// 背景的卡片出来了，而不是玻璃出来了」）。改用共享组捕获后，垫底是
  /// live 的合成器捕获，不能再垫任何快照。
  final bool useAncestorGroupCapture;

  /// 弹窗家族的玻璃**能不能真的画出来**（技术 / 系统门禁）。
  ///
  /// 自 2026-09-19 起弹窗锁成「永远液态玻璃的标准档」（见 [LiquidGlassRole.pinnedChrome]），
  /// 材质不再由用户的档位 / 作用范围开关 / 模糊开关决定，所以这里只剩「能不能采样」
  /// 一个问题 —— 直接问表面自己。调用方用它判断要不要准备共享组捕获垫层
  /// （见列表弹窗的 `_hasSubmenu` 那段）。
  static bool liquidSurfaceActive(BuildContext context) =>
      LiquidGlassSurface.isAvailable(context, LiquidGlassRole.pinnedChrome);

  /// 当前弹窗是否走不透明实底面（[HyperosSolidPopupSurface]）。
  ///
  /// 只剩两类情形会走到：调用方强制实底（WebView 场景），以及**技术 / 系统门禁**
  /// 让玻璃画不出来（平台视图上方、系统无障碍降级、没有 shader 后端）。
  /// 调用方（如列表弹窗的墨色选择）据此把「为透明玻璃准备的壁纸感知墨色」重置为
  /// 主题墨 —— 实底不再透出壁纸，浅色实底上的白墨不可读。
  static bool solidSurfaceActive(
    BuildContext context, {
    bool opaqueSurface = false,
  }) {
    if (opaqueSurface) {
      return true;
    }
    return !liquidSurfaceActive(context);
  }

  @override
  Widget build(BuildContext context) {
    // 让位缩放由 GlassPopupLayout **布局级**缩小面板矩形完成（本地 fork）：
    // 玻璃按缩后尺寸画。这里不再包 AnimatedScale / forceCanvasBoard。
    final Widget body = LiquidGlassSurface(
      borderRadius: cornerRadius,
      role: LiquidGlassRole.pinnedChrome,
      grouped: useAncestorGroupCapture,
      refractionFactor: thicknessFactor,
      maxRefraction: maxRefraction,
      fallbackBuilder: (fallbackContext) =>
          LiquidGlassDegradation.shouldDegrade(fallbackContext)
          ? HyperosSolidPopupSurface(
              cornerRadius: cornerRadius,
              child: child,
            )
          : StableFrostedSurface(
              cornerRadius: cornerRadius,
              child: child,
            ),
      child: child,
    );
    if (!surfaceShadow) {
      return body;
    }
    // 阴影深浅与二级开合同步（与边缘高光共用 MiuixGlassEdgeFade）。
    return HyperosGlassShadow.wrap(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: body,
      withShadow: body is! HyperosSolidPopupSurface,
      opacity: MiuixGlassEdgeFade.of(context).clamp(0.0, 1.0),
    );
  }
}

/// Solid opaque popup surface — the shared fallback when backdrop blur is
/// unavailable or unsafe. Over an Android platform view (WebView) the
/// BackdropFilter / liquid-glass capture reads the platform view as black,
/// so popups anchored above one must use this instead of sampled glass.
class HyperosSolidPopupSurface extends StatelessWidget {
  const HyperosSolidPopupSurface({
    super.key,
    required this.cornerRadius,
    required this.child,
  });

  final double cornerRadius;
  final Widget child;

  /// 与首页常驻球同源的那层外浮影（见 [HyperosGlassShadow]）。
  static const _kPopupShadow = [HyperosGlassShadow.shadow];

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(cornerRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HyperosColors.surfaceContainer(context),
        borderRadius: borderRadius,
        boxShadow: _kPopupShadow,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

