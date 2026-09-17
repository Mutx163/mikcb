import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/utils/first_frame_probe.dart';

import '../helpers_test_app.dart';

/// 断言的是**汇总行与采样点行的文本**（读日志的人看到的东西）。
///
/// 这个探针的全部价值就是那两行日志：字段名写错、单位错、或者某个阶段没算进
/// 去，都会让下一轮真机取证白跑。所以用例盯的是行内容，不是内部字段。
void main() {
  final lines = <String>[];

  setUp(() {
    lines.clear();
    FirstFrameProbe.debugInstall(emit: lines.add);
  });

  tearDown(FirstFrameProbe.debugReset);

  List<String> summaryLines() =>
      lines.where((line) => line.contains('preLayoutMs=')).toList();
  List<String> nodeLines() =>
      lines.where((line) => line.contains(' node=')).toList();

  Widget probeTree() {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: FirstFrameProbeNode(
        nodeTag: 'page',
        child: SizedBox(width: 100, height: 50),
      ),
    );
  }

  testWidgets('一帧结束后产出汇总行与采样点行', (tester) async {
    FirstFrameProbe.begin('push:/settings/demo');
    await tester.pumpWidget(probeTree());
    // 后置帧回调在 pumpWidget 那一帧末尾跑；再 pump 一次拿确定的时点。
    await tester.pump();

    expect(summaryLines(), hasLength(1));
    final summary = summaryLines().single;
    // 前缀与路由标签。
    expect(summary, startsWith('[first-frame] route=push:/settings/demo'));
    // 四段拆分与采样点数都在。
    for (final field in const [
      'waitMs=',
      'uiMs=',
      'preLayoutMs=',
      'layoutMs=',
      'paintMs=',
      'tailMs=',
      'nodes=1',
    ]) {
      expect(summary, contains(field), reason: '汇总行缺 $field');
    }
    // 采样点两个时刻都有值（不是缺失占位 `-`）。
    expect(summary, contains('layoutAt='));
    expect(summary, isNot(contains('layoutAt=- ')));

    expect(nodeLines(), hasLength(1));
    final node = nodeLines().single;
    expect(node, contains('node=page'));
    for (final field in const [
      'buildAt=',
      'layoutAt=',
      'layoutMs=',
      'paintMs=',
    ]) {
      expect(node, contains(field), reason: '采样点行缺 $field');
    }
  });

  testWidgets('布局与绘制两条路径都真的走到了（缺失用 "-" 而不是 0）', (tester) async {
    FirstFrameProbe.begin('push:/settings/demo');
    await tester.pumpWidget(probeTree());
    await tester.pump();

    final node = nodeLines().single;
    // `-` 表示「这一步没走到」。摆放一个 100x50 的盒子成本本来就该是 0.0ms，
    // 所以这里断言的是「有值」，不是「不为零」—— 两者含义完全不同。
    expect(node, contains('layoutAt='));
    expect(node, contains('paintAt='));
    expect(node, isNot(contains('layoutAt=-')));
    expect(node, isNot(contains('paintAt=-')));
    expect(node, isNot(contains('layoutMs=-')));
    expect(node, isNot(contains('paintMs=-')));
    expect(summaryLines().single, isNot(contains('layoutMs=-')));
  });

  testWidgets('没有 begin 时采样点静默（测试里推路由不会多出帧回调）', (
    tester,
  ) async {
    await tester.pumpWidget(probeTree());
    await tester.pump();

    expect(lines, isEmpty);
  });

  testWidgets('连续两次 begin 只结算最后一条', (tester) async {
    FirstFrameProbe.begin('push:first');
    FirstFrameProbe.begin('push:second');
    await tester.pumpWidget(probeTree());
    await tester.pump();

    expect(summaryLines(), hasLength(1));
    expect(summaryLines().single, contains('route=push:second'));
    expect(lines.join('\n'), isNot(contains('push:first')));
  });

  testWidgets('未安装时采样点不登记也不产出', (tester) async {
    FirstFrameProbe.debugReset();
    FirstFrameProbe.begin('push:ignored');
    await tester.pumpWidget(probeTree());
    await tester.pump();

    expect(lines, isEmpty);
  });

  // 这道守卫来自一次真实的返工：采样点最初挂在 `HyperosSubpage` 传出去的
  // `header` 上，而默认走折叠大标题时那条分支根本不用它 —— 采样点永远不挂载，
  // 等于白跑一轮真机。凡是给子页加采样点，先在这一条上过一遍。
  group('子页的采样点真的挂载', () {
    testWidgets('HyperosSubpage 产出 header 与 body 两条采样点', (tester) async {
      FirstFrameProbe.begin('push:test-subpage');
      await tester.pumpWidget(
        TestApp(
          home: HyperosSubpage(
            onBack: () {},
            title: const Text('Settings'),
            child: HyperosListView(
              children: const [
                HyperosListTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        nodeLines().where((line) => line.contains('node=header')),
        hasLength(1),
        reason: '顶栏采样点没挂载 —— 多半是挂到了不会被使用的那条分支上',
      );
      expect(
        nodeLines().where((line) => line.contains('node=body')),
        hasLength(1),
        reason: '内容采样点没挂载',
      );
      expect(summaryLines().single, contains('nodes=2'));
    });
  });
}
