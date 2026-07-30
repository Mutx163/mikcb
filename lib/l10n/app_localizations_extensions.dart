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
}
