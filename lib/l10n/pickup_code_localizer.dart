import '../models/campus_tool_entry.dart';
import 'app_localizations.dart';

/// 预设入口标题的本地化。
///
/// 为什么放在这一层而不是模型里：模型是纯数据（还要能进 `lib/domain` 的单测），
/// 一旦 import `AppLocalizations` 就把 l10n 的生成文件绑进数据层。本仓的
/// `holiday_name_localizer.dart` / `enum_localizations.dart` 已经是这个位置，
/// 新东西按同一处放。
///
/// 预设 id 与 `domain/campus_tool_presets.dart` 的条目 id 逐字一致；未知 id
/// 返回空串，由 [campusToolEntryTitle] 回落成「未命名入口」。
String campusToolPresetTitle(AppLocalizations l10n, String presetId) {
  return switch (presetId) {
    'campusToolsPresetCainiao' => l10n.campusToolsPresetCainiao,
    'campusToolsPresetTaobao' => l10n.campusToolsPresetTaobao,
    'campusToolsPresetTaobaoParcels' => l10n.campusToolsPresetTaobaoParcels,
    'campusToolsPresetPinduoduo' => l10n.campusToolsPresetPinduoduo,
    'campusToolsPresetPinduoduoParcels' =>
      l10n.campusToolsPresetPinduoduoParcels,
    'campusToolsPresetJdParcels' => l10n.campusToolsPresetJdParcels,
    'campusToolsPresetDouyinParcels' => l10n.campusToolsPresetDouyinParcels,
    _ => '',
  };
}

/// 一条入口的显示名：预设走 l10n；未知 id（预置表改了 id 却没补 l10n 键）
/// 回落成「未命名入口」，让缺失在界面上可见、也被测试抓到。
String campusToolEntryTitle(AppLocalizations l10n, CampusToolEntry entry) {
  final preset = campusToolPresetTitle(l10n, entry.id);
  if (preset.isNotEmpty) {
    return preset;
  }
  return l10n.campusToolsUntitledEntry;
}
