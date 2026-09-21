import 'package:flutter/material.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/progressive_blur_tuning.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../providers/weather_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart';
// 诊断标记（临时件，见 utils/frame_perf_probe.dart）。
import '../utils/frame_perf_probe.dart';
import 'timetable_week_preview.dart';

/// Live + interactive frosted sheet preview for appearance settings.
class FrostedSheetSettingsPreview extends StatelessWidget {
  const FrostedSheetSettingsPreview({
    required this.provider,
    required this.settings,
    required this.week,
    required this.blurSigma,
    required this.tintAlpha,
    required this.barrierAlpha,
    required this.blurEnabled,
    required this.onOpenDemoSheet,
    required this.glassMode,
    this.liquidGlassTuning,
    this.liquidGlassTuningDark,
    this.linkLiquidGlassTuning = true,
    this.darkGlassBoostEnabled = true,
    this.softGlassTuning = SoftGlassTuning.defaults,
    this.progressiveBlurTuning = ProgressiveBlurTuning.defaults,
    super.key,
  });

  final FrostedGlassMode glassMode;
  final LiquidGlassTuning? liquidGlassTuning;

  /// 液态玻璃的深色档与两个成对开关（2026-09-21）。
  ///
  /// 与 [progressiveBlurTuning] 同一条理由：**预览必须跟草稿一起走**，否则
  /// 用户在外观编辑器里调深色档、预览却按浅色出图 —— 那比没有预览更坏。
  final LiquidGlassTuning? liquidGlassTuningDark;
  final bool linkLiquidGlassTuning;
  final bool darkGlassBoostEnabled;

  /// 柔光滑杆草稿（非空缺省，直接进预览 appearance）。
  final SoftGlassTuning softGlassTuning;

  /// 渐进模糊参数（预览里的顶栏玻璃带同款材质，必须跟草稿一起走，
  /// 否则预览与真实首页不同观感）。
  final ProgressiveBlurTuning progressiveBlurTuning;
  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final double blurSigma;
  final double tintAlpha;
  final double barrierAlpha;
  final bool blurEnabled;
  final VoidCallback onOpenDemoSheet;

  static const _previewHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 作用范围开关直读草稿设置，保证预览/演示与真实表面判定一致。
    final appearance = FrostedAppearance(
      sheetBlurSigma: blurSigma,
      sheetTintAlpha: tintAlpha,
      sheetBarrierAlpha: barrierAlpha,
      blurEnabled: blurEnabled,
      glassMode: glassMode,
      liquidGlassTuning: liquidGlassTuning,
      liquidGlassTuningDark: liquidGlassTuningDark,
      linkLiquidGlassTuning: linkLiquidGlassTuning,
      darkGlassBoostEnabled: darkGlassBoostEnabled,
      // 卡片那套直接从 `settings` 读，不走构造参数：两个调用点传进来的都是**草稿**
      // （`settings: _draft`），逐字段再复制一遍只会多一个能漏传的地方。
      courseCardGlassTuning: settings.courseCardGlassTuning,
      softGlassTuning: softGlassTuning,
      progressiveBlurTuning: progressiveBlurTuning,
      // 预览里的首页玻璃带（HomePageChromeGlassFill）经 scope 读顶栏材质
      // 与子页风格；缺省会让预览带永远渲染默认档，与真实首页不符。
      subpageHeaderBlurStyle: settings.subpageHeaderBlurStyle,
      homeBandGlassMaterial: settings.homeBandGlassMaterial,
      liquidGlassDockEnabled: settings.liquidGlassDockEnabled,
    );

    return FrostedAppearanceScope(
      appearance: appearance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipPath.shape(
            shape: HyperosTheme.cardShape(),
            child: SizedBox(
              height: _previewHeight,
              // The live liquid-glass menu is not rendered inline here. A grouped
              // backdrop inside the scrollable settings ListView captures the whole
              // scrolling viewport (BackdropFilter.grouped's capture is the cull
              // rect — the viewport — and cannot be narrowed by widget-level
              // RepaintBoundary/ClipRect), so it flickers and misaligns on scroll.
              // The home top menu avoids this by being a modal over a static page.
              // So this box previews only the timetable backdrop; the live glass
              // menu is previewed by the "open demo" button below — a modal that
              // uses the same code path as the home top menu.
              child: TimetableWeekPreview(
                provider: provider,
                settings: settings,
                week: week,
                maxVisibleSections: 2,
                includeAppHeader: true,
                heightBudget: _previewHeight,
                isSettingsPreview: true,
                // 这块预览的是首页外观，天气行跟着首页一起出现/消失。
                weather: context.watch<WeatherProvider?>(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          HyperosButton(
            label: l10n.frostedSheetPreviewOpenAction,
            variant: HyperosButtonVariant.secondary,
            expand: true,
            onPressed: onOpenDemoSheet,
          ),
        ],
      ),
    );
  }
}

/// Full-size demo sheet opened from the appearance settings preview button.
class FrostedSheetSettingsDemoSheet extends StatelessWidget {
  const FrostedSheetSettingsDemoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildSheet(context);
  }

  Widget _buildSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    const tileSpacing = 10.0;

    Widget tile(IconData icon, String title) {
      return Expanded(
        child: _DemoMenuTile(
          icon: icon,
          title: title,
          titleStyle: typo.body.xs2.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.15,
            color: colors.foreground,
          ),
          accentColor: colorScheme.primary,
        ),
      );
    }

    return HyperosSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.frostedSheetPreviewDemoTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.frostedSheetPreviewDemoSubtitle,
            style: HyperosTypography.sectionDescription(context),
          ),
          const SizedBox(height: 14),
          // 四块瓦片各自是 [LiquidGlassSurface]（液态档才建），分组采样由各自
          // 的 `grouped` 打开：祖先 BackdropGroup 的共享捕获点保证瓦片互相
          // 看不到对方的输出，不必再挂一层包内专属的共享层。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(Icons.bar_chart_rounded, l10n.homeMenuStatisticsTitle),
              const SizedBox(width: tileSpacing),
              tile(Icons.tune_rounded, l10n.homeMenuSettingsTitle),
              const SizedBox(width: tileSpacing),
              tile(Icons.file_upload_outlined, l10n.homeMenuImportTitle),
              const SizedBox(width: tileSpacing),
              tile(
                Icons.add_circle_outline_rounded,
                l10n.homeMenuAddCourseTitle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          HyperosButton(
            label: l10n.closeAction,
            variant: HyperosButtonVariant.secondary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

Future<void> showFrostedSheetSettingsDemo(BuildContext context) {
  // 诊断标记（临时件，见 utils/frame_perf_probe.dart）：这个演示弹层的内容比
  // 普通弹层重得多（含课表预览 + 四块玻璃砖），量与「普通弹层」分开，
  // 否则 `sheet:open` 这一条会把两种完全不同的开销混在一个名字里。
  FramePerfProbe.mark('sheet:open:demoPreview');
  return showHomeHyperosSheet<void>(
    context: context,
    builder: (_) => const FrostedSheetSettingsDemoSheet(),
  );
}

class _DemoMenuTile extends StatelessWidget {
  const _DemoMenuTile({
    required this.icon,
    required this.title,
    required this.titleStyle,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final TextStyle titleStyle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    const iconWellRadius = BorderRadius.all(Radius.circular(10));
    const iconSize = 24.0;
    const wellSize = 46.0;
    const verticalPadding = 13.0;
    const horizontalPadding = 7.0;

    final content = Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HyperosFrostedSurface(
              borderRadius: iconWellRadius,
              blurEnabled: false,
              tint: HyperosBlurredHeader.accentSurfaceTintColor(accentColor),
              child: SizedBox(
                width: wellSize,
                height: wellSize,
                child: Center(
                  child: Icon(icon, color: accentColor, size: iconSize),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ],
        ),
      ),
    );

    // 液态玻璃画不出来时（技术 / 系统门禁）落到这里 —— 见下方 return 的说明。
    Widget frostedTile() => HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      blurEnabled: false,
      tint: HyperosBlurredHeader.nestedSurfaceTintColor(
        context,
        withBlur: HyperosBlurredHeader.backdropBlurEnabled(context),
      ),
      child: content,
    );

    // 四块瓦片在**演示弹层**里 —— 与弹层同一条规矩：自 2026-09-19 起永远液态玻璃的
    // 标准档，材质不再随用户的档位变化，只剩技术 / 系统门禁（fallback 仍是原来的磨砂瓦片）。
    return LiquidGlassSurface(
      borderRadius: HyperosTheme.cardBorderRadius.topLeft.x,
      role: LiquidGlassRole.pinnedChrome,
      // 四块瓦片是并列的兄弟：必须进祖先 BackdropGroup 共享同一个捕获点，
      // 否则后画的瓦片会把先画的那块玻璃一起折射进去（玻璃叠玻璃）。
      grouped: true,
      fallbackBuilder: (_) => frostedTile(),
      child: content,
    );
  }
}
