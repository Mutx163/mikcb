import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/data/timetable_repository.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/unified_transfer_access.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/holiday_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/sync_rollback_snapshot_store.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';
import 'package:university_timetable/services/warehouse_macro_service.dart';

/// 回滚点**终态**的验收测试（2026-11）。
///
/// ## 修的是什么
///
/// 回滚快照此前只写不读、恢复成功也不清理：
///
/// 1. `pendingIncompleteRestore()` 零调用者 —— 盘上的记录没人读（纯隐私负担）；
/// 2. `clear()` 零调用者 —— `applying` 记录永远留着，下次启动误报「恢复没走完」；
/// 3. catch 分支回滚成功也不标记/清除 —— 同一个误报；
/// 4. merge 路径抓了快照却不落盘 —— 途中被杀没有撤销点。
///
/// 现在三条终态路径（恢复成功 / 回滚成功 / 撤销）都清掉落盘记录，而
/// `undoLastApply` 在内存撤销点缺失时会**读回**盘上那条 `applying`
/// —— 记录不再是只写不读。
///
/// ## 为什么这样搭测试
///
/// `_applySnapshotData` 会真的写仓储 / warehouse / 假期。本用例把这几层都
/// 换成同签名的替身（只覆盖本流程用到的成员），把焦点留在「落盘记录的生命
/// 周期」上；数据本身怎么写不在本测试的判据里。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _SpyStore store;
  late _FakeRepository repository;
  late _FakeWarehousePrefs warehousePrefs;
  late _FakeMacroService macroService;
  late _FakeHolidayService holidayService;
  late TimetableProvider transferProvider;

  final exportedAt = DateTime.utc(2026, 7, 5, 12);

  TimetableProfile profile(String name) => TimetableProfile(
    id: 'profile-1',
    name: name,
    courses: const [],
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: exportedAt,
    lastUsedAt: exportedAt,
  );

  TimeScheme scheme() => TimeScheme(
    id: 'scheme-1',
    name: '默认作息',
    sections: TimetableSettings.defaults().sections,
    createdAt: exportedAt,
    updatedAt: exportedAt,
  );

  AppSyncSnapshot snapshotNamed(String name) => AppSyncSnapshot(
    profiles: [profile(name)],
    activeProfileId: 'profile-1',
    timeSchemes: [scheme()],
    teacherRecords: const [],
    locationRecords: const [],
    warehouse: const WarehouseSyncBundle(),
    macros: const [],
    customHolidays: const [],
    exportedAt: exportedAt,
    deviceId: 'device-a',
    contentSha256: '',
  );

  AppSyncSnapshotService buildService() => AppSyncSnapshotService(
    timetableRepository: repository,
    warehousePreferencesService: warehousePrefs,
    warehouseMacroService: macroService,
    holidayService: holidayService,
    rollbackSnapshotStore: store,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('rollback_terminal_test');
    store = _SpyStore(directoryProvider: () async => tmp);
    repository = _FakeRepository();
    warehousePrefs = _FakeWarehousePrefs();
    macroService = _FakeMacroService();
    holidayService = _FakeHolidayService();
    transferProvider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
  });

  tearDown(() {
    transferProvider.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('回滚点的三条终态都清理盘上明文记录', () {
    test('恢复成功：记录写过后被清掉，不会被当成「没走完」', () async {
      final service = buildService();
      final port = _FakePort(profiles: [profile('恢复后')]);

      final error = await service.applySnapshot(
        provider: port,
        transferPort: UnifiedTransferProviderAccess(transferProvider),
        snapshot: snapshotNamed('云端'),
      );

      expect(error, isNull);
      // 先落盘（applying）再清 —— 两件事都要发生，否则「清理」可能只是没写过。
      expect(store.saveCalls, greaterThanOrEqualTo(1));
      expect(store.clearCalls, greaterThanOrEqualTo(1));
      expect(await store.read(), isNull);
      expect(await service.pendingIncompleteRestore(), isNull);
    });

    test('回滚成功：本地回到应用前，记录被清掉（不再误报）', () async {
      final service = buildService();
      final port = _FakePort(profiles: [profile('恢复前')])
        ..failNextImport = true;

      final error = await service.applySnapshot(
        provider: port,
        transferPort: UnifiedTransferProviderAccess(transferProvider),
        snapshot: snapshotNamed('云端'),
      );

      expect(error, isNotNull, reason: '第一次 import 失败，应回报错误');
      // 契约收口：先落盘 applying，随后回滚成功必须清掉；留着就会在下次
      // 启动被 `pendingIncompleteRestore` 误判成「上次恢复没走完」。
      expect(store.saveCalls, greaterThanOrEqualTo(1));
      expect(store.clearCalls, greaterThanOrEqualTo(1));
      expect(await store.read(), isNull);
      expect(await service.pendingIncompleteRestore(), isNull);
    });

    test('撤销成功：内存撤销点与盘上记录一起清掉', () async {
      final service = buildService();
      final port = _FakePort(profiles: [profile('恢复后')]);
      final error = await service.applySnapshot(
        provider: port,
        transferPort: UnifiedTransferProviderAccess(transferProvider),
        snapshot: snapshotNamed('云端'),
      );
      expect(error, isNull);

      final clearedBeforeUndo = store.clearCalls;
      final undone = await service.undoLastApply(provider: port);

      expect(undone, isTrue);
      expect(store.clearCalls, greaterThan(clearedBeforeUndo));
      expect(await store.read(), isNull);
    });
  });

  test('进程重启后：盘上 applying 记录是唯一退路，undoLastApply 会读它', () async {
    // 模拟「上次恢复途中被杀」：盘上留着一条 applying + 可解析的快照。
    final seedService = buildService();
    final rollbackJson = seedService.buildSnapshotJsonFromSnapshot(
      snapshotNamed('崩溃前的本地'),
    );
    await store.save(
      undoId: 'undo-crash',
      snapshotJson: rollbackJson,
      state: SyncRollbackRecord.applyingState,
    );

    // 新进程 = 新服务实例，内存里没有 `_lastRollbackSnapshot`。
    final restarted = buildService();
    final port = _FakePort(profiles: [profile('被写了一半')]);
    expect(await restarted.pendingIncompleteRestore(), isNotNull);

    final undone = await restarted.undoLastApply(provider: port);

    expect(
      undone,
      isTrue,
      reason: '`pendingIncompleteRestore` 必须有真实读取方 —— 否则回滚点是只写不读',
    );
    expect(await store.read(), isNull, reason: '撤销成功后记录必须清掉');
  });
}

/// 只覆盖本流程用到的仓储成员：写盘一次都不碰。
class _FakeRepository extends TimetableRepository {
  _FakeRepository() : super(StorageService.forTesting());

  @override
  Future<List<String>> getTeacherRecords() async => const [];

  @override
  Future<List<String>> getLocationRecords() async => const [];

  @override
  Future<PartnerTimetableBinding?> getPartnerTimetableBinding() async => null;

  @override
  Future<void> saveTeacherRecords(List<String> teachers) async {}

  @override
  Future<void> saveLocationRecords(List<String> locations) async {}

  @override
  Future<void> saveLocationTimeGroups(List<LocationTimeGroup> groups) async {}

  @override
  Future<void> saveScheduleDateRules(List<ScheduleDateRule> rules) async {}

  @override
  Future<void> saveScheduleDateRuleLastAppliedSignature(
    String? signature,
  ) async {}

  @override
  Future<void> savePartnerTimetableBinding(
    PartnerTimetableBinding? binding,
  ) async {}
}

class _FakeWarehousePrefs extends WarehouseImportPreferencesService {
  @override
  Future<WarehouseSyncBundle> exportSyncBundle() async =>
      const WarehouseSyncBundle();

  @override
  Future<void> importSyncBundle(
    WarehouseSyncBundle bundle, {
    WarehouseSyncSections sections = const WarehouseSyncSections(),
  }) async {}
}

class _FakeMacroService extends WarehouseMacroService {
  @override
  Future<List<WarehouseMacroRecord>> exportAllMacros() async => const [];

  @override
  Future<void> importAllMacros(List<WarehouseMacroRecord> records) async {}
}

class _FakeHolidayService extends HolidayService {
  @override
  Future<List<HolidayEntry>?> loadCustomHolidays() async => const [];

  @override
  Future<void> saveCustomHolidays(List<HolidayEntry> entries) async {}
}

/// 记录「落盘 / 清理」各发生几次，用来证明成功路径是**先写后清**，
/// 而不是压根没写（那也能让 read() 返回 null，但证不了修复点）。
class _SpyStore extends SyncRollbackSnapshotStore {
  _SpyStore({required super.directoryProvider});

  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<void> save({
    required String undoId,
    required String snapshotJson,
    required String state,
    DateTime? createdAt,
  }) {
    saveCalls++;
    return super.save(
      undoId: undoId,
      snapshotJson: snapshotJson,
      state: state,
      createdAt: createdAt,
    );
  }

  @override
  Future<void> clear() {
    clearCalls++;
    return super.clear();
  }
}

/// 12 成员的快照宿主窄面替身；`failNextImport` 让第一次完整备份导入失败，
/// 把 `applySnapshot` 推进「回滚」分支。
class _FakePort implements AppSyncTimetablePort {
  _FakePort({required this.profiles});

  @override
  List<TimetableProfile> profiles;

  bool failNextImport = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<T> runMutationExclusive<T>(Future<T> Function() action) => action();

  @override
  String? get activeProfileId => 'profile-1';

  @override
  List<TimeScheme> get timeSchemes => const [];

  @override
  List<LocationTimeGroup> get locationTimeGroups => const [];

  @override
  List<ScheduleDateRule> get scheduleDateRules => const [];

  @override
  String? scheduleDateRuleLastAppliedSignature;

  @override
  Future<String?> importFullAppDataBackup(String content) async {
    if (failNextImport) {
      failNextImport = false;
      return 'import_failed';
    }
    return null;
  }

  @override
  Future<void> replaceLocationTimeGroups(
    List<LocationTimeGroup> groups, {
    bool resync = true,
  }) async {}

  @override
  Future<void> replaceScheduleDateRules(
    List<ScheduleDateRule> rules, {
    bool resync = true,
  }) async {}

  @override
  Future<void> reloadFromStorageAfterExternalApply() async {
    // 应用后重建镜像：测试里只需保持列表可用（字段本身即可读）。
  }
}
