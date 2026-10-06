import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/webdav_sync_coordinator.dart';
import 'package:university_timetable/services/webdav_sync_service.dart';

/// 回归钉（2026-10-05 审查第 18 轮）：**抛出来**的同步异常也必须留下可见的失败痕迹。
///
/// 协调器的三个入口（`maybePullRemote` 自动拉取、`_performAutoUpload` 防抖上传、
/// `syncNow` 手动同步）原先都写成 `try { ... } finally { isSyncing = false }`，
/// 没有 catch。而 `_applyResult` 是全类唯一写 `status.lastError` 的地方 ——
/// 于是 `downloadAndApply` / `uploadSnapshot` / `syncNow` 一抛（凭证读取、
/// `buildConnectionParams` 的远端前置、config 解析都会抛），这次云同步失败就没有
/// 任何落点：Cloud Sync 的徽章永远干净，而自动同步其实已经停了。两个后台入口
/// 还是 `unawaited(...)`（main.dart 的 maybePullRemote、协调器里的防抖 Timer），
/// 异常连一条日志都不留。
class _ThrowingSyncService extends WebdavSyncService {
  @override
  Future<WebdavSyncResult> syncNow({
    required TimetableProvider provider,
    bool allowConflictPrompt = true,
  }) => throw StateError('test_sync_now_threw_with_a_secret_url');

  // 第 32 轮补的三个同形入口：真实抛源是 keystore 读密码（
  // webdav_sync_credentials_store.dart:18 的裸 FlutterSecureStorage.read 会抛
  // PlatformException），且它发生在 uploadSnapshot 自己的 try 之前。
  @override
  Future<WebdavSyncResult> createManualBackup({
    required TimetableProvider provider,
  }) => throw StateError('test_manual_backup_threw_with_a_secret_url');

  @override
  Future<WebdavSyncResult> restoreFromBackup({
    required TimetableProvider provider,
    required String entryId,
    bool uploadAsCurrent = true,
  }) => throw StateError('test_restore_threw_with_a_secret_url');

  @override
  Future<WebdavSyncResult> deleteBackup({required String entryId}) =>
      throw StateError('test_delete_threw_with_a_secret_url');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;
  late WebdavSyncCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    WebdavSyncCoordinator.resetInstanceForTesting();
    provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    coordinator = WebdavSyncCoordinator(syncService: _ThrowingSyncService());
    coordinator.bindProvider(provider);
  });

  tearDown(() {
    provider.dispose();
    WebdavSyncCoordinator.resetInstanceForTesting();
  });

  test('抛异常的同步要折叠成 failed 结果，而不是把异常丢回调用方', () async {
    final result = await coordinator.syncNow();

    expect(result.kind, WebdavSyncResultKind.failed);
    expect(coordinator.status.isSyncing, isFalse);
  });

  test('折叠出的失败必须写进 lastError —— 那是 UI 唯一的显示位', () async {
    await coordinator.syncNow();

    expect(coordinator.status.lastError, isNotNull);
    expect(coordinator.status.lastError, 'sync_failed');
  });

  test('lastError 里不能带异常原文（它会被 localizeSyncError 查表后显示给用户）', () async {
    await coordinator.syncNow();

    expect(coordinator.status.lastError ?? '', isNot(contains('secret_url')));
    expect(coordinator.status.lastError ?? '', isNot(contains('StateError')));
  });

  // 第 32 轮：另外三个同形入口（手动备份 / 恢复 / 删除）此前只有 try/finally，
  // 抛出来就是"转一下、徽章干净、其实没成"。三者都要走同一个折叠。
  group('手动备份 / 恢复 / 删除也要把抛出的异常折叠成可见失败', () {
    test('手动备份抛异常时结果与 lastError 都要落下来', () async {
      final result = await coordinator.createManualBackup();

      expect(result.kind, WebdavSyncResultKind.failed);
      expect(coordinator.status.isSyncing, isFalse);
      expect(coordinator.status.lastError, 'sync_failed');
      expect(coordinator.status.lastError ?? '', isNot(contains('secret_url')));
    });

    test('恢复抛异常时结果与 lastError 都要落下来', () async {
      final result = await coordinator.restoreBackup('entry-1');

      expect(result.kind, WebdavSyncResultKind.failed);
      expect(coordinator.status.isSyncing, isFalse);
      expect(coordinator.status.lastError, 'sync_failed');
    });

    test('删除抛异常时结果与 lastError 都要落下来', () async {
      final result = await coordinator.deleteBackup('entry-1');

      expect(result.kind, WebdavSyncResultKind.failed);
      expect(coordinator.status.isSyncing, isFalse);
      expect(coordinator.status.lastError, 'sync_failed');
    });
  });
}
