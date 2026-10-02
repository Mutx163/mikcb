import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_followup_sheets.dart';

import '../helpers_test_app.dart';

/// 回归钉（2026-10-02 审查第 6 轮，改课弹层的节次选择范围）：
///
/// `course_followup_sheets.dart:308` 的 `_sectionNumbers` 用的是
/// `widget.settings.sectionCount`（**全局**节数），而同一个弹层里
/// - 预览钟点 `_timeRangeForSections`（:342）读 `widget.sectionTimes`，
/// - 调用方传的是课程解析后的那份节次表
///   （`timetable_screen.dart:9153-9158`：`resolvedSectionsForCourse(course) ?? scheme?.sections ?? settings.sections`），
/// - 确认写回时 `validateCourseTimeSchemeOverride`（provider:2281 起）同样按这门课
///   自己的作息模板判越界。
///
/// 于是钉了别的作息模板（`timeSchemeIdOverride`）的课，选择范围与判据不是同一份表：
/// 模板比全局长 → 那几节根本选不到（"这门课明明有第 10 节，弹层里选不了"）；
/// 模板比全局短 → 能选到越界节次，此时预览的目标时间行整条消失、「→ …」那行回落到
/// *原课* 的钟点（看着像改成功），点确认才被 provider 抛错拒绝。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<SectionTime> scheme(int count) => [
    for (var i = 0; i < count; i++)
      SectionTime(
        startTime: '0${(i % 9) + 1}:00',
        endTime: '0${(i % 9) + 1}:45',
      ),
  ];

  final course = Course(
    id: 'reschedule-course',
    name: '晚自习',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '07:00',
    endTime: '07:45',
    timeSchemeIdOverride: 'scheme-long',
  );

  Future<void> openSheet(
    WidgetTester tester, {
    required TimetableSettings settings,
    required List<SectionTime> sectionTimes,
  }) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCourseRescheduleSheet(
              context,
              course: course,
              sourceWeek: 1,
              settings: settings,
              weekDays: const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
              sectionTimes: sectionTimes,
              locationSuggestions: const ['A101'],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('调本周这节课'), findsOneWidget);
    // 节次字段是 Text.rich（label 与 value 拼在一个富文本里），find.text 找不到，
    // 只能按 TextSpan 的合并文本匹配。
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText().contains('开始节次') == true,
      ),
    );
    await tester.pumpAndSettle();
  }

  TimetableSettings settingsWith(int sectionCount) {
    // `sectionCount` 是 `sections.length` 的派生 getter（timetable_settings.dart:3395），
    // 所以只能靠节次表本身决定全局节数。
    return TimetableSettings.defaults().copyWith(
      sections: scheme(sectionCount),
    );
  }

  testWidgets('课程自己的作息模板比全局长时，多出来的节次可选', (tester) async {
    await openSheet(
      tester,
      settings: settingsWith(8),
      sectionTimes: scheme(12),
    );

    expect(find.text('第 12 节'), findsOneWidget);
    expect(find.text('第 9 节'), findsOneWidget);
  });

  testWidgets('课程自己的作息模板比全局短时，越界节次不该出现在选项里', (
    tester,
  ) async {
    await openSheet(
      tester,
      settings: settingsWith(12),
      sectionTimes: scheme(8),
    );

    expect(find.text('第 9 节'), findsNothing);
    expect(find.text('第 8 节'), findsOneWidget);
  });

  testWidgets('节次表缺失时退回全局节数（不因空列表把选择器清空）', (tester) async {
    await openSheet(
      tester,
      settings: settingsWith(10),
      sectionTimes: const [],
    );

    expect(find.text('第 10 节'), findsOneWidget);
  });
}
