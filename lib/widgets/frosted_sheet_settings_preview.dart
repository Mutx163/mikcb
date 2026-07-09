import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
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
    super.key,
  });

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
    final appearance = FrostedAppearance(
      sheetBlurSigma: blurSigma,
      sheetTintAlpha: tintAlpha,
      sheetBarrierAlpha: barrierAlpha,
      blurEnabled: blurEnabled,
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
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  TimetableWeekPreview(
                    provider: provider,
                    settings: settings,
                    week: week,
                    maxVisibleSections: 2,
                    includeAppHeader: true,
                    applyHomePageBackdrop: true,
                    heightBudget: _previewHeight,
                  ),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: _MiniHomeFrostedMenuSheet(),
                  ),
                ],
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
  return showHomeHyperosSheet<void>(
    context: context,
    builder: (_) => const FrostedSheetSettingsDemoSheet(),
  );
}

class _MiniHomeFrostedMenuSheet extends StatelessWidget {
  const _MiniHomeFrostedMenuSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final titleStyle = typo.body.xs2.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.1,
      fontSize: 9,
      color: colors.foreground,
    );

    Widget miniTile(IconData icon, String title) {
      return Expanded(
        child: _DemoMenuTile(
          icon: icon,
          title: title,
          titleStyle: titleStyle,
          accentColor: colorScheme.primary,
          compact: true,
        ),
      );
    }

    return HyperosSheetFrame(
      frosted: true,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          miniTile(Icons.bar_chart_rounded, '统计'),
          const SizedBox(width: 6),
          miniTile(Icons.tune_rounded, '设置'),
          const SizedBox(width: 6),
          miniTile(Icons.file_upload_outlined, '导入'),
          const SizedBox(width: 6),
          miniTile(Icons.add_circle_outline_rounded, '加课'),
        ],
      ),
    );
  }
}

class _DemoMenuTile extends StatelessWidget {
  const _DemoMenuTile({
    required this.icon,
    required this.title,
    required this.titleStyle,
    required this.accentColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final TextStyle titleStyle;
  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const iconWellRadius = BorderRadius.all(Radius.circular(10));
    final iconSize = compact ? 18.0 : 24.0;
    final wellSize = compact ? 32.0 : 46.0;
    final verticalPadding = compact ? 6.0 : 13.0;
    final horizontalPadding = compact ? 4.0 : 7.0;

    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      child: Material(
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
              SizedBox(height: compact ? 4 : 7),
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
      ),
    );
  }
}
