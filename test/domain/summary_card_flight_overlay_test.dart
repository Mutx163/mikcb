import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';
import 'package:university_timetable/widgets/timetable/timetable_anchored_day_overlay.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

/// 摘要卡在**真实转场壳**里是不是真的从星期格里长出来（2026-10-23）。
///
/// 上面两份测试验的是「数据」与「这一张卡自己的渲染」。这里验的是**装配**：
/// 把 `TimetableAnchoredDayOverlay` 真的跑起来、真的推进动画，量那一张飞行卡
/// 在每一帧的位置。
///
/// 为什么必须单独验装配：飞行卡的矩形来自 `summaryFlight`，而它又依赖「摘要卡
/// 终点已经被量到」。如果装配漏了（比如终点一直量不到、或者转场期间面板被移出
/// 树导致量不到），数据与渲染两份测试都会绿 —— 因为它俩根本不走这条路径。
void main() {
  const settings = TimetableSettings(sections: <SectionTime>[]);
  const headerHeight = 40.0;
  const viewportWidth = 392.0;
  const timeColumnWidth = 40.0;

  // 摘要卡在屏幕上的实测位置（模拟 MeasureFlightTarget 的结果）。
  const endRect = Rect.fromLTWH(14, headerHeight + 14, 364, 107);

  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(viewportWidth, 740));
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
        home: FrostedAppearanceScope(
          appearance: FrostedAppearance.defaults,
          child: Scaffold(
            body: Column(
              children: [
                // 真正占位的那条星期栏（40 高），下面才是转场层。
                const SizedBox(height: headerHeight),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 210),
                    builder: (context, value, _) {
                      return TimetableAnchoredDayOverlay(
                        panel: const SizedBox.expand(
                          child: ColoredBox(color: Color(0xFFEEEEEE)),
                        ),
                        expandAnimation: AlwaysStoppedAnimation(value),
                        weekTimeColumnWidth: timeColumnWidth,
                        visibleDayCount: 7,
                        selectedDayIndex: 4,
                        sectionHeight: 60,
                        settings: settings,
                        cardInset: 0,
                        summaryFlight: const SummaryFlightInput(
                          endRectOnScreen: endRect,
                          weekdayLabel: '周五',
                          cellDateLabel: '03/20',
                          titleLabel: '03月20日 周五',
                          metaLabel: '第 3 周',
                          countLabel: '1 门课',
                          fill: Color(0xFFFFFFFF),
                          ink: Color(0xFF1A1A1A),
                          mutedInk: Color(0x8A1A1A1A),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('第一帧就在星期格上，中途一路长大，落定贴着摘要卡位置', (tester) async {
    await pumpOverlay(tester);

    // 转场刚开始。
    await tester.pump(const Duration(milliseconds: 1));
    final startCard = find.byType(SummaryFlightCard);
    expect(
      startCard,
      findsOneWidget,
      reason: '转场一开始就该有这张飞行卡（否则就是「闪现出现」）',
    );
    final rect = tester.getRect(startCard);
    // 起点：星期栏那一格（下标 4/7、层宽 392、时间列 40）。
    final expectedStartCell = summaryStartCellRect(
      viewportWidth: viewportWidth,
      timeColumnWidth: timeColumnWidth,
      visibleDayCount: 7,
      selectedDayIndex: 4,
      headerHeight: headerHeight,
    ).shift(const Offset(0, headerHeight));
    expect(
      rect.left,
      closeTo(expectedStartCell.left, 2),
      reason: '第一帧左边界应贴着星期格（不是面板左边）',
    );
    expect(
      rect.width,
      closeTo(expectedStartCell.width, 2),
      reason: '第一帧宽度应等于星期格（约 '
          '${expectedStartCell.width.toStringAsFixed(1)}dp），实际 ${rect.width}',
    );
    expect(rect.height, closeTo(headerHeight, 2), reason: '第一帧高度应等于星期格高度');

    // 推进到中途：必须比起点大、比终点小。
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    final mid = tester.getRect(find.byType(SummaryFlightCard));
    expect(
      mid.width,
      greaterThan(expectedStartCell.width),
      reason: '中途应该已经长大了',
    );
    expect(
      mid.width,
      lessThan(364),
      reason: '中途不该已经到了终点宽度',
    );

    // 落定：飞行卡消失、真面板接管。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byType(SummaryFlightCard),
      findsNothing,
      reason: '落定后飞行卡必须让位给真摘要卡',
    );
    expect(tester.takeException(), isNull);
  });
}
