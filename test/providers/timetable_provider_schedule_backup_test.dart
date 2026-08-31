import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

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

  test('single-profile backup restores recurring schedule metadata', () async {
    final provider = await createProvider();
    final schedule = ScheduleItem(
      id: 'backup-schedule',
      title: '固定自习',
      startDate: DateTime(2026, 4, 6),
      endDate: DateTime(2026, 5, 4),
      startTime: '19:00',
      endTime: '20:00',
      recurrence: ScheduleRecurrence.weekly,
      exceptionDates: [DateTime(2026, 4, 13)],
      reminderMinutesBefore: 15,
      enabled: false,
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );
    await provider.addScheduleItem(schedule);

    final content = provider.dataTransferService.buildBackupJson(
      profileName: provider.activeProfile?.name,
      courses: provider.courses,
      tasks: provider.tasks,
      scheduleItems: provider.scheduleItems,
      exams: provider.exams,
      settings: provider.settings,
      currentWeek: provider.currentWeek,
    );

    final restored = await createProvider();
    expect(await restored.importAppDataBackup(content), isNull);

    final restoredSchedule = restored.scheduleItems.single;
    expect(restoredSchedule.recurrence, ScheduleRecurrence.weekly);
    expect(restoredSchedule.exceptionDates, [DateTime(2026, 4, 13)]);
    expect(restoredSchedule.reminderMinutesBefore, 15);
    expect(restoredSchedule.enabled, isFalse);
  });

  test('full backup restore applies date rules and location groups', () async {
    final source = await createProvider();
    final scheme = await source.createTimeScheme(
      name: '备份作息',
      sections: const [SectionTime(startTime: '10:00', endTime: '10:45')],
    );
    final group = await source.createLocationTimeGroup(
      name: '备份教学楼',
      timeSchemeId: scheme.id,
      keywords: const [LocationKeyword(pattern: 'B')],
    );
    final ruleResult = await source.createScheduleDateRule(
      name: '备份日期规则',
      timeSchemeId: scheme.id,
      startDate: '2026-09-01',
      endDate: '2026-09-07',
    );
    final content = source.dataTransferService.buildFullBackupJson(
      profiles: source.profiles,
      activeProfileId: source.activeProfileId,
      timeSchemes: source.timeSchemes,
      scheduleDateRules: source.scheduleDateRules,
      locationTimeGroups: source.locationTimeGroups,
    );

    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
    final restored = await createProvider();
    expect(await restored.importFullAppDataBackup(content), isNull);

    expect(restored.scheduleDateRules.single.id, ruleResult.rule.id);
    expect(
      restored.scheduleDateRules.single.timeSchemeId,
      ruleResult.rule.timeSchemeId,
    );
    expect(restored.locationTimeGroups.single.id, group.id);
    expect(restored.locationTimeGroups.single.timeSchemeId, group.timeSchemeId);
    expect(restored.timeSchemes.any((item) => item.id == scheme.id), isTrue);

    final reloaded = await createProvider();
    expect(reloaded.scheduleDateRules.single.id, ruleResult.rule.id);
    expect(reloaded.locationTimeGroups.single.id, group.id);
  });
}
