import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_course_display_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_ink_style.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_summary_card.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';

/// 落定那一帧，飞行摘要卡的**下半部分**与真卡逐值同位（2026-10-24 补）。
///
/// ## 抓的是什么
///
/// 飞行摘要卡曾经自己只画了一个计数胶囊，而真卡还有「X 节日程」、进行中、
/// 冲突、非本周、考试、情侣空闲。这些块在落定那一帧**凭空冒出来**。
///
/// 修法是让飞行卡直接复用**真卡构建的那一个 widget**（
/// `TimetableDayViewSummaryCard.onLowerSectionBuilt`），并且用终点的宽度与实测
/// 顶边（72）把它摆上去。
///
/// 这条测试就钉住「摆得对不对」：
///
/// 1. 用有课 + 有日程 + 有考试的一天构建真卡，从回调里拿到下半部分；
/// 2. 量真卡里那几个胶囊**相对卡面**的位置；
/// 3. 把同一份塞进飞行卡、t=1，量同样几个胶囊相对卡面的位置；
/// 4. 逐项比 —— 差得多就说明「飞行卡的下半部分与真卡不在同一个地方」，
///    落定那一帧会看到胶囊跳一下。
void main() {
  const settings = TimetableSettings(sections: <SectionTime>[]);
  final courseA = Course(
    id: 'a',
    name: '高等数学',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 5,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: '#ef4444',
  );
  final courseB = Course(
    id: 'b',
    name: '大学物理',
    teacher: '李老师',
    location: 'B202',
    dayOfWeek: 5,
    startSection: 3,
    endSection: 4,
    startTime: '10:00',
    endTime: '11:40',
    color: '#3b82f6',
  );

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: FrostedAppearanceScope(
      appearance: FrostedAppearance.defaults,
      child: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
    ),
  );

  /// 真卡的下半部分 + 那几个胶囊相对卡面的位置。
  Future<(Widget, Map<String, Rect>, Size)> pumpRealCard(
    WidgetTester tester,
  ) async {
    Widget? captured;
    final exams = <Exam>[
      Exam(
        id: 'e1',
        courseId: 'a',
        name: '期末考试',
        dateTime: DateTime(2026, 3, 20),
        startTime: '08:30',
        endTime: '10:30',
        createdAt: DateTime(2026, 3),
        updatedAt: DateTime(2026, 3),
      ),
    ];
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 364,
          child: TimetableDayViewSummaryCard(
            surfaceKey: null,
            settings: settings,
            week: 3,
            dateLabel: '03月20日 周五',
            isToday: true,
            currentCourse: courseA,
            courseItems: [
              DayCourseDisplayItem(course: courseA, isCurrentWeekCourse: true),
              DayCourseDisplayItem(
                course: courseB,
                isCurrentWeekCourse: true,
                isConflicting: true,
              ),
            ],
            scheduleItems: [
              ScheduleItem(
                id: 's1',
                title: '班会',
                date: DateTime(2026, 3, 20),
                startTime: '19:00',
                endTime: '20:00',
                createdAt: DateTime(2026, 3),
                updatedAt: DateTime(2026, 3),
              ),
            ],
            agendaItems: const [],
            dayExams: exams,
            inkEnvironment: const DayViewInkEnvironment(backdropBlurOn: false),
            radius: 20,
            onClose: () {},
            onLowerSectionBuilt: (section) => captured = section,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(captured, isNotNull, reason: '真卡必须把下半部分交出来，否则飞行卡只能自己复刻');

    final surface = tester.getRect(
      find
          .descendant(
            of: find.byType(TimetableDayViewSummaryCard),
            matching: find.byType(CourseSurface),
          )
          .first,
    );
    Map<String, Rect> rel() {
      final out = <String, Rect>{};
      // 文案取自真卡实测（`日程 1 项` / `冲突 1 节` / `正在上课 · …`），
      // 考试只匹配名字（它的倒计时随「今天」变，写死会随日期老化）。
      for (final probe in [
        '2 门课',
        '日程 1 项',
        '正在上课 · 高等数学',
        '冲突 1 节',
        '期末考试',
      ]) {
        final f = find.textContaining(probe);
        if (f.evaluate().isNotEmpty) {
          out[probe] = tester.getRect(f.first).shift(-surface.topLeft);
        }
      }
      return out;
    }

    return (captured!, rel(), surface.size);
  }

  testWidgets('落定帧：下半部分与真卡逐值同位（不多不少不跳）', (tester) async {
    final (section, realRects, realSize) = await pumpRealCard(tester);
    expect(
      realRects.length,
      greaterThanOrEqualTo(3),
      reason:
          '真卡这一组输入应该产出「计数 + 日程 + 冲突 + 考试」好几个胶囊，'
          '否则这条测试没有区分力。实测到 ${realRects.keys.toList()}',
    );

    // 飞行卡：同一份下半部分，t=1。
    const spec = SummaryFlightSpec(
      startCell: Rect.fromLTWH(241, -40, 50, 40),
      endRect: Rect.fromLTWH(14, 14, 364, 107),
      weekdayLabel: '周五',
      cellDateLabel: '03/20',
      titleLabel: '03月20日 周五',
      metaLabel: '今天 · 第 3 周',
      lowerSection: null, // 下面用真卡那一份覆盖
      fill: Color(0xFFFFFFFF),
      ink: Color(0xFF000000),
      mutedInk: Color(0x8A000000),
    );
    final frame = lerpSummaryFlight(
      spec: SummaryFlightSpec(
        startCell: spec.startCell,
        endRect: spec.endRect,
        weekdayLabel: spec.weekdayLabel,
        cellDateLabel: spec.cellDateLabel,
        titleLabel: spec.titleLabel,
        metaLabel: spec.metaLabel,
        lowerSection: section,
        fill: spec.fill,
        ink: spec.ink,
        mutedInk: spec.mutedInk,
      ),
      t: 1,
    );

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        Stack(
          children: [
            Positioned.fromRect(
              rect: frame.rect,
              child: SummaryFlightCard(frame: frame, settings: settings),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final flightSurface = tester.getRect(find.byType(SummaryFlightCard));
    // 终点卡宽必须与真卡一致，否则下半部分的换行会不同。
    expect(
      flightSurface.width,
      closeTo(realSize.width, 0.5),
      reason: '飞行卡落定宽度必须等于真卡宽度（否则胶囊换行不同）',
    );

    for (final entry in realRects.entries) {
      final f = find.textContaining(entry.key);
      expect(
        f,
        findsWidgets,
        reason:
            '落定帧缺少「${entry.key}」—— 说明飞行卡的下半部分没画全，'
            '这个胶囊会在落定那一帧凭空冒出来。',
      );
      final flightRect = tester.getRect(f.first).shift(-flightSurface.topLeft);
      expect(
        flightRect.left,
        closeTo(entry.value.left, 1.5),
        reason: '「${entry.key}」左边：真卡 ${entry.value.left} / 飞行卡 ${flightRect.left}',
      );
      expect(
        flightRect.top,
        closeTo(entry.value.top, 1.5),
        reason:
            '「${entry.key}」顶边：真卡 ${entry.value.top} / 飞行卡 ${flightRect.top}'
            ' —— 差得多就是落定那一帧胶囊跳了一下',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('中途：下半部分用终点宽度排布，不换行', (tester) async {
    final (section, realRects, _) = await pumpRealCard(tester);
    expect(realRects, isNotEmpty);

    const endRect = Rect.fromLTWH(14, 14, 364, 107);
    final spec = SummaryFlightSpec(
      startCell: const Rect.fromLTWH(241, -40, 50, 40),
      endRect: endRect,
      weekdayLabel: '周五',
      cellDateLabel: '03/20',
      titleLabel: '03月20日 周五',
      metaLabel: '今天 · 第 3 周',
      lowerSection: section,
      fill: const Color(0xFFFFFFFF),
      ink: const Color(0xFF000000),
      mutedInk: const Color(0x8A000000),
    );
    final frame = lerpSummaryFlight(spec: spec, t: 0.8);

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        Stack(
          children: [
            Positioned.fromRect(
              rect: frame.rect,
              child: SummaryFlightCard(frame: frame, settings: settings),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    // 中途卡还没长到终点宽，但下半部分必须已经按**终点宽度**排好：
    // 所以「日程」胶囊仍在「计数」右边同一行（没有掉到下一行）。
    final count = find.textContaining('2 门课');
    final schedule = find.textContaining('日程 1 项');
    if (count.evaluate().isNotEmpty && schedule.evaluate().isNotEmpty) {
      final a = tester.getRect(count.first);
      final b = tester.getRect(schedule.first);
      expect(
        b.top,
        closeTo(a.top, 1.5),
        reason:
            '中途「日程」胶囊掉到了下一行（top 差 ${(b.top - a.top).abs()}）—— '
            '说明下半部分用了**当前卡宽**而不是终点宽度排布，中途会看到换行跳变。',
      );
      expect(b.left, greaterThan(a.left));
    }
    expect(tester.takeException(), isNull);
  });
}
