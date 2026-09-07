// 回归测试:OpenContainer(vendored 优化版)在 container transform 转场期间
// 不得逐帧重建 closedBuilder/openBuilder。
//
// 背景:上游 animations 2.2.0 的 buildPage 把两个 builder 调用放进
// AnimatedBuilder.builder(未用 child 参数),300ms 转场实测 openBuilder
// 被调 20 次——日视图课程详情展开时整个 AddCourseScreen 表单页逐帧
// rebuild,UI 线程爆帧,动画呈幻灯片感。vendored 版把内容子树缓存为
// identical 实例,element diff 短路,逐帧只重建轻量 morph 壳。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/open_container.dart';

void main() {
  Future<void> pumpOpenContainer(WidgetTester tester, List<int> calls) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OpenContainer<void>(
              closedBuilder: (context, open) {
                calls[0]++;
                return TextButton(onPressed: open, child: const Text('open me'));
              },
              openBuilder: (context, close) {
                calls[1]++;
                return const Scaffold(body: Text('editor'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('打开转场期间 openBuilder 只构建一次(而非每帧)', (tester) async {
    final calls = List<int>.filled(2, 0);
    await pumpOpenContainer(tester, calls);
    final closedBefore = calls[0];

    await tester.tap(find.text('open me'));
    await tester.pump(); // 转场第一帧
    // 逐帧推进 300ms 转场(默认 transitionDuration)。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    // 上游每帧重调:300ms ≈ 19 帧 → openCalls≈20。优化后:打开只建一次。
    expect(calls[1], 1, reason: 'openBuilder 应只在转场期间构建一次');
    // closed 副本:打开转场开始时建一次(源树占位后不再每帧重建)。
    expect(calls[0] - closedBefore, lessThanOrEqualTo(2),
        reason: 'closedBuilder 不应每帧重建');
    expect(find.text('editor'), findsOneWidget);
  });

  testWidgets('关闭转场仍完整播放且 closed 卡副本恢复显示', (tester) async {
    final calls = List<int>.filled(2, 0);
    await pumpOpenContainer(tester, calls);
    await tester.tap(find.text('open me'));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);

    // 关闭:编辑器返回键路径等价于 closeContainer → pop。
    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pop();
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.text('open me'), findsOneWidget, reason: '关闭后源卡片应恢复');
    expect(tester.takeException(), isNull);
  });
}