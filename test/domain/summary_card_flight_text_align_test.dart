import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';
import 'package:university_timetable/widgets/timetable/timetable_weekday_header.dart';

/// 摘要卡起飞那一帧，两行字必须**落在星期格真实的那两行字上**（2026-10-23 审核补）。
///
/// ## 抓的是一个 10px 的偏差
///
/// 起点那两行字原先靠「CJK 1em / 其余 0.55em」粗估宽度来居中。实测：
///
/// | 文字 | 字号 | 真实宽 | 估算宽 | 居中偏差 |
/// |---|---|---|---|---|
/// | `周五` | 10 | 20.5 | 20.0 | 0.25px（看不出来） |
/// | `03/20` | 8.5 | **43.75** | 23.375 | **10.19px**（一眼能看出） |
///
/// 数字与斜杠在无衬线字体里的实际 advance 远大于 0.55em，靠调系数治不好
/// （换字体/换语言/两位数日期还会变）。现在起点侧改用 `Align` 让 Flutter 用
/// 真实排版宽度居中，中间用对齐因子插值。
///
/// 这条测试直接量**起点帧的飞行卡文字矩形**与**真实星期栏格子文字矩形**，
/// 逐行比顶边与水平中心。之前的 19 例测试都没量这一项（只量了格子外框）。
void main() {
  const headerHeight = TimetableWeekdayHeader.height;
  const viewportWidth = 392.0;
  const timeColumnWidth = 40.0;
  const dayOfWeek = 5;

  final settings = TimetableSettings(
    sections: const <SectionTime>[],
    semesterStartDate: DateTime(2026, 3, 2),
  );

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );

  Future<Rect> pumpRealCell(WidgetTester tester, String label) async {
    await tester.binding.setSurfaceSize(
      const Size(viewportWidth, headerHeight),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        SizedBox(
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
    );
    await tester.pump();
    return tester.getRect(find.text(label));
  }

  Future<SummaryFlightFrame> pumpStartFrame(WidgetTester tester) async {
    // 层顶在 y=headerHeight；飞行卡起点在层局部 top=-headerHeight，
    // 所以它在屏幕上正好落在星期栏那条带里。
    await tester.binding.setSurfaceSize(const Size(viewportWidth, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const cell = Rect.fromLTWH(
      timeColumnWidth + 4 * ((viewportWidth - timeColumnWidth) / 7),
      -headerHeight,
      (viewportWidth - timeColumnWidth) / 7,
      headerHeight,
    );
    const spec = SummaryFlightSpec(
      startCell: cell,
      endRect: Rect.fromLTWH(14, headerHeight + 14, 364, 107),
      weekdayLabel: '周五',
      cellDateLabel: '03/20',
      titleLabel: '03月20日 周五',
      metaLabel: '第 3 周',
      lowerSection: null,
      fill: Color(0xFFFFFFFF),
      ink: Color(0xFF000000),
      mutedInk: Color(0x8A000000),
    );
    final frame = lerpSummaryFlight(spec: spec, t: 0);

    await tester.pumpWidget(
      app(
        Column(
          children: [
            const SizedBox(height: headerHeight),
            Expanded(
              child: Builder(
                builder: (context) {
                  return Stack(
                    // 必须 Clip.none：卡顶在层上方（与生产路径一致）。
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fromRect(
                        rect: frame.rect.shift(
                          const Offset(0, headerHeight),
                        ),
                        child: SummaryFlightCard(
                          frame: frame,
                          settings: settings,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    return frame;
  }

  testWidgets('起点帧：两行字与真实星期格逐行对齐（顶边 + 水平中心）', (tester) async {
    final realWeekday = await pumpRealCell(tester, '周五');
    final realDate = await pumpRealCell(tester, '03/20');

    await pumpStartFrame(tester);
    final card = tester.getRect(find.byType(SummaryFlightCard));
    final flightWeekday = tester.getRect(find.text('周五'));
    final flightDate = tester.getRect(find.text('03/20'));

    // 真实格子那一次是把星期栏单独铺满 40dp 画面量的，所以它的 y 就是
    // 「相对星期栏顶部」；飞行卡则在 740 高的画面里，卡顶就是星期栏顶部
    // （层局部 top=-40 + 层顶 40）。两边统一到「相对星期栏顶部」再比。
    final flightWeekdayRel = flightWeekday.top - card.top;
    final flightDateRel = flightDate.top - card.top;
    expect(
      flightWeekdayRel,
      closeTo(realWeekday.top, 1.5),
      reason:
          '「周五」顶边对不上：真格子 ${realWeekday.top.toStringAsFixed(2)}'
          ' / 飞行卡 ${flightWeekdayRel.toStringAsFixed(2)}',
    );
    expect(
      flightDateRel,
      closeTo(realDate.top, 1.5),
      reason:
          '日期顶边对不上：真格子 ${realDate.top.toStringAsFixed(2)}'
          ' / 飞行卡 ${flightDateRel.toStringAsFixed(2)}',
    );

    // 水平中心：这是 10px 偏差真正暴露的地方。
    expect(
      flightWeekday.center.dx - card.center.dx,
      closeTo(0, 1.5),
      reason:
          '「周五」必须水平居中。偏 ${(flightWeekday.center.dx - card.center.dx).toStringAsFixed(2)}px',
    );
    expect(
      flightDate.center.dx - card.center.dx,
      closeTo(0, 1.5),
      reason:
          '日期必须水平居中。曾经用「其余字符 0.55em」估算宽度，`03/20` 真实宽 '
          '43.75 而估算 23.375，居中偏了 10.19px。现在偏 '
          '${(flightDate.center.dx - card.center.dx).toStringAsFixed(2)}px。',
    );

  });

  testWidgets('落定帧：日期标题靠左 14dp（摘要卡内边距）', (tester) async {
    await pumpStartFrame(tester);
    // 直接测插值终点的对齐因子语义。
    const spec = SummaryFlightSpec(
      startCell: Rect.fromLTWH(241, -40, 50, 40),
      endRect: Rect.fromLTWH(14, 14, 364, 107),
      weekdayLabel: '周五',
      cellDateLabel: '03/20',
      titleLabel: '03月20日 周五',
      metaLabel: '第 3 周',
      lowerSection: null,
      fill: Color(0xFFFFFFFF),
      ink: Color(0xFF000000),
      mutedInk: Color(0x8A000000),
    );
    final end = lerpSummaryFlight(spec: spec, t: 1);
    expect(
      end.dateCenterFactor,
      closeTo(0, 1e-9),
      reason: '落定时必须完全靠左（对齐因子 0），不能还带居中',
    );
    expect(
      end.weekdayCenterFactor,
      closeTo(0, 1e-9),
      reason: '落定时星期名已淡出，因子也应为 0',
    );
    final start = lerpSummaryFlight(spec: spec, t: 0);
    expect(
      start.dateCenterFactor,
      closeTo(1, 1e-9),
      reason: '起点必须完全居中（对齐因子 1）',
    );
  });
}
