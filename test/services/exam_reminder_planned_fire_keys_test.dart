import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/services/exam_reminder_service.dart';

/// 逾期未投递的提醒必须留在"计划键"里（第 32 轮）。
///
/// Dart 与 Kotlin 各指认对方兜底：
/// - `exam_reminder_service.dart` 的 `buildFires` / `buildScheduleFires` 刻意只收
///   **严格未来**的响点，注释写着"原生另有 failedOverdueFires 通道专门重试"；
/// - 原生 `ExamReminderScheduler.kt:112-131` 判一条逾期未投递的 fire 要不要重试，
///   用的正是 `fireKey(fire) in activeFireKeys`，而那个键集来自
///   `buildActiveFireKeys(fires)`（:436）—— 就是那份"只含未来"的列表。
///
/// 已过期的响点永远不在里面 → `isActive == false` → 整条被 `persistFires`(:134)
/// 覆盖掉。后果：通知权限被拒 / 勿扰 / 渠道静音时没弹出去的那条考试提醒，
/// 在下一次冷启动 reconcile 时永久消失，用户既没收到提醒也没有任何提示。
void main() {
  Course? noCourse(Exam exam) => null;

  Exam oneHourPresetExam() {
    return Exam(
      id: 'exam-1',
      courseId: 'course-1',
      name: '期末考试',
      dateTime: DateTime(2026, 7, 20),
      startTime: '08:30',
      endTime: '10:30',
      location: 'A-301',
      seatNumber: '12',
      reminderPreset: ExamReminderPreset.hour1,
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );
  }

  group('buildPlannedFireKeys 覆盖已到点、但可能没弹出去的提前量', () {
    test('响点已过 10 秒：不投它，但键要留在计划里', () {
      // 唯一响点 = 08:30 前 1 小时 = 07:30:00，现在 07:30:10，考试 10:30 才结束。
      final now = DateTime(2026, 7, 20, 7, 30, 10);

      // 投递列表仍然只有严格未来（这条既有行为不能变，否则刚响过的会立刻重投）。
      expect(
        ExamReminderService.buildFires(
          exams: [oneHourPresetExam()],
          resolveCourse: noCourse,
          now: now,
        ),
        isEmpty,
      );

      expect(
        ExamReminderService.buildPlannedFireKeys(
          exams: [oneHourPresetExam()],
          resolveCourse: noCourse,
          now: now,
        ),
        contains('exam-1#60'),
        reason: '键不在计划里 = 原生那条"逾期未投递重试一次"的通道永远拿不到货',
      );
    });

    test('用户改了提前量后，旧的那条仍然判为不活跃', () {
      // hour1 预设 → 计划里只有 #60；原生里残留的 #30 不该被重试。
      final keys = ExamReminderService.buildPlannedFireKeys(
        exams: [oneHourPresetExam()],
        resolveCourse: noCourse,
        now: DateTime(2026, 7, 20, 7, 0),
      );

      expect(keys, contains('exam-1#60'));
      expect(keys, isNot(contains('exam-1#30')));
    });

    test('考试已经结束了就不再重试', () {
      final keys = ExamReminderService.buildPlannedFireKeys(
        exams: [oneHourPresetExam()],
        resolveCourse: noCourse,
        now: DateTime(2026, 7, 20, 11, 0),
      );

      expect(keys, isEmpty);
    });
  });

  test('接线棘：reconcile 必须把计划键而不是投递列表交给原生', () {
    final source = File(
      'lib/services/exam_reminder_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('activeFireKeys: buildPlannedFireKeys('),
      reason: '还交 buildActiveFireKeys(fires) 的话，重试通道依旧是空的',
    );
    expect(
      RegExp('activeFireKeys: buildActiveFireKeys\\(fires\\)').hasMatch(source),
      isFalse,
    );
  });
}
