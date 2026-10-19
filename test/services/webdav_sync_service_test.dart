import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/webdav_client_service.dart';
import 'package:university_timetable/services/webdav_sync_config.dart';
import 'package:university_timetable/services/webdav_sync_service.dart';

void main() {
  test('webdav config normalizes remote folder path', () {
    const config = WebdavSyncConfig(remoteFolder: 'Apps/qingyu-sync');
    expect(config.normalizedRemoteFolder, '/Apps/qingyu-sync/');
    expect(config.snapshotRemotePath, '/Apps/qingyu-sync/snapshot.mikcb');
    expect(config.metaRemotePath, '/Apps/qingyu-sync/snapshot.meta.json');
    expect(config.historyRemoteFolder, '/Apps/qingyu-sync/history/');
    expect(
      config.historyIndexRemotePath,
      '/Apps/qingyu-sync/history/index.json',
    );
    expect(
      config.historyBackupRemotePath('20260707-183045-abcdef12.mikcb'),
      '/Apps/qingyu-sync/history/20260707-183045-abcdef12.mikcb',
    );
  });

  test('historyBackupRemotePath rejects path traversal', () {
    const config = WebdavSyncConfig(remoteFolder: 'Apps/qingyu-sync');
    expect(
      config.historyBackupRemotePath('../secret.mikcb'),
      '/Apps/qingyu-sync/history/secret.mikcb',
    );
    expect(
      config.historyBackupRemotePath('nested/../safe.mikcb'),
      '/Apps/qingyu-sync/history/safe.mikcb',
    );
    expect(
      () => config.historyBackupRemotePath('..'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => config.historyBackupRemotePath(''),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('sync conflict auto resolver keeps local when newer', () {
    final choice = resolveSyncConflictAutomatically(
      SyncConflictInfo(
        localExportedAt: DateTime.utc(2026, 7, 5, 13),
        remoteExportedAt: DateTime.utc(2026, 7, 5, 12),
        localHash: 'local',
        remoteHash: 'remote',
      ),
    );
    expect(choice, SyncConflictChoice.keepLocal);
  });

  test('background conflict resolver never silently keeps local', () {
    final choice = resolveSyncConflictForBackground(
      SyncConflictInfo(
        localExportedAt: DateTime.utc(2026, 7, 5, 13),
        remoteExportedAt: DateTime.utc(2026, 7, 5, 12),
        localHash: 'local',
        remoteHash: 'remote',
      ),
    );
    expect(choice, SyncConflictChoice.keepRemote);
  });

  test('auto upload allows when remote matches last uploaded baseline', () {
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: 'baseline',
        lastAppliedRemoteHash: 'other',
        lastUploadedLocalHash: 'baseline',
        localContentSha256: 'local-new',
        localHasUserAuthoredData: true,
      ),
      WebdavAutoUploadDecision.allow,
    );
  });

  test('auto upload blocks when remote drifted from baseline', () {
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: 'remote-other-device',
        lastAppliedRemoteHash: 'baseline',
        lastUploadedLocalHash: 'baseline',
        localContentSha256: 'local-new',
        localHasUserAuthoredData: true,
      ),
      WebdavAutoUploadDecision.remoteDrifted,
    );
  });

  test('auto upload is upToDate when remote equals local', () {
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: 'same',
        lastAppliedRemoteHash: 'old',
        lastUploadedLocalHash: 'old',
        localContentSha256: 'same',
        localHasUserAuthoredData: true,
      ),
      WebdavAutoUploadDecision.upToDate,
    );
  });

  test('auto upload allows first upload when remote meta missing', () {
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: null,
        lastAppliedRemoteHash: null,
        lastUploadedLocalHash: null,
        localContentSha256: 'local',
        localHasUserAuthoredData: true,
      ),
      WebdavAutoUploadDecision.allow,
    );
  });

  // ── 本地空数据守卫（2026-10-19）────────────────────────────────────
  // 拉取侧早就有「本机没有用户数据就别乱覆盖」的保护，上传侧此前没有：
  // 本地课表被误覆盖/清空后，任意一次保存都会触发防抖自动上传，把云端最后
  // 一份好数据顶成空壳。守卫在「上次传的有数据、这次没有」时生效；标志未知
  // （null：只拉取过从未上传的设备、旧版升级后首传前）同样拦——这两种状态
  // 恰恰是没有任何闸可撞的盲区。唯一放行口是「确知上次传的就是空的」(false)。

  test(
    'auto upload blocks when local lost user data but cloud still has some',
    () {
      expect(
        decideWebdavAutoUpload(
          remoteContentSha256: 'baseline-with-courses',
          lastAppliedRemoteHash: 'baseline-with-courses',
          lastUploadedLocalHash: 'baseline-with-courses',
          localContentSha256: 'local-empty',
          localHasUserAuthoredData: false,
          lastUploadedHadUserData: true,
        ),
        WebdavAutoUploadDecision.localDataEmpty,
      );
    },
  );

  test('auto upload still allows settings-only users (never had user data)', () {
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: 'baseline-settings-only',
        lastAppliedRemoteHash: 'baseline-settings-only',
        lastUploadedLocalHash: 'baseline-settings-only',
        localContentSha256: 'local-settings-changed',
        localHasUserAuthoredData: false,
        lastUploadedHadUserData: false,
      ),
      WebdavAutoUploadDecision.allow,
    );
  });

  test(
    'auto upload blocks when the previous upload flag is unknown',
    () {
      // 标志未知（旧版升级后首传前、或只拉取过从未上传的设备——拉取路径
      // 不写这个键）不能按「不能拦」处理：这正是「本地掉空 + 云端未变」时
      // 唯一没闸的状态，放行=空壳覆盖云端好数据。拦的是静默自动上传，
      // 手动备份仍可强推，代价不对称，宁可拦。
      expect(
        decideWebdavAutoUpload(
          remoteContentSha256: 'baseline',
          lastAppliedRemoteHash: 'baseline',
          lastUploadedLocalHash: 'baseline',
          localContentSha256: 'local-empty',
          localHasUserAuthoredData: false,
        ),
        WebdavAutoUploadDecision.localDataEmpty,
      );
    },
  );

  test(
    'auto upload blocks pull-only device whose local data dropped empty',
    () {
      // 只拉取过的设备：lastAppliedRemoteHash 由拉取路径写入，
      // lastUploadedLocalHash 仍是 null（从未上传）。云端未变时旧逻辑落进
      // matchesBaseline 分支放行——2026-10-19 审查发现的盲区本体。
      expect(
        decideWebdavAutoUpload(
          remoteContentSha256: 'cloud-v1',
          lastAppliedRemoteHash: 'cloud-v1',
          lastUploadedLocalHash: null,
          localContentSha256: 'local-empty',
          localHasUserAuthoredData: false,
        ),
        WebdavAutoUploadDecision.localDataEmpty,
      );
    },
  );

  test('empty local still reports upToDate when remote already matches', () {
    // 云端已经是这份空快照（例如用户手动备份过一次空状态）：不 PUT、
    // 也不该报「本地掉了」，upToDate 更准确。
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: 'local-empty',
        lastAppliedRemoteHash: 'old',
        lastUploadedLocalHash: 'old',
        localContentSha256: 'local-empty',
        localHasUserAuthoredData: false,
        lastUploadedHadUserData: true,
      ),
      WebdavAutoUploadDecision.upToDate,
    );
  });

  test('empty local is allowed when there is no remote to protect', () {
    expect(
      decideWebdavAutoUpload(
        remoteContentSha256: null,
        lastAppliedRemoteHash: null,
        lastUploadedLocalHash: null,
        localContentSha256: 'local-empty',
        localHasUserAuthoredData: false,
        lastUploadedHadUserData: true,
      ),
      WebdavAutoUploadDecision.allow,
    );
  });

  test('content hash ignores exportedAt and deviceId', () {
    final base = <String, dynamic>{
      'app': 'mikcb',
      'schemaVersion': AppSyncSnapshotService.schemaVersion,
      'backupType': AppSyncSnapshotService.backupType,
      'activeProfileId': 'p1',
      'profiles': const <dynamic>[],
      'timeSchemes': const <dynamic>[],
      'teacherRecords': const <String>[],
      'locationRecords': const <String>[],
      'warehouse': const <String, dynamic>{},
      'customHolidays': const <dynamic>[],
      'partnerTimetableBinding': null,
    };
    final a = AppSyncSnapshotService.computeContentSha256({
      ...base,
      'exportedAt': '2026-07-05T12:00:00.000Z',
      'deviceId': 'device-a',
    });
    final b = AppSyncSnapshotService.computeContentSha256({
      ...base,
      'exportedAt': '2026-07-05T18:00:00.000Z',
      'deviceId': 'device-b',
    });
    expect(a, b);
  });

  test('webdav first sync treats divergent snapshots as conflict', () {
    expect(
      webdavPullHasSyncConflict(
        lastUploadedLocalHash: null,
        lastAppliedRemoteHash: null,
        localContentSha256: 'local-hash',
        remoteContentSha256: 'remote-hash',
      ),
      isTrue,
    );
  });

  test('webdav first sync skips conflict when snapshots match', () {
    expect(
      webdavPullHasSyncConflict(
        lastUploadedLocalHash: null,
        lastAppliedRemoteHash: null,
        localContentSha256: 'same-hash',
        remoteContentSha256: 'same-hash',
      ),
      isFalse,
    );
  });

  test('webdav pull requires both sides changed after baseline exists', () {
    expect(
      webdavPullHasSyncConflict(
        lastUploadedLocalHash: 'baseline',
        lastAppliedRemoteHash: 'baseline',
        localContentSha256: 'local-new',
        remoteContentSha256: 'baseline',
      ),
      isFalse,
    );
    expect(
      webdavPullHasSyncConflict(
        lastUploadedLocalHash: 'baseline',
        lastAppliedRemoteHash: 'baseline',
        localContentSha256: 'local-new',
        remoteContentSha256: 'remote-new',
      ),
      isTrue,
    );
  });

  test('background pull cancels first sync when local has user data', () {
    expect(
      webdavBackgroundPullShouldCancel(
        lastUploadedLocalHash: null,
        lastAppliedRemoteHash: null,
        localContentSha256: 'local-hash',
        localHasUserData: true,
      ),
      isTrue,
    );
  });

  test('background pull allows first sync when local is empty', () {
    expect(
      webdavBackgroundPullShouldCancel(
        lastUploadedLocalHash: null,
        lastAppliedRemoteHash: null,
        localContentSha256: 'local-hash',
        localHasUserData: false,
      ),
      isFalse,
    );
  });

  test('background pull cancels when local changed since upload', () {
    expect(
      webdavBackgroundPullShouldCancel(
        lastUploadedLocalHash: 'baseline',
        lastAppliedRemoteHash: 'baseline',
        localContentSha256: 'local-new',
        localHasUserData: true,
      ),
      isTrue,
    );
  });

  test('manual pull conflict keeps remote without prompt when local is empty', () {
    expect(
      resolveManualPullConflictChoice(localHasUserData: false),
      SyncConflictChoice.keepRemote,
    );
  });

  test('manual pull conflict defers to prompt when local has user data', () {
    expect(resolveManualPullConflictChoice(localHasUserData: true), isNull);
  });

  test('sync conflict info flags default to regular conflict', () {
    final info = SyncConflictInfo(
      localExportedAt: DateTime.utc(2026, 7, 5, 13),
      remoteExportedAt: DateTime.utc(2026, 7, 5, 12),
      localHash: 'local',
      remoteHash: 'remote',
    );
    expect(info.isFirstSyncDivergence, isFalse);
    expect(info.localHasUserData, isFalse);
  });

  test('backup index recovery aborts when index and listing both fail', () {
    final action = decideWebdavBackupIndexRecovery(
      indexResult: const WebdavGetBytesResult.failed('index_timeout'),
      listingResult: const WebdavHistoryListResult.failed('listing_timeout'),
    );
    expect(action, WebdavBackupIndexRecoveryAction.failed);
  });

  test(
    'backup index recovery aborts when failed index has no successful listing',
    () {
      expect(
        decideWebdavBackupIndexRecovery(
          indexResult: const WebdavGetBytesResult.failed('index_timeout'),
          listingResult: const WebdavHistoryListResult.ok([]),
        ),
        WebdavBackupIndexRecoveryAction.failed,
      );
      expect(
        decideWebdavBackupIndexRecovery(
          indexResult: const WebdavGetBytesResult.failed('index_timeout'),
          listingResult: const WebdavHistoryListResult.notFound(),
        ),
        WebdavBackupIndexRecoveryAction.failed,
      );
    },
  );

  test(
    'backup index recovery treats missing index and empty listing as empty',
    () {
      final action = decideWebdavBackupIndexRecovery(
        indexResult: const WebdavGetBytesResult.notFound(),
        listingResult: const WebdavHistoryListResult.ok([]),
      );
      expect(action, WebdavBackupIndexRecoveryAction.empty);
    },
  );

  test('backup index recovery rebuilds from a successful listing', () {
    final action = decideWebdavBackupIndexRecovery(
      indexResult: const WebdavGetBytesResult.failed('index_timeout'),
      listingResult: const WebdavHistoryListResult.ok(['one.mikcb']),
    );
    expect(action, WebdavBackupIndexRecoveryAction.rebuildFromListing);
  });

  test('history listing failure classification preserves not-found', () {
    final missing = WebdavClientService.classifyHistoryListFailure(
      StateError('404 Not Found'),
    );
    final failed = WebdavClientService.classifyHistoryListFailure(
      StateError('connection reset'),
    );
    expect(missing.isNotFound, isTrue);
    expect(missing.isFailed, isFalse);
    expect(failed.isFailed, isTrue);
  });
}
