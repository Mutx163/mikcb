import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
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
        'locationTimeGroups': snapshot.locationTimeGroups
            .map((group) => group.toJson())
            .toList(),
        'teacherRecords': snapshot.teacherRecords,
        'locationRecords': snapshot.locationRecords,
        'warehouse': {
          ...snapshot.warehouse.withoutPasswords().toJson(),
          'macros': snapshot.macros.map((macro) => macro.toJson()).toList(),
        },
        'customHolidays': snapshot.customHolidays
            .map((entry) => entry.toJson())
            .toList(),
        'partnerTimetableBinding': null,
      };
      final hash = AppSyncSnapshotService.computeContentSha256(
        payloadWithoutHash,
      );
      final json = service.buildSnapshotJsonFromSnapshot(
        AppSyncSnapshot(
          profiles: snapshot.profiles,
          activeProfileId: snapshot.activeProfileId,
          timeSchemes: snapshot.timeSchemes,
          locationTimeGroups: snapshot.locationTimeGroups,
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
      expect(parsed.locationTimeGroups, isEmpty);
      expect(
        parsed.warehouse.rememberedLogins.single.login.username,
        'student',
      );
      // Cloud sync JSON must strip teaching-system passwords (C3).
      expect(parsed.warehouse.rememberedLogins.single.login.password, isEmpty);
      expect(
        parsed.warehouse.customImportUrls['demo'],
        'https://example.com/login',
      );
      expect(parsed.contentSha256, hash);
    },
  );

  test('sync snapshot round trip preserves location time groups', () {
    final service = AppSyncSnapshotService();
    final exportedAt = DateTime.utc(2026, 7, 9, 12);
    final groups = [
      LocationTimeGroup(
        id: 'group-main',
        name: '主教学楼',
        timeSchemeId: 'scheme-1',
        keywords: const [
          LocationKeyword(pattern: 'A主', mode: LocationKeywordMatchMode.prefix),
        ],
      ),
      LocationTimeGroup(
        id: 'group-other',
        name: '其他教学楼',
        timeSchemeId: 'scheme-2',
        keywords: const [
          LocationKeyword(pattern: 'A1', mode: LocationKeywordMatchMode.prefix),
          LocationKeyword(pattern: 'A6', mode: LocationKeywordMatchMode.prefix),
        ],
      ),
    ];
    final snapshot = AppSyncSnapshot(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '大二下',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 1,
          createdAt: exportedAt,
          lastUsedAt: exportedAt,
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: [
        TimeScheme(
          id: 'scheme-1',
          name: '主教作息',
          sections: const [SectionTime(startTime: '08:20', endTime: '09:05')],
          createdAt: exportedAt,
          updatedAt: exportedAt,
        ),
        TimeScheme(
          id: 'scheme-2',
          name: '其他作息',
          sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
          createdAt: exportedAt,
          updatedAt: exportedAt,
        ),
      ],
      locationTimeGroups: groups,
      teacherRecords: const [],
      locationRecords: const [],
      warehouse: const WarehouseSyncBundle(),
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
      'profiles': snapshot.profiles.map((profile) => profile.toJson()).toList(),
      'timeSchemes': snapshot.timeSchemes
          .map((scheme) => scheme.toJson())
          .toList(),
      'locationTimeGroups': groups.map((group) => group.toJson()).toList(),
      'teacherRecords': const <String>[],
      'locationRecords': const <String>[],
      'warehouse': {
        ...snapshot.warehouse.toJson(),
        'macros': const <dynamic>[],
      },
      'customHolidays': const <dynamic>[],
      'partnerTimetableBinding': null,
    };
    final hash = AppSyncSnapshotService.computeContentSha256(
      payloadWithoutHash,
    );
    final json = service.buildSnapshotJsonFromSnapshot(
      AppSyncSnapshot(
        profiles: snapshot.profiles,
        activeProfileId: snapshot.activeProfileId,
        timeSchemes: snapshot.timeSchemes,
        locationTimeGroups: groups,
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

    expect(parsed.locationTimeGroups, hasLength(2));
    expect(parsed.locationTimeGroups.first.name, '主教学楼');
    expect(parsed.locationTimeGroups.first.keywords.single.pattern, 'A主');
    expect(parsed.locationTimeGroups.last.keywordSummary, 'A1, A6');
    expect(parsed.contentSha256, hash);
  });

  test('sync snapshot preserves partner timetable binding metadata', () {
    final service = AppSyncSnapshotService();
    final exportedAt = DateTime.utc(2026, 7, 8, 12);
    final binding = PartnerTimetableBinding(
      partnerProfileId: 'partner-imported',
      partnerName: '小明的课表',
      linkedAt: exportedAt,
      lastImportedAt: exportedAt,
      weekOffset: 1,
      mineColorHex: '#FF5722',
      partnerColorHex: '#4CAF50',
      togetherColorHex: '#9C27B0',
    );
    final snapshot = AppSyncSnapshot(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '我的课表',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 2,
          createdAt: exportedAt,
          lastUsedAt: exportedAt,
        ),
        TimetableProfile(
          id: 'partner-imported',
          name: '小明的课表',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 3,
          createdAt: exportedAt,
          lastUsedAt: exportedAt,
          profileKind: TimetableProfileKind.partnerImported,
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: const [],
      teacherRecords: const [],
      locationRecords: const [],
      warehouse: const WarehouseSyncBundle(),
      macros: const [],
      customHolidays: const [],
      exportedAt: exportedAt,
      deviceId: 'device-a',
      contentSha256: '',
      partnerTimetableBinding: binding,
      includesPartnerTimetableBinding: true,
    );
    final payloadWithoutHash = {
      'app': 'mikcb',
      'schemaVersion': AppSyncSnapshotService.schemaVersion,
      'backupType': AppSyncSnapshotService.backupType,
      'exportedAt': exportedAt.toIso8601String(),
      'deviceId': 'device-a',
      'activeProfileId': 'profile-1',
      'profiles': snapshot.profiles.map((profile) => profile.toJson()).toList(),
      'timeSchemes': const <dynamic>[],
      'locationTimeGroups': const <dynamic>[],
      'teacherRecords': const <String>[],
      'locationRecords': const <String>[],
      'warehouse': {
        ...snapshot.warehouse.toJson(),
        'macros': const <dynamic>[],
      },
      'customHolidays': const <dynamic>[],
      'partnerTimetableBinding': binding.toJson(),
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
        partnerTimetableBinding: binding,
        includesPartnerTimetableBinding: true,
      ),
    );
    final parsed = service.parseSnapshotJson(json);

    expect(parsed.includesPartnerTimetableBinding, isTrue);
    expect(parsed.partnerTimetableBinding?.partnerName, '小明的课表');
    expect(parsed.partnerTimetableBinding?.weekOffset, 1);
    expect(parsed.partnerTimetableBinding?.mineColorHex, '#FF5722');
    expect(
      parsed.profiles.any((profile) => profile.id == 'partner-imported'),
      isTrue,
    );
  });

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
