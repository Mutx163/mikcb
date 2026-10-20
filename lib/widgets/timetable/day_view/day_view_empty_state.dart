import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../utils/home_page_background.dart';
import 'day_view_ink_style.dart';

/// 日视图「这一天没有课」的空态（居中两行字）。
///
/// 2026-10-20 自 `timetable_day_view_part.dart` 的
/// `_TimetableScreenState._buildDayViewEmptyState` 搬出：只做展示，
/// 墨色判据所需的壁纸亮度由 [inkEnvironment] 传入。
class TimetableDayViewEmptyState extends StatelessWidget {
  final int week;
  final TimetableSettings settings;
  final DayViewInkEnvironment inkEnvironment;

  const TimetableDayViewEmptyState({
    super.key,
    required this.week,
    required this.settings,
    required this.inkEnvironment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    final colorScheme = Theme.of(context).colorScheme;
    // Same wallpaper auto-contrast as weekday / time-axis chrome: default ink
    // flips black↔white over dark photos; a custom hex keeps its hue and only
    // gets its lightness pushed. The empty state sits mid-screen, so judge
    // from the card-region band.
    final titleColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: hasBackdrop,
      wallpaperLuminance:
          inkEnvironment.wallpaperBodyLuminance ??
          inkEnvironment.wallpaperTopLuminance,
    );
    final subtitleColor = homePageOverWallpaperMutedInk(titleColor);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.dayViewEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.weekLabel(week),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}
