import 'package:flutter/material.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/frosted/liquid_glass_degradation.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
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
    super.key,
  });

  final FrostedGlassMode glassMode;
  final LiquidGlassTuning? liquidGlassTuning;
  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final double blurSigma;
  final double tintAlpha;
  final double barrierAlpha;
  final bool blurEnabled;
  final VoidCallback onOpenDemoSheet;

  static const _previewHeight = 280.0;

  /// Preview-only render protection against the liquid-glass package's
  /// extreme-parameter artifacts.
  ///
  /// Past the dense preset's thickness/blur (28/14) the package shaders break
  /// down: the refraction displacement (thickness*10) exceeds the geometry
  /// texture's 8-bit encoding range and quantises into vertical stripes, and
  /// the edge-lighting pass paints fringe gradients on the band's visible
  /// edges. The real home page never sees this — it renders the *saved*
  /// tuning, which only becomes extreme if the user saves one — but this
  /// preview mirrors the live slider draft, so pulling a knob to the max
  /// used to paint stripes and fringes all over the preview band.
  ///
  /// Clamp the preview display only: slider ranges, the saved tuning and the
  /// real home page are untouched. Values at or below the dense preset pass
  /// through unchanged, so the preview stays 1:1 for every stock preset.
  static LiquidGlassTuning? previewSafeTuning(LiquidGlassTuning? tuning) {
    if (tuning == null) {
      return null;
    }
    return tuning.copyWith(
      thickness: tuning.thickness.clamp(
        LiquidGlassTuning.minThickness,
        LiquidGlassTuning.presetDense.thickness,
      ),
      blur: tuning.blur.clamp(
        LiquidGlassTuning.minBlur,
        LiquidGlassTuning.presetDense.blur,
      ),
    );
  }

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
      liquidGlassTuning: previewSafeTuning(liquidGlassTuning),
      liquidGlassPopupEnabled: settings.liquidGlassPopupEnabled,
      liquidGlassSelectSheetEnabled: settings.liquidGlassSelectSheetEnabled,
      liquidGlassSheetDialogEnabled: settings.liquidGlassSheetDialogEnabled,
      liquidGlassHomeChromeEnabled: settings.liquidGlassHomeChromeEnabled,
      liquidGlassDockEnabled: settings.liquidGlassDockEnabled,
      liquidGlassPickerButtonsEnabled: settings.liquidGlassPickerButtonsEnabled,
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
                applyHomePageBackdrop: true,
                heightBudget: _previewHeight,
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
    final appearance = FrostedAppearanceScope.of(context);
    // 演示的是真实弹窗材质：跟随「液态玻璃作用范围 → 弹窗与对话框」。
    final useLiquidGlass =
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassSheetDialogEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);

    return _buildSheet(context, useLiquidGlass: useLiquidGlass);
  }

  Widget _buildSheet(BuildContext context, {required bool useLiquidGlass}) {
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
      frosted: true,
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
          // Liquid-glass mode uses one shared layer for all four tiles:
          // identical siblings share one backdrop capture, so refraction at tile
          // edges samples a continuous backdrop instead of four independent
          // own-layer captures (which caused seam lines).
          Builder(
            builder: (context) {
              final tiles = Row(
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
              );

              if (!useLiquidGlass) {
                return tiles;
              }

              // Only liquid-glass mode needs a shared refraction layer. The
              // other modes use the same translucent nested surface rule as
              // settings cards; keeping them out of this layer prevents a
              // Gaussian/classic preview from rendering as liquid glass.
              return HyperosLiquidGlassLayer(
                role: HyperosLiquidGlassRole.nestedTile,
                // Sample the modal group's undimmed backdrop (matches home menu).
                useBackdropGroup: true,
                child: tiles,
              );
            },
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
        padding: EdgeInsets.symmetric(
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
            SizedBox(height: 7),
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

    final appearance = FrostedAppearanceScope.of(context);
    final useLiquidGlass =
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassSheetDialogEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
    if (useLiquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.nestedTile,
        borderRadius: HyperosTheme.cardBorderRadius.topLeft.x,
        // Tiles live in a shared HyperosLiquidGlassLayer (see the demo sheet);
        // sharedLayer registers this shape in the ancestor layer. A per-tile
        // instant FakeGlass underlay would paint its own backdrop filter per
        // tile, re-introducing seams, so it stays off here.
        layerMode: HyperosLiquidGlassLayerMode.sharedLayer,
        child: content,
      );
    }

    // Classic frosted / Gaussian / translucent modes keep nested cards as a
    // translucent tint over the already-frosted modal. They must not create a
    // liquid surface just because the demo card is shared with the liquid path.
    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      blurEnabled: false,
      tint: HyperosBlurredHeader.nestedSurfaceTintColor(
        context,
        withBlur: HyperosBlurredHeader.backdropBlurEnabled(context),
      ),
      child: content,
    );
  }
}
