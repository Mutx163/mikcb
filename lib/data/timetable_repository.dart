import '../models/timetable_profile.dart';
import '../services/storage_service.dart';

/// Profile 持久化仓储 —— 解耦阶段 2 的收口缝（OPTIMIZATION.md §4 阶段 2）。
///
/// 本刀刻意保持行为 1:1：底层仍是 [StorageService] 的单 key 全量覆写 +
/// 串行写链。引入它的目的是把「何时写 / 写什么」从 `TimetableProvider`
/// 中剥离出来：后续的分片存储、脏标记批量提交（`markDirty` → 事件循环
/// 末尾 flush）只改本类内部实现，47 个调用方无感。
class TimetableRepository {
  TimetableRepository(this._storage);

  final StorageService _storage;

  /// 当前存储布局版本。v1 = `timetable_profiles` 单 key 全量 JSON 数组，
  /// 与历史格式完全一致。版本号记录在独立 key（见
  /// [StorageService.getProfilesSchemaVersion]），布局演进（分片 / 信封）
  /// 时递增并以它为迁移闸。
  static const int storageSchemaVersion = 1;

  int _stampedVersion = 0;

  Future<List<TimetableProfile>> loadProfiles() => _storage.getProfiles();

  Future<String?> getActiveProfileId() => _storage.getActiveProfileId();

  Future<void> setActiveProfileId(String profileId) =>
      _storage.setActiveProfileId(profileId);

  /// 全量保存所有 profile，并确保版本号 key 已落盘。
  ///
  /// 版本号只在值变化时写入，避免每次保存的额外 prefs 写放大。
  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    await _storage.saveProfiles(profiles);
    if (_stampedVersion != storageSchemaVersion) {
      await _storage.setProfilesSchemaVersion(storageSchemaVersion);
      _stampedVersion = storageSchemaVersion;
    }
  }
}
