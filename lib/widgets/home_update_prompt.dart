import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_update_service.dart';
import 'package:university_timetable/services/support_creator_service.dart';

/// Mutable state shared by the home update prompt and the download task.
///
/// The prompt is hosted in a Miuix popup registry, while the actual download
/// runs in the home screen state. A [ChangeNotifier] keeps progress updates
/// local to the popup instead of rebuilding the timetable behind it.
class HomeUpdatePromptController extends ChangeNotifier {
  bool isInAppDownloading = false;
  bool isCancellingDownload = false;
  bool isInAppComplete = false;
  bool isInAppFailed = false;
  bool isInAppCancelled = false;
  int downloadedBytes = 0;
  int? totalBytes;
  int? systemDownloadId;
  SystemDownloadProgress? systemDownloadProgress;

  void beginInAppDownload() {
    isInAppDownloading = true;
    isCancellingDownload = false;
    isInAppComplete = false;
    isInAppFailed = false;
    isInAppCancelled = false;
    downloadedBytes = 0;
    totalBytes = null;
    // 用户改走应用内下载时，必须忘掉系统下载器留下的那一份：见
    // discardStaleSystemDownload 的说明。
    _clearSystemDownload();
    notifyListeners();
  }

  void updateInAppProgress(int downloaded, int? total) {
    downloadedBytes = downloaded;
    totalBytes = total;
    notifyListeners();
  }

  void markCancelling() {
    isCancellingDownload = true;
    notifyListeners();
  }

  void finishInAppDownload({required bool success, bool cancelled = false}) {
    isInAppDownloading = false;
    isCancellingDownload = false;
    isInAppComplete = success;
    isInAppFailed = !success && !cancelled;
    isInAppCancelled = cancelled;
    notifyListeners();
  }

  void resetInAppDownload() {
    isInAppDownloading = false;
    isCancellingDownload = false;
    isInAppComplete = false;
    isInAppFailed = false;
    isInAppCancelled = false;
    downloadedBytes = 0;
    totalBytes = null;
    // "整体复位"就要连系统下载器那一份一起复位：原先只清 in-app 字段，
    // 系统那两条字段没有任何清理点，会把上一次的终态带到下一次弹窗里。
    _clearSystemDownload();
    notifyListeners();
  }

  void beginSystemDownload({
    required int downloadId,
    required SystemDownloadProgress progress,
  }) {
    systemDownloadId = downloadId;
    systemDownloadProgress = progress;
    notifyListeners();
  }

  void updateSystemDownload(SystemDownloadProgress progress) {
    systemDownloadProgress = progress;
    notifyListeners();
  }

  void _clearSystemDownload() {
    systemDownloadId = null;
    systemDownloadProgress = null;
  }

  /// 丢弃**已进入终态**的系统下载器记录。
  ///
  /// 系统下载器的进度轮询到终态就停了（`watchSystemDownloadProgress` 在
  /// successful/failed 后关闭流），而 `systemDownloadId` / `systemDownloadProgress`
  /// 这两个字段除了这里没有任何清理点 —— 上一次下载的结果会永久留在控制器里。
  /// 控制器又是首页 State 的字段（活过每一次弹窗），而 build 里
  /// `hasSystemProgress` 优先于应用内进度、`isFailed`/`isComplete` 又把系统终态
  /// OR 进来，于是：用完一次系统下载器（失败或成功）后再点更新提示，弹窗一打开
  /// 就是红色"下载失败"，按钮也变成 忽略/继续下载；更糟的是接着改走应用内下载时，
  /// 进度条读的还是那条早已死掉的系统下载，永远不动。
  ///
  /// 正在进行（pending / running / paused）的一律保留：那种情况下重开弹窗不该把
  /// 还在跑的下载进度清零。
  void discardStaleSystemDownload() {
    final progress = systemDownloadProgress;
    if (progress == null) {
      return;
    }
    switch (progress.status) {
      case SystemDownloadStatus.pending:
      case SystemDownloadStatus.running:
      case SystemDownloadStatus.paused:
        return;
      case SystemDownloadStatus.successful:
      case SystemDownloadStatus.failed:
      case SystemDownloadStatus.unknown:
        _clearSystemDownload();
        notifyListeners();
    }
  }
}

/// Displays a Miuix update dialog over the home page.
Future<void> showHomeUpdatePrompt(
  BuildContext context, {
  required AppReleaseInfo release,
  required String currentVersion,
  required AppUpdateDownloadChannel downloadChannel,
  required bool hasDirectDownload,
  required HomeUpdatePromptController controller,
  required Future<bool> Function() onDownload,
  required Future<void> Function() onViewRelease,
  required VoidCallback onCancelDownload,
  required Future<bool> Function() onResumeDownload,
}) {
  // 每次打开弹窗都清掉上一次系统下载器的**终态**记录：控制器属于首页 State，
  // 活过每一次弹窗，而进度轮询在终态就停了，那两个字段再没人写。不清的话，
  // 上一次"用系统下载器下载失败"会让这一次弹窗一开就是红色失败条。
  // 仍在进行的下载（pending/running/paused）会被保留。
  controller.discardStaleSystemDownload();
  return _showHomeUpdatePromptDialog(
    context,
    release: release,
    currentVersion: currentVersion,
    downloadChannel: downloadChannel,
    hasDirectDownload: hasDirectDownload,
    controller: controller,
    onDownload: onDownload,
    onViewRelease: onViewRelease,
    onCancelDownload: onCancelDownload,
    onResumeDownload: onResumeDownload,
  );
}

Future<void> _showHomeUpdatePromptDialog(
  BuildContext context, {
  required AppReleaseInfo release,
  required String currentVersion,
  required AppUpdateDownloadChannel downloadChannel,
  required bool hasDirectDownload,
  required HomeUpdatePromptController controller,
  required Future<bool> Function() onDownload,
  required Future<void> Function() onViewRelease,
  required VoidCallback onCancelDownload,
  required Future<bool> Function() onResumeDownload,
}) async {
  await showHyperosSheet<void>(
    context: context,
    builder: (sheetContext) {
      return _HomeUpdatePromptDialog(
        release: release,
        currentVersion: currentVersion,
        downloadChannel: downloadChannel,
        hasDirectDownload: hasDirectDownload,
        controller: controller,
        onDownload: onDownload,
        onViewRelease: onViewRelease,
        onCancelDownload: onCancelDownload,
        onResumeDownload: onResumeDownload,
        onDismiss: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class _HomeUpdatePromptDialog extends StatelessWidget {
  const _HomeUpdatePromptDialog({
    required this.release,
    required this.currentVersion,
    required this.downloadChannel,
    required this.hasDirectDownload,
    required this.controller,
    required this.onDownload,
    required this.onViewRelease,
    required this.onCancelDownload,
    required this.onResumeDownload,
    required this.onDismiss,
  });

  final AppReleaseInfo release;
  final String currentVersion;
  final AppUpdateDownloadChannel downloadChannel;
  final bool hasDirectDownload;
  final HomeUpdatePromptController controller;
  final Future<bool> Function() onDownload;
  final Future<void> Function() onViewRelease;
  final VoidCallback onCancelDownload;
  final Future<bool> Function() onResumeDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final theme = MiuixTheme.of(context);
        final colors = theme.colors;
        final textStyles = theme.textStyles;
        final systemProgress = controller.systemDownloadProgress;
        final hasSystemProgress =
            controller.systemDownloadId != null && systemProgress != null;
        final inAppProgressVisible =
            controller.isInAppDownloading ||
            controller.isInAppComplete ||
            controller.isInAppFailed ||
            controller.isInAppCancelled;
        final hasProgress = hasSystemProgress || inAppProgressVisible;
        final progress = hasSystemProgress
            ? _resolveProgress(
                systemProgress.downloadedBytes,
                systemProgress.totalBytes,
              )
            : _resolveProgress(
                controller.downloadedBytes,
                controller.totalBytes,
              );
        final systemCompleted =
            systemProgress?.status == SystemDownloadStatus.successful;
        final systemFailed =
            systemProgress?.status == SystemDownloadStatus.failed;
        final isComplete = controller.isInAppComplete || systemCompleted;
        final isFailed = controller.isInAppFailed || systemFailed;
        final isCancelled = controller.isInAppCancelled;
        final isInAppBusy = controller.isInAppDownloading;
        final isSystemBusy = _isSystemDownloadBusy(systemProgress);
        final progressLabel = hasSystemProgress
            ? _systemProgressLabel(l10n, systemProgress)
            : _inAppProgressLabel(l10n, progress);

        return HyperosSheetFrame(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.aboutUpdateAvailableHeadline,
                textAlign: TextAlign.center,
                style: HyperosTypography.sheetTitle(context),
              ),
              const SizedBox(height: 8),
              MiuixText(
                release.title,
                style: textStyles.title4,
                color: colors.onBackground,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // 版本过渡压缩为一行：旧版本弱化、新版本主题色强调，
              // 替代原先「版本 x」+「当前版本 -> 最新版本」两行重复信息。
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MiuixText(
                    currentVersion,
                    style: textStyles.body2,
                    color: colors.onSurfaceSecondary,
                  ),
                  const SizedBox(width: 6),
                  MiuixText(
                    '→',
                    style: textStyles.body2,
                    color: colors.onSurfaceVariantSummary,
                  ),
                  const SizedBox(width: 6),
                  MiuixText(
                    release.version,
                    style: textStyles.body2,
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 更新说明左对齐并放宽行高，长文本不再居中堆叠。
              MiuixText(
                _summarizeReleaseBody(
                  release.body,
                  fallback: l10n.aboutUpdateAvailableHint,
                ),
                style: textStyles.body2,
                color: colors.onSurfaceSecondary,
                height: 1.45,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasProgress) ...[
                const SizedBox(height: 18),
                _MiuixDownloadProgress(
                  progress: progress,
                  label: progressLabel,
                  colors: colors,
                  textStyle: textStyles.body2,
                  isFailed: isFailed,
                  isComplete: isComplete,
                ),
              ],
              const SizedBox(height: 20),
              if (isInAppBusy)
                MiuixTextButton(
                  controller.isCancellingDownload
                      ? l10n.aboutDownloadCancelling
                      : l10n.aboutCancelDownloadAction,
                  onPressed: controller.isCancellingDownload
                      ? null
                      : onCancelDownload,
                )
              else if (isSystemBusy)
                MiuixTextButton(l10n.closeAction, onPressed: onDismiss)
              else if (isComplete)
                MiuixText(
                  l10n.aboutInstallReady,
                  style: textStyles.body2,
                  color: colors.primary,
                  textAlign: TextAlign.center,
                )
              else if (isFailed) ...[
                MiuixText(
                  l10n.aboutSystemDownloaderFailed,
                  style: textStyles.body2,
                  color: colors.error,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MiuixTextButton(
                        l10n.aboutDismissDialogAction,
                        onPressed: onDismiss,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MiuixButton(
                        onPressed: () async {
                          final keepOpen = await onDownload();
                          if (!keepOpen) {
                            onDismiss();
                          }
                        },
                        child: MiuixText(
                          l10n.aboutContinueDownloadAction,
                          style: textStyles.button,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isCancelled) ...[
                MiuixText(
                  l10n.aboutDownloadCancelled,
                  style: textStyles.body2,
                  color: colors.onSurfaceSecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MiuixTextButton(
                        l10n.aboutDismissDialogAction,
                        onPressed: onDismiss,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MiuixButton(
                        onPressed: () async {
                          final keepOpen = await onResumeDownload();
                          if (!keepOpen) {
                            onDismiss();
                          }
                        },
                        child: MiuixText(
                          l10n.aboutContinueDownloadAction,
                          style: textStyles.button,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                _buildActions(l10n: l10n, textStyles: textStyles),
            ],
          ),
        );
      },
    );
  }

  bool _isSystemDownloadBusy(SystemDownloadProgress? progress) {
    if (progress == null) {
      return false;
    }
    return switch (progress.status) {
      SystemDownloadStatus.pending ||
      SystemDownloadStatus.running ||
      SystemDownloadStatus.paused ||
      SystemDownloadStatus.unknown => true,
      SystemDownloadStatus.successful || SystemDownloadStatus.failed => false,
    };
  }

  Widget _buildActions({
    required AppLocalizations l10n,
    required MiuixTextStyles textStyles,
  }) {
    final downloadLabel = !hasDirectDownload
        ? l10n.aboutOpenReleasePageAction
        : downloadChannel == AppUpdateDownloadChannel.pgyer
        ? l10n.aboutOpenDownloadPageAction
        : l10n.aboutDownloadNowAction;
    // 左右各占一半的均衡布局：次要动作（查看发布说明）居左，
    // 主要动作（立即下载 / 打开页面）居右。
    return Row(
      children: [
        Expanded(
          child: MiuixTextButton(
            l10n.aboutViewReleaseAction,
            onPressed: () async {
              onDismiss();
              await onViewRelease();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MiuixButton(
            onPressed: () async {
              final keepOpen = await onDownload();
              if (!keepOpen) {
                onDismiss();
              }
            },
            child: MiuixText(
              downloadLabel,
              style: textStyles.button,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  String _inAppProgressLabel(AppLocalizations l10n, double? progress) {
    if (controller.isCancellingDownload) {
      return l10n.aboutDownloadCancelling;
    }
    if (progress == null) {
      return l10n.aboutDownloadingBytes(
        _formatBytes(controller.downloadedBytes),
      );
    }
    return l10n.aboutDownloadingPercent((progress * 100).toStringAsFixed(1));
  }

  String _systemProgressLabel(
    AppLocalizations l10n,
    SystemDownloadProgress progress,
  ) {
    return switch (progress.status) {
      SystemDownloadStatus.pending => l10n.aboutSystemDownloaderQueued,
      SystemDownloadStatus.running =>
        progress.totalBytes == null
            ? l10n.aboutDownloadingBytes(_formatBytes(progress.downloadedBytes))
            : l10n.aboutDownloadingPercent(
                ((_resolveProgress(
                              progress.downloadedBytes,
                              progress.totalBytes,
                            ) ??
                            0) *
                        100)
                    .toStringAsFixed(1),
              ),
      SystemDownloadStatus.paused => l10n.aboutSystemDownloaderQueued,
      SystemDownloadStatus.successful => l10n.aboutInstallReady,
      SystemDownloadStatus.failed => l10n.aboutSystemDownloaderFailed,
      SystemDownloadStatus.unknown => l10n.aboutSystemDownloaderQueued,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static double? _resolveProgress(int downloadedBytes, int? totalBytes) {
    if (totalBytes == null || totalBytes <= 0) {
      return null;
    }
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String _summarizeReleaseBody(String body, {required String fallback}) {
    final lines = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) => line.replaceFirst(RegExp(r'^[-*•]\s+'), ''))
        .take(4)
        .join('\n');
    return lines.isEmpty ? fallback : lines;
  }
}

class _MiuixDownloadProgress extends StatelessWidget {
  const _MiuixDownloadProgress({
    required this.progress,
    required this.label,
    required this.colors,
    required this.textStyle,
    required this.isFailed,
    required this.isComplete,
  });

  final double? progress;
  final String label;
  final MiuixColors colors;
  final TextStyle textStyle;
  final bool isFailed;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final indicatorColors = MiuixProgressIndicatorColors(
      foregroundColor: isFailed ? colors.error : colors.primary,
      disabledForegroundColor: colors.onSurfaceVariantSummary,
      backgroundColor: colors.secondaryContainer,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MiuixText(
          label,
          style: textStyle,
          color: isFailed
              ? colors.error
              : isComplete
              ? colors.primary
              : colors.onSurfaceSecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        MiuixLinearProgressIndicator(
          progress: progress,
          colors: indicatorColors,
        ),
      ],
    );
  }
}
