import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/services/exam_reminder_service.dart';

/// 提醒调度的两个静默失效路径（2026-10-02 审查）。
///
/// 1. **重复投递**：Dart 侧重建提醒表时保留「响点在未来 30 秒宽限以外」的所有
///    条目，即 `fireAt ∈ (now-30s, now]` 仍然照发。刚弹出过一次的那条已经从原生
///    快照里删掉了，但改一节课就会 `_syncExamReminders` 重建整张表，30 秒内重建
///    时它还在窗口内 → 原生 `futureFires`（ExamReminderScheduler.kt:87）把它排到
///    一个过去时刻，AlarmManager 立刻再投一次。代码里那句注释
///    （「reconstructing past points here would cause duplicates」）说的正是这件事，
///    实现却和注释相反。
/// 2. **requestCode 碰撞**：`stableRequestCode` 只留 24 位（`& 0x00ffffff`）。
///    碰撞后两条 PendingIntent 身份相同、`FLAG_UPDATE_CURRENT` 让后写入的那条
///    整体顶掉前一条的触发时刻，那条更早的提醒就再也不会响。
///    规模实测（见下面第一个用例的搜索）：`schedule:<uuid>#<date>` 形状的键在
///    4000 条并发 fire 时零碰撞、10000 条约 2 次、30000 条约 37 次，所以这一条
///    属**加固**，需要几十条按天重复并带多个提前量的日程铺满一年才会碰到；
///    消解逻辑本身是集合确定且零副作用的，故保留。
void main() {
  Course buildCourse() {
    return Course(
      id: 'course-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );
  }

  ExamReminderFire buildFire(String examId, int offsetMinutes, int fireAtMillis) {
    return ExamReminderFire(
      examId: examId,
      offsetMinutes: offsetMinutes,
      fireAtMillis: fireAtMillis,
      examStartMillis: fireAtMillis + offsetMinutes * 60000,
      title: '提醒',
      body: '',
      requestCode: ExamReminderService.stableRequestCode(examId, offsetMinutes),
    );
  }

  group('不再重投刚刚响过的点', () {
    test('日程响点过期 10 秒后不再被重建', () {
      final items = [
        ScheduleItem(
          id: 's1',
          title: '每日自习',
          startDate: DateTime(2026, 7, 10),
          endDate: DateTime(2026, 7, 12),
          startTime: '09:00',
          endTime: '10:00',
          recurrence: ScheduleRecurrence.daily,
          reminderMinutesBefore: 10,
          createdAt: DateTime(2026, 7),
          updatedAt: DateTime(2026, 7),
        ),
      ];
      // 07-10 的响点是 08:50:00，现在 08:50:10 —— 它刚响过 10 秒。
      final fires = ExamReminderService.buildScheduleFires(
        scheduleItems: items,
        now: DateTime(2026, 7, 10, 8, 50, 10),
      );

      expect(
        fires.map((f) => f.fireAtMillis).toList(),
        [
          DateTime(2026, 7, 11, 8, 50).millisecondsSinceEpoch,
          DateTime(2026, 7, 12, 8, 50).millisecondsSinceEpoch,
        ],
        reason: '已经响过的点不能重建回去，否则原生会立刻再投一次',
      );
    });

    test('考试响点过期 10 秒后不再被重建', () {
      final exam = Exam(
        id: 'exam-1',
        courseId: 'course-1',
        name: '期末考试',
        dateTime: DateTime(2026, 7, 20),
        startTime: '08:30',
        endTime: '10:30',
        location: 'A-301',
        seatNumber: '12',
        reminderPreset: ExamReminderPreset.hour1,
        customReminderMinutes: const [],
        createdAt: DateTime(2026, 4),
        updatedAt: DateTime(2026, 4),
      );
      // 唯一响点 = 08:30 前 1 小时 = 07:30:00，现在 07:30:10。
      final fires = ExamReminderService.buildFires(
        exams: [exam],
        resolveCourse: (_) => buildCourse(),
        now: DateTime(2026, 7, 20, 7, 30, 10),
      );

      expect(fires, isEmpty);
    });
  });

  group('requestCode 碰撞消解', () {
    test('散列空间确实会碰撞（用真实 id 形状搜出一对同码键）', () {
      // 固定种子：搜索过程与结果都是确定的，不会今天绿明天红。
      final random = Random(20261002);
      String hex(int n) =>
          List.generate(n, (_) => random.nextInt(16).toRadixString(16)).join();
      String uuidLike() =>
          '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';

      final seen = <int, String>{};
      String? first;
      String? second;
      for (var i = 0; i < 40000 && second == null; i++) {
        // 与 _scheduleFireId 同形状：日程实例的 fire id 是 `schedule:<itemId>#<日期>`。
        final id = 'schedule:${uuidLike()}#${20260101 + i}';
        final code = ExamReminderService.stableRequestCode(id, 30);
        final previous = seen[code];
        if (previous != null) {
          first = previous;
          second = id;
        } else {
          seen[code] = id;
        }
      }

      expect(
        second,
        isNotNull,
        reason: 'stableRequestCode 只留 24 位，几万个 schedule 键必然出现同码',
      );
      expect(
        ExamReminderService.stableRequestCode(first!, 30),
        ExamReminderService.stableRequestCode(second!, 30),
      );

      final assigned = ExamReminderService.assignDistinctRequestCodes([
        buildFire(first, 30, 1),
        buildFire(second, 30, 2),
      ]);

      expect(assigned.map((f) => f.requestCode).toSet(), hasLength(2));
      // 消解只动碰撞的那一条，另一条保持原生散列值（原生侧按存量码取消，
      // 编码集合稳定才能让「改一条提醒」不牵动其它提醒的 PendingIntent）。
      final lexicallyFirst = [first, second]..sort();
      expect(
        assigned
            .firstWhere((f) => f.examId == lexicallyFirst.first)
            .requestCode,
        ExamReminderService.stableRequestCode(lexicallyFirst.first, 30),
      );
    });

    test('映射只取决于集合本身，与拼装顺序无关', () {
      final ids = [for (var i = 0; i < 3000; i++) 'schedule:occ-$i'];
      final fires = [
        for (var i = 0; i < ids.length; i++)
          buildFire(ids[i], 30, 1_000_000 + i * 60_000),
      ];

      final assigned = ExamReminderService.assignDistinctRequestCodes(fires);
      final reversed = ExamReminderService.assignDistinctRequestCodes(
        fires.reversed.toList(),
      );

      expect(assigned.map((f) => f.requestCode).toSet(), hasLength(3000));
      expect(assigned, hasLength(3000));
      for (final fire in assigned) {
        expect(
          reversed.firstWhere((f) => f.examId == fire.examId).requestCode,
          fire.requestCode,
          reason: '同一批提醒每次重建必须拿到同一套编码',
        );
      }
      // 输出仍按响点升序（原生与既有测试都依赖这个形状）。
      for (var i = 1; i < assigned.length; i++) {
        expect(
          assigned[i].fireAtMillis >= assigned[i - 1].fireAtMillis,
          isTrue,
        );
      }
    });

    test('消解后其余字段原样保留', () {
      final original = buildFire('exam-9', 45, 123456789);
      final assigned = ExamReminderService.assignDistinctRequestCodes([
        original,
      ]);

      expect(assigned.single.examId, 'exam-9');
      expect(assigned.single.offsetMinutes, 45);
      expect(assigned.single.fireAtMillis, 123456789);
      expect(assigned.single.examStartMillis, original.examStartMillis);
      expect(assigned.single.title, '提醒');
      expect(assigned.single.requestCode, original.requestCode);
    });
  });
}
