import 'dart:async';

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
  /// 与历史格式完全一致。版本号由 [StorageService] 的全部 profiles 写路径
  /// 自动盖章（幂等，比对盘上值），记录在独立 key；布局演进（分片 /
  /// 信封）时递增并以它为迁移闸。
  static const int storageSchemaVersion = StorageService.profilesSchemaVersion;

  Future<List<TimetableProfile>> loadProfiles() => _storage.getProfiles();

  Future<String?> getActiveProfileId() => _storage.getActiveProfileId();

  Future<void> setActiveProfileId(String profileId) =>
      _storage.setActiveProfileId(profileId);

  /// 在写链上原子地读改写 profiles 列表。
  ///
  /// Partner 导入 / 解绑等服务层流程经此入口变更 profiles；仓储因此成为
  /// 唯一写入口——后续脏标记批量提交 / 分片存储只需协调本类内部，避免
  /// 「provider 延迟 flush 撞上外部 RMW」的双写丢失。
  Future<List<TimetableProfile>> updateProfiles(
    FutureOr<List<TimetableProfile>> Function(List<TimetableProfile> current)
    transform,
  ) => _storage.updateProfiles(transform);

  /// 全量保存所有 profile。版本号由 [StorageService] 写路径自动盖章
  /// （幂等、比对盘上值），此处无需额外处理。
  Future<void> saveProfiles(List<TimetableProfile> profiles) =>
      _storage.saveProfiles(profiles);
}
