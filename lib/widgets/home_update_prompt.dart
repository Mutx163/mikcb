import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
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
}) {
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
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      return MiuixScaffold(
        containerColor: Colors.transparent,
        contentWindowInsets: EdgeInsets.zero,
        content: (_) => _HomeUpdatePromptDialog(
          release: release,
          currentVersion: currentVersion,
          downloadChannel: downloadChannel,
          hasDirectDownload: hasDirectDownload,
          controller: controller,
          onDownload: onDownload,
          onViewRelease: onViewRelease,
          onCancelDownload: onCancelDownload,
          onDismiss: () => Navigator.of(dialogContext).pop(),
        ),
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
        final isDownloadBusy = isInAppBusy || isSystemBusy;
        final progressLabel = hasSystemProgress
            ? _systemProgressLabel(l10n, systemProgress)
            : _inAppProgressLabel(l10n, progress);

        return MiuixOverlayDialog(
          show: true,
          title: l10n.aboutUpdateAvailableHeadline,
          summary: l10n.versionLabel(release.version),
          onDismissRequest: isDownloadBusy ? null : onDismiss,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MiuixText(
                release.title,
                style: textStyles.title4,
                color: colors.onBackground,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              MiuixText(
                '${l10n.aboutCurrentVersionLabel}: $currentVersion  ->  '
                '${l10n.aboutLatestVersionLabel}: ${release.version}',
                style: textStyles.body2,
                color: colors.onSurfaceSecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              MiuixText(
                _summarizeReleaseBody(
                  release.body,
                  fallback: l10n.aboutUpdateAvailableHint,
                ),
                style: textStyles.body2,
                color: colors.onSurfaceSecondary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
              else if (isFailed)
                MiuixText(
                  l10n.aboutSystemDownloaderFailed,
                  style: textStyles.body2,
                  color: colors.error,
                  textAlign: TextAlign.center,
                )
              else if (isCancelled)
                MiuixText(
                  l10n.aboutDownloadCancelled,
                  style: textStyles.body2,
                  color: colors.onSurfaceSecondary,
                  textAlign: TextAlign.center,
                )
              else
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        MiuixTextButton(
          l10n.aboutViewReleaseAction,
          onPressed: () async {
            onDismiss();
            await onViewRelease();
          },
        ),
        const SizedBox(width: 8),
        MiuixButton(
          onPressed: () async {
            final keepOpen = await onDownload();
            if (!keepOpen) {
              onDismiss();
            }
          },
          child: MiuixText(downloadLabel, style: textStyles.button),
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
        .take(3)
        .join(' ');
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
