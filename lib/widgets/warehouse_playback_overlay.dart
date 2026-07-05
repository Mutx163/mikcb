import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (state) {
      case PlaybackUiState.hidden:
        return const SizedBox.shrink();
      case PlaybackUiState.playing:
        return _buildPlayingOverlay(context, theme, colorScheme);
      case PlaybackUiState.pausedForInput:
        return _buildPausedOverlay(context, theme, colorScheme);
      case PlaybackUiState.executingImport:
        return _buildExecutingImportOverlay(context, theme, colorScheme);
      case PlaybackUiState.finished:
        return _buildFinishedOverlay(context, theme, colorScheme);
      case PlaybackUiState.error:
        return _buildErrorOverlay(context, theme, colorScheme);
    }
  }

  Widget _buildPlayingOverlay(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '自动导入中…',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (schoolName != null || adapterName != null) ...[
              const SizedBox(height: 6),
              Text(
                '${schoolName ?? ""} · ${adapterName ?? ""}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Text(
                '步骤 ${progress.currentStepIndex + 1} / ${progress.totalSteps}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ),
            Text(
              progress.statusLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedOverlay(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Stack(
      children: [
        IgnorePointer(child: Container(color: Colors.black26)),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '需要手动操作',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress.pauseReason ?? '请完成当前需要的手动操作。完成后点击继续。',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FButton(
                            variant: FButtonVariant.outline,
                            onPress: onCancel,
                            child: const Text('取消导入'),
                          ),
                          FButton(
                            variant: FButtonVariant.primary,
                            onPress: onContinueAfterPause,
                            prefix: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            child: const Text('继续'),
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

  Widget _buildExecutingImportOverlay(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '回放完成，正在执行导入脚本…',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (schoolName != null || adapterName != null) ...[
              const SizedBox(height: 6),
              Text(
                '${schoolName ?? ""} · ${adapterName ?? ""}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedOverlay(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '导入完成',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (schoolName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$schoolName · $adapterName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FButton(
                      variant: FButtonVariant.primary,
                      onPress: onDismiss,
                      prefix: const Icon(Icons.check_rounded, size: 18),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '导入失败',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress.errorMessage ?? '发生未知错误',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FButton(
                          variant: FButtonVariant.outline,
                          onPress: onDismiss,
                          child: const Text('关闭'),
                        ),
                        if (onRetry != null)
                          FButton(
                            variant: FButtonVariant.primary,
                            onPress: onRetry,
                            prefix: const Icon(Icons.refresh_rounded, size: 18),
                            child: const Text('重试'),
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
    );
  }
}

/// 用于显示在适配器卡片上的宏录制存在指示器
class MacroIndicator extends StatelessWidget {
  final bool hasMacro;
  final String? label;

  const MacroIndicator({super.key, required this.hasMacro, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!hasMacro) {
      return FButton(
        variant: FButtonVariant.outline,
        onPress: null,
        prefix: const Icon(Icons.radio_button_unchecked_rounded, size: 16),
        child: const Text('录制'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flash_on_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label ?? '快捷导入',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
