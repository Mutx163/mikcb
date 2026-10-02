import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/widgets/course_card.dart';

import '../helpers_test_app.dart';

/// 回归钉（2026-10-02 审查第 6 轮，课卡右上角角标行）：
///
/// `course_card.dart` 有两组互斥的 Positioned：
/// - `if (topRightBadgeText != null || hasReminder)` → 只传
///   `customBadgeText` / `showReminderBell`，**从不**传 showHoliday / showSuspended；
/// - `if (isHoliday && topRightBadgeText == null && !hasReminder)` → 才画「假」。
///
/// 于是一节课同时有提醒铃铛（或备注/冲突角标）与放假标记时，「假」整条消失，
/// 卡片只剩铃铛 + 0.3 透明度。日课表就是这个组合：
/// `timetable_screen.dart:6911` 传 `hasReminder`、`:6922` 传 `isHoliday`，
/// 用户先给某节课设了单节课提醒、之后同步到该日为节假日（或课程被停课），
/// 看到的是「这节课还上」的样子，只有放假时该有的「假」字没出现。
///
/// 同文件 :263 的 `showReminderBell: hasReminder` 在 `!hasReminder` 门槛下恒为
/// false（死实参），说明作者本意是两者并排 —— `_buildBadgeRow` 也确实现成支持
/// 多枚角标并排，`hasReminder` 的文档注释写着「与备注角标并排展示」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final course = Course(
    id: 'course-holiday',
    name: '高等数学',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  Future<void> pumpCard(
    WidgetTester tester,
    CourseCard card,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: Center(
          child: SizedBox(width: 320, height: 180, child: card),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final compact in [false, true]) {
    final label = compact ? '紧凑卡（日课表）' : '完整卡';

    testWidgets('$label：放假 + 提醒铃铛时两枚角标并排', (tester) async {
      await pumpCard(
        tester,
        CourseCard(
          course: course,
          isCompact: compact,
          isHoliday: true,
          hasReminder: true,
        ),
      );

      expect(find.text('假'), findsOneWidget);
      expect(find.byIcon(Icons.alarm_on_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label：停课 + 提醒铃铛时「停」不被吞掉', (tester) async {
      await pumpCard(
        tester,
        CourseCard(
          course: course,
          isCompact: compact,
          isSuspended: true,
          hasReminder: true,
        ),
      );

      expect(find.text('停'), findsOneWidget);
      expect(find.byIcon(Icons.alarm_on_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label：放假 + 备注角标时三枚共存', (tester) async {
      await pumpCard(
        tester,
        CourseCard(
          course: course,
          isCompact: compact,
          isHoliday: true,
          topRightBadgeText: '备注',
        ),
      );

      expect(find.text('假'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label：放假优先于停课，两者不同时出现', (tester) async {
      await pumpCard(
        tester,
        CourseCard(
          course: course,
          isCompact: compact,
          isHoliday: true,
          isSuspended: true,
        ),
      );

      expect(find.text('假'), findsOneWidget);
      expect(find.text('停'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('窄格里三枚角标并排不溢出（日课表一格约 50px）', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Center(
          child: SizedBox(
            width: 56,
            height: 90,
            child: CourseCard(
              course: course,
              isCompact: true,
              isHoliday: true,
              hasReminder: true,
              topRightBadgeText: '冲',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('假'), findsOneWidget);
    expect(find.text('冲'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无提醒的放假课仍只有「假」一枚角标', (tester) async {
    await pumpCard(
      tester,
      CourseCard(course: course, isHoliday: true),
    );

    expect(find.text('假'), findsOneWidget);
    expect(find.byIcon(Icons.alarm_on_rounded), findsNothing);
  });

  testWidgets('普通课不画任何放假/停课角标', (tester) async {
    await pumpCard(tester, CourseCard(course: course));

    expect(find.text('假'), findsNothing);
    expect(find.text('停'), findsNothing);
  });
}
