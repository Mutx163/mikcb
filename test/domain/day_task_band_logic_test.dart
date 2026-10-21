import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_task_band_logic.dart';
import 'package:university_timetable/models/course_task.dart';

/// 日视图待办带的分档与排序。
///
/// 期望值全部**人手推**：给一组任务、一个目标日期，按口径算「哪些该出现、
/// 出现在哪一档、顺序是什么」。不从实现里反抄——那样两边错得一样还是绿的。
///
/// 日期一律取未来的固定日（2026-06-15 周一），不用「今天」：用今天会让用例
/// 在当天某个钟点后翻红（本仓 `exam` 那条踩过一次，见 TEST-POLICY）。
CourseTask _task({
  required String id,
  required DateTime? dueDate,
  bool isCompleted = false,
  String? courseId,
  String title = '作业',
  DateTime? createdAt,
}) {
  final stamp = createdAt ?? DateTime(2026, 6, 1, 9);
  return CourseTask(
    id: id,
    title: title,
    courseId: courseId,
    dueDate: dueDate,
    isCompleted: isCompleted,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

void main() {
  final targetDay = DateTime(2026, 6, 15);

  test('今天到期未完成 → today 档', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [_task(id: 'a', dueDate: targetDay)],
      date: targetDay,
    );

    expect(data.today, hasLength(1));
    expect(data.today.single.task.id, 'a');
    expect(data.overdue, isEmpty);
    expect(data.completed, isEmpty);
    expect(data.isNotEmpty, isTrue);
  });

  test('逾期未完成 → overdue 档，不进 today 档', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [_task(id: 'late', dueDate: DateTime(2026, 6, 12))],
      date: targetDay,
    );

    expect(data.overdue, hasLength(1));
    expect(data.overdue.single.task.id, 'late');
    expect(data.overdue.single.overdueDays, 3, reason: '6-15 减 6-12 = 3 天');
    expect(data.today, isEmpty, reason: '逾期与今天是互斥的两档，不能同时出现');
  });

  test('今天到期但已完成 → completed 档，不进 today 档', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'done', dueDate: targetDay, isCompleted: true),
      ],
      date: targetDay,
    );

    expect(data.completed, hasLength(1));
    expect(data.completed.single.task.id, 'done');
    expect(data.today, isEmpty, reason: '已完成不能算今天的行动项');
    expect(data.actionableCount, 0, reason: '摘要卡只数还没做的');
  });

  test('无 dueDate 的任务一个档都不进', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [_task(id: 'nodate', dueDate: null)],
      date: targetDay,
    );

    expect(data, isNotNull);
    expect(data.isEmpty, isTrue, reason: '无日期归到某天会让它在一年里重复 300 多次');
    expect(data.visibleCount, 0);
  });

  test('未来到期不在这条带里（那是「以后要交的」）', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [_task(id: 'future', dueDate: DateTime(2026, 6, 20))],
      date: targetDay,
    );

    expect(data.isEmpty, isTrue);
  });

  test('别的日期到期的已完成任务不出现在今天', () {
    // 昨天交的作业只在昨天的日视图留记录，今天不该再看见。
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'done-yesterday', dueDate: DateTime(2026, 6, 14), isCompleted: true),
      ],
      date: targetDay,
    );

    expect(data.isEmpty, isTrue);
  });

  test('逾期超过 3 条时折叠，只留最早到期的 3 条', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'd-10', dueDate: DateTime(2026, 6, 10)),
        _task(id: 'd-11', dueDate: DateTime(2026, 6, 11)),
        _task(id: 'd-12', dueDate: DateTime(2026, 6, 12)),
        _task(id: 'd-13', dueDate: DateTime(2026, 6, 13)),
        _task(id: 'd-14', dueDate: DateTime(2026, 6, 14)),
      ],
      date: targetDay,
    );

    expect(data.overdue, hasLength(DayTaskBandLogic.maxOverdueRows));
    expect(
      data.overdue.map((row) => row.task.id),
      ['d-10', 'd-11', 'd-12'],
      reason: '欠得最久的先看见',
    );
    expect(data.hiddenOverdueCount, 2);
    expect(data.visibleCount, 3, reason: 'visibleCount 不含被折叠的');
  });

  test('逾期折叠不改变「还要做几件事」的总数口径', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'd-10', dueDate: DateTime(2026, 6, 10)),
        _task(id: 'd-11', dueDate: DateTime(2026, 6, 11)),
        _task(id: 'd-12', dueDate: DateTime(2026, 6, 12)),
        _task(id: 'd-13', dueDate: DateTime(2026, 6, 13)),
        _task(id: 'today-1', dueDate: targetDay),
      ],
      date: targetDay,
    );

    expect(data.today, hasLength(1));
    expect(data.overdue, hasLength(3));
    expect(data.hiddenOverdueCount, 1);
    expect(
      data.actionableCount,
      4,
      reason: '逾期 3 条可见 + 今天 1 条；被折叠的那条仍算「欠着」',
    );
  });

  test('今天到期：有课程关联的排在无关联之前', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(
          id: 'loose',
          dueDate: targetDay,
          createdAt: DateTime(2026, 6),
        ),
        _task(
          id: 'course',
          dueDate: targetDay,
          courseId: 'c1',
          createdAt: DateTime(2026, 6, 2),
        ),
      ],
      date: targetDay,
    );

    expect(
      data.today.map((row) => row.task.id),
      ['course', 'loose'],
      reason: '「哪门课的作业」比随手记的一件事有更多上下文，先看见',
    );
  });

  test('今天到期：同课程按创建时间，创建时间相同按 id', () {
    final sameCreated = DateTime(2026, 6, 3);
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(
          id: 'b-later',
          dueDate: targetDay,
          courseId: 'c1',
          createdAt: DateTime(2026, 6, 5),
        ),
        _task(
          id: 'a-earlier',
          dueDate: targetDay,
          courseId: 'c1',
          createdAt: DateTime(2026, 6, 3),
        ),
        _task(
          id: 'c-tie',
          dueDate: targetDay,
          courseId: 'c1',
          createdAt: sameCreated,
        ),
        _task(
          id: 'd-tie',
          dueDate: targetDay,
          courseId: 'c1',
          createdAt: sameCreated,
        ),
      ],
      date: targetDay,
    );

    expect(
      data.today.map((row) => row.task.id),
      // 前两条按创建时间（6-3 < 6-5）；后两条创建时间相同 → 退化到 id 升序，
      // 'c-tie' < 'd-tie'，与 id 无关的稳定规则。
      ['a-earlier', 'c-tie', 'd-tie', 'b-later'],
    );
  });

  test('逾期：同日期时有课程关联的在前', () {
    final due = DateTime(2026, 6, 12);
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'loose', dueDate: due),
        _task(id: 'course', dueDate: due, courseId: 'c9'),
      ],
      date: targetDay,
    );

    expect(data.overdue.map((row) => row.task.id), ['course', 'loose']);
  });

  test('三档同时存在时各自独立，互不串档', () {
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'o1', dueDate: DateTime(2026, 6, 13)),
        _task(
          id: 'd1',
          dueDate: targetDay,
          isCompleted: true,
          createdAt: DateTime(2026, 6, 4),
        ),
        _task(id: 't1', dueDate: targetDay),
      ],
      date: targetDay,
    );

    expect(data.overdue.map((row) => row.task.id), ['o1']);
    expect(data.today.map((row) => row.task.id), ['t1']);
    expect(data.completed.map((row) => row.task.id), ['d1']);
    expect(data.actionableCount, 2, reason: '逾期 1 + 今天 1，已完成不算');
  });

  test('空列表 → empty 单例语义（isEmpty 为 true，三个档都空）', () {
    final data = DayTaskBandLogic.resolve(tasks: const [], date: targetDay);

    expect(data.isEmpty, isTrue);
    expect(data.overdue, isEmpty);
    expect(data.today, isEmpty);
    expect(data.completed, isEmpty);
    expect(data.hiddenOverdueCount, 0);
    expect(DayTaskBandData.empty.isNotEmpty, isFalse);
  });

  test('同一天跨时区的 dueDate 归一：带时分秒的 dueDate 仍算当天', () {
    // CourseTask 构造会把 dueDate 归一成 dateOnly，这里钉住那个归一对分档有效。
    final data = DayTaskBandLogic.resolve(
      tasks: [
        _task(id: 'with-time', dueDate: DateTime(2026, 6, 15, 23, 59)),
      ],
      date: targetDay,
    );

    expect(data.today, hasLength(1), reason: '23:59 到期在当天任何时刻都不算逾期');
    expect(data.overdue, isEmpty);
  });

  test('needsDefaultTitle 只对空标题为真', () {
    expect(
      DayTaskBandLogic.needsDefaultTitle(_task(id: 'x', dueDate: targetDay, title: '')),
      isTrue,
    );
    expect(
      DayTaskBandLogic.needsDefaultTitle(_task(id: 'x', dueDate: targetDay, title: '  ')),
      isTrue,
      reason: '只有空白也算空，否则卡上是看不见的空白行',
    );
    expect(
      DayTaskBandLogic.needsDefaultTitle(
        _task(id: 'x', dueDate: targetDay, title: '第三章习题'),
      ),
      isFalse,
    );
  });

  /// 清单页「今日」筛选与待办带的共用口径（2026-10-21 收口）。
  ///
  /// 原先清单页用 `isDueOn(today)` 单条判据，逾期作业在「今日」档里彻底消失
  /// ——而日视图待办带早已把逾期单列。同一个 App 里两处对「今日」的定义不同，
  /// 用户看到的是「带子上说欠着 3 项，点进清单页一条都没有」。
  group('isRelevantToday：清单页与待办带共用的「今日」口径', () {
    test('今天到期（未完成）：收', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(id: 'a', dueDate: targetDay),
          targetDay,
        ),
        isTrue,
      );
    });

    test('今天到期已完成：也收（用户要能回看「今天交了没」）', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(id: 'a', dueDate: targetDay, isCompleted: true),
          targetDay,
        ),
        isTrue,
      );
    });

    test('昨天到期未完成：收（这是原先被漏掉的那一档）', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(id: 'a', dueDate: targetDay.subtract(const Duration(days: 1))),
          targetDay,
        ),
        isTrue,
        reason: '逾期作业在「今日」里消失 = 最该看见的时候看不见',
      );
    });

    test('昨天到期已完成：不收（做完了，不是今天的行动项）', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(
            id: 'a',
            dueDate: targetDay.subtract(const Duration(days: 1)),
            isCompleted: true,
          ),
          targetDay,
        ),
        isFalse,
      );
    });

    test('明天到期：不收（那是以后的事）', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(id: 'a', dueDate: targetDay.add(const Duration(days: 1))),
          targetDay,
        ),
        isFalse,
      );
    });

    test('没有截止日：不收（无期限任务不归任何一天）', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(id: 'a', dueDate: null),
          targetDay,
        ),
        isFalse,
      );
    });

    test('时间带时分秒但仍是同一天：算今天', () {
      expect(
        DayTaskBandLogic.isRelevantToday(
          _task(id: 'a', dueDate: DateTime(2026, 6, 15, 23, 59)),
          targetDay,
        ),
        isTrue,
      );
    });

    test('与待办带逐条对齐：两边取到的作业集合完全相同', () {
      final tasks = <CourseTask>[
        _task(
          id: 'overdue',
          dueDate: targetDay.subtract(const Duration(days: 2)),
        ),
        _task(id: 'today', dueDate: targetDay),
        _task(id: 'todayDone', dueDate: targetDay, isCompleted: true),
        _task(
          id: 'oldDone',
          dueDate: targetDay.subtract(const Duration(days: 5)),
          isCompleted: true,
        ),
        _task(id: 'future', dueDate: targetDay.add(const Duration(days: 3))),
      ];

      final band = DayTaskBandLogic.resolve(tasks: tasks, date: targetDay);
      final relevantIds = tasks
          .where((task) => DayTaskBandLogic.isRelevantToday(task, targetDay))
          .map((task) => task.id)
          .toSet();
      final bandIds = <String>{
        ...band.overdue.map((row) => row.task.id),
        ...band.today.map((row) => row.task.id),
        ...band.completed.map((row) => row.task.id),
      };

      expect(relevantIds, bandIds, reason: '清单页与待办带不能对「今日」有分歧');
      expect(band.actionableCount, 2, reason: '逾期 1 + 今天未完成 1');
    });
  });
}
