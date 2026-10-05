import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/support_creator_service.dart';
import 'package:university_timetable/widgets/home_update_prompt.dart';

/// 更新弹窗控制器的失败原因与系统下载记录归属（2026-10-05 审查）。
///
/// 两条缺陷都能在这一层证明，不需要整页夹具：
///
/// 1. **失败被统一报成"调用系统下载管理器失败"**。`isFailed` 是
///    `controller.isInAppFailed || systemFailed` 两件事的 OR，而视图里那条分支只渲染
///    `l10n.aboutSystemDownloaderFailed`（「调用系统下载管理器失败」）。控制器从来没有
///    任何字段承载真实原因，首页 `timetable_screen.dart:10019/10033` 手里的
///    `update_download_hash_mismatch` / `update_download_http_failed` /
///    `update_sha256_unverified_install_refused` 一进门就被丢掉。后果是：镜像/文件被篡改
///    导致 SHA-256 校验拒绝安装时，用户看到一句与实际无关的"系统下载管理器失败"，
///    还留着一个「继续下载」按钮，于是反复重试同一个污染源 —— 而"校验没过"这个安全信号
///    完全看不见。同族的关于页（`about_screen.dart:1336`）是把 error 显示出来的。
/// 2. **系统下载进度不认得自己属于哪条下载**。首页的
///    `_systemDownloadSubscription` 只声明（:311）+ dispose 里 cancel（:703），
///    全仓**从未被赋值** —— 起流的地方用 `unawaited` 闭包把句柄丢了，所以旧 watcher
///    关不掉；而 `updateSystemDownload(progress)` 不带 downloadId，两条 watcher 会交替写
///    同一个字段，新下载的百分比会被旧那条的"排队中"覆盖回去。
/// 3. **unknown 记录仍被显示成"请到下载列表查看进度"**。上一批把"什么算 settled"
///    统一成 `SystemDownloadProgress.isSettled`（轮询到 unknown 就收流），但视图里
///    `_systemProgressLabel` 还有第四份口径：`unknown => aboutSystemDownloaderQueued`。
///    于是下载行被用户从系统「下载管理」里删掉之后，弹窗同时显示 0% 进度条 +
///    "请在下载列表里查看进度"（轮询已停，永远不会动）+ 还能点的「立即下载」。
///    控制器一侧把 unknown 直接当"这条记录已经没了"来清理，UI 就退回正常动作行，
///    不需要新文案，也不留第四份判断。
void main() {
  SystemDownloadProgress progress(
    SystemDownloadStatus status, {
    int downloaded = 10,
  }) => SystemDownloadProgress(
    status: status,
    downloadedBytes: downloaded,
    totalBytes: 100,
  );

  group('应用内失败的真正原因', () {
    test('finishInAppDownload 要把 error 码留给视图，而不是只置一个 isFailed', () {
      final controller = HomeUpdatePromptController();
      controller.beginInAppDownload();

      controller.finishInAppDownload(
        success: false,
        error: 'update_sha256_unverified_install_refused',
      );

      expect(controller.isInAppFailed, isTrue);
      expect(
        controller.inAppFailureReason,
        'update_sha256_unverified_install_refused',
        reason: '视图要能区分"校验没过"与"系统下载器调不动"，否则谎报',
      );
    });

    test('对照：取消与成功都不该留下失败原因', () {
      final controller = HomeUpdatePromptController();
      controller.beginInAppDownload();
      controller.finishInAppDownload(
        success: false,
        cancelled: true,
        error: 'update_download_http_failed',
      );
      expect(controller.isInAppCancelled, isTrue);
      expect(
        controller.inAppFailureReason,
        isNull,
        reason: '用户自己取消的不算失败，也不该显示失败原因',
      );

      controller.beginInAppDownload();
      controller.finishInAppDownload(success: true);
      expect(controller.isInAppComplete, isTrue);
      expect(controller.inAppFailureReason, isNull);
    });

    test('重开下载与整体复位都要清掉上一次的失败原因', () {
      final controller = HomeUpdatePromptController();
      controller.beginInAppDownload();
      controller.finishInAppDownload(
        success: false,
        error: 'update_download_hash_mismatch',
      );
      expect(controller.inAppFailureReason, isNotNull);

      controller.beginInAppDownload();
      expect(controller.inAppFailureReason, isNull, reason: '再点一次下载就该忘掉上次');

      controller.finishInAppDownload(
        success: false,
        error: 'update_download_hash_mismatch',
      );
      controller.resetInAppDownload();
      expect(controller.inAppFailureReason, isNull);
    });
  });

  group('系统下载记录的归属', () {
    test('updateSystemDownload 必须认得 downloadId，旧 watcher 的进度不许覆盖新的', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(
        downloadId: 11,
        progress: progress(SystemDownloadStatus.running, downloaded: 60),
      );

      controller.updateSystemDownload(
        12,
        progress(SystemDownloadStatus.running, downloaded: 90),
      );
      expect(
        controller.systemDownloadProgress?.downloadedBytes,
        60,
        reason: '属于别的下载 id 的进度必须当场被丢弃，否则两条 watcher 交替写同一字段',
      );

      controller.updateSystemDownload(
        11,
        progress(SystemDownloadStatus.paused, downloaded: 65),
      );

      expect(controller.systemDownloadId, 11);
      expect(
        controller.systemDownloadProgress?.downloadedBytes,
        65,
        reason: '属于别的下载 id 的进度要丢弃，否则两条 watcher 交替写同一个字段',
      );
      expect(controller.systemDownloadProgress?.status, SystemDownloadStatus.paused);
    });

    test('unknown 表示这条下载已经不在了：清掉记录而不是显示"去下载列表看进度"', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(
        downloadId: 21,
        progress: progress(SystemDownloadStatus.pending),
      );

      controller.updateSystemDownload(
        21,
        progress(SystemDownloadStatus.unknown),
      );

      expect(controller.systemDownloadId, isNull);
      expect(
        controller.systemDownloadProgress,
        isNull,
        reason: '轮询到 unknown 就停了，留着它只会显示一条永远不动的 0% + queued 文案',
      );
    });

    test('对照：begin 时就拿到 unknown 也不该立起一条死记录', () {
      final controller = HomeUpdatePromptController();

      controller.beginSystemDownload(
        downloadId: 31,
        progress: progress(SystemDownloadStatus.unknown),
      );

      expect(controller.systemDownloadId, isNull);
      expect(controller.systemDownloadProgress, isNull);
    });

    test('对照：成功与失败终态要照常留着，供弹窗显示"可安装"或失败条', () {
      final controller = HomeUpdatePromptController();
      controller.beginSystemDownload(
        downloadId: 41,
        progress: progress(SystemDownloadStatus.running),
      );

      controller.updateSystemDownload(
        41,
        progress(SystemDownloadStatus.successful, downloaded: 100),
      );

      expect(controller.systemDownloadId, 41);
      expect(
        controller.systemDownloadProgress?.status,
        SystemDownloadStatus.successful,
      );
    });
  });
}
