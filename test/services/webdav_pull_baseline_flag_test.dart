import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/providers/app_sync_timetable_access.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/unified_transfer_access.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';
import 'package:university_timetable/services/webdav_client_service.dart';
import 'package:university_timetable/services/webdav_sync_config.dart';
import 'package:university_timetable/services/webdav_sync_credentials_store.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';
import 'package:university_timetable/services/webdav_sync_service.dart';
import 'package:webdav_plus/webdav_plus.dart';

const String _remoteHash = 'remote-sha256';
const String _localHash = 'local-sha256';

AppSyncSnapshot _snapshot({
  required String deviceId,
  required String contentSha256,
  List<String> teachers = const [],
}) {
  return AppSyncSnapshot(
    profiles: const [],
    activeProfileId: null,
    timeSchemes: const [],
    teacherRecords: teachers,
    locationRecords: const [],
    warehouse: const WarehouseSyncBundle(),
    macros: const [],
    customHolidays: const [],
    exportedAt: DateTime.utc(2026, 10, 20),
    deviceId: deviceId,
    contentSha256: contentSha256,
  );
}

/// 只把「解析出来的远端快照」与「应用结果」握在手里的替身：
/// 真实 apply 需要完整 provider 数据面，与本用例要验证的「标志回写」无关。
class _FakeSnapshotService extends AppSyncSnapshotService {
  _FakeSnapshotService({
    required this.remote,
    required this.local,
    this.applyError,
  });

  final AppSyncSnapshot remote;
  final AppSyncSnapshot local;
  final String? applyError;
  int applyCalls = 0;

  @override
  AppSyncSnapshot parseSnapshotJson(String content) => remote;

  @override
  Future<AppSyncSnapshot> collectSnapshot({
    required AppSyncTimetablePort provider,
    required String deviceId,
    DateTime? exportedAt,
  }) async => local;

  @override
  Future<String?> applySnapshotJson({
    required AppSyncTimetablePort provider,
    required UnifiedTransferPort transferPort,
    required String content,
  }) async {
    applyCalls += 1;
    return applyError;
  }
}

class _FakeCredentialsStore extends WebdavSyncCredentialsStore {
  const _FakeCredentialsStore();

  @override
  Future<String?> readPassword() async => 'password';

  @override
  Future<String> getOrCreateDeviceId() async => 'local-device';
}

class _MemoryConfigStore extends WebdavSyncConfigStore {
  _MemoryConfigStore(this.config);

  WebdavSyncConfig config;

  @override
  Future<WebdavSyncConfig> load() async => config;

  @override
  Future<void> save(WebdavSyncConfig next) async {
    config = next;
  }
}

class _FakeClientService extends WebdavClientService {
  _FakeClientService({required this.meta});

  final AppSyncSnapshotMeta meta;

  @override
  Future<WebdavRemoteMetaResult> getRemoteMetaResult({
    required WebdavClient client,
    required String remotePath,
  }) async {
    return WebdavRemoteMetaResult.ok(meta);
  }

  @override
  Future<Uint8List?> getBytes({
    required WebdavClient client,
    required String remotePath,
    Duration timeout = WebdavClientService.defaultOperationTimeout,
  }) async {
    return Uint8List.fromList(utf8.encode('{"schemaVersion":2}'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 基线：本机曾上传空快照（lastUploadedHadUserData=false），本地自那以后
  /// 没改过（localHash 未变），远端已被另一台设备换成新内容（remoteHash）。
  WebdavSyncConfig baselineConfig() {
    return const WebdavSyncConfig(
      enabled: true,
      username: 'user@example.com',
      baseUrl: 'https://dav.example.com/dav/',
      lastUploadedLocalHash: _localHash,
      lastUploadedHadUserData: false,
    );
  }

  AppSyncSnapshotMeta remoteMeta() => AppSyncSnapshotMeta(
    exportedAt: DateTime.utc(2026, 10, 20),
    contentSha256: _remoteHash,
    deviceId: 'remote-device',
  );

  group('拉取成功回写 lastUploadedHadUserData（空快照守卫残留组合）', () {
    test('云端有用户数据时回写 true，并因此拦住随后「本地掉空」的自动上传', () async {
      final configStore = _MemoryConfigStore(baselineConfig());
      final snapshotService = _FakeSnapshotService(
        remote: _snapshot(
          deviceId: 'remote-device',
          contentSha256: _remoteHash,
          teachers: const ['王老师'],
        ),
        local: _snapshot(
          deviceId: 'local-device',
          contentSha256: _localHash,
        ),
      );
      final service = WebdavSyncService(
        snapshotService: snapshotService,
        configStore: configStore,
        credentialsStore: const _FakeCredentialsStore(),
        clientService: _FakeClientService(meta: remoteMeta()),
      );

      final result = await service.downloadAndApply(
        provider: AppSyncTimetableViewAccess(TimetableProvider(autoInitialize: false)),
        transferPort: UnifiedTransferProviderAccess(
          TimetableProvider(autoInitialize: false),
        ),
      );

      expect(result.kind, WebdavSyncResultKind.downloaded);
      expect(snapshotService.applyCalls, 1);
      // 缺陷修复点：拉取成功＝本地就是云端那份，标志必须跟着变成 true。
      expect(configStore.config.lastUploadedHadUserData, isTrue);
      expect(configStore.config.lastAppliedRemoteHash, _remoteHash);

      // 推理链收口：本地随后掉空（localHasUserAuthoredData=false）时，
      // 自动上传必须被拦成 localDataEmpty，而不是拿 false 当放行口。
      expect(
        decideWebdavAutoUpload(
          remoteContentSha256: 'another-remote-sha256',
          lastAppliedRemoteHash: configStore.config.lastAppliedRemoteHash,
          lastUploadedLocalHash: configStore.config.lastUploadedLocalHash,
          localContentSha256: 'empty-sha256',
          localHasUserAuthoredData: false,
          lastUploadedHadUserData: configStore.config.lastUploadedHadUserData,
        ),
        WebdavAutoUploadDecision.localDataEmpty,
      );
    });

    test('云端本身就是空快照时回写 false，「上次同步就是空的」放行口保持不变', () async {
      final configStore = _MemoryConfigStore(baselineConfig());
      final service = WebdavSyncService(
        snapshotService: _FakeSnapshotService(
          remote: _snapshot(
            deviceId: 'remote-device',
            contentSha256: _remoteHash,
          ),
          local: _snapshot(
            deviceId: 'local-device',
            contentSha256: _localHash,
          ),
        ),
        configStore: configStore,
        credentialsStore: const _FakeCredentialsStore(),
        clientService: _FakeClientService(meta: remoteMeta()),
      );

      final result = await service.downloadAndApply(
        provider: AppSyncTimetableViewAccess(TimetableProvider(autoInitialize: false)),
        transferPort: UnifiedTransferProviderAccess(
          TimetableProvider(autoInitialize: false),
        ),
      );

      expect(result.kind, WebdavSyncResultKind.downloaded);
      expect(configStore.config.lastUploadedHadUserData, isFalse);
      // 空对空且云端仍是我们刚拉取的基线：既不是「上次有这次没了」，也不是
      // 远端漂移，自动上传按既有语义放行——这条不是本次要收紧的面。
      expect(
        decideWebdavAutoUpload(
          remoteContentSha256: configStore.config.lastAppliedRemoteHash,
          lastAppliedRemoteHash: configStore.config.lastAppliedRemoteHash,
          lastUploadedLocalHash: configStore.config.lastUploadedLocalHash,
          localContentSha256: 'empty-sha256',
          localHasUserAuthoredData: false,
          lastUploadedHadUserData: configStore.config.lastUploadedHadUserData,
        ),
        WebdavAutoUploadDecision.allow,
      );
    });

    test('快照应用失败时不改配置，标志保持原值（不能把失败当成功盖章）', () async {
      final configStore = _MemoryConfigStore(baselineConfig());
      final service = WebdavSyncService(
        snapshotService: _FakeSnapshotService(
          remote: _snapshot(
            deviceId: 'remote-device',
            contentSha256: _remoteHash,
            teachers: const ['王老师'],
          ),
          local: _snapshot(
            deviceId: 'local-device',
            contentSha256: _localHash,
          ),
          applyError: 'apply_failed',
        ),
        configStore: configStore,
        credentialsStore: const _FakeCredentialsStore(),
        clientService: _FakeClientService(meta: remoteMeta()),
      );

      final result = await service.downloadAndApply(
        provider: AppSyncTimetableViewAccess(TimetableProvider(autoInitialize: false)),
        transferPort: UnifiedTransferProviderAccess(
          TimetableProvider(autoInitialize: false),
        ),
      );

      expect(result.kind, WebdavSyncResultKind.failed);
      expect(result.message, 'apply_failed');
      expect(configStore.config.lastUploadedHadUserData, isFalse);
      expect(configStore.config.lastAppliedRemoteHash, isNull);
    });
  });
}
