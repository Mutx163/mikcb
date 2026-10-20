import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../services/app_sync_snapshot_service.dart';
import 'timetable_provider.dart';

/// [AppSyncTimetablePort] 的宿主适配器：把 [TimetableProvider] 的公开面以窄
/// 端口交给云同步快照管线（`lib/services/app_sync_snapshot_service.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由组合根
/// （`main.dart` 的 `bindProvider`）与测试构造注入。
///
/// **刻意不 implements `UnifiedTransferPort`**：快照服务自己只要 12 个成员，
/// 而统一传输要 34 个。让它白继承那 24 个用不到的成员，正是 honest-scope
/// 笔记点名的「端口虚胖」病。所以转手给统一传输时走**独立参数**
/// `transferPort`，由组合根一并注入（同一个 provider 装配成两个镜头）。
///
/// 成员一律**一行转发**，不改语义——尤其
/// [reloadFromStorageAfterExternalApply] 是**动作**（重跑加载、重建镜像、
/// 强制 resync），不是读快照；[scheduleDateRuleLastAppliedSignature] 是
/// 读写对，采集时读、应用时写回，必须落到同一份 provider 状态。
class AppSyncTimetableViewAccess implements AppSyncTimetablePort {
  AppSyncTimetableViewAccess(this._provider);

  final TimetableProvider _provider;

  @override
  Future<void> initialize() => _provider.initialize();

  @override
  Future<T> runMutationExclusive<T>(Future<T> Function() action) =>
      _provider.runMutationExclusive(action);

  @override
  List<TimetableProfile> get profiles => _provider.profiles;

  @override
  String? get activeProfileId => _provider.activeProfileId;

  @override
  List<TimeScheme> get timeSchemes => _provider.timeSchemes;

  @override
  List<LocationTimeGroup> get locationTimeGroups =>
      _provider.locationTimeGroups;

  @override
  List<ScheduleDateRule> get scheduleDateRules => _provider.scheduleDateRules;

  @override
  String? get scheduleDateRuleLastAppliedSignature =>
      _provider.scheduleDateRuleLastAppliedSignature;

  @override
  set scheduleDateRuleLastAppliedSignature(String? value) =>
      _provider.scheduleDateRuleLastAppliedSignature = value;

  @override
  Future<String?> importFullAppDataBackup(String content) =>
      _provider.importFullAppDataBackup(content);

  @override
  Future<void> replaceLocationTimeGroups(
    List<LocationTimeGroup> groups, {
    bool resync = true,
  }) => _provider.replaceLocationTimeGroups(groups, resync: resync);

  @override
  Future<void> replaceScheduleDateRules(
    List<ScheduleDateRule> rules, {
    bool resync = true,
  }) => _provider.replaceScheduleDateRules(rules, resync: resync);

  @override
  Future<void> reloadFromStorageAfterExternalApply() =>
      _provider.reloadFromStorageAfterExternalApply();
}
