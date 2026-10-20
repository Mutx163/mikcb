import '../domain/time_scheme_logic.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';

/// 设置写入口需要的最小宿主面：内存里的设置 / 课表列表、活动作息表，
/// 以及落盘 / 通知 / 埋点 / 触感这四个副作用钩子。
///
/// `TimetableProvider` 的成员都是现成的（getter 已有、私有钩子各包一层），
/// 所以适配成本只有十几行；服务本身不 import provider，可用假端口单测。
abstract interface class TimetableSettingsWritePort {
  TimetableSettings get settings;
  set settings(TimetableSettings value);

  List<TimetableProfile> get profiles;
  set profiles(List<TimetableProfile> value);

  List<TimeScheme> get timeSchemes;

  /// 把当前设置与活动课表落盘；失败时抛错，由本服务回滚。
  Future<void> persistActiveProfileState();

  void notifyStateChanged();

  /// 设置真的落盘之后把旧值交给性能埋点（宿主 `_logPerformanceSnapshotIfChanged`）。
  void logPerformanceSnapshotIfChanged(TimetableSettings previous);

  /// 边缘触感跟随设置开关（只在宿主侧存在 UI 依赖，服务不 import ui/）。
  void applyEdgeHaptics(bool enabled);
}

/// 设置写入口的内存快照：落盘失败要退回的就是这两份。
class TimetableSettingsWriteSnapshot {
  const TimetableSettingsWriteSnapshot({
    required this.settings,
    required this.profiles,
  });

  final TimetableSettings settings;
  final List<TimetableProfile> profiles;
}

/// 一次「改设置 → 落盘 → 失败回滚」的完整协议 —— **只有这一份定义**。
///
/// 2026-10-20 从 `providers/timetable/settings_repository.dart`（原分片，56 行）
/// 与 `TimetableProvider.updateSettings` / `_TimetableThemePort.replaceSavedThemes`
/// 两处手写协议合并而来（K3）。行为逐字保持：
///
/// - 写入口先取快照，再改内存、落盘；失败时退回 `settings` 与 `profiles` 两份
///   （只退设置不够：`_persistActiveProfileState` 第一步就把新设置并进课表列表，
///   下一次成功写入会把从未落库的改动当成既有状态落盘 —— 用户视角是
///   「那次失败之后，我根本没改过的设置自己生效了」）。
/// - 写入本身**必须由宿主的写盘串行门包住**（`update` 不自己取门：门在宿主，
///   主题服务与本入口共用同一道门，这里再包一层会改变重入语义）。
/// - 主题列表写入（`replaceSavedThemes`）共用快照/回滚，但不归一节次、不埋点。
///
/// 回归钉：`test/providers/settings_write_rollback_test.dart`。
class TimetableSettingsWriter {
  const TimetableSettingsWriter._();

  static TimetableSettingsWriteSnapshot snapshot(TimetableSettingsWritePort port) {
    return TimetableSettingsWriteSnapshot(
      settings: port.settings,
      profiles: List<TimetableProfile>.from(port.profiles),
    );
  }

  /// 某份设置「应该看到」的节次表：活动作息模板才是节次与钟点的真源。
  static TimetableSettings normalize(
    TimetableSettingsWritePort port,
    TimetableSettings settings,
  ) {
    final scheme = TimeSchemeLogic.getSchemeById(
      port.timeSchemes,
      settings.activeTimeSchemeId,
    );
    if (scheme == null) {
      return settings;
    }
    if (TimeSchemeLogic.sectionsSignature(settings.sections) ==
        TimeSchemeLogic.sectionsSignature(scheme.sections)) {
      return settings;
    }
    return settings.copyWith(
      sections: List<SectionTime>.from(scheme.sections),
      activeTimeSchemeId: scheme.id,
    );
  }

  /// 落盘失败时把设置写入口退回原样（调用方负责通知与上抛）。
  static void rollback(
    TimetableSettingsWritePort port,
    TimetableSettingsWriteSnapshot snapshot,
  ) {
    port.settings = snapshot.settings;
    port.profiles = snapshot.profiles;
    port.applyEdgeHaptics(snapshot.settings.enableHaptics);
  }

  /// 批量更新设置（主题导入、上课提醒开关、天气与统计设置、撤销主题变更、
  /// 传输层写入）：快照 → 归一节次 → 落盘；失败回滚并刷新后上抛，成功刷新并埋点。
  static Future<void> update(
    TimetableSettingsWritePort port,
    TimetableSettings newSettings,
  ) async {
    final previous = snapshot(port);
    port.settings = normalize(port, newSettings);
    port.applyEdgeHaptics(port.settings.enableHaptics);
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      rollback(port, previous);
      port.notifyStateChanged();
      rethrow;
    }
    port.notifyStateChanged();
    port.logPerformanceSnapshotIfChanged(previous.settings);
  }

  /// 主题列表写入：与 [update] 共用快照/回滚，但不归一节次、不埋点。
  static Future<void> replaceSavedThemes(
    TimetableSettingsWritePort port,
    List<SavedTheme> Function(TimetableSettings settings) build,
  ) async {
    final previous = snapshot(port);
    port.settings = port.settings.copyWith(savedThemes: build(port.settings));
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      rollback(port, previous);
      rethrow;
    }
    port.notifyStateChanged();
  }
}
