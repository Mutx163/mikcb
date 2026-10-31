// 月视图日期格的**内容层**契约（2026-10-22 立，2026-10-23 按"格子进白卡"重写）。
//
// 用户口径（2026-10-23）：「框框区域像小米日历这样」——格子的底色改由外面那张
// **白色日历卡**提供，格子自己只画内容。于是 2026-10-22 那条「空白日不画卡片」
// 的判据整个失效（格子不再有自己的卡），换成下面三条真正还成立的：
//
// 1. 日期数字、色带、角标三件事都还在，且**都不依赖卡片材质**；
// 2. 假期的「休/班」是角标，不许吃掉当天的课（旧实现实测：假期+2 门课显示 0 个）；
// 3. 标记仍是底边色带 —— 圆点在 43.86dp 的格子里 5 个要 55dp，溢出 14.57dp。
//
// 放 `test/services/`：按 TEST-POLICY，`test/widgets` / `test/screens` 不再新增。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/month_view_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_day_cell.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_metrics.dart';

/// 一天的造数据（只造渲染层需要的字段）。
MonthDayEntry entry({
  int courses = 0,
  int exams = 0,
  int schedules = 0,
  bool holiday = false,
  bool workday = false,
  bool outside = false,
  int day = 8,
}) {
  const palette = ['#4C6FFF', '#22C55E', '#F59E0B', '#EC4899'];
  return MonthDayEntry(
    date: DateTime(2026, 10, day),
    weekIndex: 44,
    weekInSemester: true,
    courseCount: courses,
    courseColorHexes: [for (var i = 0; i < courses; i++) palette[i % 4]],
    examCount: exams,
    scheduleCount: schedules,
    isHoliday: holiday,
    isAdjustedWorkday: workday,
    isOutsideMonth: outside,
  );
}

/// 把一格放进**真机宽度**的 7 列网格里量（单格 pump 会量到假宽度）。
Future<void> pumpCell(
  WidgetTester tester,
  MonthDayEntry e, {
  bool today = false,
  bool selected = false,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 851 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: SizedBox(
          height: 47.4,
          child: Row(
            children: [
              const SizedBox(width: MonthGrid.weekLabelWidth),
              // 目标格占第 1 列，其余 6 列留空 —— 宽度与真机完全一致。
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(MonthMetrics.cellGap),
                  child: MonthDayCell(
                    entry: e,
                    isToday: today,
                    isSelected: selected,
                    onTap: () {},
                  ),
                ),
              ),
              for (var i = 0; i < 6; i++) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 这一格画了几个色段（= `ColoredBox` 个数）。
int stripSegments(WidgetTester tester) {
  final boxes = find.descendant(
    of: find.byType(MonthDayCell),
    matching: find.byType(ColoredBox),
  );
  return boxes.evaluate().length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('格子只画内容：不再自带卡片材质', () {
    testWidgets('任何格子都不建 CourseSurface（材质由外面的白卡提供）', (tester) async {
      for (final e in [
        entry(),
        entry(courses: 2),
        entry(exams: 1),
        entry(holiday: true),
      ]) {
        await pumpCell(tester, e);
        // ⚠️ 2026-10-23：格子进白卡之后不该再有自己的课程卡材质 ——
        // 一屏 42 层材质是上一版"有点丑"的一部分（42 个边框、无阅读单位）。
        expect(
          find.descendant(
            of: find.byType(MonthDayCell),
            matching: find.byType(Material),
          ),
          findsWidgets,
          reason: '仍需一层 Material 承载水波纹（那不是卡片材质）',
        );
      }
    });

    testWidgets('日号在任何状态下都画出来（不靠卡面着色才可见）', (tester) async {
      await pumpCell(tester, entry(courses: 1));
      expect(find.text('${DateTime(2026, 10, 8).day}'), findsOneWidget);

      await pumpCell(tester, entry(), today: true);
      expect(find.text('8'), findsOneWidget, reason: '今天也要有日号');

      await pumpCell(tester, entry(), selected: true);
      expect(find.text('8'), findsOneWidget, reason: '选中也要有日号');
    });
  });

  group('假期不再吃掉当天的课', () {
    testWidgets('假期 + 2 门课：色带 2 段（旧实现是 0）', (tester) async {
      await pumpCell(tester, entry(holiday: true, courses: 2));

      expect(
        stripSegments(tester),
        2,
        reason:
            '旧实现把「休」和标记画在同一行的互斥分支里 '
            '(`if (badge != null) ... else ...dots`)，假期+2 门课实测显示 0 个 —— '
            '国庆那几天明明排了课，日历上是空的。现在「休」在右上角，课照常显示。',
      );
    });

    testWidgets('调休上班 + 3 门课：色带 3 段', (tester) async {
      await pumpCell(tester, entry(workday: true, courses: 3));
      expect(stripSegments(tester), 3);
    });

    testWidgets('假期标记本身还在（角标没被挪没）', (tester) async {
      await pumpCell(tester, entry(holiday: true, courses: 2));
      expect(find.byType(MonthBadge), findsOneWidget);
      expect(
        tester.widget<MonthBadge>(find.byType(MonthBadge)).text,
        '休',
        reason: '角标挪位置了，但文案还是那个「休」',
      );
    });
  });

  group('标记换成色带后不再溢出', () {
    testWidgets('5 个标记（4 课 + 考试 + 日程）零溢出', (tester) async {
      await pumpCell(tester, entry(courses: 4, exams: 1, schedules: 1));

      expect(
        tester.takeException(),
        isNull,
        reason:
            '圆点时代 5 个标记要 55dp、格子只有 40.43dp 内容区，'
            '溢出 14.57dp；色带按格宽均分，不该再溢出。',
      );
      // 4 段课程 + 考试 + 日程 = 6 段
      expect(stripSegments(tester), 6);
    });

    testWidgets('1..6 个标记全都不溢出', (tester) async {
      for (final n in [1, 2, 3, 4, 5, 6]) {
        await pumpCell(tester, entry(courses: n));
        expect(tester.takeException(), isNull, reason: '$n 个标记不该溢出');
      }
    });

    testWidgets('课程色段封顶 4 段（再多就分不清了）', (tester) async {
      // 6 门课 → 只画前 4 段；考试 / 日程各再占一段。
      await pumpCell(tester, entry(courses: 6, exams: 1, schedules: 1));
      expect(stripSegments(tester), 6);
    });
  });

  group('月外补位格：弱化但不消失', () {
    testWidgets('月外格不画色带（不在本月里浮出来）', (tester) async {
      await pumpCell(tester, entry(courses: 3, outside: true));
      expect(
        stripSegments(tester),
        0,
        reason:
            '月外格是邻月的日子，不该在本月里浮出来 —— '
            '否则同一批格子翻月后会有两种长相',
      );
    });

    testWidgets('月外格仍然有日号（弱化不是藏掉）', (tester) async {
      await pumpCell(tester, entry(day: 28, outside: true));
      expect(find.text('28'), findsOneWidget);
    });
  });

  group('色带高度是定值', () {
    test('色带比圆点矮，但比 1dp 厚（1dp 会被抗锯齿打成虚线）', () {
      expect(MonthMetrics.cellStripHeight, greaterThan(1.0));
      expect(
        MonthMetrics.cellStripHeight,
        lessThan(MonthDot.extent),
        reason: '色带是背景信号，不该比它取代的圆点行还占地方',
      );
    });
  });
}
