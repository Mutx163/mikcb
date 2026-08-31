import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/transfer_package.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  const customSections = [
    SectionTime(startTime: '08:00', endTime: '08:45'),
    SectionTime(startTime: '08:55', endTime: '09:40'),
  ];

  Course buildCourse(String timeSchemeId) {
    return Course(
      id: 'transferred-course',
      name: '跨设备课程',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      timeSchemeIdOverride: timeSchemeId,
    );
  }

  test('merge maps a device-local scheme ID by section signature', () async {
    final provider = await createProvider();
    final localScheme = await provider.createTimeScheme(
      name: '目标设备模板',
      sections: customSections,
    );
    final sourceScheme = localScheme.copyWith(
      id: 'source-device-scheme',
      name: '源设备模板',
    );

    final incoming = TransferPackage(
      packageId: 'cross-device-signature-match',
      scope: TransferScope.currentTimetable,
      courses: [buildCourse(sourceScheme.id)],
      settings: TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: sourceScheme.id,
        sections: sourceScheme.sections,
      ),
      timeSchemes: [sourceScheme],
      scheduleDateRules: const [
        ScheduleDateRule(
          id: 'source-rule',
          name: '源设备规则',
          timeSchemeId: 'source-device-scheme',
          startDate: '2026-09-01',
          endDate: '2026-09-07',
        ),
      ],
      locationTimeGroups: const [
        LocationTimeGroup(
          id: 'source-location-group',
          name: '源设备地点',
          timeSchemeId: 'source-device-scheme',
        ),
      ],
    );

    final result = await UnifiedTransferService().applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );

    expect(result.applied, isTrue, reason: result.error);
    expect(provider.courses.single.timeSchemeIdOverride, localScheme.id);
    expect(provider.settings.activeTimeSchemeId, localScheme.id);
    expect(provider.scheduleDateRules.single.timeSchemeId, localScheme.id);
    expect(provider.locationTimeGroups.single.timeSchemeId, localScheme.id);
    expect(
      provider.timeSchemes.where((scheme) => scheme.id == sourceScheme.id),
      isEmpty,
    );
  });

  test(
    'merge creates and remaps a scheme absent on the target device',
    () async {
      final provider = await createProvider();
      final sourceScheme = TimeScheme(
        id: 'source-only-scheme',
        name: '源设备专属模板',
        sections: const [
          SectionTime(startTime: '10:00', endTime: '10:45'),
          SectionTime(startTime: '10:55', endTime: '11:40'),
          SectionTime(startTime: '11:50', endTime: '12:35'),
        ],
        createdAt: DateTime(2026, 8),
        updatedAt: DateTime(2026, 8),
      );

      final incoming = TransferPackage(
        packageId: 'cross-device-new-scheme',
        scope: TransferScope.currentTimetable,
        courses: [buildCourse(sourceScheme.id)],
        settings: TimetableSettings.defaults().copyWith(
          activeTimeSchemeId: sourceScheme.id,
          sections: sourceScheme.sections,
        ),
        timeSchemes: [sourceScheme],
      );

      final result = await UnifiedTransferService().applyToProvider(
        provider: provider,
        incoming: incoming,
        mode: TransferApplyMode.merge,
      );

      expect(result.applied, isTrue, reason: result.error);
      final importedScheme = provider.timeSchemes.firstWhere(
        (scheme) => scheme.name == sourceScheme.name,
      );
      expect(importedScheme.id, isNot(sourceScheme.id));
      expect(provider.courses.single.timeSchemeIdOverride, importedScheme.id);
      expect(provider.settings.activeTimeSchemeId, importedScheme.id);
    },
  );

  test('overwrite maps foreign scheme IDs before legacy restore', () async {
    final provider = await createProvider();
    final sourceScheme = TimeScheme(
      id: 'source-overwrite-scheme',
      name: '覆盖导入作息',
      sections: const [
        SectionTime(startTime: '14:00', endTime: '14:45'),
        SectionTime(startTime: '14:55', endTime: '15:40'),
      ],
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
    );
    final incoming = TransferPackage(
      packageId: 'cross-device-overwrite',
      scope: TransferScope.currentTimetable,
      courses: [buildCourse(sourceScheme.id)],
      settings: TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: sourceScheme.id,
        sections: sourceScheme.sections,
      ),
      currentWeek: 1,
      timeSchemes: [sourceScheme],
    );

    final result = await UnifiedTransferService().applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );

    expect(result.applied, isTrue, reason: result.error);
    final importedScheme = provider.timeSchemes.firstWhere(
      (scheme) => scheme.name == sourceScheme.name,
    );
    expect(provider.courses.single.timeSchemeIdOverride, importedScheme.id);
    expect(provider.settings.activeTimeSchemeId, importedScheme.id);
  });

  test(
    'week package keeps only in-week records and referenced schemes',
    () async {
      final provider = await createProvider();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: DateTime(2026, 9, 7),
          semesterWeekCount: 16,
        ),
      );
      await provider.setCurrentWeek(2);

      final inWeekScheme = await provider.createTimeScheme(
        name: '本周作息',
        sections: customSections,
      );
      final outOfWeekScheme = await provider.createTimeScheme(
        name: '其他作息',
        sections: const [SectionTime(startTime: '13:00', endTime: '13:45')],
      );
      final inWeekGroup = await provider.createLocationTimeGroup(
        name: '本周教学楼',
        timeSchemeId: inWeekScheme.id,
        keywords: const [LocationKeyword(pattern: 'A')],
      );
      final outOfWeekGroup = await provider.createLocationTimeGroup(
        name: '其他教学楼',
        timeSchemeId: outOfWeekScheme.id,
        keywords: const [LocationKeyword(pattern: 'B')],
      );
      final inWeekRule = await provider.createScheduleDateRule(
        name: '本周规则',
        timeSchemeId: inWeekScheme.id,
        startDate: '2026-09-14',
        endDate: '2026-09-20',
      );
      final outOfWeekRule = await provider.createScheduleDateRule(
        name: '其他规则',
        timeSchemeId: outOfWeekScheme.id,
        startDate: '2026-09-28',
        endDate: '2026-10-04',
      );
      final inWeekItem = ScheduleItem(
        id: 'in-week-item',
        title: '本周日程',
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 9, 15),
        startTime: '10:00',
        endTime: '11:00',
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
      );
      final outOfWeekItem = inWeekItem.copyWith(
        id: 'out-of-week-item',
        title: '其他日程',
        startDate: DateTime(2026, 9, 29),
        endDate: DateTime(2026, 9, 29),
      );
      await provider.addScheduleItem(inWeekItem);
      await provider.addScheduleItem(outOfWeekItem);
      await provider.addCourse(
        Course(
          id: 'in-week-course',
          name: '本周课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          startWeek: 2,
          endWeek: 2,
        ),
      );
      await provider.addCourse(
        Course(
          id: 'out-of-week-course',
          name: '其他课程',
          teacher: '李老师',
          location: 'B201',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 1,
          startTime: '13:00',
          endTime: '13:45',
          startWeek: 4,
          endWeek: 4,
        ),
      );

      final package = UnifiedTransferService().buildCurrentPackage(
        provider: provider,
        scope: TransferScope.weekTimetable,
      );

      expect(package.courses.map((course) => course.id), ['in-week-course']);
      expect(package.scheduleItems.map((item) => item.id), ['in-week-item']);
      expect(package.scheduleDateRules.map((rule) => rule.id), [
        inWeekRule.rule.id,
      ]);
      expect(package.locationTimeGroups.map((group) => group.id), [
        inWeekGroup.id,
      ]);
      expect(
        package.timeSchemes.map((scheme) => scheme.id),
        contains(inWeekScheme.id),
      );
      expect(
        package.timeSchemes.map((scheme) => scheme.id),
        isNot(contains(outOfWeekScheme.id)),
      );
      expect(
        package.scheduleDateRules.map((rule) => rule.id),
        isNot(contains(outOfWeekRule.rule.id)),
      );
      expect(
        package.locationTimeGroups.map((group) => group.id),
        isNot(contains(outOfWeekGroup.id)),
      );
    },
  );
}
