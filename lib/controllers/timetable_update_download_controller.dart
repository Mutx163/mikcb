import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_service.dart';
import '../services/support_creator_service.dart';
import '../widgets/home_update_prompt.dart';

/// 版本更新下载族（2026-10-20 从 `timetable_update_download_part.dart` 转成
/// 独立库）。
///
/// 负责「检查结果的首页提示 / 系统下载器 / 应用内下载与换源重试 / 取消 /
/// 打开 Release 页」；所有需要 BuildContext 的方法都由调用方传入，控制器本身
/// 不持有屏幕或 State。
class TimetableUpdateDownloadController {
  TimetableUpdateDownloadController({
    AppUpdateService? updateService,
    SupportCreatorService? supportCreatorService,
  }) : updateService = updateService ?? AppUpdateService(),
       supportCreatorService =
           supportCreatorService ?? SupportCreatorService();

  final AppUpdateService updateService;
  final SupportCreatorService supportCreatorService;
  final HomeUpdatePromptController promptController =
      HomeUpdatePromptController();

  AppUpdateDownloadController? _homeDownloadController;
  StreamSubscription<SystemDownloadProgress>? _systemDownloadSubscription;
  bool _isPromptVisible = false;
  bool _hasPresentedPrompt = false;
  bool? _lastCheckIncludePrerelease;
  Future<void>? _inflightCheck;
  bool _disposed = false;

  void scheduleUpdateCheckIfNeeded({
    required bool enabled,
    required TimetableProvider provider,
    required bool Function() isMounted,
    required Future<void> Function({required bool includePrerelease}) check,
  }) {
    if (!enabled) {
      return;
    }
    final includePrerelease = provider.settings.appUpdateIncludePrerelease;
    if (_lastCheckIncludePrerelease == includePrerelease) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) {
        return;
      }
      unawaited(check(includePrerelease: includePrerelease));
    });
  }

  Future<void> checkForAppUpdate({
    required bool includePrerelease,
    required Future<AppUpdateCheckResult?> Function(bool includePrerelease)
    runCheck,
    required void Function(AppUpdateCheckResult result) onResult,
    required bool Function() isMounted,
  }) async {
    // De-dupe by sharing the in-flight future; concurrent callers await the
    // same check instead of racing past a boolean flag.
    final inflight = _inflightCheck;
    if (inflight != null) {
      await inflight;
      return;
    }
    _lastCheckIncludePrerelease = includePrerelease;
    final future = () async {
      final result = await runCheck(includePrerelease);
      if (result != null && isMounted()) {
        onResult(result);
      }
    }();
    _inflightCheck = future;
    try {
      await future;
    } finally {
      if (identical(_inflightCheck, future)) {
        _inflightCheck = null;
      }
    }
  }

  /// 检测到新版本后在首页弹出更新提醒（受「弹窗提醒」开关控制，关闭时保持
  /// 静默，仅依赖 ⋮ 菜单红点角标）。
  void scheduleHomeUpdatePrompt({
    required BuildContext context,
    required TimetableSettings settings,
    required AppUpdateCheckResult result,
  }) {
    if (!result.hasUpdate ||
        result.latestRelease == null ||
        _hasPresentedPrompt ||
        _isPromptVisible) {
      return;
    }
    if (!settings.appUpdatePromptEnabled) {
      return;
    }
    final release = result.latestRelease!;
    final channel = AppUpdateDownloadChannelX.fromValue(
      settings.appUpdateDownloadChannel,
    );
    final source = AppUpdateDownloadSourceX.fromValue(
      settings.appUpdateDownloadSource,
    );
    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final mirrorPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    final effectiveDownloadUrl = updateService.getEffectiveDownloadUrl(
      release: release,
      channel: channel,
      source: source,
      mirrorUrlPrefix: mirrorPrefix,
    );
    final hasDirectDownload =
        effectiveDownloadUrl != null && effectiveDownloadUrl.trim().isNotEmpty;
    final promptDownloadUrl = effectiveDownloadUrl ?? release.releaseUrl;
    if (promptDownloadUrl.trim().isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || _hasPresentedPrompt || _isPromptVisible) {
        return;
      }
      // 首页不在栈顶时（例如启动直达二级页）不打断用户。
      if (ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _hasPresentedPrompt = true;
      _isPromptVisible = true;
      unawaited(
        _showHomeUpdatePromptAndTrackState(
          context: context,
          settings: settings,
          release: release,
          currentVersion: result.currentVersion,
          channel: channel,
          downloadUrl: promptDownloadUrl,
          hasDirectDownload: hasDirectDownload,
        ),
      );
    });
  }

  Future<void> _showHomeUpdatePromptAndTrackState({
    required BuildContext context,
    required TimetableSettings settings,
    required AppReleaseInfo release,
    required String currentVersion,
    required AppUpdateDownloadChannel channel,
    required String downloadUrl,
    required bool hasDirectDownload,
  }) async {
    try {
      await showHomeUpdatePrompt(
        context,
        release: release,
        currentVersion: currentVersion,
        downloadChannel: channel,
        hasDirectDownload: hasDirectDownload,
        controller: promptController,
        onDownload: () async {
          if (!hasDirectDownload) {
            await _openUpdateReleasePage(release.releaseUrl);
            return false;
          }
          return startHomeUpdateDownload(
            context: context,
            settings: settings,
            release: release,
            channel: channel,
            downloadUrl: downloadUrl,
          );
        },
        // 「查看 Release」开列表页（按渠道）；「没有直链时去拿安装包」那条仍开
        // tag 页——那里才有本版的资产。
        onViewRelease: () => _openUpdateReleasePage(
          AppUpdateService.releaseListUrlFor(channel),
        ),
        onCancelDownload: cancelHomeUpdateDownload,
        onResumeDownload: () => startHomeUpdateDownload(
          context: context,
          settings: settings,
          release: release,
          channel: channel,
          downloadUrl: downloadUrl,
        ),
      );
    } finally {
      _isPromptVisible = false;
    }
  }

  Future<bool> startHomeUpdateDownload({
    required BuildContext context,
    required TimetableSettings settings,
    required AppReleaseInfo release,
    required AppUpdateDownloadChannel channel,
    required String downloadUrl,
  }) async {
    if (channel == AppUpdateDownloadChannel.pgyer) {
      await _openUpdateReleasePage(downloadUrl);
      return false;
    }
    if (settings.appUpdateDownloadChannel ==
        AppUpdateDownloadChannel.pgyer.value) {
      await _openUpdateReleasePage(downloadUrl);
      return false;
    }

    if (settings.appUpdateUseSystemDownloader) {
      final version = release.version.trim().replaceAll(' ', '_');
      final int? downloadId;
      try {
        downloadId = await supportCreatorService.enqueueSystemDownload(
          url: downloadUrl,
          fileName: version.isEmpty ? 'mikcb_update.apk' : 'mikcb_v$version.apk',
          title: AppLocalizations.of(context)!.aboutUpdatePackageTitle,
          description: AppLocalizations.of(
            context,
          )!.aboutUpdatePackageDescription,
        );
      } catch (_) {
        // 原生确实会 `result.error("DOWNLOAD_ENQUEUE_FAILED" / "DOWNLOAD_QUERY_FAILED")`。
        // 原先这里没有 try：异常穿过弹窗 onPressed 那个没人 await 的 Future
        // 落进 zone，用户点「立即下载」什么都不发生，只会反复点。
        promptController.finishInAppDownload(success: false);
        return true;
      }
      if (downloadId == null) {
        promptController.finishInAppDownload(success: false);
        return true;
      }
      final initialProgress = await supportCreatorService
          .querySystemDownloadProgress(downloadId);
      if (initialProgress != null) {
        promptController.beginSystemDownload(
          downloadId: downloadId,
          progress: initialProgress,
        );
      }
      _watchSystemUpdateDownload(downloadId);
      return true;
    }

    final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
      settings.appUpdateMirrorPreset,
    );
    final mirrorPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: mirrorPreset,
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    // 下载候选：GitCode 等首选直连失败后自动回退 GitHub 原始直链再试一次；
    // 取消、不受信任地址、无摘要拒装、安装器打开失败不换源重试。
    final candidates = <String>[downloadUrl];
    final githubUrl = release.downloadUrl?.trim() ?? '';
    if (githubUrl.isNotEmpty && githubUrl != downloadUrl) {
      candidates.add(githubUrl);
    }
    var cancelled = false;
    // 换源重试期间留住最后一次真实失败原因：弹窗的失败条要靠它区分
    // "摘要不匹配 / SHA-256 拒装"与被它原先谎报成"调用系统下载管理器失败"。
    String? lastFailureReason;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final controller = AppUpdateDownloadController();
      _homeDownloadController = controller;
      promptController.beginInAppDownload();
      final error = await updateService.downloadAndInstallUpdate(
        candidate,
        promptController.updateInAppProgress,
        controller,
        mirrorUrlPrefix: mirrorPrefix,
        expectedApkSha256: release.expectedApkSha256,
      );
      if (!context.mounted) {
        return true;
      }
      _homeDownloadController = null;
      cancelled = error == AppUpdateService.downloadCancelledMessage;
      if (error == null || cancelled) {
        promptController.finishInAppDownload(
          success: error == null,
          cancelled: cancelled,
        );
        return true;
      }
      final notRetryable =
          error.startsWith('update_download_url_untrusted') ||
          error.startsWith('update_sha256_unverified_install_refused') ||
          error.startsWith('update_open_installer_failed');
      lastFailureReason = error;
      if (notRetryable || index == candidates.length - 1) {
        break;
      }
    }
    promptController.finishInAppDownload(
      success: false,
      cancelled: cancelled,
      error: lastFailureReason,
    );
    return true;
  }

  void _watchSystemUpdateDownload(int downloadId) {
    // 旧 watcher 必须关掉，否则两条 watcher 交替写同一个控制器字段，
    // 新的百分比会被旧那条的"排队中"覆盖回去、数字来回跳。
    _systemDownloadSubscription?.cancel();
    _systemDownloadSubscription = supportCreatorService
        .watchSystemDownloadProgress(downloadId)
        .listen(
          (progress) {
            if (_disposed) {
              return;
            }
            // 带上 downloadId：只有仍属于当前这条下载的进度才写进控制器。
            promptController.updateSystemDownload(downloadId, progress);
          },
          // 走到这里就是真的读不到了：保持弹窗可见，由失败条/清理逻辑表达。
          onError: (Object error, StackTrace stackTrace) {},
          cancelOnError: false,
        );
  }

  void cancelHomeUpdateDownload() {
    _homeDownloadController?.cancel();
    promptController.markCancelling();
  }

  Future<void> _openUpdateReleasePage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void dispose() {
    _disposed = true;
    _homeDownloadController?.cancel();
    unawaited(_systemDownloadSubscription?.cancel());
    _systemDownloadSubscription = null;
    promptController.dispose();
  }
}
