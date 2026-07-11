import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/webdav_sync_config.dart';

void main() {
  test('webdav config normalizes remote folder path', () {
    const config = WebdavSyncConfig(remoteFolder: 'Apps/qingyu-sync');
    expect(config.normalizedRemoteFolder, '/Apps/qingyu-sync/');
    expect(config.snapshotRemotePath, '/Apps/qingyu-sync/snapshot.mikcb');
    expect(config.metaRemotePath, '/Apps/qingyu-sync/snapshot.meta.json');
    expect(config.historyRemoteFolder, '/Apps/qingyu-sync/history/');
    expect(config.historyIndexRemotePath, '/Apps/qingyu-sync/history/index.json');
    expect(
      config.historyBackupRemotePath('20260707-183045-abcdef12.mikcb'),
      '/Apps/qingyu-sync/history/20260707-183045-abcdef12.mikcb',
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
}
