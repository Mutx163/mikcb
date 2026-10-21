import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_task_band_logic.dart';
import 'package:university_timetable/models/course_task.dart';

/// 作业表单「打开时的默认状态」（2026-10-21）。
///
/// 这个页面同时是**新建 / 从课程加 / 编辑**三个入口的同一个页面。默认值选错，
/// 用户每次都要多付一次代价，而错得最狠的那一档（键盘吃掉半屏、加完看不见）
/// 只有渲染层才看得见。判据本身是纯函数，在这里直接钉住。
void main() {
  group('shouldAutofocusTitle：只有纯新建才抢焦点', () {
    test('纯新建（无编辑、无课程上下文）→ 抢焦点', () {
      expect(
        TaskFormDefaults.shouldAutofocusTitle(
          isEditing: false,
          hasInitialCourse: false,
          hasInitialWeek: false,
        ),
        isTrue,
        reason: '用户进这个页面唯一动作就是打字，替他把「先点一下」省掉',
      );
    });

    test('从课程加作业 → 不抢焦点', () {
      expect(
        TaskFormDefaults.shouldAutofocusTitle(
          isEditing: false,
          hasInitialCourse: true,
          hasInitialWeek: true,
        ),
        isFalse,
        reason: '表单已预填，实测 360x640 屏 + 300dp 键盘会遮住'
            '来源课程 / 截止日期 / 已完成 三行',
      );
    });

    test('只给课程不给周次 → 也不抢', () {
      expect(
        TaskFormDefaults.shouldAutofocusTitle(
          isEditing: false,
          hasInitialCourse: true,
          hasInitialWeek: false,
        ),
        isFalse,
      );
    });

    test('只给周次不给课程 → 也不抢', () {
      expect(
        TaskFormDefaults.shouldAutofocusTitle(
          isEditing: false,
          hasInitialCourse: false,
          hasInitialWeek: true,
        ),
        isFalse,
      );
    });

    test('编辑已有作业 → 不抢焦点', () {
      expect(
        TaskFormDefaults.shouldAutofocusTitle(
          isEditing: true,
          hasInitialCourse: false,
          hasInitialWeek: false,
        ),
        isFalse,
        reason: '编辑时最常见的动作是勾完成 / 挪日期，未必是改标题',
      );
    });

    test('编辑且带课程上下文 → 同样不抢', () {
      expect(
        TaskFormDefaults.shouldAutofocusTitle(
          isEditing: true,
          hasInitialCourse: true,
          hasInitialWeek: true,
        ),
        isFalse,
      );
    });
  });

  group('initialDueDate：新建默认今天，编辑不覆盖', () {
    final today = DateTime(2026, 10, 21, 15, 30);
    final todayOnly = CourseTask.dateOnly(today);

    test('新建 + 无课程上下文 → 今天', () {
      expect(
        TaskFormDefaults.initialDueDate(
          editingDueDate: null,
          courseOccurrenceDate: null,
          isEditing: false,
          today: today,
        ),
        todayOnly,
        reason: '无日期的作业在日视图与「今日」里都不可见，'
            '默认今天才能让「记今天的事」立刻成立',
      );
    });

    test('新建 + 有课程日期 → 用那节课的日期，不是今天', () {
      expect(
        TaskFormDefaults.initialDueDate(
          editingDueDate: null,
          courseOccurrenceDate: DateTime(2026, 11, 3),
          isEditing: false,
          today: today,
        ),
        DateTime(2026, 11, 3),
        reason: '从某节课加作业，交作业的日子就是那节课那天',
      );
    });

    test('编辑 + 原有日期 → 原样沿用，不改成今天', () {
      expect(
        TaskFormDefaults.initialDueDate(
          editingDueDate: DateTime(2026, 11, 20),
          courseOccurrenceDate: DateTime(2026, 11, 3),
          isEditing: true,
          today: today,
        ),
        DateTime(2026, 11, 20),
        reason: '用户可能自己关掉了 deadline，打开编辑页又给他填回来等于替他改数据',
      );
    });

    test('编辑 + 原本就没有日期 → 保持没有（不被补成今天）', () {
      expect(
        TaskFormDefaults.initialDueDate(
          editingDueDate: null,
          courseOccurrenceDate: null,
          isEditing: true,
          today: today,
        ),
        isNull,
      );
    });

    test('带时分秒的 today 会被归一成当天零点', () {
      final result = TaskFormDefaults.initialDueDate(
        editingDueDate: null,
        courseOccurrenceDate: null,
        isEditing: false,
        today: today,
      );
      expect(result, todayOnly);
      expect(result!.hour, 0);
      expect(result.minute, 0);
    });
  });
}
