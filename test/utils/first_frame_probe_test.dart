import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/utils/first_frame_probe.dart';

import '../helpers_test_app.dart';

/// 断言的是**汇总行与采样点行的文本**（读日志的人看到的东西）。
///
/// 这个探针的全部价值就是那几行日志：字段名写错、单位错、或者某个阶段没算进
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
  List<String> frameLines() =>
      lines.where((line) => RegExp(r' frame=\d').hasMatch(line)).toList();
  List<String> nodeLines() =>
      lines.where((line) => line.contains(' node=')).toList();

  /// 取 `key=value` 里的 value（value 到下一个空格为止）。
  String fieldOf(String line, String key) =>
      RegExp('$key=([^ ]+)').firstMatch(line)?.group(1) ?? '';

  Widget probeTree() {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: FirstFrameProbeNode(
        nodeTag: 'page',
        child: SizedBox(width: 100, height: 50),
      ),
    );
  }

  testWidgets('一帧结束后产出汇总行、帧行与采样点行', (tester) async {
    FirstFrameProbe.begin('push:/settings/demo');
    await tester.pumpWidget(probeTree());
    await tester.pump();

    final summary = summaryLines().single;
    expect(summary, startsWith('[first-frame] route=push:/settings/demo'));
    for (final field in const [
      'waitMs=',
      'uiMs=',
      'preLayoutMs=',
      'layoutMs=',
      'paintMs=',
      'paintFrame=',
      'frames=',
      'nodes=1',
    ]) {
      expect(summary, contains(field), reason: '汇总行缺 $field');
    }

    expect(frameLines(), isNotEmpty);
    expect(frameLines().first, contains('frame=1'));

    final node = nodeLines().single;
    expect(node, contains('node=page'));
    for (final field in const [
      'buildFrame=',
      'buildAt=',
      'layoutFrame=',
      'layoutAt=',
      'layoutMs=',
      'layoutPasses=',
      'paintFrame=',
      'paintPasses=',
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
    expect(node, isNot(contains('layoutAt=-')));
    expect(node, isNot(contains('layoutMs=-')));
    expect(fieldOf(node, 'layoutPasses'), '1');
    expect(
      int.parse(fieldOf(summaryLines().single, 'paintFrame')),
      greaterThanOrEqualTo(1),
    );
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

  group('子页的采样点真的挂载', () {
    testWidgets('HyperosSubpage 产出四条采样点（外壳 + 内容）', (tester) async {
      FirstFrameProbe.begin('push:test-subpage');
      await tester.pumpWidget(
        TestApp(
          home: HyperosSubpage(
            onBack: () {},
            title: const Text('Settings'),
            child: const HyperosListView(
              children: [
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

      final found = nodeLines()
          .map((line) => fieldOf(line, 'node'))
          .where((tag) => tag.isNotEmpty)
          .toSet();
      // `page` 那条挂在 `HyperosPageRoute.buildPage` 上，所以直接渲染子页时不会有它
      // —— 这一条测的是子页内部的四个采样点都真的挂上了。
      expect(
        found,
        equals(<String>{'headerShell', 'header', 'bodyShell', 'body'}),
        reason: '实际挂载的采样点：$found（顶栏那两个多半挂到了不会被使用的分支上）',
      );
      expect(summaryLines().single, contains('nodes=${found.length}'));
    });

    // 真机首轮测下来 `paintMs` 全是缺失（`-`）。分开发现是：**真 `Navigator.push`
    // 的第一帧只做构建与布局，不做绘制** —— 绘制落在第二帧。这条用例把这个口径
    // 钉住：既证明探针能记到绘制，也证明它不是在第一帧记到的。谁改了帧推进逻辑
    // 让这条红了，先回头看类文档第 1 条。
    testWidgets('真 push 的绘制落在第一帧之后（首帧只构建+布局）', (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) => HyperosListTile(
              icon: Icons.settings_outlined,
              title: 'Open',
              onTap: () => HyperosNavigation.push(
                context,
                settings: const RouteSettings(name: '/test/pushed'),
                builder: (_) => const HyperosSubpage(
                  title: Text('Pushed'),
                  child: SizedBox(height: 200, width: 200),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      lines.clear();

      tester.widget<HyperosListTile>(
        find.widgetWithText(HyperosListTile, 'Open'),
      ).onTap!();
      // 首帧只构建+布局；绘制在下一帧，所以要多推几帧才拿得到结算行。
      for (var i = 0; i < 4 && summaryLines().isEmpty; i++) {
        await tester.pump();
      }

      final summary = summaryLines().single;
      expect(summary, contains('route=push:/test/pushed'));
      expect(
        fieldOf(summary, 'paintFrame'),
        isNot('-'),
        reason: '绘制一次都没记到 —— 探针口径漏了，不是「首帧不绘制」',
      );
      expect(
        int.parse(fieldOf(summary, 'paintFrame')),
        greaterThan(1),
        reason: '绘制落回第一帧了 —— 首帧「只构建+布局」这条口径要重新确认',
      );
    });
  });
}
