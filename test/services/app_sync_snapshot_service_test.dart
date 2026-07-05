import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

void main() {
  test(
    'sync snapshot json round trip preserves timetable and warehouse data',
    () {
      final service = AppSyncSnapshotService();
      final exportedAt = DateTime.utc(2026, 7, 5, 12);
      final snapshot = AppSyncSnapshot(
        profiles: [
          TimetableProfile(
            id: 'profile-1',
            name: '大二下',
            courses: const [],
            settings: TimetableSettings.defaults(),
            currentWeek: 2,
            createdAt: exportedAt,
            lastUsedAt: exportedAt,
          ),
        ],
        activeProfileId: 'profile-1',
        timeSchemes: [
          TimeScheme(
            id: 'scheme-1',
            name: '本校作息',
            sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
            createdAt: exportedAt,
            updatedAt: exportedAt,
          ),
        ],
        teacherRecords: const ['张老师'],
        locationRecords: const ['A101'],
        warehouse: const WarehouseSyncBundle(
          rememberedLogins: [
            WarehouseRememberedLoginEntry(
              adapterId: 'demo',
              login: WarehouseRememberedLogin(
                username: 'student',
                password: 'secret',
              ),
            ),
          ],
          customImportUrls: {'demo': 'https://example.com/login'},
          recentSchoolIds: ['school-a'],
        ),
        macros: const [],
        customHolidays: const [],
        exportedAt: exportedAt,
        deviceId: 'device-a',
        contentSha256: '',
      );
      final payloadWithoutHash = {
        'app': 'mikcb',
        'schemaVersion': AppSyncSnapshotService.schemaVersion,
        'backupType': AppSyncSnapshotService.backupType,
        'exportedAt': exportedAt.toIso8601String(),
        'deviceId': 'device-a',
        'activeProfileId': 'profile-1',
        'profiles': snapshot.profiles
            .map((profile) => profile.toJson())
            .toList(),
        'timeSchemes': snapshot.timeSchemes
            .map((scheme) => scheme.toJson())
            .toList(),
        'teacherRecords': snapshot.teacherRecords,
        'locationRecords': snapshot.locationRecords,
        'warehouse': {
          ...snapshot.warehouse.toJson(),
          'macros': snapshot.macros.map((macro) => macro.toJson()).toList(),
        },
        'customHolidays': snapshot.customHolidays
            .map((entry) => entry.toJson())
            .toList(),
      };
      final hash = AppSyncSnapshotService.computeContentSha256(
        payloadWithoutHash,
      );
      final json = service.buildSnapshotJsonFromSnapshot(
        AppSyncSnapshot(
          profiles: snapshot.profiles,
          activeProfileId: snapshot.activeProfileId,
          timeSchemes: snapshot.timeSchemes,
          teacherRecords: snapshot.teacherRecords,
          locationRecords: snapshot.locationRecords,
          warehouse: snapshot.warehouse,
          macros: snapshot.macros,
          customHolidays: snapshot.customHolidays,
          exportedAt: snapshot.exportedAt,
          deviceId: snapshot.deviceId,
          contentSha256: hash,
        ),
      );
      final parsed = service.parseSnapshotJson(json);

      expect(parsed.activeProfileId, 'profile-1');
      expect(parsed.profiles.single.name, '大二下');
      expect(parsed.teacherRecords, ['张老师']);
      expect(
        parsed.warehouse.rememberedLogins.single.login.username,
        'student',
      );
      expect(
        parsed.warehouse.customImportUrls['demo'],
        'https://example.com/login',
      );
      expect(parsed.contentSha256, hash);
    },
  );

  test('resolveSyncConflictAutomatically prefers newer exportedAt', () {
    final choice = resolveSyncConflictAutomatically(
      SyncConflictInfo(
        localExportedAt: DateTime.utc(2026, 7, 5, 10),
        remoteExportedAt: DateTime.utc(2026, 7, 5, 12),
        localHash: 'a',
        remoteHash: 'b',
      ),
    );
    expect(choice, SyncConflictChoice.keepRemote);
  });
}
