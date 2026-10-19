import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import '../../utils/home_page_background.dart';

/// 周网格时间列里的一节（2026-10-20 从课表页 State 搬出）。
///
/// 只做节次号与起止时间的排版/墨色；壁纸亮度由调用方注入。
class TimetableSectionTimeCell extends StatelessWidget {
  final int sectionNumber;
  final SectionTime section;
  final TimetableSettings settings;
  final double? wallpaperLuminance;

  const TimetableSectionTimeCell({
    super.key,
    required this.sectionNumber,
    required this.section,
    required this.settings,
    required this.wallpaperLuminance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same wallpaper auto-contrast as weekday ink; a custom time-axis hex keeps
    // its hue and only gets its lightness pushed. The time column spans the
    // body band (not the status/title strip), so judge from the card-region
    // sample.
    final timeAxisColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.timeAxisFontColorDark
          : settings.timeAxisFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultTimeAxisFontColorDark
          : TimetableSettings.defaultTimeAxisFontColorLight,
      themeFallback: isDark ? Colors.white : Colors.grey.shade800,
      hasBackdrop: hasHomePageBackdrop(settings),
      wallpaperLuminance: wallpaperLuminance,
    );
    final timeAxisMutedColor = homePageOverWallpaperMutedInk(timeAxisColor);
    final compactTextStyle = TextStyle(
      fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
      color: timeAxisMutedColor,
      height: 1.05,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$sectionNumber',
          style: TextStyle(
            fontSize: settings.compactFontSize.clamp(8.0, 11.0),
            fontWeight: FontWeight.bold,
            color: timeAxisColor,
          ),
        ),
        if (settings.timetableSectionTimeDisplayMode !=
            SectionTimeDisplayMode.hidden)
          Text(section.startTime, style: compactTextStyle),
        if (settings.timetableSectionTimeDisplayMode ==
            SectionTimeDisplayMode.startAndEnd)
          Text(section.endTime, style: compactTextStyle),
      ],
    );
  }
}
