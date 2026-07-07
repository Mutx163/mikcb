import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/widgets/warehouse_macro_replayer.dart';
import 'package:university_timetable/widgets/warehouse_playback_overlay.dart';

import '../helpers_test_app.dart';

ReplayProgress _progress({
  ReplayStepStatus status = ReplayStepStatus.running,
  String? errorMessage,
  String? pauseReason,
}) {
  return ReplayProgress(
    currentStepIndex: 0,
    totalSteps: 2,
    currentStep: const MacroStep(type: MacroStepType.delay, waitMs: 1000),
    status: status,
    errorMessage: errorMessage,
    pauseReason: pauseReason,
  );
}

Future<void> _pumpOverlay(
  WidgetTester tester, {
  required PlaybackUiState state,
  ReplayProgress? progress,
  VoidCallback? onCancel,
  VoidCallback? onContinueAfterPause,
  VoidCallback? onDismiss,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    TestApp(
      home: PlaybackOverlay(
        progress: progress ?? _progress(),
        state: state,
        schoolName: '测试学校',
        adapterName: '测试教务',
        onCancel: onCancel,
        onContinueAfterPause: onContinueAfterPause,
        onDismiss: onDismiss,
        onRetry: onRetry,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('paused overlay shows manual controls', (tester) async {
    var cancelled = false;
    var continued = false;

    await _pumpOverlay(
      tester,
      state: PlaybackUiState.pausedForInput,
      progress: _progress(
        status: ReplayStepStatus.pausedForInput,
        pauseReason: '请手动输入验证码；完成后点击继续',
      ),
      onCancel: () => cancelled = true,
      onContinueAfterPause: () => continued = true,
    );

    expect(find.text('需要手动操作'), findsOneWidget);
    expect(find.textContaining('验证码'), findsOneWidget);

    await tester.tap(find.text('取消导入'));
    await tester.pump();
    await tester.tap(find.text('继续'));
    await tester.pump();

    expect(cancelled, isTrue);
    expect(continued, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('executing import state is distinct from finished', (
    tester,
  ) async {
    await _pumpOverlay(tester, state: PlaybackUiState.executingImport);

    expect(find.text('回放完成，正在执行导入脚本…'), findsOneWidget);
    expect(find.text('导入完成'), findsNothing);
  });

  testWidgets('finished state no longer renders centered overlay', (
    tester,
  ) async {
    await _pumpOverlay(tester, state: PlaybackUiState.finished);

    expect(find.text('导入完成'), findsNothing);
  });
}
