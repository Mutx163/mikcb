import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'warehouse_macro_replayer.dart';

/// 回放覆盖层：在回放期间显示在 WebView 上方
class PlaybackOverlay extends StatelessWidget {
  final ReplayProgress progress;
  final PlaybackUiState state;
  final String? schoolName;
  final String? adapterName;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final VoidCallback? onContinueAfterPause;

  const PlaybackOverlay({
    super.key,
    required this.progress,
    required this.state,
    this.schoolName,
    this.adapterName,
    this.onCancel,
    this.onRetry,
    this.onDismiss,
    this.onContinueAfterPause,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case PlaybackUiState.hidden:
        return const SizedBox.shrink();
      case PlaybackUiState.playing:
        return _buildPlayingOverlay(context);
      case PlaybackUiState.pausedForInput:
        return _buildPausedOverlay(context);
      case PlaybackUiState.executingImport:
        return _buildExecutingImportOverlay(context);
      case PlaybackUiState.finished:
        return const SizedBox.shrink();
      case PlaybackUiState.error:
        return _buildErrorOverlay(context);
    }
  }

  Widget _buildScrim({required Widget child}) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.54),
      child: SafeArea(child: child),
    );
  }

  TextStyle _onScrimTitleStyle(BuildContext context) {
    return HyperosTypography.listTitle(
      context,
    ).copyWith(color: Colors.white, fontWeight: FontWeight.w700);
  }

  TextStyle _onScrimBodyStyle(BuildContext context) {
    return HyperosTypography.listDetail(
      context,
    ).copyWith(color: Colors.white70);
  }

  Widget _buildPlayingOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = _schoolAdapterLine();

    return _buildScrim(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HyperosCircularProgress(size: 48, strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            l10n.quickImportPlayingTitle,
            style: _onScrimTitleStyle(context),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: _onScrimBodyStyle(context)),
          ],
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: HyperosLinearProgress(
              value: progress.progress,
              minHeight: 6,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Text(
              l10n.quickImportPlaybackStepProgress(
                progress.currentStepIndex + 1,
                progress.totalSteps,
              ),
              style: _onScrimBodyStyle(context),
            ),
          ),
          if (progress.statusLabel(l10n).isNotEmpty)
            Text(
              progress.statusLabel(l10n),
              style: _onScrimBodyStyle(
                context,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 32),
          HyperosButton(
            label: l10n.quickImportCancelPlaybackAction,
            variant: HyperosButtonVariant.secondary,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }

  Widget _buildPausedOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        IgnorePointer(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.26)),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: HyperosControlCard(
                child: HyperosControlCardInset(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HyperosIconBadge(
                        icon: Icons.warning_amber_rounded,
                        accent: HyperosIconColors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.quickImportManualInputTitle,
                        style: HyperosTypography.listTitle(context),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress.pauseReason != null
                            ? localizeServiceMessage(
                                l10n,
                                progress.pauseReason!,
                              )
                            : l10n.quickImportManualInputHint,
                        textAlign: TextAlign.center,
                        style: HyperosTypography.listDetail(context),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: HyperosButton(
                              label: l10n.quickImportCancelImportAction,
                              variant: HyperosButtonVariant.secondary,
                              expand: true,
                              onPressed: onCancel,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: HyperosButton(
                              label: l10n.quickImportContinueAction,
                              expand: true,
                              onPressed: onContinueAfterPause,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutingImportOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = _schoolAdapterLine();

    return _buildScrim(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HyperosCircularProgress(size: 48, strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            l10n.quickImportExecutingScriptTitle,
            style: _onScrimTitleStyle(context),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: _onScrimBodyStyle(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _buildScrim(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: HyperosControlCard(
            child: HyperosControlCardInset(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HyperosIconBadge(
                    icon: Icons.error_outline_rounded,
                    accent: HyperosIconColors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.importFailedStatus,
                    style: HyperosTypography.listTitle(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress.errorMessage ?? l10n.quickImportUnknownError,
                    textAlign: TextAlign.center,
                    style: HyperosTypography.listDetail(context),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: HyperosButton(
                          label: l10n.closeAction,
                          variant: HyperosButtonVariant.secondary,
                          expand: true,
                          onPressed: onDismiss,
                        ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: HyperosButton(
                            label: l10n.quickImportRetryAction,
                            expand: true,
                            onPressed: onRetry,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _schoolAdapterLine() {
    if (schoolName == null && adapterName == null) {
      return null;
    }
    return '${schoolName ?? ''} · ${adapterName ?? ''}'.trim();
  }
}

/// 用于显示在适配器卡片上的宏录制存在指示器
class MacroIndicator extends StatelessWidget {
  final bool hasMacro;
  final String? label;

  const MacroIndicator({super.key, required this.hasMacro, this.label});

  @override
  Widget build(BuildContext context) {
    if (!hasMacro) {
      return HyperosButton(
        label: AppLocalizations.of(context)!.startRecordingTooltip,
        variant: HyperosButtonVariant.secondary,
        onPressed: null,
      );
    }

    return HyperosTag(
      label: label ?? AppLocalizations.of(context)!.quickImportTooltip,
      backgroundColor: HyperosColors.primary(context).withValues(alpha: 0.12),
    );
  }
}
