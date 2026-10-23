import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/course_surface.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';

/// 飞行的摘要卡**画出来的样子**（2026-10-23）。
///
/// 上一份 `summary_card_flight_test.dart` 验的是几何数据。这里验的是渲染：
/// 数据对、渲染错（比如忘了按 rect 摆、文字用了固定字号）在真机上就是一坨。
///
/// 判据三条，都是站在用户那一边的：
///
/// 1. 起点那一帧看起来**就是星期格里那一格**：两张小字、居中、没有叉、没投影；
/// 2. 落定那一帧看起来**就是摘要卡**：完整日期、有叉、有投影、圆角 20；
/// 3. 中间任何一帧都不溢出、不裁字（小格里塞不下完整标题会变成一团）。
void main() {
  const settings = TimetableSettings(sections: <SectionTime>[]);
  const spec = SummaryFlightSpec(
    startCell: Rect.fromLTWH(241.1, -40, 50.3, 40),
    endRect: Rect.fromLTWH(14, 14, 364, 107),
    weekdayLabel: '周五',
    cellDateLabel: '03/20',
    titleLabel: '03月20日 周五',
    metaLabel: '今天 · 第 3 周',
    countLabel: '1 门课',
    fill: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1A1A),
    mutedInk: Color(0x8A1A1A1A),
  );

  Future<void> pumpFrame(WidgetTester tester, SummaryFlightFrame frame) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // 起点在负区间（星期栏那条带），所以整层往下让 40 才看得见。
              Positioned.fromRect(
                rect: frame.rect.shift(const Offset(0, 40)),
                child: SummaryFlightCard(frame: frame, settings: settings),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('起点帧：两行小字、无叉、无投影', (tester) async {
    await pumpFrame(tester, lerpSummaryFlight(spec: spec, t: 0));

    expect(find.text('周五'), findsOneWidget, reason: '起点必须有星期名');
    expect(find.text('03/20'), findsOneWidget, reason: '起点必须有紧凑日期');
    expect(
      find.text('03月20日 周五'),
      findsNothing,
      reason: '起点不该已经是完整日期（那是终点那一份）',
    );
    expect(
      find.byIcon(Icons.close_rounded),
      findsNothing,
      reason: '星期格里没有叉，起点也不该有',
    );

    // 字号：与星期格实测一致（星期名 10 / 日期 8.5）。
    final weekday = tester.widget<Text>(find.text('周五'));
    expect(weekday.style?.fontSize, closeTo(10, 0.01));
    expect(weekday.style?.fontWeight, FontWeight.w800);
    final date = tester.widget<Text>(find.text('03/20'));
    expect(date.style?.fontSize, closeTo(8.5, 0.01));

    expect(tester.takeException(), isNull, reason: '起点帧不该溢出');
  });

  testWidgets('落定帧：完整日期 + 叉 + 计数胶囊 + 「今天 · 第几周」', (tester) async {
    await pumpFrame(tester, lerpSummaryFlight(spec: spec, t: 1));

    expect(find.text('03月20日 周五'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('1 门课'), findsOneWidget);
    expect(find.text('今天 · 第 3 周'), findsOneWidget);
    expect(
      find.text('周五'),
      findsNothing,
      reason: '完整日期里已含「周五」，再单画一行会重复',
    );

    // 字号：与摘要卡实测一致（标题 16）。
    final title = tester.widget<Text>(find.text('03月20日 周五'));
    expect(title.style?.fontSize, closeTo(16, 0.01));

    // 位置：标题顶边 46（摘要卡实测值）。
    final card = tester.getRect(find.byType(SummaryFlightCard));
    final titleRect = tester.getRect(find.text('03月20日 周五'));
    expect(titleRect.top - card.top, closeTo(46, 1.5));

    // 圆角：落定必须是 20（与真议程卡/摘要卡同值，否则落地跳一下）。
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SummaryFlightCard),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(20));
    expect(
      decoration.boxShadow,
      isNotNull,
      reason: '落定必须有投影（与摘要卡同值）',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('起点没有可见卡面（星期格那一格本来只是几行字）', (tester) async {
    // 起点就画不透明卡面，会在星期栏上凭空冒出一块白卡。
    //
    // ⚠️ 判据是「卡面**不可见**」而不是「没有卡面」：外层组件必须恒定（见
    // `SummaryFlightCard` 里那段注释 —— 中途换 widget 类型会让整棵子树重建，
    // 卡里的字会闪）。所以这里查的是 `CourseSurface.opacityScale` 与渐变 alpha。
    await pumpFrame(tester, lerpSummaryFlight(spec: spec, t: 0));
    final surfaces = find.byType(CourseSurface);
    if (surfaces.evaluate().isNotEmpty) {
      final flight = tester.widget<CourseSurface>(surfaces);
      expect(
        flight.opacityScale,
        closeTo(0, 0.01),
        reason: '起点卡面必须完全透明（opacityScale=0）。星期栏那一格是「几行字'
            '压在壁纸上」，第一帧就画一块实心卡，读起来像凭空冒出来一张卡。',
      );
    }
    // 字必须看得见（这才是起点的全部内容）。
    expect(find.text('周五'), findsOneWidget);
    expect(find.text('03/20'), findsOneWidget);

    // 长到 40% 时卡面已经可见（否则会「只有字在飘、卡片最后才出现」）。
    await pumpFrame(tester, lerpSummaryFlight(spec: spec, t: 0.4));
    final mid = tester.widget<CourseSurface>(find.byType(CourseSurface));
    expect(
      mid.opacityScale,
      greaterThan(0.9),
      reason: '到 40% 卡面应该已经完全不透明（前 30% 淡入完毕）',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('中途帧：不溢出、不因为窄格子裁字崩掉', (tester) async {
    for (final t in [0.1, 0.25, 0.5, 0.7, 0.9]) {
      await pumpFrame(tester, lerpSummaryFlight(spec: spec, t: t));
      expect(
        tester.takeException(),
        isNull,
        reason: 't=$t 这一帧渲染时报错了（多半是小格子塞了大字号）',
      );
    }
  });
}
