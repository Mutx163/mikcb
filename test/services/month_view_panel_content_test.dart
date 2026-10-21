import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/month_view_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_overview.dart';

/// 月视图**下半屏信息区**的契约（2026-10-21）。
///
/// 用户口径：「下面信息区域，看看怎么丰富一下，目前没有课程的时候，下面就是
/// 纯空白」，并且要「把那个『点任意一天查看安排』这行字去掉」。
///
/// ## 两条测试分工
///
/// 1. **整页那条**钉「那句提示真的没了」+「没选日期时下半屏有东西」——
///    这两件事只有连着真实页面才验得了（那句提示原来是页面里的一块）；
/// 2. **组件那几条**直接把 [MonthPanelOverview] 单独 pump 起来，用
///    [MonthViewLogic.buildMonthGrid] 造数据 —— 不经过 provider 的写操作，
///    避免测试去等持久化管线（本仓实测：在 widget 测试里 `await
///    provider.updateSettings(...)` 会让用例挂到超时）。
///
/// 放 `test/services/`：按 TEST-POLICY，`test/widgets` / `test/screens` 不再新增。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(
    WidgetTester tester, {
    required MonthGridData grid,
    required DateTime now,
    ValueChanged<DateTime>? onDayTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthPanelOverview(
              grid: grid,
              upcoming: MonthViewLogic.scheduledDaysOfMonth(grid, today: now),
              settings: const TimetableSettings(sections: []),
              onDayTap: onDayTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 造一份有课的 2026-10 网格：周一的课，学期 2026-09-07 开学。
  MonthGridData octoberWithCourse() {
    final settings = const TimetableSettings(
      sections: [],
      semesterWeekCount: 16,
    ).copyWith(semesterStartDate: DateTime(2026, 9, 7));
    return MonthViewLogic.buildMonthGrid(
      year: 2026,
      month: 10,
      now: DateTime(2026, 10, 15),
      courses: [
        Course(
          id: 'c-mon',
          name: '月视图测试课',
          teacher: '老师',
          location: '教室',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:50',
          color: '#4C6FFF',
        ),
      ],
      scheduleItems: const [],
      exams: const [],
      settings: settings,
      holidayData: null,
    );
  }

  /// 整月空白的一份网格。
  MonthGridData emptyOctober() {
    final settings = const TimetableSettings(
      sections: [],
      semesterWeekCount: 16,
    ).copyWith(semesterStartDate: DateTime(2026, 9, 7));
    return MonthViewLogic.buildMonthGrid(
      year: 2026,
      month: 10,
      now: DateTime(2026, 10, 15),
      courses: const [],
      scheduleItems: const [],
      exams: const [],
      settings: settings,
      holidayData: null,
    );
  }

  group('整页：那句提示已删掉，下半屏不再是空白', () {
    late TimetableProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = TimetableProvider(
        storageService: StorageService.forTesting(),
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
    });

    tearDown(() => provider.dispose());

    testWidgets('进月视图：没有「点任意一天查看安排」，下半屏有概览', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: MonthViewScreen(),
          ),
        ),
      );
      await tester.pump();

      // ① 那句提示必须整件消失（键已从 6 个 ARB 里删除，代码里也不再有那块）。
      expect(
        find.text('点任意一天查看安排'),
        findsNothing,
        reason: '用户明确要求删掉这行提示。它既没回答问题（这个月有多少事），'
            '又让整块下半屏留成空白。',
      );
      expect(find.text('Tap a day to see its schedule'), findsNothing);

      // ② 下半屏必须有内容 —— 这是本轮改动的全部目的。
      expect(
        find.byType(MonthPanelOverview),
        findsOneWidget,
        reason: '没选日期时下半屏必须是本月概览，不能是空白',
      );
    });
  });

  group('组件：概览卡的有数据 / 空态两种形态', () {
    testWidgets('有课：三个数字 + 「本月概览」标题 + 有安排的日子', (tester) async {
      final grid = octoberWithCourse();
      // 人推：2026-10 的周一是 10/5、10/12、10/19、10/26 → 课程节次 4 次。
      expect(grid.overview.courseCount, 4);

      await pumpPanel(tester, grid: grid, now: DateTime(2026, 10, 15));

      expect(find.text('本月概览'), findsOneWidget);
      // 三个标签都在：用户才知道「这个月没考试」是确定的事，不是没加载出来。
      expect(find.text('课程'), findsOneWidget);
      expect(find.text('考试'), findsOneWidget);
      expect(find.text('日程'), findsOneWidget);
      // 课程数是 4（大数字）。
      expect(find.text('4'), findsWidgets);
      // 有安排的天数 == 有课的天数 == 4 天。
      expect(find.text('有安排 4 天'), findsOneWidget);
      // 「本月有安排的日子」这一节也得出现（它是那列可点的预览卡）。
      expect(find.text('本月有安排的日子'), findsOneWidget);
      // 有数据时不该出空态卡。
      expect(find.text('这个月还没有安排'), findsNothing);
    });

    testWidgets('整月空：给空态卡 + 下一步去处，不摆三个 0', (tester) async {
      await pumpPanel(
        tester,
        grid: emptyOctober(),
        now: DateTime(2026, 10, 15),
      );

      expect(
        find.text('这个月还没有安排'),
        findsOneWidget,
        reason: '整月空的时候摆「0 / 0 / 0」读起来像加载失败；要给一句明确的空态',
      );
      expect(find.text('先加一节课，日历上就会显示圆点'), findsOneWidget);
      // 空态下**不摆统计表**（那三个 0 只会误导）：三个标签一个都不该出现。
      // 标题「本月概览」保留 —— 它说明这张卡在讲什么，不算多余信息。
      expect(find.text('课程'), findsNothing);
      expect(find.text('考试'), findsNothing);
      expect(find.text('日程'), findsNothing);
      // 「本月有安排的日子」那一列也不该出现（没有任何一天可选）。
      expect(find.text('本月有安排的日子'), findsNothing);
    });

    testWidgets('点预览卡：把那一天交回去（选中日期的入口）', (tester) async {
      final grid = octoberWithCourse();
      DateTime? tapped;
      await pumpPanel(
        tester,
        grid: grid,
        now: DateTime(2026, 10, 15),
        onDayTap: (date) => tapped = date,
      );

      // 从今天（10/15）往后第一个有课的日子是 10/19。
      // 预览卡的标题是「10月19日」。
      final target = find.text('10月19日').first;
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pump();
      expect(
        tapped,
        DateTime(2026, 10, 19),
        reason: '点一张预览卡就该选中那一天（排序口径由 scheduledDaysOfMonth 保证）',
      );
    });
  });
}
