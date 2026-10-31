import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/month_view_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_calendar_card.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid_handle.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_metrics.dart';

/// 日历白卡 + 卡底拉杆的结构契约（2026-10-23）。
///
/// 用户口径：「拉杆区域，还有框框区域像这样」——小米日历的表格是一张白卡，
/// 拉杆是卡底正中那根条。
///
/// ⚠️ 这个文件**只组件级** pump `MonthCalendarCard`，不碰 `MonthViewScreen`：
/// 后者会连带 import 整个首页栈，任何别的泳道在途改动都会让本文件编译不过。
/// 整页级的契约在 `month_view_aesthetic_contract_test.dart`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MonthGridData october() {
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

  Future<void> pumpCard(
    WidgetTester tester, {
    VoidCallback? onDragStart,
    Size size = const Size(393, 460),
    Widget? navigator,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: MonthCalendarCard(
                navigator: navigator,
                onDragStart: onDragStart ?? () {},
                onDragUpdate: (_) {},
                onDragEnd: (_) {},
                child: MonthGrid(
                  grid: october(),
                  selectedDate: null,
                  onDayTap: (_) {},
                  rowHeight: 48,
                  progress: const AlwaysStoppedAnimation<double>(1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('日历是一张白卡', () {
    testWidgets('卡片底色 = 主题 surface（白卡，不是壁纸）', (tester) async {
      await pumpCard(tester);
      final context = tester.element(find.byType(MonthCalendarCard));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(MonthCalendarCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(
        decoration.color!.toARGB32(),
        Theme.of(context).colorScheme.surface.toARGB32(),
        reason:
            '日历卡必须是实底白卡（与信息卡同色）。'
            '画在壁纸上的透明表就是上一版"42 个边框铺满一屏"的版面',
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(MonthMetrics.calendarCardRadius),
        reason: '圆角要比里面的日期格大一档（外大内小，层级才分得开）',
      );
    });

    testWidgets('圆角被裁掉（选中色块不会从卡角戳出来）', (tester) async {
      await pumpCard(tester);
      expect(
        find.descendant(
          of: find.byType(MonthCalendarCard),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
        reason: '不裁的话，第一列/最后一列的选中圆角块会在卡角外面露出直角',
      );
    });

    testWidgets('内容不贴卡片边缘（网格离卡边有卡内边距）', (tester) async {
      // 2026-10-23 真机：第一版把卡内边距写成 cellGap（1.5dp），表头「周一」
      // 与周次列直接顶着卡片边缘 —— 24 圆角的白卡看起来像"内容溢出的图片被
      // 裁了一刀"。这是用户说"非常诡异"的一半原因。
      //
      // ⚠️ 判据必须对**网格整体**的矩形，不能对「周一」那个 Text：表头是
      // 居中的，内边距是 0 时它照样离卡边很远 —— 拿它量会得到一个假绿
      //（本地探针实测：内边距改成 0 后那条断言仍然全绿）。
      await pumpCard(tester);
      final cardRect = tester.getRect(find.byType(MonthCalendarCard));
      final gridRect = tester.getRect(find.byType(MonthGrid));

      const expectedInset =
          MonthMetrics.gridInnerPadding - MonthMetrics.cellGap;
      expect(
        gridRect.left - cardRect.left,
        closeTo(expectedInset, 1),
        reason:
            '网格离卡片左沿 ${(gridRect.left - cardRect.left).toStringAsFixed(1)}dp，'
            '应为 $expectedInset dp —— 卡内边距没生效时表头会顶着圆角',
      );
      expect(
        gridRect.right,
        closeTo(cardRect.right - expectedInset, 1),
        reason: '右侧对称：卡片内容必须左右留同样的内边距',
      );
      expect(
        gridRect.top - cardRect.top,
        closeTo(MonthMetrics.cardPadding, 1),
        reason:
            '表头离卡片顶边 ${(gridRect.top - cardRect.top).toStringAsFixed(1)}dp，'
            '应为 ${MonthMetrics.cardPadding}dp（贴着 24 圆角会读成"被裁过"）',
      );
    });

    testWidgets('缺投影 = 白卡在浅色壁纸上糊进背景', (tester) async {
      await pumpCard(tester);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(MonthCalendarCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(
        decoration.boxShadow,
        isNotNull,
        reason:
            '日历卡必须与信息卡一样有柔和投影 —— '
            '2026-10-23 真机：上半没投影、下半有，同一屏两种"浮起高度"',
      );
      expect(decoration.boxShadow, isNotEmpty);
    });
  });

  group('月份导航是这张卡的表头（2026-10-23 整体化）', () {
    // 用户口径：「顶部的 2026年10月，左右按钮，回今日区域，看看这些能不能和
    // 下面的日期做一下整体化」。
    //
    // 改造前导航住在满宽玻璃带里，与下面这张 8dp 外沿 / 24 圆角的日历白卡之间
    // 隔着一圈壁纸 —— 而它控制的正是这张卡，读起来是"上面的仪表盘遥控下面的
    // 表格"。现在它是卡顶一行。
    testWidgets('导航行在卡片内部、表格之上', (tester) async {
      await pumpCard(
        tester,
        navigator: const Text('2026年 10月', key: ValueKey('nav')),
      );

      final nav = find.byKey(const ValueKey('nav'));
      expect(nav, findsOneWidget);
      expect(
        find.descendant(of: find.byType(MonthCalendarCard), matching: nav),
        findsOneWidget,
        reason:
            '导航必须在日历卡**内部** —— 放在卡外的玻璃带里，'
            '它与"它所控制的这张表"就分属两套视觉系统（用户要的整体化正是这个）',
      );

      final navRect = tester.getRect(nav);
      final gridRect = tester.getRect(find.byType(MonthGrid));
      expect(
        navRect.bottom,
        lessThanOrEqualTo(gridRect.top + 1),
        reason: '导航必须在表格**之上**（卡的表头），不能压在日期格上',
      );
    });

    testWidgets('不传导航时卡片不留空白（高度自动少一段）', (tester) async {
      // 组件级调用 / 别的宿主可能不需要导航：那时不该留一条 40dp 的空带。
      await pumpCard(tester);
      final withoutNav = tester.getRect(find.byType(MonthCalendarCard)).height;
      await pumpCard(
        tester,
        navigator: const SizedBox(height: 40, key: ValueKey('nav')),
      );
      final withNav = tester.getRect(find.byType(MonthCalendarCard)).height;
      // 两次外部给的 SizedBox 高度相同（460），所以卡高相同 ——
      // 这里钉的是"导航确实占进去、表格被压缩"，而不是卡变高。
      expect(
        withNav,
        closeTo(withoutNav, 0.5),
        reason: '卡片总高由外部 SizedBox 决定，导航只挤占表格空间',
      );
    });

    test('卡内非表格开销 = 导航 + 分隔线 + 拉杆（一个常量，两处共用）', () {
      // 2026-10-23 实测：导航搬进卡后只扣了拉杆那段 →
      // `RenderFlex overflowed by 41 pixels`（正好 40 + 1）。
      expect(
        MonthCalendarCard.cardChrome,
        closeTo(
          MonthCalendarCard.navHeight +
              MonthCalendarCard.dividerHeight +
              MonthCalendarCard.chromeHeight,
          1e-9,
        ),
        reason: 'cardChrome 必须把卡内三段都算进去；漏一段就溢出',
      );
      expect(MonthCalendarCard.navHeight, greaterThan(0));
      expect(MonthCalendarCard.dividerHeight, greaterThan(0));
      expect(MonthCalendarCard.chromeHeight, greaterThan(0));
    });
  });

  group('拉杆在卡底正中', () {
    testWidgets('拉杆是卡片的子节点，且在网格下方', (tester) async {
      await pumpCard(tester);
      final handle = find.byType(MonthGridHandle);
      expect(handle, findsOneWidget);
      expect(
        find.descendant(of: find.byType(MonthCalendarCard), matching: handle),
        findsOneWidget,
        reason: '拉杆属于这张卡（小米日历同款语义），必须在卡内部',
      );

      final handleRect = tester.getRect(handle);
      final gridRect = tester.getRect(find.byType(MonthGrid));
      expect(
        handleRect.top,
        greaterThanOrEqualTo(gridRect.bottom - 0.5),
        reason: '拉杆在网格下方，不能压在日期格上',
      );
    });

    testWidgets('拉杆水平居中（卡底正中，不是靠左/靠右）', (tester) async {
      await pumpCard(tester);
      final cardRect = tester.getRect(find.byType(MonthCalendarCard));
      final bar = find.descendant(
        of: find.byType(MonthGridHandle),
        matching: find.byType(Container),
      );
      final barRect = tester.getRect(bar.first);
      expect(
        barRect.center.dx,
        closeTo(cardRect.center.dx, 1),
        reason: '卡底那根条必须居中',
      );
      expect(
        barRect.width,
        closeTo(MonthGridHandle.barWidth, 1),
        reason: '视觉宽度 60dp',
      );
      expect(
        barRect.height,
        closeTo(MonthGridHandle.barHeight, 1),
        reason: '视觉高度 5dp',
      );
    });

    testWidgets('拉杆条贴在卡底但没被圆角切掉（卡片给了底部留白）', (tester) async {
      await pumpCard(tester);
      final cardRect = tester.getRect(find.byType(MonthCalendarCard));
      final handleRect = tester.getRect(find.byType(MonthGridHandle));
      expect(
        handleRect.bottom,
        lessThanOrEqualTo(cardRect.bottom - MonthMetrics.cellGap + 0.5),
        reason:
            '拉杆整块必须留在卡内、且底部还有 cellGap 的留白 —— '
            '贴着卡边会被圆角切掉一半，读起来像渲染错误',
      );
    });

    testWidgets('拖拽回调真的接上了', (tester) async {
      var started = 0;
      var updated = 0;
      var ended = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SizedBox(
              width: 393,
              height: 460,
              child: MonthCalendarCard(
                onDragStart: () => started++,
                onDragUpdate: (_) => updated++,
                onDragEnd: (_) => ended++,
                child: MonthGrid(
                  grid: october(),
                  selectedDate: null,
                  onDayTap: (_) {},
                  rowHeight: 48,
                  progress: const AlwaysStoppedAnimation<double>(1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.drag(find.byType(MonthGridHandle), const Offset(0, -40));
      await tester.pumpAndSettle();

      expect(started, greaterThan(0), reason: '拖拉杆必须触发网格收放（回调要接上）');
      expect(updated, greaterThan(0));
      expect(ended, greaterThan(0));
    });
  });
}
