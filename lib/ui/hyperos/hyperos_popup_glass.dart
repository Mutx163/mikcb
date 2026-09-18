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

import 'hyperos_blurred_header.dart';
import 'hyperos_sheet.dart';
import 'hyperos_theme.dart';
import 'frosted/liquid_glass_degradation.dart';
import 'liquid/liquid_glass_surface.dart';
import 'soft_glass/soft_glass_surface.dart';
import 'soft_glass/stable_frosted_surface.dart';

/// 弹层与首页常驻圆球**共用**的「轮廓 + 浮影」。
///
/// 为什么必须只有一处定义：首页那两颗球（「更多」「爱心」）不是按钮自己画的，
/// 而是"弹窗先画、再交接给常驻球"——上游形变动画的终点就是锚点大小的一块玻璃。
/// 两侧的描边/阴影只要不一致，交接那一瞬就会跳：真机反馈「阴影在弹窗收回后
/// 一秒突然出现」，根因正是常驻球有阴影而弹窗那颗没有（上游 `MiuixGlassPanel`
/// 默认带 `stroke` + `floating` 阴影，本仓的注入面把整块面板换掉时把这两层丢了）。
///
/// 用法：弹层侧传 [HyperosSelectPopupGlass.surfaceEdge]，球侧用这里的常量自己
/// 搭（球还要多垫一层洗色）。
abstract final class HyperosGlassEdge {
  /// 外浮影。数值与 [HyperosSolidPopupSurface] 既有的那层一致：实底分支本来就
  /// 有阴影，两边同值才谈得上"同源"。
  static const shadow = BoxShadow(color: Color(0x24000000), blurRadius: 20);

  /// 0.75 逻辑像素的发丝轮廓线（与顶栏分隔线同口径）：只勾出边界，不抢内容。
  static const ringWidth = 0.75;

  static Color ringColor(BuildContext context) => HyperosColors.outline(context);

  /// 把一块玻璃面按同源参数包上「浮影（下）+ 轮廓线（上）」。
  ///
  /// - 轮廓线 must 叠在玻璃**之上**：降级实底分支的面是不透明的，画在下面会被
  ///   整块盖掉。
  /// - [withShadow] 只在面**自带了同值阴影**时关掉（实底分支），否则会叠两层。
  /// - [clipBehavior] 必须 `none`，否则 Stack 默认会把外浮影裁掉。
  static Widget wrap(
    BuildContext context, {
    required BorderRadius borderRadius,
    required Widget child,
    bool withShadow = true,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (withShadow)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: const [shadow],
              ),
            ),
          ),
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: ringColor(context),
                  width: ringWidth,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
    this.surfaceEdge = false,
    this.enableEdgeHighlight = true,
  });

  final double cornerRadius;
  final Widget child;

  /// 面上再叠一圈同源轮廓 + 浮影（见 [HyperosGlassEdge]）。
  ///
  /// 默认关：其余弹层（选择弹窗、列表弹窗）保持原观感，那些弹层没有"要交接给
  /// 常驻球"的终点。**OS4 注入面必须开**（`os4_glass_popup_surface.dart`）——
  /// 首页菜单收起时那颗球就是这块面缩到锚点大小，两侧不一致就会在交接瞬间跳。
  final bool surfaceEdge;

  /// 上游那圈「贴边加法白」高光要不要画（透传给 `SoftGlassSurface`）。
  ///
  /// 默认开 —— 那是柔光玻璃的标准观感，弹层一律保持。**只有首页那颗常驻玻璃球
  /// 关掉它**（`FHeaderActionBall`）：球的轮廓由 [HyperosGlassEdge] 那道不透明
  /// 描边保证，任何背景上都读得出；而上游这圈加法白在球上属于**零收益、纯副作用** ——
  /// 纯色底上"白叠白"等于没画（历史反馈「没壁纸时球看不见」正是这个成因，当时的
  /// 修法是补轮廓线），有壁纸时球内部变成壁纸糊出来的颜色，贴边那层白一叠就顶到
  /// 纯白，读起来是"一圈没有过渡的死白边"（用户反馈：柔光档 + 壁纸，右上角球的
  /// 白边特别重）。
  ///
  /// ⚠️ 关闭它会让球与"菜单收起时那块缩到锚点大小的面板"在描边上有差异（面板仍带
  /// 高光）。两侧仍是同一个组件、同一圈轮廓与浮影，只是那 1px 高光的有无 ——
  /// 这是有意接受的取舍，见 `.agents/notes/implemented/bug-fix/`
  /// 下 2026-09-17 那篇。
  final bool enableEdgeHighlight;

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

  /// 当前外观下弹窗是否走柔光玻璃面（Hyper-PiliPlus SoftGlass 风格）。
  ///
  /// 与 [liquidSurfaceActive] 同口径：柔光与液态同为高级材质，受**同一组**
  /// 「作用范围」开关约束。关闭时落入 [solidSurfaceActive]的实底分支
  /// （不降级为高斯）。此前该判定只看全局档位，全局柔光时
  /// 六个作用范围开关全部失效（历史 bug）。
  static bool softSurfaceActive(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    return appearance.glassMode == FrostedGlassMode.softGlass &&
        appearance.liquidGlassPopupEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
  }

  /// 当前外观下弹窗是否走液态玻璃面（与 [build] 分支同一口径，供调用方
  /// 判断是否需要准备共享组捕获垫层）。
  static bool liquidSurfaceActive(BuildContext context) {
    final appearance = FrostedAppearanceScope.of(context);
    return appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassPopupEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
  }

  /// 当前外观下弹窗是否走不透明实底面（[HyperosSolidPopupSurface]）。
  ///
  /// 判定与 [build] 的材质分支同序：调用方强制实底（WebView 场景）→
  /// 实底；液态玻璃激活 → 液态面（自带模糊，不受 blur 总开关约束）；
  /// 否则 blur 总开关关闭、系统降级、或「液态玻璃作用范围」关闭本家族
  /// → 实底。调用方（如列表弹窗的墨色选择）据此把「为透明玻璃准备的
  /// 壁纸感知墨色」重置为主题墨——实底不再透出壁纸，浅色实底上的白墨
  /// 不可读。
  static bool solidSurfaceActive(
    BuildContext context, {
    bool opaqueSurface = false,
  }) {
    if (opaqueSurface) {
      return true;
    }
    if (liquidSurfaceActive(context) || softSurfaceActive(context)) {
      return false;
    }
    if (LiquidGlassDegradation.familyFallsBackToSolid(
      context,
      advancedFamilyEnabled: FrostedAppearanceScope.of(
        context,
      ).liquidGlassPopupEnabled,
    )) {
      return true;
    }
    return !HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  @override
  Widget build(BuildContext context) {
    final surface = _buildSurface(context);
    if (!surfaceEdge) {
      return surface;
    }
    return HyperosGlassEdge.wrap(
      context,
      borderRadius: BorderRadius.circular(cornerRadius),
      child: surface,
      // 实底分支自带同值浮影（[HyperosSolidPopupSurface]），再叠一层会明显更黑。
      withShadow: surface is! HyperosSolidPopupSurface,
    );
  }

  Widget _buildSurface(BuildContext context) {
    final borderRadius = BorderRadius.circular(cornerRadius);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final appearance = FrostedAppearanceScope.of(context);

    // Soft glass (global): milky frost panel for anchored popups.
    if (softSurfaceActive(context)) {
      return HyperosFrostedPanelScope(
        child: SoftGlassSurface(
          borderRadius: borderRadius,
          blurEnabled: useBlur,
          // 不传 recipe：全 app 柔光玻璃共用 [SoftGlassSurface] 的唯一配方
          // （顶栏 / 底栏 / 弹窗 / 面板同参）。曾经这里单独挂 dialog 配方、
          // 顶栏挂 floatingNavigation 配方——同一个材质两种雾度，用户口径
          // 「是柔光玻璃就全部显示一样」。
          enableShadows: false,
          enableEdgeHighlight: enableEdgeHighlight,
          child: child,
        ),
      );
    }

    // Liquid glass owns its own blur/refraction and must not be gated by the
    // platform BackdropFilter capability. Otherwise anchored popups become
    // solid surfaces on desktop while sheets and headers keep their glass.
    // 「液态玻璃作用范围 → 下拉选择弹窗」关闭时回退磨砂/实底材质。
    final useLiquidGlass = liquidSurfaceActive(context);

    if (useLiquidGlass) {
      // 与顶栏带 / 玻璃坞 / 卡片完全同一个组件、同一份参数（
      // [LiquidGlassSurface] 只从 scope 读调参）。任何表面都不得再传自己的
      // 档位或捕获源——那正是「同一个材质几种观感」的成因。
      return LiquidGlassSurface(
        borderRadius: cornerRadius,
        // 二级子卡（[useAncestorGroupCapture]）进祖先 BackdropGroup 的共享
        // 捕获点：由此采到「遮罩下的页面」，而不是把主面板玻璃的输出再折射
        // 一遍（玻璃叠玻璃读感浑浊）。
        grouped: useAncestorGroupCapture,
        refractionFactor: thicknessFactor,
        // 引擎没有 shader filter 后端 / 着色器未就绪时回落稳定磨砂面：
        // 仍是玻璃观感，不会突然变成一块实底。
        fallbackBuilder: (_) =>
            StableFrostedSurface(cornerRadius: cornerRadius, child: child),
        child: child,
      );
    }

    // Blur disabled, 或「液态玻璃作用范围 → 下拉选择弹窗」关闭
    // → solid opaque surface.
    //
    // 家族关闭时不再降级为磨砂：磨砂走实时 BackdropFilter，入场动画
    // （弹簧缩放 + 揭示裁切）期间采不到稳定背景，面板会整段渲染为透明，
    // 动画结束才「啪」地出现——读起来就是弹窗没有动画。实体卡片不依赖
    // 背景采样，动画全程正常。
    if (!useBlur ||
        LiquidGlassDegradation.familyFallsBackToSolid(
          context,
          advancedFamilyEnabled: appearance.liquidGlassPopupEnabled,
        )) {
      return HyperosSolidPopupSurface(cornerRadius: cornerRadius, child: child);
    }

    // Frosted / gaussian / translucent：**与柔光/液态统一走稳定快照**
    // （[StableFrostedSurface]）——入场动画期间四种材质共用同一张稳定背景，
    // 不再出现"磨砂在入场时采不到稳定背景、整段发平"这种与其它材质不一致的
    // 观感。没有采样源时该类内部维持原实时 BackdropFilter 分支，不会变差。
    //
    // 历史：这里原本直接 `BackdropFilter.grouped` + `sheetTintColor`。sigma 与
    // tint 仍然由共享的弹层材质档位决定（见 [StableFrostedSurface]）。
    return StableFrostedSurface(
      cornerRadius: cornerRadius,
      child: child,
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

  /// 与首页常驻球同源的那层外浮影（见 [HyperosGlassEdge]）。
  static const _kPopupShadow = [HyperosGlassEdge.shadow];

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

