import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
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
      // 课表页面
      timetableShowNonCurrentWeekCourses: true,
      sectionHeight: 90,
      timetableHideWeekends: true,
      screenshotSharePromptEnabled: false,
      timetableCourseCardGap: 3,
      timetablePageBackgroundColor: '#ABCDEF',
      homePageBackgroundScope: 15,
      homePageHeaderBlurEnabled: true,
      subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
      homeBandGlassMaterial: 'liquid',
      weekdayBarFontColorLight: '#222222',
      homePageWallpaperPath: '/tmp/wallpaper.png',
      wallpaperHistory: const [
        WallpaperHistoryEntry(key: '/tmp/wallpaper.png'),
        WallpaperHistoryEntry(key: '/tmp/wallpaper_2.png'),
      ],
      // 外观
      appThemeMode: AppThemeMode.dark,
      appFontMode: AppFontMode.serif,
      appFontWeight: 700,
      appTextScale: 1.3,
      themeSeedColor: '#FF0000',
      frostedBlurEnabled: false,
      frostedSheetBlurSigma: 20,
      liquidGlassDockEnabled: false,
      // 液态玻璃的浅/深成对（2026-09-21）：非默认值，否则下面的断言是白过的。
      liquidGlassTuning: LiquidGlassTuning.presetDense,
      liquidGlassTuningDark: LiquidGlassTuning.presetClear,
      linkLiquidGlassTuning: false,
      darkGlassBoostEnabled: false,
      // 首页与导航（自外观页拆出的独立恢复作用域）
      homeNavigationForm: HomeNavigationForm.glassDock,
      homeTitleStyle: HomeTitleStyle.brand,
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
    expect(
      result.homePageHeaderBlurEnabled,
      defaults.homePageHeaderBlurEnabled,
    );
    expect(result.subpageHeaderBlurStyle, defaults.subpageHeaderBlurStyle);
    expect(result.homeBandGlassMaterial, defaults.homeBandGlassMaterial);
    // 材质轴（玻璃模式 / 模糊总开关 / 磨砂滑杆 / 底栏作用范围）：控件在本页的
    // 「玻璃 / 材质」区块里，恢复默认跟着本页一起走。
    expect(result.frostedGlassMode, defaults.frostedGlassMode);
    expect(result.frostedBlurEnabled, defaults.frostedBlurEnabled);
    expect(result.frostedSheetBlurSigma, defaults.frostedSheetBlurSigma);
    expect(result.liquidGlassDockEnabled, defaults.liquidGlassDockEnabled);
    // 浅/深成对：三个新字段也必须跟着本页回默认，否则「恢复默认」会留下一套
    // 用户以为已经清掉的深色档与开关。
    expect(result.liquidGlassTuning, defaults.liquidGlassTuning);
    expect(result.liquidGlassTuningDark, defaults.liquidGlassTuningDark);
    expect(result.linkLiquidGlassTuning, defaults.linkLiquidGlassTuning);
    expect(result.darkGlassBoostEnabled, defaults.darkGlassBoostEnabled);
    // 柔光 / 渐进的 tuning 与液态同类：可空字段，恢复默认必须真的清掉。
    expect(result.softGlassTuning, defaults.softGlassTuning);
    expect(result.progressiveBlurTuning, defaults.progressiveBlurTuning);
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
    expectUntouchedEssentials(result);
  });

  test('外观恢复默认只重置应用级外观', () {
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
    // 材质轴不再由本 scope 恢复：控件 2026-09-19 搬到「课表页面」，
    // 「恢复默认只覆盖本页看得见的控件」这条规矩跟着走（见下面那条用例）。
    expect(result.frostedBlurEnabled, dirtySettings().frostedBlurEnabled);
    expect(result.frostedSheetBlurSigma, dirtySettings().frostedSheetBlurSigma);
    expect(result.liquidGlassDockEnabled, isFalse);

    // 首页与导航的字段保持「脏」值：导航形态已拆到独立 scope。
    final dirty = dirtySettings();
    expect(result.courseCardFontSize, dirty.courseCardFontSize);
    expect(result.sectionHeight, dirty.sectionHeight);
    expect(result.widgetShowCountdown, dirty.widgetShowCountdown);
    expect(result.homeNavigationForm, dirty.homeNavigationForm);
    expect(result.homeTitleStyle, dirty.homeTitleStyle);
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
