import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_task_band_logic.dart';
import 'package:university_timetable/models/course_task.dart';

/// 取消截止日期之后，作业还能不能被找到（2026-10-21 用户实测报告）。
///
/// 用户操作路径：日视图加一条作业（默认今天）→ 点进去 → 关掉截止日期 →
/// 「找不到这条作业了」。
///
/// 根因不是 bug 而是设计：无 `dueDate` 的作业不归属任何一天
/// （`DayTaskBandLogic.resolve` 直接跳过），这个规则本身是对的——把它归到
/// 「今天」会让同一条在一年里重复出现 300 多次。问题在于**取消日期之后，
/// 三处入口同时失效，只剩「全部」一个档，而「全部」不是默认档**，
/// 用户没有任何线索知道它去哪了。
///
/// 修法不是把它硬塞进某一天，而是：
/// 1. 清单页在「今日」「本周」下统计被筛掉的无日期作业，给一条可点提示；
/// 2. 表单里那句提示写清「去哪找」。
void main() {
  final today = CourseTask.dateOnly(DateTime(2026, 10, 21));

  CourseTask undated({String id = 'u1', bool isCompleted = false}) => CourseTask(
    id: id,
    title: '第三章习题',
    isCompleted: isCompleted,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );

  group('无日期作业的可见性（钉住现状，说明为什么需要提示）', () {
    test('日视图待办带不显示它', () {
      final band = DayTaskBandLogic.resolve(
        tasks: [undated()],
        date: today,
      );
      expect(band.isNotEmpty, isFalse);
      expect(band.today, isEmpty);
      expect(band.overdue, isEmpty);
    });

    test('「今日」档筛不到它', () {
      expect(DayTaskBandLogic.isRelevantToday(undated(), today), isFalse);
    });

    test('「本周」档也筛不到它', () {
      expect(
        undated().isDueBetween(today, today.add(const Duration(days: 6))),
        isFalse,
      );
    });

    test('它永远不会被判成逾期（不该出现在「已逾期」里）', () {
      expect(undated().isOverdue(now: today), isFalse);
      expect(
        undated().isOverdue(now: today.add(const Duration(days: 365))),
        isFalse,
      );
    });
  });

  group('对照：有截止日期的作业在「今日」是可见的', () {
    test('今天到期的能被今日档收到', () {
      final dated = CourseTask(
        id: 'd1',
        title: '第三章习题',
        dueDate: today,
        createdAt: DateTime(2026, 10, 21),
        updatedAt: DateTime(2026, 10, 21),
      );
      expect(DayTaskBandLogic.isRelevantToday(dated, today), isTrue);
      expect(
        DayTaskBandLogic.resolve(tasks: [dated], date: today).isNotEmpty,
        isTrue,
      );
    });
  });
}
