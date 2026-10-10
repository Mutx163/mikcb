part of 'timetable_screen.dart';

/// 版本更新下载族（2026-10-10 自 `timetable_screen.dart` 原样搬入）。
///
/// `_TimetableScreenState` 的成员扩展：相关字段声明仍在主类（extension 不能
/// 声明实例字段），方法在此按功能域聚拢。搬移是**原样移动**——除本头注释与
/// extension 包裹外，方法体一个字符都没有改。
///
/// `_runUpdateCheck` 仍留在主类：它体内两处 setState 在 extension 里会触发
/// invalid_use_of_protected_member（analysis 级警告，CI --fatal-infos 不放行）。
extension _TimetableScreenUpdateDownload on _TimetableScreenState {
  Future<void> _openTopMenuUpdatePage() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    // 版本检查做完、页面马上要推上来了：这时候才请收菜单 —— 早一步（检查期间）
    // 收掉，首页顶上那两颗球就会在页面盖上来之前先冒出来闪一下。
    _requestCloseHomeMenu();
    await Navigator.of(context).push<void>(
      HyperosPageRoute<void>(
        builder: (_) => AboutUpdateScreen(packageInfo: packageInfo),
      ),
    );
  }

  void _scheduleUpdateCheckIfNeeded(TimetableProvider provider) {
    if (!widget.enableUpdateCheck) {
      return;
    }
    final includePrerelease = provider.settings.appUpdateIncludePrerelease;
    if (_lastUpdateCheckIncludePrerelease == includePrerelease) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _checkForAppUpdate(includePrerelease: includePrerelease);
    });
  }

  Future<void> _checkForAppUpdate({required bool includePrerelease}) async {
    // De-dupe by sharing the in-flight future; concurrent callers await the
    // same check instead of racing past a boolean flag.
    final inflight = _inflightUpdateCheck;
    if (inflight != null) {
      await inflight;
      return;
    }
    _lastUpdateCheckIncludePrerelease = includePrerelease;
    final Future<void> check = _runUpdateCheck(
      includePrerelease: includePrerelease,
    );
    _inflightUpdateCheck = check;
    try {
      await check;
    } finally {
      if (identical(_inflightUpdateCheck, check)) {
        _inflightUpdateCheck = null;
      }
    }
  }

  /// 检测到新版本后在首页弹出更新提醒（受「弹窗提醒」开关控制，
  /// 关闭时保持静默，仅依赖 ⋮ 菜单红点角标）。
  void _scheduleHomeUpdatePrompt(AppUpdateCheckResult result) {
    if (!result.hasUpdate ||
        result.latestRelease == null ||
        _hasPresentedUpdatePrompt ||
        _isUpdatePromptVisible) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
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
    final effectiveDownloadUrl = _updateService.getEffectiveDownloadUrl(
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
      if (!mounted || _hasPresentedUpdatePrompt || _isUpdatePromptVisible) {
        return;
      }
      // 首页不在栈顶时（例如启动直达二级页）不打断用户。
      if (ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _hasPresentedUpdatePrompt = true;
      _isUpdatePromptVisible = true;
      unawaited(
        _showHomeUpdatePromptAndTrackState(
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
        controller: _updatePromptController,
        onDownload: () async {
          if (!hasDirectDownload) {
            await _openUpdateReleasePage(release.releaseUrl);
            return false;
          }
          return _startHomeUpdateDownload(
            release: release,
            channel: channel,
            downloadUrl: downloadUrl,
          );
        },
        onViewRelease: () => _openUpdateReleasePage(release.releaseUrl),
        onCancelDownload: _cancelHomeUpdateDownload,
        onResumeDownload: () => _startHomeUpdateDownload(
          release: release,
          channel: channel,
          downloadUrl: downloadUrl,
        ),
      );
    } finally {
      _isUpdatePromptVisible = false;
    }
  }

  Future<bool> _startHomeUpdateDownload({
    required AppReleaseInfo release,
    required AppUpdateDownloadChannel channel,
    required String downloadUrl,
  }) async {
    if (channel == AppUpdateDownloadChannel.pgyer) {
      await _openUpdateReleasePage(downloadUrl);
      return false;
    }

    final settings = context.read<TimetableProvider>().settings;
    if (settings.appUpdateDownloadChannel ==
        AppUpdateDownloadChannel.pgyer.value) {
      await _openUpdateReleasePage(downloadUrl);
      return false;
    }

    if (_useSystemUpdateDownloader(settings)) {
      final version = release.version.trim().replaceAll(' ', '_');
      final int? downloadId;
      try {
        downloadId = await _supportCreatorService.enqueueSystemDownload(
          url: downloadUrl,
          fileName: version.isEmpty ? 'mikcb_update.apk' : 'mikcb_v$version.apk',
          title: AppLocalizations.of(context)!.aboutUpdatePackageTitle,
          description: AppLocalizations.of(
            context,
          )!.aboutUpdatePackageDescription,
        );
      } catch (_) {
        // 原生确实会 `result.error("DOWNLOAD_ENQUEUE_FAILED" / "DOWNLOAD_QUERY_FAILED")`
        // （`MainActivity.kt:1119/1132`）。原先这里没有 try：异常穿过弹窗 `onPressed`
        // 那个没人 await 的 Future 落进 zone，用户点「立即下载」什么都不发生
        // （无进度条、无报错、弹窗原样），只会反复点。关于页的同一调用
        // （`about_screen.dart:1387-1409`）是有 catch + toast 的。
        // 原因码留空是对的：这一条真的是"调用系统下载管理器失败"。
        _updatePromptController.finishInAppDownload(success: false);
        return true;
      }
      if (downloadId == null) {
        // 原先 `return false` 会让弹窗静默关掉（`onDownload` 返回 false 即 dismiss），
        // 用户看不到任何"没成功"的信号。
        _updatePromptController.finishInAppDownload(success: false);
        return true;
      }
      final initialProgress = await _supportCreatorService
          .querySystemDownloadProgress(downloadId);
      if (initialProgress != null) {
        _updatePromptController.beginSystemDownload(
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
      _updatePromptController.beginInAppDownload();
      final error = await _updateService.downloadAndInstallUpdate(
        candidate,
        _updatePromptController.updateInAppProgress,
        controller,
        mirrorUrlPrefix: mirrorPrefix,
        expectedApkSha256: release.expectedApkSha256,
      );
      if (!mounted) {
        return true;
      }
      _homeDownloadController = null;
      cancelled = error == AppUpdateService.downloadCancelledMessage;
      if (error == null || cancelled) {
        _updatePromptController.finishInAppDownload(
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
    _updatePromptController.finishInAppDownload(
      success: false,
      cancelled: cancelled,
      error: lastFailureReason,
    );
    return true;
  }

  bool _useSystemUpdateDownloader(TimetableSettings settings) {
    return settings.appUpdateUseSystemDownloader;
  }

  void _watchSystemUpdateDownload(int downloadId) {
    // `_systemDownloadSubscription` 原先只有两处出现：声明（:311）与 dispose 里的
    // `cancel()`（:703），**全仓从未被赋值** —— 起流的地方是 `unawaited(() async {
    // await for ... }())`，句柄被丢掉，所以旧 watcher 一条都关不掉。pending/paused 不是
    // settled（`support_creator_service.dart:143-144`），于是关掉弹窗后这条下载仍以
    // 350ms 一次的频率查平台通道，直到整页销毁；若期间再发起一次（应用内→取消→改用
    // 系统下载器→点「继续下载」），两条 watcher 交替写同一个控制器字段，新的百分比
    // 会被旧那条的"排队中"覆盖回去、数字来回跳。
    _systemDownloadSubscription?.cancel();
    _systemDownloadSubscription = _supportCreatorService
        .watchSystemDownloadProgress(downloadId)
        .listen(
          (progress) {
            if (!mounted) {
              return;
            }
            // 带上 downloadId：只有仍属于当前这条下载的进度才写进控制器。
            _updatePromptController.updateSystemDownload(downloadId, progress);
          },
          // 下载行在 provider 接手前会短暂查不到 —— 服务层现在自己重试若干次
          // （`maxTransientFailures`，默认 3）。走到这里就是真的读不到了：保持弹窗可见，
          // 由失败条/清理逻辑去表达，不再像旧注释那样假装"下一次观察会恢复"。
          onError: (Object error, StackTrace stackTrace) {},
          cancelOnError: false,
        );
  }

  void _cancelHomeUpdateDownload() {
    _homeDownloadController?.cancel();
    _updatePromptController.markCancelling();
  }

  Future<void> _openUpdateReleasePage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

}