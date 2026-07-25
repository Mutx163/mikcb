import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

void main() {
  final exportedAt = DateTime.utc(2026, 7, 5, 12);

  TimetableProfile factoryDefaultProfile({
    List<Course> courses = const [],
    String name = '默认课表',
    TimetableProfileKind profileKind = TimetableProfileKind.normal,
  }) {
    return TimetableProfile(
      id: 'profile-1',
      name: name,
      courses: courses,
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: exportedAt,
      lastUsedAt: exportedAt,
      profileKind: profileKind,
    );
  }

  TimeScheme singleScheme() {
    return TimeScheme(
      id: 'scheme-1',
      name: '默认作息',
      sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
      createdAt: exportedAt,
      updatedAt: exportedAt,
    );
  }

  /// Baseline first-install snapshot: one default profile, one scheme, no user data.
  AppSyncSnapshot emptyAuthoredSnapshot({
    List<TimetableProfile>? profiles,
    List<TimeScheme>? timeSchemes,
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    List<String> teacherRecords = const [],
    List<String> locationRecords = const [],
    WarehouseSyncBundle warehouse = const WarehouseSyncBundle(),
    PartnerTimetableBinding? partnerTimetableBinding,
  }) {
    return AppSyncSnapshot(
      profiles: profiles ?? [factoryDefaultProfile()],
      activeProfileId: 'profile-1',
      timeSchemes: timeSchemes ?? [singleScheme()],
      locationTimeGroups: locationTimeGroups,
      scheduleDateRules: scheduleDateRules,
      teacherRecords: teacherRecords,
      locationRecords: locationRecords,
      warehouse: warehouse,
      macros: const [],
      customHolidays: const [],
      exportedAt: exportedAt,
      deviceId: 'device-a',
      contentSha256: '',
      partnerTimetableBinding: partnerTimetableBinding,
      includesPartnerTimetableBinding: partnerTimetableBinding != null,
    );
  }

  group('AppSyncSnapshot.hasUserAuthoredData', () {
    test('false for factory-default empty snapshot', () {
      expect(emptyAuthoredSnapshot().hasUserAuthoredData, isFalse);
    });

    test('true when teacher or location records exist', () {
      expect(
        emptyAuthoredSnapshot(
          teacherRecords: const ['张老师'],
        ).hasUserAuthoredData,
        isTrue,
      );
      expect(
        emptyAuthoredSnapshot(
          locationRecords: const ['A101'],
        ).hasUserAuthoredData,
        isTrue,
      );
    });

    test('true when locationTimeGroups exist', () {
      expect(
        emptyAuthoredSnapshot(
          locationTimeGroups: [
            LocationTimeGroup(
              id: 'group-1',
              name: '主教学楼',
              timeSchemeId: 'scheme-1',
              keywords: const [LocationKeyword(pattern: 'A主')],
            ),
          ],
        ).hasUserAuthoredData,
        isTrue,
      );
    });

    test('true when scheduleDateRules list is non-empty', () {
      expect(
        emptyAuthoredSnapshot(
          scheduleDateRules: const [
            ScheduleDateRule(
              id: 'rule-1',
              name: '夏令时',
              timeSchemeId: 'scheme-1',
              startDate: '2026-05-01',
              endDate: '2026-09-30',
            ),
          ],
        ).hasUserAuthoredData,
        isTrue,
      );
    });

    test(
      'true when warehouse prefs, partner binding, or multi scheme/profile',
      () {
        expect(
          emptyAuthoredSnapshot(
            warehouse: const WarehouseSyncBundle(recentSchoolIds: ['school-a']),
          ).hasUserAuthoredData,
          isTrue,
        );
        expect(
          emptyAuthoredSnapshot(
            partnerTimetableBinding: PartnerTimetableBinding(
              partnerProfileId: 'partner-1',
              partnerName: '小明',
              linkedAt: exportedAt,
            ),
          ).hasUserAuthoredData,
          isTrue,
        );
        expect(
          emptyAuthoredSnapshot(
            timeSchemes: [
              singleScheme(),
              TimeScheme(
                id: 'scheme-2',
                name: '第二套',
                sections: const [
                  SectionTime(startTime: '09:00', endTime: '09:45'),
                ],
                createdAt: exportedAt,
                updatedAt: exportedAt,
              ),
            ],
          ).hasUserAuthoredData,
          isTrue,
        );
        expect(
          emptyAuthoredSnapshot(
            profiles: [
              factoryDefaultProfile(),
              TimetableProfile(
                id: 'profile-2',
                name: '第二课表',
                courses: const [],
                settings: TimetableSettings.defaults(),
                currentWeek: 1,
                createdAt: exportedAt,
                lastUsedAt: exportedAt,
              ),
            ],
          ).hasUserAuthoredData,
          isTrue,
        );
      },
    );

    test('true when profile has courses or renamed away from 默认课表', () {
      expect(
        emptyAuthoredSnapshot(
          profiles: [
            factoryDefaultProfile(
              courses: [
                Course(
                  id: 'c1',
                  name: '高数',
                  teacher: '张',
                  location: 'A1',
                  dayOfWeek: 1,
                  startSection: 1,
                  endSection: 2,
                  startTime: '08:00',
                  endTime: '09:40',
                  startWeek: 1,
                  endWeek: 16,
                ),
              ],
            ),
          ],
        ).hasUserAuthoredData,
        isTrue,
      );
      expect(
        emptyAuthoredSnapshot(
          profiles: [factoryDefaultProfile(name: '我的课表')],
        ).hasUserAuthoredData,
        isTrue,
      );
    });

    test('true when profile is partner-imported even without courses', () {
      expect(
        emptyAuthoredSnapshot(
          profiles: [
            factoryDefaultProfile(
              profileKind: TimetableProfileKind.partnerImported,
            ),
          ],
        ).hasUserAuthoredData,
        isTrue,
      );
    });

    test(
      'false when only default scheme is customized but profile still empty',
      () {
        // Documented gap: deep edits to the single default scheme alone do not
        // trip hasUserAuthoredData (threshold is length > 1, not content).
        expect(
          emptyAuthoredSnapshot(
            timeSchemes: [
              TimeScheme(
                id: 'scheme-1',
                name: '深度自定义',
                sections: const [
                  SectionTime(startTime: '07:30', endTime: '08:10'),
                  SectionTime(startTime: '08:20', endTime: '09:00'),
                ],
                createdAt: exportedAt,
                updatedAt: exportedAt,
              ),
            ],
          ).hasUserAuthoredData,
          isFalse,
        );
      },
    );
  });

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
        'scheduleDateRules': snapshot.scheduleDateRules
            .map((rule) => rule.toJson())
            .toList(),
        'scheduleDateRuleLastAppliedSignature': null,
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
      'scheduleDateRules': const <dynamic>[],
      'scheduleDateRuleLastAppliedSignature': null,
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
      'scheduleDateRules': const <dynamic>[],
      'scheduleDateRuleLastAppliedSignature': null,
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

  test(
    'sync snapshot strips live_test courses and keeps lastAppliedSignature',
    () {
      final service = AppSyncSnapshotService();
      final exportedAt = DateTime.utc(2026, 7, 23, 12);
      final profileWithFixtures = TimetableProfile(
        id: 'profile-1',
        name: '主课表',
        courses: [
          Course(
            id: 'live_test_01',
            name: '测试课',
            teacher: '',
            location: '',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 1,
            startTime: '08:00',
            endTime: '08:45',
          ),
          Course(
            id: 'real-course',
            name: '真实课',
            teacher: '',
            location: '',
            dayOfWeek: 2,
            startSection: 1,
            endSection: 1,
            startTime: '08:00',
            endTime: '08:45',
          ),
        ],
        settings: TimetableSettings.defaults(),
        currentWeek: 1,
        createdAt: exportedAt,
        lastUsedAt: exportedAt,
      );
      final stripped = AppSyncSnapshotService.stripLiveTestingFixtureCourses([
        profileWithFixtures,
      ]);
      expect(stripped.single.courses.map((course) => course.id), [
        'real-course',
      ]);

      final payloadWithoutHash = {
        'app': 'mikcb',
        'schemaVersion': AppSyncSnapshotService.schemaVersion,
        'backupType': AppSyncSnapshotService.backupType,
        'exportedAt': exportedAt.toIso8601String(),
        'deviceId': 'device-a',
        'activeProfileId': 'profile-1',
        'profiles': stripped.map((item) => item.toJson()).toList(),
        'timeSchemes': const <dynamic>[],
        'locationTimeGroups': const <dynamic>[],
        'scheduleDateRules': const <dynamic>[],
        'scheduleDateRuleLastAppliedSignature':
            'rule-1|scheme-1|2026-07-01|2026-08-31',
        'teacherRecords': const <String>[],
        'locationRecords': const <String>[],
        'warehouse': {
          ...const WarehouseSyncBundle().toJson(),
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
          profiles: stripped,
          activeProfileId: 'profile-1',
          timeSchemes: const [],
          teacherRecords: const [],
          locationRecords: const [],
          warehouse: const WarehouseSyncBundle(),
          macros: const [],
          customHolidays: const [],
          exportedAt: exportedAt,
          deviceId: 'device-a',
          contentSha256: hash,
          scheduleDateRuleLastAppliedSignature:
              'rule-1|scheme-1|2026-07-01|2026-08-31',
        ),
      );
      final parsed = service.parseSnapshotJson(json);
      expect(
        parsed.scheduleDateRuleLastAppliedSignature,
        'rule-1|scheme-1|2026-07-01|2026-08-31',
      );
      expect(parsed.profiles.single.courses.map((course) => course.id), [
        'real-course',
      ]);
    },
  );
}
