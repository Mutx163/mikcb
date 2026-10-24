import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';
import 'package:university_timetable/widgets/timetable/timetable_weekday_header.dart';

/// 摘要卡「从星期栏当日格飞出来」的两端几何（2026-10-23）。
///
/// ## 这一层在验什么
///
/// 用户口径：「日视图带叉叉的日期卡片，能不能从顶部星期栏的当日的星期里面，
/// 一对一缩放出来，效果和课程卡片差不多」。
///
/// 「一对一」的判据只有一条：**第一帧那张飞行卡必须正好落在星期栏那一格上**，
/// 中间每一帧都还在格子与摘要卡之间，最后一帧正好等于摘要卡。所以这里量的是
/// **矩形**，不是「看起来像」：
///
/// 1. 起点矩形 vs 真实 `TimetableWeekdayHeader` 里那一格的 `tester.getRect`；
/// 2. 中间帧严格在两端之间（单调、无回弹、无跳变）；
/// 3. 终点矩形 = 摘要卡实测矩形（逐值）；
/// 4. 圆角 14 → 20、投影 0 → 0.08、关闭叉只在后段出现。
void main() {
  const headerHeight = TimetableWeekdayHeader.height;
  const viewportWidth = 392.0;
  const timeColumnWidth = 40.0;

  group('起点必须正好落在星期栏那一格上', () {
    for (final (visibleCount, selectedIndex, dayOfWeek) in [
      (7, 4, 5),
      (5, 4, 5),
      (7, 0, 1),
      (7, 6, 7),
    ]) {
      testWidgets('$visibleCount 天 / 选中下标 $selectedIndex', (tester) async {
        final settings = TimetableSettings(
          sections: const <SectionTime>[],
          timetableHideWeekends: visibleCount == 5,
          semesterStartDate: DateTime(2026, 3, 2),
        );
        await tester.binding.setSurfaceSize(
          const Size(viewportWidth, headerHeight),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: SizedBox(
                width: viewportWidth,
                height: headerHeight,
                child: TimetableWeekdayHeader(
                  settings: settings,
                  week: 3,
                  timeColumnWidth: timeColumnWidth,
                  hideBottomBorder: true,
                  wallpaperTopLuminance: null,
                  wallpaperWeekdayLuminance: null,
                  pageController: null,
                  isDayView: false,
                  visibleDayViewWeek: null,
                  shouldShowOverlay: true,
                  isSelectedDay: (w, d) => w == 3 && d == dayOfWeek,
                  hasExamOnDate: (_) => false,
                  hasScheduleOnDate: (_) => false,
                  onShowWeekSelector: () {},
                  onDayTapDown: (_) {},
                  onDayTap: (_, _) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final real = tester.getRect(
          find.byKey(ValueKey('weekday-header-3-$dayOfWeek')),
        );
        // 转场层的顶边 = 星期栏下沿 ⇒ 起点是负高度区间。这里把层原点设成
        // (0, headerHeight)，于是算出来的矩形与真实屏幕矩形可以直接比。
        final computed = summaryStartCellRect(
          viewportWidth: viewportWidth,
          timeColumnWidth: timeColumnWidth,
          visibleDayCount: visibleCount,
          selectedDayIndex: selectedIndex,
          headerHeight: headerHeight,
        ).shift(const Offset(0, headerHeight));

        expect(
          computed.left,
          closeTo(real.left, 1.5),
          reason: '格子左边界：真卡 ${real.left} / 算出 ${computed.left}',
        );
        expect(
          computed.width,
          closeTo(real.width, 1.5),
          reason: '格子宽度：真卡 ${real.width} / 算出 ${computed.width}',
        );
        expect(computed.top, closeTo(real.top, 0.01));
        expect(computed.height, closeTo(real.height, 0.01));
      });
    }
  });

  group('起点兜底：越界下村不能算出屏外的格子', () {
    test('selectedDayIndex 越界时钳到可见范围内（release 下 assert 不存在）', () {
      final normal = summaryStartCellRect(
        viewportWidth: viewportWidth,
        timeColumnWidth: timeColumnWidth,
        visibleDayCount: 5,
        selectedDayIndex: 4,
        headerHeight: headerHeight,
      );
      final overflow = summaryStartCellRect(
        viewportWidth: viewportWidth,
        timeColumnWidth: timeColumnWidth,
        visibleDayCount: 5,
        selectedDayIndex: 9,
        headerHeight: headerHeight,
      );
      expect(
        overflow,
        normal,
        reason: '越界应钳到最后一格（5 天时下标 4），而不是照算到屏外',
      );
      final negative = summaryStartCellRect(
        viewportWidth: viewportWidth,
        timeColumnWidth: timeColumnWidth,
        visibleDayCount: 5,
        selectedDayIndex: -3,
        headerHeight: headerHeight,
      );
      expect(
        negative.left,
        closeTo(timeColumnWidth, 0.01),
        reason: '负数应钳到第一格（左边界 = 时间列宽）',
      );
      expect(negative.width, closeTo(normal.width, 0.01));
    });

    test('visibleDayCount 为 0 时给一个零矩形（不除零）', () {
      final rect = summaryStartCellRect(
        viewportWidth: viewportWidth,
        timeColumnWidth: timeColumnWidth,
        visibleDayCount: 0,
        selectedDayIndex: 0,
        headerHeight: headerHeight,
      );
      expect(rect.width, 0);
      expect(rect.height, 0);
      expect(rect.width.isNaN, isFalse, reason: '不能因为除零得到 NaN');
    });
  });

  group('两端插值：中间帧必在两端之间，端点逐值贴合', () {
    const spec = SummaryFlightSpec(
      startCell: Rect.fromLTWH(241.1, -40, 48.3, 40),
      endRect: Rect.fromLTWH(14, 14, 364, 107),
      weekdayLabel: '周五',
      cellDateLabel: '03/20',
      titleLabel: '03月20日 周五',
      metaLabel: '第 3 周',
      lowerSection: null,
      fill: Color(0xFFFFFFFF),
      ink: Color(0xFF1A1A1A),
      mutedInk: Color(0x8A1A1A1A),
    );

    test('t=0 逐项等于起点', () {
      final f = lerpSummaryFlight(spec: spec, t: 0);
      expect(f.rect, spec.startCell);
      expect(f.radius, closeTo(14, 1e-9));
      expect(f.shadowOpacity, closeTo(0, 1e-9));
      expect(f.closeOpacity, closeTo(0, 1e-9));
      expect(f.dateFontSize, closeTo(8.5, 1e-9));
      // 起点用星期格那份紧凑日期，而不是摘要卡的完整标题。
      expect(f.dateText, spec.cellDateLabel);
    });

    test('t=1 逐项等于终点', () {
      final f = lerpSummaryFlight(spec: spec, t: 1);
      expect(f.rect, spec.endRect);
      expect(f.radius, closeTo(20, 1e-9));
      expect(f.shadowOpacity, closeTo(0.08, 1e-9));
      expect(f.closeOpacity, closeTo(1, 1e-9));
      expect(f.dateFontSize, closeTo(16, 1e-9));
      expect(f.dateText, spec.titleLabel);
      // 终点：星期名被完整日期取代。
      expect(f.weekdayOpacity, closeTo(0, 1e-9));
    });

    test('中途矩形严格落在两端之间且单调（不回弹）', () {
      final samples = [
        for (var i = 0; i <= 20; i++)
          lerpSummaryFlight(spec: spec, t: i / 20),
      ];
      for (var i = 1; i < samples.length; i++) {
        final a = samples[i - 1].rect;
        final b = samples[i].rect;
        // 左边界、顶边、宽、高各自单向走（起点在右下、终点在左上）。
        expect(
          b.left,
          lessThanOrEqualTo(a.left + 1e-6),
          reason: '第 $i 帧左边界往回走了：${a.left} → ${b.left}',
        );
        expect(
          b.top,
          greaterThanOrEqualTo(a.top - 1e-6),
          reason: '第 $i 帧顶边往回走了：${a.top} → ${b.top}',
        );
        expect(
          b.width,
          greaterThanOrEqualTo(a.width - 1e-6),
          reason: '第 $i 帧变窄了：${a.width} → ${b.width}',
        );
        expect(
          b.right,
          greaterThanOrEqualTo(a.right - 1e-6),
          reason: '第 $i 帧右边界往回走了：${a.right} → ${b.right}',
        );
        expect(
          b.height,
          greaterThanOrEqualTo(a.height - 1e-6),
          reason: '第 $i 帧变矮了：${a.height} → ${b.height}',
        );
        // 每一帧都必须落在「起点 ∪ 终点」这条带里（不许飞出去）。
        expect(b.left, greaterThanOrEqualTo(spec.endRect.left - 0.001));
        expect(
          b.right,
          lessThanOrEqualTo(
            math.max(spec.startCell.right, spec.endRect.right) + 0.001,
          ),
        );
      }
    });

    test('圆角 / 投影 / 关闭叉都是单调的', () {
      var lastRadius = -1.0;
      var lastShadow = -1.0;
      var lastClose = -1.0;
      for (var i = 0; i <= 10; i++) {
        final f = lerpSummaryFlight(spec: spec, t: i / 10);
        expect(f.radius, greaterThanOrEqualTo(lastRadius));
        expect(f.shadowOpacity, greaterThanOrEqualTo(lastShadow));
        expect(f.closeOpacity, greaterThanOrEqualTo(lastClose));
        lastRadius = f.radius;
        lastShadow = f.shadowOpacity;
        lastClose = f.closeOpacity;
      }
    });

    test('关闭叉只在后 40% 出现（不会挤在还没长大的格里）', () {
      for (var i = 0; i <= 6; i++) {
        final f = lerpSummaryFlight(spec: spec, t: i / 10);
        expect(f.closeOpacity, closeTo(0, 1e-9), reason: 't=${i / 10} 就已经有叉了');
      }
      expect(lerpSummaryFlight(spec: spec, t: 0.8).closeOpacity,
          closeTo(0.5, 1e-9));
    });

    test('文案在 0.45 处切换（与课程卡同一节奏）', () {
      expect(kSummaryTextSwitchAt, closeTo(0.45, 1e-9));
      expect(
        lerpSummaryFlight(spec: spec, t: 0.44).dateText,
        spec.cellDateLabel,
      );
      expect(
        lerpSummaryFlight(spec: spec, t: 0.46).dateText,
        spec.titleLabel,
      );
    });
  });
}
