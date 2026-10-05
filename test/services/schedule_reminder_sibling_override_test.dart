import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/services/exam_reminder_service.dart';

/// 回归钉（2026-10-05 审查第 16 轮）：日程提醒的去重口径必须与首页展开器同一条。
///
/// `ScheduleItemExpander.putByDisplayDate` 早就改成「兄弟例外各占一键」（同一系列的
/// 两次不同例外被移到同一天时，两条都要留下），但 `exam_reminder_service` 里那份
/// 副本还在用 `sourceItemId@显示日` 覆盖式去重：界面上两张卡都在，提醒表里却只有
/// 一条 —— 被吞的那条不进 `buildScheduleActiveIds`，原生对账一看"这个 id 不在活跃
/// 集合里"就把用户已经设好的闹钟取消掉。
void main() {
  ScheduleItem build({
    required String id,
    String title = '组会',
    DateTime? startDate,
    DateTime? endDate,
    ScheduleRecurrence recurrence = ScheduleRecurrence.none,
    Iterable<DateTime> exceptionDates = const <DateTime>[],
    String? seriesId,
    DateTime? occurrenceDate,
  }) {
    final start = startDate ?? DateTime(2026, 9, 8);
    return ScheduleItem(
      id: id,
      title: title,
      startDate: start,
      endDate: endDate ?? start,
      startTime: '09:00',
      endTime: '10:00',
      recurrence: recurrence,
      exceptionDates: exceptionDates,
      seriesId: seriesId,
      occurrenceDate: occurrenceDate,
      reminderMinutesBefore: 30,
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
    );
  }

  // 2026-09-01 是周二，weekly 以开始日的星期重复：09-01 / 08 / 15 / 22 / 29。
  // 真实存储里"把某次移到别的日子"会把原日期记进 exceptionDates（否则同一次
  // 移动会同时留下原日与新日的两个实例，fire id 还完全相同），这里照此建模。
  final series = build(
    id: 'series',
    startDate: DateTime(2026, 9),
    endDate: DateTime(2026, 9, 30),
    recurrence: ScheduleRecurrence.weekly,
    exceptionDates: [DateTime(2026, 9), DateTime(2026, 9, 15)],
  );
  // 把 09-01 那次与 09-15 那次都移到 09-08 显示：两条真实存在、可分别撤销的条目。
  final movedFromSep1 = build(
    id: 'ov-a',
    title: '从 09-01 移来',
    startDate: DateTime(2026, 9, 8),
    seriesId: 'series',
    occurrenceDate: DateTime(2026, 9),
  );
  final movedFromSep15 = build(
    id: 'ov-b',
    title: '从 09-15 移来',
    startDate: DateTime(2026, 9, 8),
    seriesId: 'series',
    occurrenceDate: DateTime(2026, 9, 15),
  );
  final items = <ScheduleItem>[series, movedFromSep1, movedFromSep15];
  final now = DateTime(2026, 9, 1, 0, 30);

  DateTime startDayOf(ExamReminderFire fire) =>
      DateTime.fromMillisecondsSinceEpoch(fire.examStartMillis);

  test('移到同一显示日的两条例外，各自的提醒都要建立', () {
    final fires = ExamReminderService.buildScheduleFires(
      scheduleItems: items,
      now: now,
    );
    final onSep8 = fires
        .where(
          (fire) =>
              startDayOf(fire).year == 2026 &&
              startDayOf(fire).month == 9 &&
              startDayOf(fire).day == 8,
        )
        .toList();

    // 修复前这里只有 '从 09-01 移来' 一条：后一条在 key 相同处被覆盖式去重吞掉。
    expect(
      onSep8.map((fire) => fire.title).toSet(),
      {'从 09-01 移来', '从 09-15 移来'},
    );
  });

  test('活跃 id 集合要覆盖每一条提醒（原生按这个集合撤销闹钟）', () {
    final fires = ExamReminderService.buildScheduleFires(
      scheduleItems: items,
      now: now,
    );
    final activeIds = ExamReminderService.buildScheduleActiveIds(
      scheduleItems: items,
      now: now,
    );
    final onSep8 = fires
        .where(
          (fire) =>
              startDayOf(fire).year == 2026 &&
              startDayOf(fire).month == 9 &&
              startDayOf(fire).day == 8,
        )
        .toList();
    final movedIds = onSep8.map((fire) => fire.examId).toSet();

    // 两条被移到同一天的例外各自有一个稳定的 fire id，两个都必须在活跃集合里；
    // 少一个，原生对账就会把那条已设好的闹钟当成"不再需要"取消掉。
    expect(movedIds, hasLength(2));
    expect(activeIds, containsAll(movedIds));
    // id 不重复：同一 id 出现两次会让 requestCode 撞车，两条提醒互相顶掉。
    expect(fires.map((fire) => fire.examId).toSet(), hasLength(fires.length));
  });

  test('对照：只有一条例外时不会凭空多出一条提醒', () {
    final fires = ExamReminderService.buildScheduleFires(
      scheduleItems: <ScheduleItem>[series, movedFromSep1],
      now: now,
    );
    final onSep8 = fires
        .where(
          (fire) =>
              startDayOf(fire).year == 2026 &&
              startDayOf(fire).month == 9 &&
              startDayOf(fire).day == 8,
        )
        .toList();

    // 覆盖项压住自然展开的那一次，只剩移动来的这一条 —— 与首页卡片数量一致。
    expect(onSep8.map((fire) => fire.title).toList(), ['从 09-01 移来']);
  });
}
