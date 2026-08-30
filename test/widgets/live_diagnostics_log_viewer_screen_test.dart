import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/live_diagnostics_log_viewer_screen.dart';

import '../helpers_test_app.dart';

void main() {
  // 分页窗口测试用：450 条日志，初始窗口只应渲染最新 200 条。
  String buildPagedLog(int count) {
    final buffer = StringBuffer(
      '轻屿课表 - 应用日志\nexportedAt=1744166400000\nbrand=Xiaomi\n----\n',
    );
    for (var i = 0; i < count; i++) {
      buffer.write(
        'time=${1744166400000 + i * 1000}\n'
        'level=info\nsource=app\ncategory=nav\nmessage=日志条目 $i\n\n',
      );
    }
    return buffer.toString();
  }

  // 头部筛选条是横向 Scrollable，scrollUntilVisible 的 Scrollable.first 会
  // 命中它；这里直拖日志列表滚动，直到目标进入构建范围。
  Future<void> dragToListTarget(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40; i++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, 800));
      await tester.pumpAndSettle();
    }
    fail('未能滚动到目标：$finder');
  }

  const sampleLog = '''轻屿课表 - 应用日志
exportedAt=1744166400000
brand=Xiaomi
----
time=1744166400000
level=error
source=native
category=render_failed
message=渲染失败
stackTrace=
  line 1

time=1744166500000
source=app
category=debug_snapshot
message=已捕获快照负载
extras=
  step=refresh
''';

  testWidgets('viewer can filter logs by level and raw tab follows filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var exported = 0;
    var cleared = 0;
    await tester.pumpWidget(
      TestApp(
        home: LiveDiagnosticsLogViewerScreen(
          title: '日志中心',
          rawLog: sampleLog,
          isRecordingEnabled: true,
          onExport: (_) async {
            exported += 1;
          },
          onClear: () async {
            cleared += 1;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('查看与排序'), findsOneWidget);
    expect(find.textContaining('渲染失败'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('已捕获快照负载'),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('已捕获快照负载'), findsOneWidget);

    await tester.tap(find.textContaining('渲染失败').first);
    await tester.pumpAndSettle();
    expect(find.text('超级岛'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('已捕获快照负载'),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('已捕获快照负载').first);
    await tester.pumpAndSettle();
    expect(find.text('应用'), findsOneWidget);

    await tester.tap(find.text('错误 1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('渲染失败'), findsWidgets);
    expect(find.textContaining('已捕获快照负载'), findsNothing);

    await tester.tap(find.bySemanticsLabel('查看与排序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('原文'));
    await tester.pumpAndSettle();
    // 点遮罩关掉弹层，回到正文验证视图确实切到了原文。
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.textContaining('渲染失败'), findsOneWidget);
    expect(find.textContaining('已捕获快照负载'), findsNothing);

    await tester.tap(find.bySemanticsLabel('导出日志'));
    await tester.pumpAndSettle();
    expect(exported, 1);

    await tester.tap(find.bySemanticsLabel('清空日志'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
  });

  testWidgets('viewer can sort logs by time ascending and descending', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      TestApp(
        home: LiveDiagnosticsLogViewerScreen(
          title: '日志中心',
          rawLog: sampleLog,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('渲染失败'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('查看与排序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('倒序'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    final descending = find.textContaining('已捕获快照负载');
    expect(descending, findsWidgets);
    expect(
      tester.getTopLeft(descending.first).dy <
          tester.getTopLeft(find.textContaining('渲染失败').first).dy,
      isTrue,
    );

    await tester.tap(find.bySemanticsLabel('查看与排序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('正序'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.textContaining('渲染失败').first).dy <
          tester.getTopLeft(find.textContaining('已捕获快照负载').first).dy,
      isTrue,
    );
  });

  testWidgets('viewer updates when watchRawLog emits new content', (
    tester,
  ) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      TestApp(
        home: LiveDiagnosticsLogViewerScreen(
          title: '日志中心',
          watchRawLog: () => controller.stream,
        ),
      ),
    );
    await tester.pump();

    controller.add(sampleLog);
    await tester.pumpAndSettle();

    expect(find.textContaining('渲染失败'), findsWidgets);
  });

  testWidgets(
    'recording toggle lives outside the viewer; paused state shows a hint row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        TestApp(
          home: LiveDiagnosticsLogViewerScreen(
            title: '日志中心',
            rawLog: sampleLog,
            isRecordingEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 开关不得回到本页（页面只留只读状态提示），防止回归。
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('记录已关闭'), findsOneWidget);
    },
  );

  testWidgets(
    'scrolled content sits flush under the level filter bar (no dead strip)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 长列表是复现关键：内容过短会走「短页弹回补偿」分支，掩盖死区。
      final longLog = StringBuffer(
        '轻屿课表 - 应用日志\nexportedAt=1744166400000\nbrand=Xiaomi\n----\n',
      );
      for (var i = 0; i < 40; i++) {
        longLog.write(
          'time=${1744166400000 + i * 1000}\n'
          'level=info\nsource=app\ncategory=nav\nmessage=导航路由已变更 $i\n\n',
        );
      }

      await tester.pumpWidget(
        MediaQuery(
          // 注入真机状态栏 inset（34110c5e 同款教训）。
          data: const MediaQueryData(padding: EdgeInsets.only(top: 51)),
          child: TestApp(
            home: LiveDiagnosticsLogViewerScreen(
              title: '日志中心',
              rawLog: longLog.toString(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double listViewportTop() =>
          tester.getTopLeft(find.byType(ListView).first).dy;
      double chipsBottom() =>
          tester.getBottomLeft(find.textContaining('全部').first).dy;

      // 静止：列表视口顶贴着筛选条（仅扩展区底距 + 列表顶距的余量）。
      final restGap = listViewportTop() - chipsBottom();
      expect(restGap, greaterThanOrEqualTo(0));
      expect(restGap, lessThan(24), reason: '静止时筛选条下不应有大片空白');

      // 滚动后：折叠大标题曾让 inset 保持展开态高度，收起的标题区变成
      // 裁切死区；关闭折叠后视口必须仍贴着筛选条。
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      final scrolledGap = listViewportTop() - chipsBottom();
      expect(scrolledGap, greaterThanOrEqualTo(0));
      expect(
        scrolledGap,
        lessThan(24),
        reason: '滚动收起后筛选条下不得留出大标题高度的空白死区',
      );
    },
  );

  testWidgets('log list pages: renders the latest window, loads earlier on demand', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      TestApp(
        home: LiveDiagnosticsLogViewerScreen(
          title: '日志中心',
          rawLog: buildPagedLog(450),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始只渲染最新一页（直传 rawLog 不自动贴底，视口停在列表顶）：
    // 顶部是加载行+窗口最早条目 250，最旧条目不进列表；
    // 等级计数仍按全量 450 统计。
    expect(find.textContaining('日志条目 250'), findsOneWidget);
    expect(find.textContaining('日志条目 0'), findsNothing);
    expect(find.text('全部 450'), findsOneWidget);

    // 点「加载更早」：窗口起点前移一页（450-200-200=50），
    // 视口锚在原条目 250 上不跳动。
    await tester.tap(find.textContaining('加载更早日志'));
    await tester.pumpAndSettle();
    expect(find.textContaining('日志条目 250'), findsOneWidget);
    await dragToListTarget(tester, find.textContaining('日志条目 50'));
    expect(find.textContaining('还有 50 条'), findsOneWidget);
    expect(find.textContaining('日志条目 49'), findsNothing);

    // 再次加载把最早一段全部载入，加载行随之消失。
    await tester.tap(find.textContaining('加载更早日志'));
    await tester.pumpAndSettle();
    await dragToListTarget(tester, find.textContaining('日志条目 0'));
    expect(find.textContaining('加载更早日志'), findsNothing);
  });

  testWidgets('export receives the full log while the list stays paged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? exportedText;
    await tester.pumpWidget(
      TestApp(
        home: LiveDiagnosticsLogViewerScreen(
          title: '日志中心',
          rawLog: buildPagedLog(450),
          onExport: (text) async {
            exportedText = text;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 列表按分页只渲染最新一页，但导出拿到的必须是从最早到最新的全量日志。
    expect(find.textContaining('日志条目 0'), findsNothing);
    await tester.tap(find.bySemanticsLabel('导出日志'));
    await tester.pumpAndSettle();
    expect(exportedText, isNotNull);
    expect(exportedText!, contains('日志条目 0'));
    expect(exportedText!, contains('日志条目 449'));
  });

  testWidgets('new arrivals do not shift the list while reading earlier pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = StreamController<String>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      TestApp(
        home: LiveDiagnosticsLogViewerScreen(
          title: '日志中心',
          watchRawLog: () => controller.stream,
        ),
      ),
    );
    await tester.pump();
    controller.add(buildPagedLog(250));
    await tester.pumpAndSettle();

    // 流式首帧自动贴最新（底部），滚到顶部点「加载更早」：
    // 250 条的窗口起点 50，一次加载后起点钉在 0。
    await dragToListTarget(tester, find.textContaining('加载更早日志'));
    await tester.tap(find.textContaining('加载更早日志'));
    await tester.pumpAndSettle();

    // 读历史期间有新日志写入：钉住的起点不得移动，视口内容原地不动。
    // append 分支只挂 250ms 刷新计时器、不同步排帧，需显式冲刷计时器。
    controller.add(buildPagedLog(253));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('日志条目 50'), findsOneWidget);
    expect(find.textContaining('加载更早日志'), findsNothing);
    expect(find.text('全部 253'), findsOneWidget);
  });
}
