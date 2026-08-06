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
