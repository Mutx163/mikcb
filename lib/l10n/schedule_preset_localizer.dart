import '../domain/schedule_quick_presets.dart';
import 'app_localizations.dart';

/// 快捷日程模板的标题文案。
///
/// 与 `pickup_code_localizer.dart` 同一处分层：模板表在 `lib/domain` 只有
/// id / 图标名 / 颜色 / 时长（纯数据，能无 UI 单测），文案要跟着语言走，
/// 所以「id → 人话」留在 l10n 层。
///
/// 未知 id 返回空串：界面据此**不渲染**这颗模板（而不是显示一个空标题的
/// 色块），同时 `test/l10n/schedule_preset_localizer_test.dart` 会把
/// 「数据表加了条目却漏配文案」当面报出来。
String scheduleQuickPresetTitle(AppLocalizations l10n, String presetId) {
  return switch (presetId) {
    'groupMeeting' => l10n.scheduleQuickPresetGroupMeeting,
    'lecture' => l10n.scheduleQuickPresetLecture,
    'meeting' => l10n.scheduleQuickPresetMeeting,
    'defense' => l10n.scheduleQuickPresetDefense,
    'interview' => l10n.scheduleQuickPresetInterview,
    'dining' => l10n.scheduleQuickPresetDining,
    'workout' => l10n.scheduleQuickPresetWorkout,
    'study' => l10n.scheduleQuickPresetStudy,
    'clinic' => l10n.scheduleQuickPresetClinic,
    'commute' => l10n.scheduleQuickPresetCommute,
    _ => '',
  };
}

/// 模板卡上的时长说明：`1 小时` / `30 分钟` / `1 小时 30 分钟`。
///
/// 为什么不复用 `scheduleReminderMinutes` 那个「提前 {minutes} 分钟」：
/// 那是提醒语义，且 90 分钟会读成「提前 90 分钟」而不是「一个半小时」。
/// 也不走 `Duration.toString()` —— 它给 `1:30:00.000000`，不是给人看的。
String scheduleQuickPresetDurationLabel(
  AppLocalizations l10n,
  int durationMinutes,
) {
  if (durationMinutes <= 0) {
    return '';
  }
  final hours = durationMinutes ~/ 60;
  final minutes = durationMinutes % 60;
  if (hours == 0) {
    return l10n.scheduleQuickPresetMinutesOnly(minutes);
  }
  if (minutes == 0) {
    return l10n.scheduleQuickPresetHoursOnly(hours);
  }
  return l10n.scheduleQuickPresetHoursMinutes(hours, minutes);
}

/// 一条模板的完整显示文案；未知 id 返回 null（见 [scheduleQuickPresetTitle]）。
String? scheduleQuickPresetLabel(
  AppLocalizations l10n,
  ScheduleQuickPreset preset,
) {
  final title = scheduleQuickPresetTitle(l10n, preset.id);
  if (title.isEmpty) {
    return null;
  }
  return title;
}

/// 套用的模板**此刻是否仍然成立**：套用过、且标题没被用户改掉。
///
/// 只看「套用过哪个 id」不够——用户套了「组会」再把标题改成「和导师讨论课题」，
/// 那颗卡若还显示选中就是在骗人：卡片说「你选的是组会」，标题却是别的内容。
///
/// 判据取**标题正文**而不是「之后有没有编辑过」的标记位：把文本改回模板标题
/// （撤销输入、误删后又补回）时，选中态应当自己回来。
///
/// 抽成纯函数而不是留在页面里的私有 getter，是为了让它能脱离 widget 树验证
/// ——`test/l10n` 是允许新增测试的位置，`test/screens` 已冻结。
String? scheduleQuickPresetActiveId(
  AppLocalizations l10n, {
  required String? appliedId,
  required String currentTitle,
}) {
  if (appliedId == null) {
    return null;
  }
  final title = scheduleQuickPresetTitle(l10n, appliedId);
  if (title.isEmpty) {
    return null;
  }
  return currentTitle.trim() == title ? appliedId : null;
}
