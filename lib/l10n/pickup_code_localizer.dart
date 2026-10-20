import '../models/pickup_code_entry.dart';
import 'app_localizations.dart';

/// 预设入口标题的本地化。
///
/// 为什么放在这一层而不是模型里：模型是纯数据（还要能进 `lib/domain` 的单测），
/// 一旦 import `AppLocalizations` 就把 l10n 的生成文件绑进数据层。本仓的
/// `holiday_name_localizer.dart` / `enum_localizations.dart` 已经是这个位置，
/// 新东西按同一处放。
///
/// 预设 id 与 `domain/pickup_code_presets.dart` 的条目 id 逐字一致；未知 id
/// 返回空串，由 [pickupCodeEntryTitle] 回落成「未命名入口」。
String pickupCodePresetTitle(AppLocalizations l10n, String presetId) {
  return switch (presetId) {
    'pickupCodePresetCainiao' => l10n.pickupCodePresetCainiao,
    'pickupCodePresetTaobao' => l10n.pickupCodePresetTaobao,
    'pickupCodePresetTaobaoParcels' => l10n.pickupCodePresetTaobaoParcels,
    'pickupCodePresetPinduoduo' => l10n.pickupCodePresetPinduoduo,
    'pickupCodePresetPinduoduoParcels' =>
      l10n.pickupCodePresetPinduoduoParcels,
    'pickupCodePresetJdParcels' => l10n.pickupCodePresetJdParcels,
    'pickupCodePresetDouyinParcels' => l10n.pickupCodePresetDouyinParcels,
    _ => '',
  };
}

/// 一条入口的显示名：预设走 l10n；未知 id（预置表改了 id 却没补 l10n 键）
/// 回落成「未命名入口」，让缺失在界面上可见、也被测试抓到。
String pickupCodeEntryTitle(AppLocalizations l10n, PickupCodeEntry entry) {
  final preset = pickupCodePresetTitle(l10n, entry.id);
  if (preset.isNotEmpty) {
    return preset;
  }
  return l10n.pickupCodeUntitledEntry;
}

/// 砖上的说明行：跳过去具体到哪（驿站自提 / 某平台的包裹列表）。
///
/// 与 [pickupCodeEntryTitle] 同一条口径：预置表里填的是 l10n 键名，这里反查；
/// 未知键返回空串，界面据此不渲染说明行（而不是显示一个空 Text 占位）。
String pickupCodeEntryHint(AppLocalizations l10n, PickupCodeEntry entry) {
  final hintKey = entry.hint;
  if (hintKey == null || hintKey.isEmpty) {
    return '';
  }
  return switch (hintKey) {
    'pickupCodePresetCainiaoHint' => l10n.pickupCodePresetCainiaoHint,
    'pickupCodePresetTaobaoHint' => l10n.pickupCodePresetTaobaoHint,
    'pickupCodePresetPinduoduoHint' => l10n.pickupCodePresetPinduoduoHint,
    'pickupCodePresetTaobaoParcelsHint' =>
      l10n.pickupCodePresetTaobaoParcelsHint,
    'pickupCodePresetPinduoduoParcelsHint' =>
      l10n.pickupCodePresetPinduoduoParcelsHint,
    'pickupCodePresetJdParcelsHint' => l10n.pickupCodePresetJdParcelsHint,
    'pickupCodePresetDouyinParcelsHint' =>
      l10n.pickupCodePresetDouyinParcelsHint,
    _ => '',
  };
}
