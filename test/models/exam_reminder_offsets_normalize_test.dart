import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/exam.dart';

/// 回归钉（2026-10-02 审查第 7 轮，考试自定义提醒偏移的读侧归一）：
///
/// 写侧有明确规则：`add_exam_screen.dart:561` 对 `totalMinutes <= 0` 直接拒绝并提示
/// `examReminderCustomInvalid`，重复值也会被挡（:575 `collidesWithOther`）。
/// 服务侧同样跳过：`exam_reminder_service.dart:345` `if (offsetMinutes <= 0) continue`。
/// 只有 `Exam.fromJson`（exam.dart:150）是裸 `as num → toInt()`，没有任何守卫 ——
/// 于是云端拉回 / 备份导入 / 局域网写入带来的 exam（`timetable_profile.dart:109`、
/// `transfer_package.dart:399` 都直接走 fromJson）可以把 0 或负数留在列表里。
///
/// 后果不是崩，而是**显示与行为互相矛盾**：考试卡的偏移标签
/// `exam_list_screen.dart:225-243 _examReminderOffsetLabel` 用
/// `(minutes % 1440) ~/ 60`，Dart 的 `%` 恒非负，`-30` 被渲染成「23 小时 + 30 分钟」，
/// 而调度侧一条通知都不会排。用户看到"考前 23 小时提醒"却永远等不到。
void main() {
  Map<String, dynamic> jsonWith(List<int> offsets) => {
    'id': 'exam-1',
    'courseId': 'course-1',
    'name': '期中高数',
    'dateTime': '2026-11-05T08:30:00',
    'startTime': '08:30',
    'endTime': '10:30',
    'location': '一教 101',
    'reminderPreset': 'custom',
    'customReminderMinutes': offsets,
  };

  test('非正数的自定义偏移在读侧被丢掉', () {
    final exam = Exam.fromJson(jsonWith([-30, 0, 45]));

    // 修复前：[-30, 0, 45] 原样留着，标签显示「23 小时 + 30 分钟」「0 分钟」。
    expect(exam.customReminderMinutes, [45]);
  });

  test('重复偏移只留一份', () {
    final exam = Exam.fromJson(jsonWith([60, 60, 1440]));

    expect(exam.customReminderMinutes, [60, 1440]);
  });

  test('合法值原样保留顺序与内容', () {
    final exam = Exam.fromJson(jsonWith([1440, 120, 30]));

    expect(exam.customReminderMinutes, [1440, 120, 30]);
  });

  test('非整数条目整条列表退回空而不是抛错', () {
    final json = jsonWith([1, 2]);
    json['customReminderMinutes'] = <Object>['x', 30];

    final exam = Exam.fromJson(json);

    expect(exam.customReminderMinutes, [30]);
  });

  test('toJson/fromJson 往返后仍是归一过的列表', () {
    final exam = Exam.fromJson(jsonWith([-10, 90]));

    expect(Exam.fromJson(exam.toJson()).customReminderMinutes, [90]);
  });
}
