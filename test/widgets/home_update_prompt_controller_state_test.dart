import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/support_creator_service.dart';
import 'package:university_timetable/widgets/home_update_prompt.dart';

/// 回归钉（2026-10-05 审查第 19 轮）：系统下载器留下的终态不能污染下一次弹窗。
///
/// `watchSystemDownloadProgress` 轮询到终态就关流，而 `systemDownloadId` /
/// `systemDownloadProgress` 这两个字段除了 `beginSystemDownload` /
/// `updateSystemDownload` 之外**没有任何清理点**；控制器又挂在首页 State 上，
/// 活过每一次弹窗。build 里 `hasSystemProgress` 优先于应用内进度、
/// `isFailed`/`isComplete` 还把系统终态 OR 进来 —— 于是上一次"用系统下载器
/// 下载失败"会让下一次弹窗一打开就是红色失败条，而改走应用内下载后进度条仍读着
/// 那条早已死掉的系统下载，永远不动。
void main() {
  SystemDownloadProgress progress(SystemDownloadStatus status) =>
      SystemDownloadProgress(
        status: status,
        downloadedBytes: 4096,
        totalBytes: 10240,
      );

  group('HomeUpdatePromptController 系统下载状态生命周期', () {
    test('终态（失败）不能带进下一次弹窗', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(downloadId: 7, progress: progress(
        SystemDownloadStatus.failed,
      ));
      expect(controller.systemDownloadId, 7);

      controller.discardStaleSystemDownload();

      expect(controller.systemDownloadId, isNull);
      expect(controller.systemDownloadProgress, isNull);
    });

    test('终态（成功）同样要丢弃，否则下次弹窗直接显示"已完成"', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(
        downloadId: 3,
        progress: progress(SystemDownloadStatus.successful),
      );

      controller.discardStaleSystemDownload();

      expect(controller.systemDownloadProgress, isNull);
    });

    test('正在进行（pending / running / paused）一律保留', () {
      for (final status in [
        SystemDownloadStatus.pending,
        SystemDownloadStatus.running,
        SystemDownloadStatus.paused,
      ]) {
        final controller = HomeUpdatePromptController();
        controller.beginSystemDownload(downloadId: 11, progress: progress(status));

        controller.discardStaleSystemDownload();

        expect(controller.systemDownloadId, 11, reason: '$status 是进行中');
        expect(
          controller.systemDownloadProgress?.downloadedBytes,
          4096,
          reason: '$status 时清掉会让重开弹窗的进度条归零',
        );
      }
    });

    test('改走应用内下载时忘掉系统下载器那一份（进度条不能读死掉的下载）', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(
        downloadId: 5,
        progress: progress(SystemDownloadStatus.failed),
      );

      controller.beginInAppDownload();

      expect(controller.isInAppDownloading, isTrue);
      expect(controller.systemDownloadId, isNull);
      expect(controller.systemDownloadProgress, isNull);
      expect(controller.downloadedBytes, 0);
    });

    test('resetInAppDownload 是整体复位：两边状态都要清', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(
        downloadId: 9,
        progress: progress(SystemDownloadStatus.running),
      );
      controller.updateInAppProgress(2048, 4096);

      controller.resetInAppDownload();

      expect(controller.systemDownloadId, isNull);
      expect(controller.downloadedBytes, 0);
      expect(controller.totalBytes, isNull);
      expect(controller.isInAppDownloading, isFalse);
    });

    test('没有系统下载时丢弃是无操作，不会误报也没通知风暴', () {
      final controller = HomeUpdatePromptController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.discardStaleSystemDownload();

      expect(notifications, 0);
      expect(controller.systemDownloadId, isNull);
    });
  });
}
