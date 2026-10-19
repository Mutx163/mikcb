import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, narrowSurfaceMaxRefraction;

/// 首页「回本周」浮钮（2026-10-19 从 timetable_screen 的 State 方法搬出）。
///
/// 只负责玻璃材质与布局；点按行为由 [onJumpToCurrentWeek] 注入，底部避让量由
/// [glassDockPillOccupancy] 显式传入，widget 自己不读 provider / State。
class TimetableBackToCurrentWeekButton extends StatelessWidget {
  const TimetableBackToCurrentWeekButton({
    super.key,
    required this.settings,
    required this.glassDockPillOccupancy,
    required this.onJumpToCurrentWeek,
  });

  final TimetableSettings settings;
  final double glassDockPillOccupancy;
  final VoidCallback onJumpToCurrentWeek;

  /// 「回本周」浮钮的高度（逻辑 px）：图标 15 与字号 11 取大者，加纵向内边距 8×2。
  ///
  /// 这个常量是**高度本身**（显式 `SizedBox`），不是对内容尺寸的旁注 ——
  /// 窄件几何适配（见 [narrowSurfaceMaxRefraction]）要按它算折射位移上限，
  /// 改内边距 / 图标尺寸时这里跟着改，两处不会走偏。
  static const double buttonHeight = 31;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foruiColors = context.theme.colors;
    final buttonOpacity =
        settings.timetableFloatingBackToCurrentWeekButtonOpacity;
    final borderRadius = BorderRadius.circular(18);
    // Do not wrap [HyperosFrostedSurface] in [Opacity]: Flutter's
    // [BackdropFilter] cannot sample content behind an opacity layer, so the
    // button would only show a solid tint and ignore the frosted-blur switch.
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final baseTint = HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
    final frostedTint = baseTint.withValues(
      alpha: (baseTint.a * buttonOpacity).clamp(0.0, 1.0),
    );
    final contentOpacity = buttonOpacity.clamp(0.0, 1.0);
    // 液态玻璃模式下用真折射圆角玻璃，而不是高斯模糊磨砂——
    // 与底栏/独立按钮同一套材质语言。
    final dockAppearance = FrostedAppearanceScope.of(context);
    // 「液态玻璃作用范围 → 玻璃坞导航」关闭时回浮按钮回磨砂圆片。
    final useLiquidGlassMaterial =
        dockAppearance.liquidGlassDockEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
    // ⚠️ **描边必须按「液态是否真的画得出来」判，不是按「用户要不要液态」判**
    // （2026-09-30）。[LiquidGlassSurface] 在着色器后端缺失时会整层走
    // `fallbackBuilder`，画出来的是磨砂片；而 [HyperosFrostedSurface] 自己不画边，
    // 于是按 `useLiquidGlassMaterial` 判掉的描边会让回落态变成一颗**没有边界**的
    // 磨砂胶囊（桌面 / 测试环境恒定命中这条）。这两个判据此前恰好一致，因为那时
    // 出厂档是高斯、液态要用户显式选；高斯退场后默认值就是液态，两者分了家。
    final liquidActuallyRenders =
        useLiquidGlassMaterial && LiquidGlassSurface.isAvailable(context);

    // 按钮内容（图标 + 文字）。液态 / 磨砂两条材质分支共用它，只有「底」不同
    // ——以前两条分支各写一份内容，改一处文字要改两遍。
    // 透明度整体压在内容层：不能包住整块玻璃，否则 BackdropFilter 采不到后面
    // 的内容（见下方那条注释）。
    Widget chipBody() => Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const ValueKey('back-to-current-week-button'),
        onTap: onJumpToCurrentWeek,
        borderRadius: borderRadius,
        child: Opacity(
          opacity: contentOpacity,
          // 高度显式钉住（= 图标 15 + 内边距 8×2，与内容撑出来的值逐像素相同），
          // 这样窄件几何适配能按常量算，不用去猜内容尺寸。
          child: SizedBox(
            height: buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.backToCurrentWeekAction,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final glassDockForm =
        settings.homeNavigationForm == HomeNavigationForm.glassDock;
    // 按钮需始终浮在玻璃坞药丸之上：玻璃坞形态下统一取「内容避让量 +
    // 24 视觉边距」与「药丸占用 + 12 视觉间隙」的较大值——周视图由外层
    // 布局避让垫高、日/设置页视口全屏时按钮自行避让，两种实现下都不被
    // 药丸遮挡；经典形态保持原 24px 边距。
    final double dockBackButtonBottom;
    if (!glassDockForm) {
      dockBackButtonBottom = 24;
    } else {
      dockBackButtonBottom =
          math.max(24, glassDockPillOccupancy + 12) +
          MediaQuery.viewPaddingOf(context).bottom;
    }
    return SafeArea(
      minimum: EdgeInsets.only(right: 20, bottom: dockBackButtonBottom),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Tooltip(
          message: l10n.backToCurrentWeekAction,
          child: HyperosGlassShadow.wrap(
            borderRadius: borderRadius,
            shadowOverride: HyperosGlassShadow.compactShadow,
            shadowKey: const ValueKey('back-to-current-week-shadow'),
            opacity: contentOpacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                // 液态档不叠描边，避免与玻璃自己的折射带叠成两层圈圈；
                // 浮影统一由外层 [HyperosGlassShadow.wrap] 负责，且只落在外圈。
                // 磨砂档留着描边 —— 磨砂片自己不画边。
                //
                // ⚠️ 按「液态是否真的画得出来」判（见上面 `liquidActuallyRenders`
                // 那条）：着色器后端缺失时表面整层回落成磨砂片，此时描边必须回来。
                border: liquidActuallyRenders
                    ? null
                    : Border.all(
                        color: foruiColors.border.withValues(
                          alpha: foruiColors.border.a * contentOpacity,
                        ),
                      ),
              ),
              child: useLiquidGlassMaterial
                  ? LiquidGlassSurface(
                      probeName: 'glassFloatButton',
                      freezeOnRouteTransition: true,
                      borderRadius: borderRadius.topLeft.x,
                      // ⚠️ 不跟祖先组采样：组采样拿到的是壁纸快照，背景会变成一块
                      // 逐帧不变、不反映下方内容的底（与「回今日」按钮同一处境，
                      // 那颗按钮的实时采样见 day view 的浮钮实现）。悬浮钮要的是实时采样。
                      //
                      // 窄件几何适配：这颗钮只有 31dp 高，折射作用带占了 47%，不压会
                      // 读成一整圈轮廓（见 [narrowSurfaceMaxRefraction]）。
                      maxRefraction: narrowSurfaceMaxRefraction(buttonHeight),
                      fallbackBuilder: (_) => ClipRRect(
                        borderRadius: borderRadius,
                        child: HyperosFrostedSurface(
                          borderRadius: borderRadius,
                          tint: frostedTint,
                          child: chipBody(),
                        ),
                      ),
                      child: chipBody(),
                    )
                  : ClipRRect(
                      borderRadius: borderRadius,
                      child: HyperosFrostedSurface(
                        borderRadius: borderRadius,
                        tint: frostedTint,
                        child: chipBody(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
