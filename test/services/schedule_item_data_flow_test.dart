import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_sync_snapshot_service.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

void main() {
  final item = ScheduleItem(
    id: 'agenda-1',
    title: '跨日活动',
    location: 'B201',
    note: '保留起止日期',
    startDate: DateTime(2026, 4, 16),
    endDate: DateTime(2026, 4, 18),
    startTime: '18:00',
    endTime: '19:30',
    color: '#123456',
    createdAt: DateTime(2026, 4),
    updatedAt: DateTime(2026, 4, 2),
    recurrence: ScheduleRecurrence.weekly,
    exceptionDates: [DateTime(2026, 4, 23)],
    seriesId: 'agenda-series',
    occurrenceDate: DateTime(2026, 4, 16),
  );

  TimetableProfile buildProfile() {
    return TimetableProfile(
      id: 'profile-1',
      name: '主课表',
      courses: const [],
      scheduleItems: [item],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: DateTime(2026, 4),
      lastUsedAt: DateTime(2026, 4, 2),
    );
  }

  void expectScheduleItemPreserved(TimetableProfile profile) {
    final restored = profile.scheduleItems.single;
    expect(restored.id, item.id);
    expect(restored.title, item.title);
    expect(restored.location, item.location);
    expect(restored.note, item.note);
    expect(restored.startDate, item.startDate);
    expect(restored.endDate, item.endDate);
    expect(restored.startTime, item.startTime);
    expect(restored.endTime, item.endTime);
    expect(restored.color, item.color);
    expect(restored.recurrence, item.recurrence);
    expect(restored.exceptionDates, item.exceptionDates);
    expect(restored.seriesId, item.seriesId);
    expect(restored.occurrenceDate, item.occurrenceDate);
  }

  test('profile JSON preserves schedule item range fields', () {
    final restored = TimetableProfile.fromJson(buildProfile().toJson());

    expectScheduleItemPreserved(restored);
  });

  test('lenient stored profile parsing preserves schedule item fields', () {
    final parsed = TimetableProfile.parseProfilesPayload([
      buildProfile().toJson(),
    ]);

    expect(parsed.didDrop, isFalse);
    expectScheduleItemPreserved(parsed.profiles.single);
  });

  test('full backup JSON preserves schedule items inside profiles', () {
    final service = DataTransferService();
    final json = service.buildFullBackupJson(
      profiles: [buildProfile()],
      activeProfileId: 'profile-1',
      timeSchemes: const [],
    );

    final restored = service.parseFullBackupJson(json);

    expectScheduleItemPreserved(restored.profiles.single);
  });

  test('sync snapshot JSON preserves schedule items inside profiles', () {
    final service = AppSyncSnapshotService();
    final exportedAt = DateTime(2026, 4, 2);
    final snapshot = AppSyncSnapshot(
      profiles: [buildProfile()],
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
    );

    final restored = service.parseSnapshotJson(
      service.buildSnapshotJsonFromSnapshot(snapshot),
    );

    expectScheduleItemPreserved(restored.profiles.single);
  });
}
