import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/live_diagnostics_log_viewer_screen.dart';

import '../helpers_test_app.dart';

void main() {
  const sampleLog = '''轻屿课表 - 超级岛诊断日志
exportedAt=1744166400000
brand=Xiaomi
----
time=1744166400000
level=error
category=render_failed
message=Render failed
stackTrace=
  line 1

time=1744166500000
category=debug_snapshot
message=Snapshot payload captured
extras=
  step=refresh
''';

  testWidgets('viewer can filter logs by level and raw tab follows filter', (
    tester,
  ) async {
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

    expect(find.text('正在记录应用日志'), findsOneWidget);
    expect(find.text('Render failed'), findsOneWidget);
    expect(find.text('Snapshot payload captured'), findsOneWidget);
    expect(find.text('显示 2 / 2 条日志'), findsOneWidget);

    await tester.tap(find.text('错误 1'));
    await tester.pumpAndSettle();

    expect(find.text('Render failed'), findsOneWidget);
    expect(find.text('Snapshot payload captured'), findsNothing);
    expect(find.text('显示 1 / 2 条日志'), findsOneWidget);

    await tester.tap(find.text('原文'));
    await tester.pumpAndSettle();

    expect(find.text('原文视图会跟随当前等级筛选，只显示对应日志块。'), findsOneWidget);
    expect(find.textContaining('Render failed'), findsOneWidget);
    expect(find.textContaining('Snapshot payload captured'), findsNothing);

    await tester.tap(find.byTooltip('导出日志'));
    await tester.pumpAndSettle();
    expect(exported, 1);

    await tester.tap(find.byTooltip('清空日志'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(find.text('已清空应用日志'), findsOneWidget);
  });
}
