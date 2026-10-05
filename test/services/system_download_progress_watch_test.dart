import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/support_creator_service.dart';

/// 系统下载器进度轮询的停止条件（2026-10-05 审查）。
///
/// 原生侧 `MainActivity.kt:1724-1731` 在**查不到这条下载**时返回的不是 null，而是一份
/// `{status:"unknown", downloadedBytes:0, totalBytes:-1}`；Dart 侧原先只有
/// `successful/failed` 算终态（`SystemDownloadProgress.isFinished`），而
/// `watchSystemDownloadProgress` 是 `while (true) { 查; yield; if (isFinished) return; delay }`。
/// 两者合起来的后果是：用户把那条下载从系统「下载管理」里删掉（或下载行被清理）之后，
/// 这条流每 350 毫秒查一次平台通道、**永不停止** —— 唯一订阅方在首页
/// （`timetable_screen.dart:10044-10059`），`if (!mounted) return` 只有整页销毁才生效，
/// 而首页活满整个会话。组件那侧还把 unknown 判成"进行中"
/// （`home_update_prompt.dart` 的 `_isSystemDownloadBusy`），于是弹窗进度条永远停在
/// 0%「下载中」，用户只能取消。
///
/// 同一条状态原先在三处有三种口径：轮询侧"还在跑"、组件侧"进行中"、控制器侧
/// （`discardStaleSystemDownload`）"已结束"。本轮统一到 [SystemDownloadProgress.isSettled]，
/// 并让订阅方注释里承诺的"下一次观察恢复"真的存在（查询抛错时重试若干次，
/// 而不是第一次异常就悄悄停流、进度冻在最后一个值上）。
SystemDownloadProgress progressOf(SystemDownloadStatus status) =>
    SystemDownloadProgress(
      status: status,
      downloadedBytes: 10,
      totalBytes: 100,
    );

/// 依次返回 [results] 的假读取口；`StateError` 表示平台通道抛错，`null` 表示原生说没有这条记录。
/// 列表用完后重复返回最后一项，这样"永不停止"的旧实现会一直吐同一个状态。
class _ScriptedCalls {
  int calls = 0;
}

SystemDownloadProgressReader scriptedReader(List<Object?> results) {
  final state = _ScriptedCalls();
  return (int downloadId) {
    final index = state.calls < results.length
        ? state.calls
        : results.length - 1;
    state.calls++;
    final outcome = results[index];
    if (outcome is StateError) {
      return Future<SystemDownloadProgress?>.error(outcome);
    }
    return Future<SystemDownloadProgress?>.value(
      outcome as SystemDownloadProgress?,
    );
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settleTimeout = Duration(seconds: 5);

  Future<List<SystemDownloadProgress>> collect(
    List<Object?> results,
    int downloadId,
  ) {
    return SupportCreatorService()
        .watchSystemDownloadProgress(
          downloadId,
          interval: Duration.zero,
          reader: scriptedReader(results),
        )
        .toList()
        .timeout(settleTimeout);
  }

  group('轮询停止条件', () {
    test('unknown（下载行已不存在）必须收流，不能每 350 毫秒查一辈子', () async {
      final emitted = await collect([
        progressOf(SystemDownloadStatus.unknown),
      ], 7);

      expect(emitted, hasLength(1));
      expect(emitted.single.status, SystemDownloadStatus.unknown);
    });

    test('对照：successful 与 failed 照旧在第一条就收流', () async {
      for (final status in [
        SystemDownloadStatus.successful,
        SystemDownloadStatus.failed,
      ]) {
        final emitted = await collect([progressOf(status)], 1);
        expect(emitted, hasLength(1), reason: '$status 是终态');
      }
    });

    test('对照：running → paused → failed 会一路发到 failed 才停', () async {
      final emitted = await collect([
        progressOf(SystemDownloadStatus.running),
        progressOf(SystemDownloadStatus.paused),
        progressOf(SystemDownloadStatus.failed),
        progressOf(SystemDownloadStatus.running),
      ], 2);

      expect(
        emitted.map((item) => item.status).toList(),
        <SystemDownloadStatus>[
          SystemDownloadStatus.running,
          SystemDownloadStatus.paused,
          SystemDownloadStatus.failed,
        ],
      );
    });

    test('null（原生明确说没有这条记录）立即收流', () async {
      final emitted = await collect(<Object?>[null], 3);
      expect(emitted, isEmpty);
    });
  });

  group('查询抛错时的恢复', () {
    test('单次抛错要重试，不能悄悄把进度冻在最后一个值上', () async {
      final emitted = await collect([
        progressOf(SystemDownloadStatus.running),
        StateError('download_query_failed'),
        progressOf(SystemDownloadStatus.successful),
      ], 4);

      expect(
        emitted.map((item) => item.status).toList(),
        <SystemDownloadStatus>[
          SystemDownloadStatus.running,
          SystemDownloadStatus.successful,
        ],
        reason: '订阅方的注释写着"让下一次观察恢复"，那就得真的再查一次',
      );
    });

    test('连续抛错到上限要把错误交给订阅方，而不是无限重试', () async {
      await expectLater(
        collect([
          StateError('download_query_failed'),
          StateError('download_query_failed'),
          StateError('download_query_failed'),
          StateError('download_query_failed'),
        ], 5),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('统一后的状态口径', () {
    test('isSettled 涵盖三个终态，isFinished 只认成功与失败', () {
      expect(progressOf(SystemDownloadStatus.successful).isFinished, isTrue);
      expect(progressOf(SystemDownloadStatus.failed).isFinished, isTrue);
      expect(progressOf(SystemDownloadStatus.unknown).isFinished, isFalse);
      for (final status in [
        SystemDownloadStatus.successful,
        SystemDownloadStatus.failed,
        SystemDownloadStatus.unknown,
      ]) {
        expect(
          progressOf(status).isSettled,
          isTrue,
          reason: '$status 之后这条记录不可能再有进展',
        );
      }
      for (final status in [
        SystemDownloadStatus.pending,
        SystemDownloadStatus.running,
        SystemDownloadStatus.paused,
      ]) {
        expect(progressOf(status).isSettled, isFalse);
      }
    });
  });
}
