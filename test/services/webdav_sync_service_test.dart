import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/webdav_sync_config.dart';

void main() {
  test('webdav config normalizes remote folder path', () {
    const config = WebdavSyncConfig(remoteFolder: 'Apps/qingyu-sync');
    expect(config.normalizedRemoteFolder, '/Apps/qingyu-sync/');
    expect(config.snapshotRemotePath, '/Apps/qingyu-sync/snapshot.mikcb');
    expect(config.metaRemotePath, '/Apps/qingyu-sync/snapshot.meta.json');
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
}
