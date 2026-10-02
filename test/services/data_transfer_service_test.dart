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

  // 这条钉子原本断言「畸形条目一律跳过、结果就是空列表」，而那正是数据丢失的
  // 入口：单课表导入把 `backup.courses` 整份替换进课表
  // （lib/providers/timetable/import_export_service.dart:358），一份课程全部
  // 解析不出来的 .mikcb 会被当成合法的**空课表**导入 —— 用户原课表被清空并写盘，
  // 界面报「导入成功」。现在「原始非空 / 解析全空」直接拒收（与同文件 :293 完整
  // 备份路径同款守卫）；逐条畸形仍然跳过，能救回的部分照救。
  test('backup parser rejects a list where every entry is malformed', () {
    final service = DataTransferService();
    final json = service.buildBackupJson(
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );

    for (final key in [
      'courses',
      'tasks',
      'scheduleItems',
      'exams',
      'timeSchemes',
      'scheduleDateRules',
      'locationTimeGroups',
    ]) {
      final payload = Map<String, dynamic>.from(jsonDecode(json) as Map)
        ..[key] = ['bad'];

      expect(
        () => service.parseBackupJson(jsonEncode(payload)),
        throwsFormatException,
        reason: '$key 原始非空却一条都读不出来，必须拒收而不是当成空列表',
      );
    }
  });

  test('backup parser still skips partially malformed entries', () {
    final service = DataTransferService();
    final json = service.buildBackupJson(
      courses: const [],
      tasks: [
        CourseTask(
          id: 'task-1',
          title: '完成作业',
          dueDate: DateTime(2026, 4, 7),
          createdAt: DateTime(2026, 4),
          updatedAt: DateTime(2026, 4),
        ),
      ],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    final payload = Map<String, dynamic>.from(jsonDecode(json) as Map);
    payload['tasks'] = [42, ...(payload['tasks'] as List), 'bad'];

    final backup = service.parseBackupJson(jsonEncode(payload));

    // 只要还剩一条读得出来就不是「整份清零」，逐条畸形继续跳过。
    expect(backup.tasks, hasLength(1));
    expect(backup.tasks.single.title, '完成作业');
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
