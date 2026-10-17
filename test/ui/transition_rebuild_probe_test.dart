import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/android_animation_scale_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';

/// 转场期间「页面子树被拆装」的结构性回归探针。
///
/// 背景（2026-10-16 真机卡顿/闪烁定案）：`_MiuixNavPageTransition` 此前按动画
/// 状态**增删包装层**（根 `Transform↔Stack`、视差补底、`ClipRRect`、`Opacity`）。
/// 页面内容由 `_ModalScopeState` 的 `_page ??= RepaintBoundary(key: _subtreeKey)`
/// 缓存（GlobalKey），包装层 runtimeType 一变，整棵页面子树就被 deactivate →
/// GlobalKey 复挂：依赖 InheritedWidget 的节点全部 `didChangeDependencies`，
/// 渲染子树整体强制重排 —— 重页面上就是动画中途的重排帧，真机读作
/// 「滑到一半冻一下」「返回时闪一下」。State 不销毁（GlobalKey 保命），
/// 所以只数 initState 探不出 —— 必须数 [deactivate]。
///
/// 本文件钉死：push / pop 全程，页面内容 State 的 deactivate 次数为 0。
class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.mounts[widget.label] = (_Probe.mounts[widget.label] ?? 0) + 1;
  }

  @override
  void deactivate() {
    _Probe.deactivates[widget.label] =
        (_Probe.deactivates[widget.label] ?? 0) + 1;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Probe extends StatefulWidget {
  const _Probe({required this.label, required this.child});

  final String label;
  final Widget child;

  static final Map<String, int> mounts = {};
  static final Map<String, int> deactivates = {};

  static void reset() {
    mounts.clear();
    deactivates.clear();
  }

  @override
  State<_Probe> createState() => _ProbeState();
}

Widget _topPage(BuildContext popContext) => Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Probe(label: 'top', child: Text('top-content')),
            ElevatedButton(
              onPressed: () => Navigator.of(popContext).pop(),
              child: const Text('back'),
            ),
          ],
        ),
      ),
    );

void main() {
  setUp(() {
    _Probe.reset();
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
  });

  /// 三层：home → middle（带 push2 按钮）→ top（带返回按钮），middle/top 都挂探针。
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F2F2),
          body: Builder(
            builder: (homeContext) => Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  homeContext,
                  settings: const RouteSettings(name: 'middle'),
                  builder: (middleContext) => Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Probe(
                            label: 'middle',
                            child: Text('middle-content'),
                          ),
                          ElevatedButton(
                            onPressed: () => HyperosNavigation.push(
                              middleContext,
                              settings: const RouteSettings(name: 'top'),
                              builder: (_) => _topPage(middleContext),
                            ),
                            child: const Text('push2'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    // middle 页此刻已挂载，deactivate 计数为基线（正常为 0）。
  }

  Future<void> pushTop(WidgetTester tester) async {
    await tester.tap(find.text('push2'));
    // 首帧门槛：push 动画在新页首帧画完前锁 0，下一帧才锚定起点
    //（与既有转场测试同口径）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('push 全程：两页内容子树零 deactivate（结构恒定）', (tester) async {
    await pumpApp(tester);
    expect(_Probe.mounts['middle'], 1);
    expect(_Probe.deactivates['middle'] ?? 0, 0);

    await pushTop(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();

    expect(
      _Probe.deactivates['top'] ?? 0,
      0,
      reason: '栈顶新页在 push 全程不应被 deactivate —— '
          '转场包装若按动画状态增删（ClipRRect/Opacity/补底/根布局），'
          '页面子树会在起步与收尾各被拆装一次（真机卡顿/闪烁根因）',
    );
    expect(
      _Probe.deactivates['middle'] ?? 0,
      0,
      reason: '被覆盖旧页在 push 全程不应被 deactivate —— '
          '视差补底/蒙层/透明度包装若在 cover>0 时才挂上，'
          '起步帧会把整棵旧页子树拆装一次',
    );
    expect(_Probe.mounts['middle'], 1, reason: 'State 顺带不得销毁');
    expect(_Probe.mounts['top'], 1);
  });

  testWidgets('pop 全程：被露出的页面内容子树零 deactivate（结构恒定）', (tester) async {
    await pumpApp(tester);
    await pushTop(tester);
    await tester.pumpAndSettle();
    expect(_Probe.deactivates['middle'] ?? 0, 0);

    await tester.tap(find.text('back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();

    expect(
      _Probe.deactivates['middle'] ?? 0,
      0,
      reason: 'pop 收尾时被露出的页面不应被 deactivate —— '
          '包装若在 cover 归零时摘掉，收尾帧会把整棵露出页子树拆装一次'
          '（返回时闪一下的根因）',
    );
    expect(_Probe.mounts['middle'], 1);
  });
}
