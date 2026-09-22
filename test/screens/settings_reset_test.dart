import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/progressive_blur_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/utils/widget_course_accent.dart';

/// 「恢复默认」必须只动本页字段。这些用例守的是两件事：
/// 1. 目标字段确实回到默认；
/// 2. 别的页、以及课程数据 / 时间模板 / 诊断开关，一个都不许动。
void main() {
  /// 一份「哪里都被改过」的设置，用来暴露越界重置。
  TimetableSettings dirtySettings() {
    return TimetableSettings.defaults().copyWith(
      // 课程卡片
      courseCardShowTeacher: false,
      courseCardShowTime: true,
      courseCardFontSize: 12,
      compactFontSize: 12,
      timetableUseUnifiedCardColor: true,
      timetableUnifiedCardColor: '#123456',
      timetableConflictCourseOpacity: 0.3,
      showConflictBadgeOnTimetable: false,
      courseCardTitleColorLight: '#111111',
      // 卡片材质那一档（实体 / 高斯 / 液态）2026-09-22 属于「外观」作用域。
      courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
      // 课表页面
      timetableShowNonCurrentWeekCourses: true,
      sectionHeight: 90,
      timetableHideWeekends: true,
      screenshotSharePromptEnabled: false,
      timetableCourseCardGap: 3,
      timetablePageBackgroundColor: '#ABCDEF',
      homePageBackgroundScope: 15,
      subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
      // 注意 `homeBandGlassMaterial` 的默认值就是 'liquid'，写 'liquid' 不算脏。
      homeBandGlassMaterial: 'liquid',
      weekdayBarFontColorLight: '#222222',
      homePageWallpaperPath: '/tmp/wallpaper.png',
      wallpaperHistory: const [
        WallpaperHistoryEntry(key: '/tmp/wallpaper.png'),
        WallpaperHistoryEntry(key: '/tmp/wallpaper_2.png'),
      ],
      // 外观（主题 + 材质轴：材质是设备级的，归本作用域）
      appThemeMode: AppThemeMode.dark,
      appFontMode: AppFontMode.serif,
      appFontWeight: 700,
      appTextScale: 1.3,
      themeSeedColor: '#FF0000',
      frostedGlassMode: FrostedGlassMode.liquidGlass,
      frostedBlurEnabled: false,
      frostedSheetBlurSigma: 20,
      liquidGlassDockEnabled: false,
      liquidGlassPreset: LiquidGlassPreset.dense,
      progressiveBlurPreset: ProgressiveBlurPreset.dense,
      homePageTimeColumnBlurEnabled: true,
      // 液态玻璃的浅/深成对（2026-09-21）：非默认值，否则下面的断言是白过的。
      liquidGlassTuning: LiquidGlassTuning.presetDense,
      liquidGlassTuningDark: LiquidGlassTuning.presetClear,
      linkLiquidGlassTuning: false,
      darkGlassBoostEnabled: false,
      // 首页与导航（自外观页拆出的独立恢复作用域）
      homeNavigationForm: HomeNavigationForm.glassDock,
      homeTitleStyle: HomeTitleStyle.brand,
      homeMenuStyle: HomeMenuStyle.grid,
      homeGridMenuActions: const ['exams', 'weather'],
      glassDockActions: const ['week', 'settings', 'statistics'],
      glassDockShowAddButton: true,
      glassDockButtonEntryId: 'exams',
      glassDockButtonIconName: 'star',
      // 小组件
      widgetShowLocation: false,
      widgetShowCountdown: false,
      widgetCourseAccentMode: WidgetCourseAccentMode.off,
      // 不属于任何恢复作用域的东西
      semesterWeekCount: 24,
      liveEnableLocalDiagnostics: true,
      liveTimeCorrectionSeconds: 7,
      appLocaleTag: 'ja',
      enableHaptics: false,
      activeTimeSchemeId: 'scheme-42',
    );
  }

  /// 无论重置哪一页，这些都不该被碰。
  void expectUntouchedEssentials(TimetableSettings result) {
    final dirty = dirtySettings();
    expect(result.semesterWeekCount, dirty.semesterWeekCount);
    expect(result.liveEnableLocalDiagnostics, dirty.liveEnableLocalDiagnostics);
    expect(result.liveTimeCorrectionSeconds, dirty.liveTimeCorrectionSeconds);
    expect(result.appLocaleTag, dirty.appLocaleTag);
    expect(result.enableHaptics, dirty.enableHaptics);
    expect(result.activeTimeSchemeId, dirty.activeTimeSchemeId);
    expect(result.sections, dirty.sections);
  }

  test('课程卡片恢复默认只重置课卡字段', () {
    final defaults = TimetableSettings.defaults();
    final result = applySettingsReset(
      dirtySettings(),
      SettingsResetScope.courseCard,
    );

    expect(result.courseCardShowTeacher, defaults.courseCardShowTeacher);
    expect(result.courseCardShowTime, defaults.courseCardShowTime);
    expect(result.courseCardFontSize, defaults.courseCardFontSize);
    expect(result.compactFontSize, defaults.compactFontSize);
    expect(
      result.timetableUseUnifiedCardColor,
      defaults.timetableUseUnifiedCardColor,
    );
    expect(
      result.timetableUnifiedCardColor,
      defaults.timetableUnifiedCardColor,
    );
    expect(
      result.timetableConflictCourseOpacity,
      defaults.timetableConflictCourseOpacity,
    );
    expect(
      result.showConflictBadgeOnTimetable,
      defaults.showConflictBadgeOnTimetable,
    );
    expect(
      result.courseCardTitleColorLight,
      defaults.courseCardTitleColorLight,
    );

    // 课表页面与外观的字段保持「脏」值。
    final dirty = dirtySettings();
    expect(
      result.timetableShowNonCurrentWeekCourses,
      dirty.timetableShowNonCurrentWeekCourses,
    );
    expect(result.sectionHeight, dirty.sectionHeight);
    expect(
      result.screenshotSharePromptEnabled,
      dirty.screenshotSharePromptEnabled,
      reason: '截屏分享开关属于课表页面页，课卡作用域不许碰它',
    );
    expect(
      result.timetablePageBackgroundColor,
      dirty.timetablePageBackgroundColor,
    );
    expect(result.appThemeMode, dirty.appThemeMode);
    expect(result.widgetShowLocation, dirty.widgetShowLocation);
    expect(
      result.courseCardSurfaceStyle,
      dirty.courseCardSurfaceStyle,
      reason: '卡片材质那一档属于「外观」作用域，课卡页不许碰它',
    );
    // 其他页的恢复默认不许碰壁纸历史。
    expect(result.wallpaperHistory, dirty.wallpaperHistory);
    expectUntouchedEssentials(result);
  });

  test('课表页面恢复默认只重置页面字段并清掉壁纸', () {
    final defaults = TimetableSettings.defaults();
    final result = applySettingsReset(
      dirtySettings(),
      SettingsResetScope.timetablePage,
    );

    expect(result.sectionHeight, defaults.sectionHeight);
    expect(result.timetableHideWeekends, defaults.timetableHideWeekends);
    expect(
      result.timetableShowNonCurrentWeekCourses,
      defaults.timetableShowNonCurrentWeekCourses,
    );
    expect(result.timetableCourseCardGap, defaults.timetableCourseCardGap);
    expect(
      result.screenshotSharePromptEnabled,
      defaults.screenshotSharePromptEnabled,
    );
    expect(
      result.timetablePageBackgroundColor,
      defaults.timetablePageBackgroundColor,
    );
    expect(result.homePageBackgroundScope, defaults.homePageBackgroundScope);
    expect(result.weekdayBarFontColorLight, defaults.weekdayBarFontColorLight);
    // 壁纸文件路径必须一并清掉，否则「恢复默认」后背景还在。
    expect(result.homePageWallpaperPath, isNull);
    expect(result.homePageBackgroundImagePath, isNull);
    // 「最近使用」是设备级**全局**历史（所有课表共用），settings 里这份只是备份 /
    // 云同步用的镜像：恢复默认只清当前课表的壁纸指针，不碰这条历史。
    expect(result.wallpaperHistory, dirtySettings().wallpaperHistory);

    final dirty = dirtySettings();
    expect(result.courseCardFontSize, dirty.courseCardFontSize);
    expect(result.appThemeMode, dirty.appThemeMode);
    // ⚠️ 材质轴 2026-09-22 起**不归本页**：它是设备级设置（所有课表共用一份，
    // 真源见 `AppGlobalSettingsService`），本页点恢复默认不该改掉别的课表也在用的
    // 那套材质。控件也一直不在本页（在「外观编辑」的材质面板里）。
    expect(result.subpageHeaderBlurStyle, dirty.subpageHeaderBlurStyle);
    expect(result.homeBandGlassMaterial, dirty.homeBandGlassMaterial);
    expect(result.frostedGlassMode, dirty.frostedGlassMode);
    expect(result.frostedBlurEnabled, dirty.frostedBlurEnabled);
    expect(result.frostedSheetBlurSigma, dirty.frostedSheetBlurSigma);
    expect(result.liquidGlassDockEnabled, dirty.liquidGlassDockEnabled);
    expect(result.liquidGlassTuning, dirty.liquidGlassTuning);
    expect(result.liquidGlassTuningDark, dirty.liquidGlassTuningDark);
    expect(result.linkLiquidGlassTuning, dirty.linkLiquidGlassTuning);
    expect(result.darkGlassBoostEnabled, dirty.darkGlassBoostEnabled);
    expect(result.progressiveBlurTuning, dirty.progressiveBlurTuning);
    expect(result.courseCardSurfaceStyle, dirty.courseCardSurfaceStyle);
    expectUntouchedEssentials(result);
  });

  test('外观恢复默认重置应用级外观与整个材质轴', () {
    final defaults = TimetableSettings.defaults();
    final result = applySettingsReset(
      dirtySettings(),
      SettingsResetScope.appearance,
    );

    expect(result.appThemeMode, defaults.appThemeMode);
    expect(result.appFontMode, defaults.appFontMode);
    expect(result.appFontWeight, defaults.appFontWeight);
    expect(result.appTextScale, defaults.appTextScale);
    expect(result.themeSeedColor, defaults.themeSeedColor);

    // 材质轴 2026-09-22 起归本作用域（控件在「外观编辑」的材质面板里，本页是它的
    // 入口；且材质是设备级设置，得有个能回到出厂的口子）。
    expect(result.frostedGlassMode, defaults.frostedGlassMode);
    expect(result.frostedBlurEnabled, defaults.frostedBlurEnabled);
    expect(result.frostedSheetBlurSigma, defaults.frostedSheetBlurSigma);
    expect(result.liquidGlassDockEnabled, defaults.liquidGlassDockEnabled);
    expect(result.liquidGlassPreset, defaults.liquidGlassPreset);
    expect(result.progressiveBlurPreset, defaults.progressiveBlurPreset);
    expect(
      result.homePageTimeColumnBlurEnabled,
      defaults.homePageTimeColumnBlurEnabled,
    );
    expect(result.courseCardSurfaceStyle, defaults.courseCardSurfaceStyle);
    expect(result.subpageHeaderBlurStyle, defaults.subpageHeaderBlurStyle);
    expect(result.homeBandGlassMaterial, defaults.homeBandGlassMaterial);
    // 浅/深成对：可空字段，恢复默认必须真的清掉（靠 clear 标记而非传 null）。
    expect(result.liquidGlassTuning, defaults.liquidGlassTuning);
    expect(result.liquidGlassTuningDark, defaults.liquidGlassTuningDark);
    expect(result.linkLiquidGlassTuning, defaults.linkLiquidGlassTuning);
    expect(result.darkGlassBoostEnabled, defaults.darkGlassBoostEnabled);
    expect(result.progressiveBlurTuning, defaults.progressiveBlurTuning);

    // 首页与导航的字段保持「脏」值：导航形态已拆到独立 scope。
    final dirty = dirtySettings();
    expect(result.courseCardFontSize, dirty.courseCardFontSize);
    expect(result.sectionHeight, dirty.sectionHeight);
    expect(result.widgetShowCountdown, dirty.widgetShowCountdown);
    expect(result.homeNavigationForm, dirty.homeNavigationForm);
    expect(result.homeTitleStyle, dirty.homeTitleStyle);
    // 课表页面自己的字段也不许被本页连带重置。
    expect(result.weekdayBarFontColorLight, dirty.weekdayBarFontColorLight);
    expect(
      result.timetablePageBackgroundColor,
      dirty.timetablePageBackgroundColor,
    );
    expect(result.homePageWallpaperPath, dirty.homePageWallpaperPath);
    expectUntouchedEssentials(result);
  });

  test('首页与导航恢复默认只重置导航字段', () {
    final defaults = TimetableSettings.defaults();
    final result = applySettingsReset(
      dirtySettings(),
      SettingsResetScope.homeNavigation,
    );

    expect(result.homeNavigationForm, defaults.homeNavigationForm);
    expect(result.glassDockActions, defaults.glassDockActions);
    expect(result.glassDockShowAddButton, defaults.glassDockShowAddButton);
    expect(result.glassDockButtonEntryId, defaults.glassDockButtonEntryId);
    expect(result.glassDockButtonIconName, defaults.glassDockButtonIconName);
    expect(result.homeTitleStyle, defaults.homeTitleStyle);

    // 外观字段不被导航页连带重置。
    final dirty = dirtySettings();
    expect(
      result.homeMenuStyle,
      dirty.homeMenuStyle,
      reason: '菜单形态故意不在本作用域（见 applySettingsReset 的注释）',
    );
    expect(
      result.homeGridMenuActions,
      dirty.homeGridMenuActions,
      reason: '菜单内容同上：纳入会得到只有一格的菜单',
    );
    expect(result.appThemeMode, dirty.appThemeMode);
    expect(result.appFontWeight, dirty.appFontWeight);
    expect(result.appTextScale, dirty.appTextScale);
    expect(result.themeSeedColor, dirty.themeSeedColor);
    expect(result.frostedSheetBlurSigma, dirty.frostedSheetBlurSigma);
    expect(result.courseCardFontSize, dirty.courseCardFontSize);
    expectUntouchedEssentials(result);
  });

  test('桌面小组件恢复默认只重置小组件字段', () {
    final defaults = TimetableSettings.defaults();
    final result = applySettingsReset(
      dirtySettings(),
      SettingsResetScope.homeWidget,
    );

    expect(result.widgetShowLocation, defaults.widgetShowLocation);
    expect(result.widgetShowCountdown, defaults.widgetShowCountdown);
    expect(result.widgetCourseAccentMode, defaults.widgetCourseAccentMode);

    final dirty = dirtySettings();
    expect(result.courseCardFontSize, dirty.courseCardFontSize);
    expect(result.sectionHeight, dirty.sectionHeight);
    expect(result.appThemeMode, dirty.appThemeMode);
    expect(result.homeNavigationForm, dirty.homeNavigationForm);
    expectUntouchedEssentials(result);
  });
}
