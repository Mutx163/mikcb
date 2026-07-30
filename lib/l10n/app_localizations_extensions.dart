/// Extensions that add missing frosted-glass/liquid-glass/localization
/// getters to [AppLocalizations] without modifying the generated ARB files.
///
/// Remove each getter once the corresponding entry exists in the ARB files.
library;

import 'app_localizations.dart';

extension FrostedGlassL10n on AppLocalizations {
  String get frostedGlassModeLabel => '玻璃模式';
  String get frostedGlassModeFrosted => '经典磨砂';
  String get frostedGlassModeLiquid => '液态玻璃';
  String get frostedGlassModeGaussian => '高斯模糊';
  String get frostedGlassModeTranslucent => '半透明';
  String get frostedSheetSectionTitle => '磨砂玻璃';
  String get frostedSheetBlurLabel => '模糊强度';
  String get frostedBlurEnabledTitle => '启用模糊';
  String get frostedSheetPreviewDemoTitle => '预览';
  String get frostedSheetPreviewDemoSubtitle => '磨砂玻璃效果实时预览';
  String get frostedSheetPreviewOpenAction => '打开预览面板';
  String get frostedLiquidGlassHint => '液态玻璃需要高性能设备支持';
  String get advancedMaterialTitle => '高级材质';
  String get advancedMaterialEntrySubtitle => '液态玻璃参数微调';
  String get liquidGlassPresetLabel => '液态玻璃预设';
  String get liquidGlassPresetClear => '清澈';
  String get liquidGlassPresetLight => '轻雾';
  String get liquidGlassPresetStandard => '标准';
  String get liquidGlassPresetDense => '浓密';
  String get liquidGlassPresetCustom => '自定义';
  String get courseCardSettingsTitle => '课程卡片';
  String get courseCardSectionFields => '显示字段';
  String get courseCardSectionLayout => '布局';
  String get courseCardSurfaceStyleLabel => '卡片外观';
  String get courseCardSurfaceStyleSubtitle => '选择课程卡片的视觉风格';
  String get courseCardSurfaceStyleSolid => '实心';
  String get courseCardSurfaceStyleTranslucent => '半透明';
  String get courseCardSurfaceStyleLiquidGlass => '液态玻璃';
  String get courseCardSurfaceStyleGaussian => '高斯模糊';
  String get courseCardSectionColor => '颜色';
  String get liveSelfCheckTitle => '自检';
  String get collapsibleLargeTitle => '折叠大标题';

  // Liquid glass parameter labels
  String get liquidGlassCustomExpandedTitle => '自定义参数';
  String get liquidGlassThicknessLabel => '厚度';
  String get liquidGlassBlurLabel => '模糊强度';
  String get liquidGlassTintLabel => '染色强度';
  String get liquidGlassLightIntensityLabel => '灯光强度';
  String get liquidGlassAmbientStrengthLabel => '环境光强度';
  String get liquidGlassRefractiveIndexLabel => '折射率';
  String get liquidGlassSaturationLabel => '饱和度';
  String get liquidGlassChromaticAberrationLabel => '色差';
  String get liquidGlassLightAngleLabel => '光照角度';
  String get liquidGlassVisibilityLabel => '可见性';
  String get liquidGlassResetAction => '恢复默认';

  // Settings page section / entry titles
  String get diagnosticsEntryTitle => '诊断';
  String get memoryStatsEntryTitle => '内存状态';
  String get generalSettingsTitle => '通用';
  String get settingsResetDefaultsTitle => '恢复默认设置';
  String get settingsResetDefaultsConfirmTitle => '确认恢复';
  String get settingsResetDefaultsConfirmBody => '将重置所有设置为出厂默认值。';
  String get settingsResetDoneMessage => '设置已重置';
  String get timetablePageSettingsTitle => '课表页面';
  String get timetablePageSectionDensity => '密度';
  String get timetablePageSectionBackToWeek => '回到当前周';
  String get timetablePageSectionBackground => '背景';
  String get largeTitleContentGap => '16.0';
  String get selectTimeTitle => '选择时间';
  String get liveSelfCheckSubtitle => '运行自检';
  String get frostedSheetPreviewShowTitle => '显示预览';
  String get frostedSheetPreviewShowSubtitle => '在顶部显示磨砂玻璃预览';
  String get aboutSupportUpdatesSectionTitle => '支持与更新';
  String get aboutProductSectionTitle => '产品';
  String get aboutCommunitySectionTitle => '社区';
  String get selectStartTimeTitle => '选择开始时间';
  String get selectEndTimeTitle => '选择结束时间';
  String get weekdayInkContrastTitle => '文字对比度增强';
  String get weekdayInkContrastBodyDark => '深色模式下增强课程文字对比度';
  String get weekdayInkContrastBodyLight => '浅色模式下增强课程文字对比度';
  String get keepCurrentColorAction => '保留当前颜色';
  String get settingsTimetableSectionTitle => '课表';
  String get liveIslandLabelEntryEnabled => '已启用';
  String get liveIslandLabelEntryDisabled => '已关闭';
  String get settingsDisplayAppearanceSectionTitle => '显示与外观';
  String get settingsReminderDesktopSectionTitle => '提醒与桌面';
  String get settingsAppSectionTitle => '应用';
  String get settingsDataShareSectionTitle => '数据与共享';
  String get coupleTimetableEntryUnboundLabel => '未绑定';
  String get settingsAboutSectionTitle => '关于';
  String get diagnosticsEntrySubtitle => '查看运行诊断日志';
  String get settingsSemesterScreenTitle => '学期设置';
  String get syncCurrentWeekNeedsStartDate => '请先设置开学日期';
  String get liveNotificationPermissionMissing => '缺少通知权限';
  String get developerSectionTitle => '开发者选项';
  String get liveTestingFixtureEntryTitle => '实况测试样例';
  String get hyperosShowcaseEntryTitle => 'HyperOS 组件展示';
  String get hyperosShowcaseEntrySubtitle => '自研 HyperOS 组件库预览';
  String get miuixShowcaseEntryTitle => 'Miuix 组件展示';
  String get miuixShowcaseEntrySubtitle => 'flutter_miuix 组件库预览';
  String get debugUiOverlayToggleTitle => '调试 UI 叠层';
}
