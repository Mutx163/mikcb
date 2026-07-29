part of '../timetable_settings_screen.dart';

/// 「恢复默认」的作用域。
///
/// 滑块类参数（节高、间距、字号、各种透明度与模糊度）最容易被调乱，而此前
/// 没有任何撤销路径。这里按页给出恢复范围，且**逐字段显式列出**：不用反射、
/// 不整体替换，保证不会顺手把课程数据、时间模板、账号绑定一起清掉。
enum SettingsResetScope {
  /// 课程卡片页。
  courseCard,

  /// 课表页面页（含壁纸与背景区域）。
  timetablePage,

  /// 外观与主题页（全应用外观）。
  appearance,

  /// 桌面小组件页。
  homeWidget,
}

/// 默认值源。`TimetableSettings` 的构造函数带全套默认值；`sections` 是必填的
/// 课程节次数据，与「外观偏好」无关，这里给空表只是为了拿到其余字段的默认值，
/// 任何 scope 都不会去读它。
const TimetableSettings _settingsDefaults = TimetableSettings(sections: []);

/// 返回把 [scope] 涉及的字段重置为默认后的设置。
///
/// 作用域之间字段不重叠：同一个字段只会属于一页，避免「在 A 页恢复默认把
/// B 页也改了」。
TimetableSettings applySettingsReset(
  TimetableSettings current,
  SettingsResetScope scope,
) {
  const d = _settingsDefaults;
  return switch (scope) {
    SettingsResetScope.courseCard => current.copyWith(
      courseCardSurfaceStyle: d.courseCardSurfaceStyle,
      courseCardShowName: d.courseCardShowName,
      courseCardShowTeacher: d.courseCardShowTeacher,
      courseCardShowLocation: d.courseCardShowLocation,
      courseCardShowTime: d.courseCardShowTime,
      courseCardShowTimeLabels: d.courseCardShowTimeLabels,
      courseCardShowWeeks: d.courseCardShowWeeks,
      courseCardShowDescription: d.courseCardShowDescription,
      courseCardVerticalAlign: d.courseCardVerticalAlign,
      courseCardHorizontalAlign: d.courseCardHorizontalAlign,
      courseCardFontSize: d.courseCardFontSize,
      compactFontSize: d.compactFontSize,
      timetableUseUnifiedCardColor: d.timetableUseUnifiedCardColor,
      timetableUnifiedCardColor: d.timetableUnifiedCardColor,
      showConflictBadgeOnTimetable: d.showConflictBadgeOnTimetable,
      timetableConflictCourseOpacity: d.timetableConflictCourseOpacity,
      linkCourseCardColors: d.linkCourseCardColors,
      courseCardTitleColorLight: d.courseCardTitleColorLight,
      courseCardTitleColorDark: d.courseCardTitleColorDark,
      courseCardDetailColorLight: d.courseCardDetailColorLight,
      courseCardDetailColorDark: d.courseCardDetailColorDark,
    ),
    SettingsResetScope.timetablePage => current.copyWith(
      timetableAutoFitSectionHeight: d.timetableAutoFitSectionHeight,
      timetableHideWeekends: d.timetableHideWeekends,
      timetableShowNonCurrentWeekCourses: d.timetableShowNonCurrentWeekCourses,
      timetableSectionTimeDisplayMode: d.timetableSectionTimeDisplayMode,
      timetableTimeColumnWidthMode: d.timetableTimeColumnWidthMode,
      sectionHeight: d.sectionHeight,
      timetableCourseCardGap: d.timetableCourseCardGap,
      timetableBackToCurrentWeekButtonStyle:
          d.timetableBackToCurrentWeekButtonStyle,
      timetableFloatingBackToCurrentWeekButtonOpacity:
          d.timetableFloatingBackToCurrentWeekButtonOpacity,
      timetablePageBackgroundColor: d.timetablePageBackgroundColor,
      homePageBackdropFollowsWeekPager: d.homePageBackdropFollowsWeekPager,
      homePageBackgroundScope: d.homePageBackgroundScope,
      homePageHeaderBlurEnabled: d.homePageHeaderBlurEnabled,
      homePageWeekdayBarBlurEnabled: d.homePageWeekdayBarBlurEnabled,
      weekdayBarFontColorLight: d.weekdayBarFontColorLight,
      weekdayBarFontColorDark: d.weekdayBarFontColorDark,
      weekdayBarAccentColorLight: d.weekdayBarAccentColorLight,
      weekdayBarAccentColorDark: d.weekdayBarAccentColorDark,
      timeAxisFontColorLight: d.timeAxisFontColorLight,
      timeAxisFontColorDark: d.timeAxisFontColorDark,
      // 壁纸文件路径一并清空，否则「恢复默认」后背景仍在。
      clearHomePageWallpaperPath: true,
      clearHomePageBackgroundImagePath: true,
    ),
    SettingsResetScope.appearance => current.copyWith(
      appThemeMode: d.appThemeMode,
      appFontMode: d.appFontMode,
      foruiTheme: d.foruiTheme,
      themeSeedColor: d.themeSeedColor,
      homeTitleStyle: d.homeTitleStyle,
      frostedGlassMode: d.frostedGlassMode,
      frostedBlurEnabled: d.frostedBlurEnabled,
      frostedSheetBlurSigma: d.frostedSheetBlurSigma,
      frostedSheetTintAlpha: d.frostedSheetTintAlpha,
      frostedSheetBarrierAlpha: d.frostedSheetBarrierAlpha,
      liquidGlassTuning: d.liquidGlassTuning,
    ),
    SettingsResetScope.homeWidget => current.copyWith(
      widgetBackgroundStyle: d.widgetBackgroundStyle,
      widgetShowLocation: d.widgetShowLocation,
      widgetShowCountdown: d.widgetShowCountdown,
      widgetHideCompletedCourses: d.widgetHideCompletedCourses,
      widgetShowTomorrowCourses: d.widgetShowTomorrowCourses,
    ),
  };
}

/// 页尾的「恢复默认」白卡。
///
/// 红色图标 + 二次确认：这是不可撤销的批量写入，不能一点就生效。
class _SettingsResetTile extends StatelessWidget {
  const _SettingsResetTile({required this.scope, required this.onReset});

  final SettingsResetScope scope;
  final ValueChanged<TimetableSettings> onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HyperosSectionGap(),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.restart_alt_rounded,
              iconAccent: HyperosIconColors.red,
              title: l10n.settingsResetDefaultsTitle,
              onTap: () => _confirm(context, l10n),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, AppLocalizations l10n) async {
    final provider = context.read<TimetableProvider>();
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.settingsResetDefaultsConfirmTitle,
      message: l10n.settingsResetDefaultsConfirmBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.settingsResetDefaultsTitle,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    onReset(applySettingsReset(provider.settings, scope));
    if (!context.mounted) {
      return;
    }
    showAppLightTip(context, message: l10n.settingsResetDoneMessage);
  }
}
