import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, narrowSurfaceMaxRefraction;

/// 日视图底部居中的「回今日」浮钮（2026-10-19 从 timetable_screen 的 State 方法搬出）。
///
/// 与「回本周」浮钮同族但**不复用**实现：位置（居中 vs 右下）、文案、动作、
/// 可见性条件、配色都不同，两边分开演进。点按行为由 [onTap] 注入，底部避让量
/// 由 [bottomInset] 显式传入，widget 自己不读 provider / State。
class TimetableBackToTodayButton extends StatelessWidget {
  const TimetableBackToTodayButton({
    super.key,
    required this.bottomInset,
    required this.onTap,
  });

  final double bottomInset;
  final VoidCallback onTap;

  /// 形状与底栏药丸同族（胶囊，圆角 = 半高），但比底栏矮一档、窄一圈：
  /// 高度取底栏 56 的约 2/3（38），左右内边距 16，而不是让文字悬在大片
  /// 留白里。高度即成品高度（外层描边画在边界内、不占布局）。
  ///
  /// 列表底部余量（timetable_screen 的 `_backToTodayButtonScrollInset`）也读
  /// [height]，避免两边各自写死数字后走偏。
  static const double height = 38;
  static const double radius = height / 2;
  static const double horizontalPadding = 16;
  static const double fontSize = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final foruiColors = context.theme.colors;
    final accent = HyperosColors.primary(context);
    final borderRadius = BorderRadius.circular(radius);
    final dockAppearance = FrostedAppearanceScope.of(context);
    // 同「回本周」浮钮那条：作用范围开关 + 系统降级。
    final useLiquidGlassMaterial =
        dockAppearance.liquidGlassDockEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
    // 描边按「液态是否真的画得出来」判，不是按「用户要不要液态」判（2026-09-30）。
    final liquidActuallyRenders =
        useLiquidGlassMaterial && LiquidGlassSurface.isAvailable(context);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final tint = HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
    final content = SizedBox(
      // 与底栏药丸同高。外层 DecoratedBox 的 1dp 描边是**画在边界内**的
      // （与 Container 不同，不占布局），所以内容高度就是成品高度。
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        // 宽度只让文字撑开（Row 取 min，别用 Center/Align —— 它们会把
        // 可用宽度吃满，胶囊就变成横贯屏幕的一条）。
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.backToTodayAction,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
    // 磨砂底：既是磨砂档本身，也是液态玻璃不可用时的回落（仍是玻璃观感）。
    Widget frostedChip() => ClipRRect(
      borderRadius: borderRadius,
      child: HyperosFrostedSurface(
        borderRadius: borderRadius,
        tint: tint,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: content,
          ),
        ),
      ),
    );
    final surface = useLiquidGlassMaterial
        ? LiquidGlassSurface(
            probeName: 'glassBackToToday',
            freezeOnRouteTransition: true,
            borderRadius: radius,
            // ⚠️ **不跟祖先组采样**（2026-09-20 用户拍板「对齐药丸实时采样」）。
            //
            // 跟组采样时，采样源是组里那张**壁纸快照**（`UndimmedBackdropCapture`
            // 画在页面主体之前，见 `homeStack`），快照的屏幕位置固定 ⇒ 这颗钮的
            // 背景逐帧一模一样，下面课表怎么滚都不变（用户口径「背景永远都是
            // 不变的」）。底栏药丸看着"会变"是因为它在组**外**（坞层被
            // `_wrapHomeWithTopMenu` 摆成采样宿主的兄弟），它那句 `grouped: true`
            // 一直是空转 —— 所以这里显式不给，走实时采样，与药丸的真实行为对齐。
            //
            // 窄件几何适配：这颗钮只有 38dp 高，而折射位移的作用带是绝对值
            // （标准档 14.5dp = 高度的 38%，药丸/圆钮 56dp 上只占 26%），上下两条
            // 带会连成一整圈轮廓。与设置页那条约 40dp 的星期条同一条规矩，见
            // [narrowSurfaceMaxRefraction]。
            maxRefraction: narrowSurfaceMaxRefraction(height),
            fallbackBuilder: (_) => frostedChip(),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
            ),
          )
        : frostedChip();
    return SafeArea(
      minimum: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: HyperosGlassShadow.wrap(
          borderRadius: borderRadius,
          shadowOverride: HyperosGlassShadow.compactShadow,
          shadowKey: const ValueKey('back-to-today-shadow'),
          child: DecoratedBox(
            // 键挂在这层**外壳**上，两种材质分支（液态 / 磨砂）都能被找到、点到；
            // 挂在分支内部的 InkWell 上时，液态档就没有键了。液态档这层只留圆角
            // （不再描边，见下）。
            key: const ValueKey('back-to-today-button'),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              // 浮影统一由外层 [HyperosGlassShadow.wrap] 负责，且只落在外圈；
              // 液态档不叠描边，避免与玻璃自己的折射带叠成两层圈圈。磨砂档必须
              // 留着描边 —— [HyperosFrostedSurface] 自己不画边。
              //
              // ⚠️ 按「液态是否真的画得出来」判（着色器后端缺失时表面整层回落成
              // 磨砂片，此时描边必须回来），理由见上面 `liquidActuallyRenders`。
              border: liquidActuallyRenders
                  ? null
                  : Border.all(color: foruiColors.border),
            ),
            child: surface,
          ),
        ),
      ),
    );
  }
}
