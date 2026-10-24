import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable/flight_text_metrics.dart';

/// 飞行卡上「两端都有的行」的**文案**必须跟随切换点（2026-10-24 补）。
///
/// ## 抓的是用户口径里最直接的那一条
///
/// 用户原话：「课程卡片里面的字不是平移过去的，而是**开始的、动画上的、最终的**，
/// 是三个位置」。
///
/// 位置那一半早就修了（每行矩形按两端真实排版复算 + 插值）。但**内容**没修：
/// 旧实现一律取终点文案（`b.text`），于是**第一帧**就把议程卡的字画在那张网格卡上：
///
/// | id | 周网格卡（用户点下去看到的） | 日议程卡 |
/// |---|---|---|
/// | teacher | `张老师` | `教师：张老师 · 第 1-2 节` |
/// | location | `教三-201` | `地点：教三-201` |
/// | time | `08:00` | `08:00 - 09:40` |
///
/// 也就是说「开始那一帧」显示的是**最终那张卡的字** —— 三个位置里的第一个就错了。
///
/// ## 判据
///
/// 1. `t=0`：共享行的文案 == 起点那份（就是用户点下去时看到的字）；
/// 2. `t=1`：== 终点那份；
/// 3. 行数也跟随（起点那份允许折两行，终点那份锁单行）；
/// 4. 只起点 / 只终点的行**不同时可见**（否则屏幕上会出现两行不同的时间）。
void main() {
  const settings = TimetableSettings(sections: <SectionTime>[]);

  FlightCardPlan plan() => buildFlightCardPlan(
    name: '高等数学',
    teacher: '张老师',
    location: '教三-201',
    settings: settings,
    gridSurfaceSize: const Size(46, 116),
    agendaSurfaceSize: const Size(364, 200),
    startTime: '08:00',
    endTime: '09:40',
    teacherLine: '教师：张老师 · 第 1-2 节',
    locationLine: '地点：教三-201',
    gridVerticalPadding: 4,
    gridTitleFontSize: 9,
    agendaTitleFontSize: 16,
    titleWeight: (_) => FontWeight.w700,
    detailWeight: (_) => FontWeight.w400,
  );

  Map<String, FlightLayoutItem> at(double t) {
    final p = plan();
    return {
      for (final item in lerpFlightLayout(
        from: p.start,
        to: p.end,
        surfaceSize: const Size(46, 116),
        t: t,
      ).items)
        item.id: item,
    };
  }

  test('切换点之前：共享行用的是起点文案（不是终点那张卡的字）', () {
    final items = at(0);
    expect(
      items['teacher']!.text,
      '张老师',
      reason:
          't=0 的教师行必须是网格卡上的「张老师」。若这里是'
          '「教师：张老师 · 第 1-2 节」，第一帧就把议程卡的字画在网格卡上了 —— '
          '正是用户说的「开始的那一个位置」不对。',
    );
    expect(
      items['location']!.text,
      '教三-201',
      reason: 't=0 的地点行必须是网格卡上的「教三-201」',
    );

    // 切换点前一点点仍然用起点文案
    expect(at(0.44)['teacher']!.text, '张老师');
  });

  test('切换点之后：换成终点文案', () {
    expect(at(1)['teacher']!.text, '教师：张老师 · 第 1-2 节');
    expect(at(1)['location']!.text, '地点：教三-201');
    expect(at(kFlightTextSwitchAt)['teacher']!.text, '教师：张老师 · 第 1-2 节');
    expect(at(0.8)['teacher']!.text, '教师：张老师 · 第 1-2 节');
  });

  test('课名两端同文案：切换点不影响它', () {
    expect(at(0)['name']!.text, '高等数学');
    expect(at(1)['name']!.text, '高等数学');
  });

  test('行数跟随切换点：起点那份允许折两行，终点那份锁单行', () {
    expect(
      at(0)['location']!.maxLines,
      isNull,
      reason:
          't=0 的地点行必须允许折行 —— 网格卡窄（内宽约 44dp），「教三-201」'
          '真的会折两行；锁成 1 行会让第一帧显示「教三-2…」。',
    );
    expect(
      at(1)['location']!.maxLines,
      1,
      reason: 't=1 的地点行与议程卡一致（锁单行 + 省略号）',
    );
  });

  test('只起点 / 只终点的行不同时可见（不出现两行不同的时间）', () {
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      final items = at(t);
      final startOnly = items.values
          .where((e) => e.id == 'time-end' && e.opacity > 0.05)
          .toList();
      final endOnly = items.values
          .where((e) => e.id == 'icon-time' && e.opacity > 0.05)
          .toList();
      expect(
        startOnly.isNotEmpty && endOnly.isNotEmpty,
        isFalse,
        reason:
            't=$t：只起点有的行（time-end「09:40」）与只终点有的行（时间胶囊）'
            '同时可见 —— 屏幕上会同时出现两种写法的同一件事。',
      );
    }
  });
}
