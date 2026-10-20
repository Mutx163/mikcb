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
/// （用户自建项）返回空串，由 [campusToolEntryTitle] 回落用户填的标题。
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

/// 一条入口最终显示的名字：
/// 1. 用户改过名 → 用用户的名字；
/// 2. 否则如果是预设 → 用当前语言的预设名；
/// 3. 都不是（自建项却没填名字的坏数据）→ 「未命名入口」。
String campusToolEntryTitle(AppLocalizations l10n, CampusToolEntry entry) {
  final custom = entry.title.trim();
  if (custom.isNotEmpty) {
    return custom;
  }
  final preset = campusToolPresetTitle(l10n, entry.id);
  if (preset.isNotEmpty) {
    return preset;
  }
  return l10n.campusToolsUntitledEntry;
}
