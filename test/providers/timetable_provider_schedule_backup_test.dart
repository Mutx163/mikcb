import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/schedule_item.dart';
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
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
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
}
