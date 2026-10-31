import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/month_view_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_metrics.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_day_agenda.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_agenda_surface.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_overview.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_surface.dart';

/// 月视图**信息卡的材质契约**（2026-10-22 立，2026-10-23 按"独立卡"重写）。
///
/// ## 判据换了，理由也换了
///
/// **旧口径**（2026-10-22）：卡不能与**面板底色**相同 —— 当时卡躺在一整块白色
/// 通栏面板里，卡若也用 `surface`，两者逐位相同、卡在视觉上不存在（深色下实测
/// 1.00:1，整块板上的卡片全消失）。
///
/// **新口径**（2026-10-23）：卡**直接浮在壁纸上**，面板没了。于是：
///
/// * 卡取 `surface`（白），与上半那张日历卡同色 —— 上下两种卡读作一套；
/// * 卡与卡的区分靠**缝隙里露出的壁纸**，不再靠灰白差；
/// * 真正要守的是「卡内文字按**卡面**判，不能拿壁纸判出的白字压白卡」。
///
/// ⚠️ 旧那条「卡底色 ≠ 面板底色」已经**没有意义**（面板不存在了）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData themeOf(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3482FF),
      brightness: brightness,
    ),
  );

  /// 2026-10 网格：每隔 3 天有课，其余空（用于概览与空态两种形态）。
  MonthGridData gridWith({required bool empty}) {
    final first = DateTime(2026, 10);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final days = <MonthDayEntry>[];
    for (var i = 0; i < 42; i++) {
      final date = start.add(Duration(days: i));
      final outside = date.month != 10;
      final busy = !empty && !outside && date.day % 3 != 0;
      days.add(
        MonthDayEntry(
          date: date,
          weekIndex: 8,
          weekInSemester: true,
          courseCount: busy ? 1 : 0,
          courseColorHexes: busy ? const ['#4C6FFF'] : const [],
          examCount: 0,
          scheduleCount: 0,
          isHoliday: false,
          isAdjustedWorkday: false,
          isOutsideMonth: outside,
        ),
      );
    }
    var count = 0;
    var busyDays = 0;
    for (final d in days) {
      if (d.isOutsideMonth) continue;
      count += d.courseCount;
      if (d.courseCount > 0) busyDays++;
    }
    return MonthGridData(
      year: 2026,
      month: 10,
      days: List.unmodifiable(days),
      today: DateTime(2026, 10, 22),
      overview: MonthOverviewStats(
        courseCount: count,
        examCount: 0,
        scheduleCount: 0,
        scheduledDayCount: busyDays,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    Brightness brightness, {
    double height = 390,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: themeOf(brightness),
        home: Scaffold(
          body: SizedBox(
            height: height,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('信息卡是白卡（与日历卡同色，不跟"面板底"比）', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：卡片填充 = 主题 surface', (tester) async {
        final grid = gridWith(empty: false);
        await pump(
          tester,
          MonthPanelOverview(
            grid: grid,
            settings: const TimetableSettings(sections: []),
            upcoming: MonthViewLogic.scheduledDaysOfMonth(
              grid,
              today: DateTime(2026, 10, 22),
            ),
            onDayTap: (_) {},
          ),
          brightness,
        );

        final context = tester.element(find.byType(MonthPanelOverview));
        final scheme = Theme.of(context).colorScheme;
        expect(
          monthInfoCardFill(context).toARGB32(),
          scheme.surface.toARGB32(),
          reason:
              '信息卡取 surface（白）—— 与上半那张日历卡同一个颜色。'
              '旧口径取 surfaceContainerHighest，是因为当时卡片躺在白色面板里、'
              '必须与板底拉开；面板没了，再用灰卡就读成上下两种语言',
        );
      });
    }

    testWidgets('议程卡与概览卡同底色（同一屏不能有两种卡语言）', (tester) async {
      for (final brightness in Brightness.values) {
        await pump(
          tester,
          MonthDayAgenda(
            date: DateTime(2026, 10, 22),
            settings: const TimetableSettings(sections: []),
            rows: const [
              MonthAgendaRow(
                kind: MonthAgendaRowKind.course,
                clockText: '08:00',
                title: '高等数学',
                subtitle: '教三 305',
                colorHex: '#4C6FFF',
              ),
            ],
            onRowTap: (_) {},
          ),
          brightness,
        );
        final context = tester.element(find.byType(MonthDayAgenda));
        expect(
          monthInfoCardFill(context).toARGB32(),
          Theme.of(context).colorScheme.surface.toARGB32(),
          reason: '${brightness.name}：议程卡与概览卡必须同色',
        );
      }
    });
  });

  group('卡内文字：按卡面判墨，不是拿壁纸判', () {
    testWidgets('墨色不透明且与卡面对比足够', (tester) async {
      for (final brightness in Brightness.values) {
        final grid = gridWith(empty: false);
        await pump(
          tester,
          MonthPanelOverview(
            grid: grid,
            settings: const TimetableSettings(sections: []),
            upcoming: MonthViewLogic.scheduledDaysOfMonth(
              grid,
              today: DateTime(2026, 10, 22),
            ),
            onDayTap: (_) {},
          ),
          brightness,
        );

        final context = tester.element(find.byType(MonthPanelOverview));
        final fill = monthInfoCardFill(context);
        final ink = monthInfoCardInk(
          context: context,
          settings: const TimetableSettings(sections: []),
          cardFill: fill,
        );
        expect(ink.a, 1, reason: '${brightness.name}：卡内文字必须不透明');
        final hi = ink.computeLuminance() > fill.computeLuminance()
            ? ink.computeLuminance()
            : fill.computeLuminance();
        final lo = ink.computeLuminance() > fill.computeLuminance()
            ? fill.computeLuminance()
            : ink.computeLuminance();
        expect(
          (hi + 0.05) / (lo + 0.05),
          greaterThan(3),
          reason: '${brightness.name}：卡面墨色与卡面本色的对比读不清',
        );
      }
    });
  });

  group('信息区是一列独立的卡：卡与卡之间必须露出壁纸', () {
    testWidgets('概览卡与预览卡之间有空隙（不是一张整板被切开）', (tester) async {
      final grid = gridWith(empty: false);
      await pump(
        tester,
        MonthPanelOverview(
          grid: grid,
          settings: const TimetableSettings(sections: []),
          upcoming: MonthViewLogic.scheduledDaysOfMonth(
            grid,
            today: DateTime(2026, 10, 22),
          ),
          onDayTap: (_) {},
        ),
        Brightness.light,
        height: 700,
      );

      final cards = find.descendant(
        of: find.byType(MonthPanelOverview),
        matching: find.byType(DayViewAgendaSurface),
      );
      final count = cards.evaluate().length;
      expect(count, greaterThanOrEqualTo(2), reason: '前置：概览卡 + 至少一张预览卡');

      final rects = [
        for (var i = 0; i < count; i++) tester.getRect(cards.at(i)),
      ];
      final gaps = <double>[
        for (var i = 1; i < rects.length; i++)
          rects[i].top - rects[i - 1].bottom,
      ];
      expect(
        gaps.every((g) => g >= MonthMetrics.itemGap / 2),
        isTrue,
        reason:
            '卡片之间要露出壁纸，才算"独立的卡"。实测缝隙 $gaps —— '
            '全为 0 说明又退回"一整块大卡片"里铺卡的老版面（用户 2026-10-23 '
            '明确要的是「单独的卡片」）',
      );
    });
  });

  group('信息卡必须是实底（玻璃在高饱和壁纸上读成"一块洞"）', () {
    testWidgets('概览卡走 forceSolid（不跟用户的玻璃材质走）', (tester) async {
      // 2026-10-23 真机：上一轮为了"跟课程卡材质走"去掉了 forceSolid，
      // 结果卡片半透明、把满屏彩色壁纸透进来 —— 用户说"非常诡异"的另一半。
      // 上半那张日历卡是实底的，下半若透壁纸，同一屏就是两种材质。
      final grid = gridWith(empty: false);
      await pump(
        tester,
        MonthPanelOverview(
          grid: grid,
          settings: const TimetableSettings(sections: []),
          upcoming: MonthViewLogic.scheduledDaysOfMonth(
            grid,
            today: DateTime(2026, 10, 22),
          ),
          onDayTap: (_) {},
        ),
        Brightness.light,
      );

      final surfaces = tester.widgetList<DayViewAgendaSurface>(
        find.descendant(
          of: find.byType(MonthPanelOverview),
          matching: find.byType(DayViewAgendaSurface),
        ),
      );
      expect(surfaces, isNotEmpty, reason: '前置：概览区至少有一张卡');
      for (final surface in surfaces) {
        expect(
          surface.forceSolid,
          isTrue,
          reason:
              '信息卡必须强制实底 —— 玻璃采的是屏级壁纸，'
              '在用户那种高饱和壁纸上会读成"一块模糊的洞"，而不是卡',
        );
      }
    });

    testWidgets('当日议程卡也是实底', (tester) async {
      await pump(
        tester,
        MonthDayAgenda(
          date: DateTime(2026, 10, 22),
          settings: const TimetableSettings(sections: []),
          rows: const [
            MonthAgendaRow(
              kind: MonthAgendaRowKind.course,
              clockText: '08:00',
              title: '高等数学',
              subtitle: '教三 305',
              colorHex: '#4C6FFF',
            ),
          ],
          onRowTap: (_) {},
        ),
        Brightness.light,
      );
      final surface = tester.widget<DayViewAgendaSurface>(
        find.byType(DayViewAgendaSurface),
      );
      expect(surface.forceSolid, isTrue, reason: '与概览卡同一档 —— 上下两种卡不能一个实底一个玻璃');
    });
  });

  group('标题在卡内（不许浮在壁纸上）', () {
    testWidgets('日期标题在议程卡内部', (tester) async {
      // 2026-10-23 真机：标题原先画在卡**外面**、直接压在高饱和壁纸上，
      // 深色小字压上去像一段找不到归属的碎字。小米日历的信息块都是"带标题的卡"。
      await pump(
        tester,
        MonthDayAgenda(
          date: DateTime(2026, 10, 22),
          settings: const TimetableSettings(sections: []),
          rows: const [
            MonthAgendaRow(
              kind: MonthAgendaRowKind.course,
              clockText: '08:00',
              title: '高等数学',
              subtitle: '教三 305',
              colorHex: '#4C6FFF',
            ),
          ],
          onRowTap: (_) {},
        ),
        Brightness.light,
      );

      final cardRect = tester.getRect(find.byType(DayViewAgendaSurface).first);
      final titleRect = tester.getRect(find.text('10月22日'));
      expect(
        titleRect.top,
        greaterThanOrEqualTo(cardRect.top),
        reason: '日期标题必须在卡片**上沿之内**，不能浮在它上面的壁纸上',
      );
      expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    });

    testWidgets('概览标题在概览卡内部', (tester) async {
      final grid = gridWith(empty: false);
      await pump(
        tester,
        MonthPanelOverview(
          grid: grid,
          settings: const TimetableSettings(sections: []),
          upcoming: MonthViewLogic.scheduledDaysOfMonth(
            grid,
            today: DateTime(2026, 10, 22),
          ),
          onDayTap: (_) {},
        ),
        Brightness.light,
        height: 700,
      );

      final cardRect = tester.getRect(find.byType(DayViewAgendaSurface).first);
      final titleRect = tester.getRect(find.text('本月概览'));
      expect(
        titleRect.top,
        greaterThanOrEqualTo(cardRect.top),
        reason: '「本月概览」这个标题必须在卡片内部（不再浮在壁纸上）',
      );
      expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    });
  });

  group('概览卡：三列用形状区分，不靠配色', () {
    testWidgets('三格图标互不相同（课程 / 考试 / 日程）', (tester) async {
      final grid = gridWith(empty: false);
      await pump(
        tester,
        MonthPanelOverview(
          grid: grid,
          settings: const TimetableSettings(sections: []),
          upcoming: MonthViewLogic.scheduledDaysOfMonth(
            grid,
            today: DateTime(2026, 10, 22),
          ),
          onDayTap: (_) {},
        ),
        Brightness.light,
      );

      // 旧实现是三颗 6dp 圆点：课程点用 primary（默认 #3482FF）、日程点用
      // 固定 #3B82F6 —— 实测对比 1.013:1，几乎是同一个蓝。现在靠图标形状区分。
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();
      expect(icons, contains(Icons.menu_book_rounded));
      expect(icons, contains(Icons.assignment_rounded));
      expect(icons, contains(Icons.schedule_rounded));
    });
  });

  group('预览卡的取舍必须说清楚', () {
    testWidgets('最多 3 张，其余以「还有 N 天」交代（不静默丢弃）', (tester) async {
      final grid = gridWith(empty: false);
      final upcoming = MonthViewLogic.scheduledDaysOfMonth(
        grid,
        today: DateTime(2026, 10, 22),
      );
      expect(
        upcoming.length,
        greaterThan(3),
        reason: '前置：这个月有安排的日子要多于 3 天，否则测不出截断',
      );

      await pump(
        tester,
        MonthPanelOverview(
          grid: grid,
          settings: const TimetableSettings(sections: []),
          upcoming: upcoming,
          onDayTap: (_) {},
        ),
        Brightness.light,
      );

      final tiles = find.descendant(
        of: find.byType(MonthPanelOverview),
        matching: find.byType(InkWell),
      );
      expect(
        tiles.evaluate().length,
        3,
        reason:
            '展开态信息区只有 390dp（实测），5 张里只有 2 张完整可见 —— '
            '放不下的部分不该"排出来但看不到"',
      );

      final remaining = upcoming.length - 3;
      expect(
        find.text('还有 $remaining 天'),
        findsOneWidget,
        reason:
            '概览卡写着「有安排 ${upcoming.length} 天」而下面只列 3 张 —— '
            '不说明剩下的在哪，两处数字互相矛盾',
      );
    });

    testWidgets('整月空：给空态卡，不摆三个 0', (tester) async {
      final grid = gridWith(empty: true);
      await pump(
        tester,
        MonthPanelOverview(
          grid: grid,
          settings: const TimetableSettings(sections: []),
          upcoming: const [],
          onDayTap: (_) {},
        ),
        Brightness.light,
      );
      expect(find.text('这个月还没有安排'), findsOneWidget);
      expect(find.text('课程'), findsNothing, reason: '0 / 0 / 0 读起来像加载失败');
    });
  });
}
