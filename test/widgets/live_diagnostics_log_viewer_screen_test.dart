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
}
