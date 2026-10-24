import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/flight_card_factory.dart';
import 'package:university_timetable/widgets/timetable/flight_text_metrics.dart';

/// 两端锚点的计划**必须被记忆化**（2026-10-24 加）。
///
/// ## 为什么
///
/// `buildFlightCardPlan` 的结果**与进度 `t` 无关**，但转场期间每帧每张卡都会
/// 调一次。实测单次约 **273µs**（内部 ~11 次 `TextPainter.layout`），8 张卡一帧
/// 就是 **2.2ms** —— 60fps 的帧预算只有 16.7ms，这一项就吃掉 13%，而它算出来的
/// 东西整场转场一个字节都没变。
///
/// ## 判据
///
/// 1. 同样的输入调两次 ⇒ **同一个对象**（说明真的命中了缓存）；
/// 2. 任一项输入变了 ⇒ 不同对象（说明键没漏项，不会拿到旧计划）。
void main() {
  setUp(resetFlightCardPlanCacheForTest);

  const settings = TimetableSettings(sections: <SectionTime>[]);

  FlightCardPlan plan({
    String name = '高等数学',
    double agendaTitleFontSize = 16,
    Size gridSurface = const Size(46, 116),
    bool alignTop = false,
  }) => flightCardPlanFor(
    name: name,
    teacher: '张老师',
    location: '教三-201',
    settings: settings,
    gridSurfaceSize: gridSurface,
    agendaSurfaceSize: const Size(364, 200),
    startTime: '08:00',
    endTime: '09:40',
    teacherLine: '教师：张老师 · 第 1-2 节',
    locationLine: '地点：教三-201',
    gridVerticalPadding: 4,
    gridTitleFontSize: 9,
    agendaTitleFontSize: agendaTitleFontSize,
    gridBaseStyle: const TextStyle(),
    agendaBaseStyle: const TextStyle(),
    agendaInfoBaseStyle: const TextStyle(),
    gridAlignTop: alignTop,
    gridCrossAxisAlignment: CrossAxisAlignment.center,
    titleWeight: (_) => FontWeight.w700,
    detailWeight: (_) => FontWeight.w400,
  );

  test('同样输入命中缓存（同一对象）', () {
    final first = plan();
    final second = plan();
    expect(
      identical(first, second),
      isTrue,
      reason:
          '同样的输入必须命中缓存。没命中说明转场每帧每张卡都在重算两端锚点 —— '
          '实测 273µs/次 × 8 卡 = 2.2ms/帧。',
    );
  });

  test('输入变了就不复用（键没漏项）', () {
    final base = plan();
    expect(identical(base, plan(name: '大学物理')), isFalse, reason: '课名变了');
    expect(
      identical(base, plan(agendaTitleFontSize: 18)),
      isFalse,
      reason: '议程卡课名字号变了（换主题 / 换字体方案）',
    );
    expect(
      identical(base, plan(gridSurface: const Size(52, 132))),
      isFalse,
      reason: '起点卡尺寸变了（换节高 / 换可见天数）',
    );
    expect(
      identical(base, plan(alignTop: true)),
      isFalse,
      reason: '垂直对齐变了（用户改设置）',
    );
  });

  test('缓存清空后会重算（不是永久命中旧值）', () {
    final first = plan();
    resetFlightCardPlanCacheForTest();
    final second = plan();
    expect(
      identical(first, second),
      isFalse,
      reason: '清空后必须重算 —— 否则测试之间会互相污染',
    );
    // 重算的结果必须与原来**逐值一致**（缓存不改变答案）
    expect(second.start.anchors.length, first.start.anchors.length);
    expect(second.end.anchors.length, first.end.anchors.length);
    for (var i = 0; i < first.start.anchors.length; i++) {
      expect(second.start.anchors[i].rect, first.start.anchors[i].rect);
    }
  });
}
