part of '../timetable_provider.dart';

/// 某份设置「应该看到」的节次表：活动作息模板才是节次与钟点的真源。
///
/// 原先是 `TimetableProvider._normalizeSettingsWithTimeScheme`（父文件 :1062-1078）。
/// 第 27 轮把它移到本分片：设置写入口要补落盘失败回滚，而父文件的行数棘轮只减不增
/// （`test/architecture/dependency_guards_test.dart` 的注释就是这条规矩的出处 ——
/// 正当做法不是抬基线，而是把规则放回它该在的分片）。
TimetableSettings _normalizeSettingsWithTimeScheme(
  TimetableProvider host,
  TimetableSettings settings,
) {
  final scheme = host._getTimeSchemeById(settings.activeTimeSchemeId);
  if (scheme == null) {
    return settings;
  }
  final hasSameSections =
      host._sectionSignature(settings.sections) ==
      host._sectionSignature(scheme.sections);
  if (hasSameSections) {
    return settings;
  }
  return settings.copyWith(
    sections: List<SectionTime>.from(scheme.sections),
    activeTimeSchemeId: scheme.id,
  );
}

/// 设置写入口的内存快照：落盘失败要退回的就是这两份。
class _SettingsWriteSnapshot {
  final TimetableSettings settings;
  final List<TimetableProfile> profiles;

  _SettingsWriteSnapshot(TimetableProvider host)
    : settings = host._settings,
      profiles = List<TimetableProfile>.from(host._profiles);
}

/// 落盘失败时把设置写入口退回原样（调用方负责 `notifyListeners()` 与上抛）。
///
/// 为什么连 `_profiles` 也要退：`_persistActiveProfileState` 的第一步就是
/// `_mergeActiveProfileIntoProfilesList`（父文件 :718-738，`settings: _settings`），
/// 它在任何磁盘写入**之前**就把新设置并进了课表列表。只退 `_settings` 的话，
/// 下一次任意成功写入会把这份从未落库的改动当成既有状态落盘 —— 用户视角是
/// 「那次失败之后，我根本没改过的设置自己生效了」。
///
/// 契约同 `updateTimetableSettings` 的 catch（父文件 :3847-3867）与主题族共用的
/// `_applySavedThemes`（:350-360）；回归钉 `test/providers/settings_write_rollback_test.dart`。
void _rollbackSettingsWrite(
  TimetableProvider host,
  _SettingsWriteSnapshot snapshot,
) {
  host._settings = snapshot.settings;
  host._profiles = snapshot.profiles;
  hyperosSetEdgeHapticsEnabled(snapshot.settings.enableHaptics);
}
