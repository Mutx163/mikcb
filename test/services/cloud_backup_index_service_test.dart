import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/cloud_backup_index_service.dart';

void main() {
  const service = CloudBackupIndexService();

  test('buildBackupId uses timestamp and hash suffix', () {
    final id = CloudBackupIndexService.buildBackupId(
      exportedAt: DateTime(2026, 7, 7, 18, 30, 45),
      contentSha256: 'abcdef1234567890',
    );
    expect(id, '20260707-183045-abcdef12');
    expect(
      CloudBackupIndexService.buildBackupFileName(id),
      '20260707-183045-abcdef12.mikcb',
    );
  });

  test('index encode/decode roundtrip', () {
    final index = CloudBackupIndex(
      entries: [
        CloudBackupEntry(
          id: 'backup-1',
          fileName: 'backup-1.mikcb',
          exportedAt: DateTime.utc(2026, 7, 7, 10),
          contentSha256: 'hash-a',
          deviceId: 'device-a',
          deviceLabel: 'Phone',
          isCurrent: true,
        ),
      ],
    );

    final decoded = service.decodeIndex(service.encodeIndex(index));
    expect(decoded.entries.length, 1);
    expect(decoded.entries.first.id, 'backup-1');
    expect(decoded.entries.first.isCurrent, isTrue);
  });

  test('addEntry deduplicates same hash', () {
    const index = CloudBackupIndex();
    final entry = CloudBackupEntry(
      id: 'backup-1',
      fileName: 'backup-1.mikcb',
      exportedAt: DateTime.utc(2026, 7, 7, 10),
      contentSha256: 'same-hash',
      deviceId: 'device-a',
      deviceLabel: 'Phone',
    );

    final first = service.addEntry(
      index: index,
      entry: entry,
      currentContentSha256: 'same-hash',
    );
    final second = service.addEntry(
      index: first,
      entry: entry.copyWith(id: 'backup-2', fileName: 'backup-2.mikcb'),
      currentContentSha256: 'same-hash',
    );

    expect(second.entries.length, 1);
    expect(second.entries.first.isCurrent, isTrue);
  });

  test('markCurrent only flags matching hash', () {
    final index = CloudBackupIndex(
      entries: [
        CloudBackupEntry(
          id: 'old',
          fileName: 'old.mikcb',
          exportedAt: DateTime.utc(2026, 7, 6),
          contentSha256: 'old-hash',
          deviceId: 'device',
          deviceLabel: 'Phone',
          isCurrent: true,
        ),
        CloudBackupEntry(
          id: 'new',
          fileName: 'new.mikcb',
          exportedAt: DateTime.utc(2026, 7, 7),
          contentSha256: 'new-hash',
          deviceId: 'device',
          deviceLabel: 'Phone',
        ),
      ],
    );

    final next = service.markCurrent(
      index: index,
      currentContentSha256: 'new-hash',
    );

    expect(next.entries.firstWhere((e) => e.id == 'old').isCurrent, isFalse);
    expect(next.entries.firstWhere((e) => e.id == 'new').isCurrent, isTrue);
  });

  test('prune keeps current and protected manual backups', () {
    final index = CloudBackupIndex(
      entries: [
        CloudBackupEntry(
          id: 'current',
          fileName: 'current.mikcb',
          exportedAt: DateTime.utc(2026, 7, 7),
          contentSha256: 'current',
          deviceId: 'device',
          deviceLabel: 'Phone',
          isCurrent: true,
        ),
        CloudBackupEntry(
          id: 'manual',
          fileName: 'manual.mikcb',
          exportedAt: DateTime.utc(2026, 1, 1),
          contentSha256: 'manual',
          deviceId: 'device',
          deviceLabel: 'Phone',
          source: CloudBackupSource.manual,
        ),
        CloudBackupEntry(
          id: 'old-auto',
          fileName: 'old-auto.mikcb',
          exportedAt: DateTime.utc(2026, 1, 1),
          contentSha256: 'old-auto',
          deviceId: 'device',
          deviceLabel: 'Phone',
        ),
      ],
    );

    final result = service.prune(
      index: index,
      maxBackupCount: 1,
      maxBackupAgeDays: 30,
      manualBackupProtected: true,
      now: DateTime.utc(2026, 7, 7),
    );

    expect(result.removedEntries.map((e) => e.id), ['old-auto']);
    expect(result.index.entries.map((e) => e.id), containsAll(['current', 'manual']));
  });

  test('countCoursesInSnapshotJson sums profile courses', () {
    const content = '''
{
  "profiles": [
    {"courses": [{}, {}]},
    {"courses": [{}]}
  ]
}
''';
    expect(CloudBackupIndexService.countCoursesInSnapshotJson(content), 3);
    expect(CloudBackupIndexService.countProfilesInSnapshotJson(content), 2);
  });
}
