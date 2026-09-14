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

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_sheet.dart';
import 'hyperos_theme.dart';
import 'frosted/liquid_glass_degradation.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';
import 'soft_glass/soft_glass_surface.dart';

/// Glass background for the select popup.
///
/// Renders the appropriate surface based on [FrostedGlassMode]:
/// - **liquidGlass**: [HyperosLiquidGlassSurface] with the shared modal role.
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
  });

  final double cornerRadius;
  final Widget child;

  /// 折射厚度缩放（0..1）：液态面按完整厚度的该比例渲染。二级子卡揭示
  /// 期间传揭示进度——厚度从近零生长到满值，顶缘折射对上方面板文字的
  /// 镜像随揭示减弱直至压暗接管，消除「字体反射」闪动。null/1 = 完整
  /// 厚度。
  final double? thicknessFactor;

  /// 浮在同一块玻璃面之上的弹层（如列表弹窗的二级子卡）置 true。
  ///
  /// 液态玻璃面按绘制顺序采样它下面的合成结果——二级子卡排在主面板
  /// 之后，直接采样就会包含主面板玻璃的输出，玻璃叠玻璃再折射一遍，
  /// 读感浑浊。置真后先铺一层**共享组捕获的磨砂底**（弹窗遮罩下的页面，
  /// 与主面板玻璃同源、由合成器逐帧刷新）把下方玻璃挡在外面，液态玻璃
  /// 再贴着这层底折射。
  ///
  /// 历史教训：这里一度垫的是宿主页面的**整页同步快照**（ui.Image），
  /// 结果展开时是一张静态照片跟着卡片走（用户口径：「就好携带一个有
  /// 背景的卡片出来了，而不是玻璃出来了」）。premium 档改为实时读底面
  /// 后，垫底必须是 live 的合成器捕获，不能再垫任何快照。
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
      // 与顶栏带 / 玻璃坞 / 卡片完全同一个组件、同一个档位常量
      // （[MikcbLiquidGlassTokens.defaultQuality]）。任何表面都不得再传自己的
      // 档位或捕获源——那正是「同一个材质几种观感」的成因。
      final surface = HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.modal,
        borderRadius: cornerRadius,
        thicknessFactor: thicknessFactor,
        child: child,
      );
      if (!useAncestorGroupCapture) {
        return surface;
      }
      // 磨砂底：共享组捕获（遮罩下的页面，合成器逐帧刷新）+ 常规磨砂
      // 参数，把主面板玻璃的输出挡在液态玻璃的采样输入之外。ClipRRect
      // 只圆底垫的角；液态玻璃面保持不裁，浅色模式的外阴影才能画到卡外。
      final sigma = HyperosBlurredHeader.blurSigmaOf(context);
      final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);
      return Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter.grouped(
                filter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.clamp,
                ),
                child: ColoredBox(color: tint),
              ),
            ),
          ),
          surface,
        ],
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

    // Frosted / gaussian / translucent: use the same sigma and tint as every
    // HyperosSheetFrame. The selected glass mode changes the shared modal
    // material, not the visual identity of one popup versus another.
    final sigma = HyperosBlurredHeader.blurSigmaOf(context);
    final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            // Grouped: samples the ancestor BackdropGroup's capture (undimmed
            // page), so the sibling modal scrim stays out of the blur input.
            child: BackdropFilter.grouped(
              filter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
              child: ColoredBox(color: tint),
            ),
          ),
          child,
        ],
      ),
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

  static const _kPopupShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 20),
  ];

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

