import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';

void main() {
  test('backup json preserves profile name', () {
    final service = DataTransferService();
    final task = CourseTask(
      id: 'task-1',
      title: '完成作业',
      dueDate: DateTime(2026, 4, 7),
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );
    final schedule = ScheduleItem(
      id: 'schedule-1',
      title: '固定自习',
      startDate: DateTime(2026, 4, 7),
      endDate: DateTime(2026, 5, 7),
      startTime: '19:00',
      endTime: '20:00',
      recurrence: ScheduleRecurrence.weekly,
      exceptionDates: [DateTime(2026, 4, 14)],
      reminderMinutesBefore: 15,
      enabled: false,
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );
    final json = service.buildBackupJson(
      profileName: '大二下',
      courses: const [],
      tasks: [task],
      scheduleItems: [schedule],
      settings: TimetableSettings.defaults(),
      currentWeek: 3,
    );

    final backup = service.parseBackupJson(json);

    expect(backup.profileName, '大二下');
    expect(backup.currentWeek, 3);
    expect(backup.tasks.single.title, '完成作业');
    expect(backup.scheduleItems.single.recurrence, ScheduleRecurrence.weekly);
    expect(backup.scheduleItems.single.exceptionDates, [DateTime(2026, 4, 14)]);
    expect(backup.scheduleItems.single.reminderMinutesBefore, 15);
    expect(backup.scheduleItems.single.enabled, isFalse);
  });

  test('backup json clamps current week to semester week count', () {
    final service = DataTransferService();
    final json = service.buildBackupJson(
      profileName: '大二下',
      courses: const [],
      settings: TimetableSettings.defaults().copyWith(semesterWeekCount: 16),
      currentWeek: 20,
    );

    final backup = service.parseBackupJson(json);

    expect(backup.currentWeek, 16);
  });

  test('backup parser skips malformed optional entries', () {
    final service = DataTransferService();
    final json = service.buildBackupJson(
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    final payload = Map<String, dynamic>.from(jsonDecode(json) as Map)
      ..['courses'] = ['bad']
      ..['tasks'] = [42]
      ..['scheduleItems'] = ['bad']
      ..['exams'] = [null]
      ..['timeSchemes'] = ['bad']
      ..['scheduleDateRules'] = [null]
      ..['locationTimeGroups'] = [42];

    final backup = service.parseBackupJson(jsonEncode(payload));
    expect(backup.courses, isEmpty);
    expect(backup.tasks, isEmpty);
    expect(backup.scheduleItems, isEmpty);
    expect(backup.exams, isEmpty);
    expect(backup.timeSchemes, isEmpty);
    expect(backup.scheduleDateRules, isEmpty);
    expect(backup.locationTimeGroups, isEmpty);
  });

  test('full backup parser rejects completely malformed core lists', () {
    final service = DataTransferService();
    final json = service.buildFullBackupJson(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '默认课表',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 1,
          createdAt: DateTime(2026, 3, 22),
          lastUsedAt: DateTime(2026, 3, 22),
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: const [],
    );
    final payload = Map<String, dynamic>.from(jsonDecode(json) as Map)
      ..['profiles'] = ['bad']
      ..['timeSchemes'] = ['bad'];

    expect(
      () => service.parseFullBackupJson(jsonEncode(payload)),
      throwsA(isA<FormatException>()),
    );
  });

  test('full backup json preserves profiles and time schemes', () {
    final service = DataTransferService();
    final json = service.buildFullBackupJson(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '大二下',
          courses: const [],
          tasks: [
            CourseTask(
              id: 'task-1',
              title: '准备展示',
              createdAt: DateTime(2026, 3, 22, 8),
              updatedAt: DateTime(2026, 3, 22, 9),
            ),
          ],
          settings: TimetableSettings.defaults(),
          currentWeek: 5,
          createdAt: DateTime(2026, 3, 22, 8),
          lastUsedAt: DateTime(2026, 3, 22, 9),
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: [
        TimeScheme(
          id: 'scheme-1',
          name: '本校作息',
          sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
          createdAt: DateTime(2026, 3, 22, 8),
          updatedAt: DateTime(2026, 3, 22, 9),
        ),
      ],
    );

    final backup = service.parseFullBackupJson(json);

    expect(backup.activeProfileId, 'profile-1');
    expect(backup.profiles.single.name, '大二下');
    expect(backup.profiles.single.tasks.single.title, '准备展示');
    expect(backup.timeSchemes.single.name, '本校作息');
  });
}
