import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/live_diagnostics_log_viewer_screen.dart';

import '../helpers_test_app.dart';

void main() {
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
}
