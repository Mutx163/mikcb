import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/hyperos/hyperos.dart';
import 'timetable_weekday_header.dart';

/// 首页下拉快捷导入的悬浮药丸（2026-10-19 从课表页 State 搬出）。
///
/// 只负责进度/文案/玻璃底与位移动画；拖拽距离、是否在跑、取消回调由调用方
/// 注入。透明到看不见时返回 `SizedBox.shrink`，避免占住点击。
class TimetableHomePullQuickImportIndicator extends StatelessWidget {
  final double dragDistance;
  final double triggerDistance;
  final bool isRunning;
  final bool hasBackdrop;
  final VoidCallback onCancel;
  final AppLocalizations l10n;

  const TimetableHomePullQuickImportIndicator({
    super.key,
    required this.dragDistance,
    required this.triggerDistance,
    required this.isRunning,
    required this.hasBackdrop,
    required this.onCancel,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final pullProgress = (dragDistance / triggerDistance).clamp(0.0, 1.0);
    // Show label a bit earlier so the pill never looks like a lone spinner.
    final showLabel = isRunning || dragDistance >= triggerDistance * 0.45;
    const indicatorTopInset = TimetableWeekdayHeader.height + 8;
    // Subtle follow — 11px max, eased, not the previous 27px linear slide.
    final followY = () {
      if (isRunning) return 0.0;
      const cap = 32.0;
      if (dragDistance <= cap) return dragDistance * 0.34;
      return cap * 0.34 + (dragDistance - cap) * 0.06;
    }();
    final eased = Curves.easeOutCubic.transform(pullProgress);
    final scale = isRunning
        ? 1.0
        : (0.92 + eased * 0.08).clamp(0.92, 1.0);
    // Fade from 0 so the pill doesn't flash at tiny drags.
    final opacity = isRunning ? 1.0 : eased.clamp(0.0, 1.0);
    // Don't build the pill at all when fully transparent to avoid hit-test.
    if (!isRunning && pullProgress < 0.02) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color:
            (isDark
                    ? HyperosMiuixDarkColors.surfaceContainerHigh
                    : HyperosMiuixLightColors.surfaceContainer)
                .withValues(alpha: isDark ? 0.88 : 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isDark ? Colors.white : HyperosMiuixLightColors.outline)
              .withValues(alpha: isDark ? 0.10 : 0.14),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: isRunning
                ? const MiuixCircularProgressIndicator(
                    size: 16,
                    strokeWidth: 1.9,
                  )
                : MiuixCircularProgressIndicator(
                    progress: pullProgress.clamp(0.0, 1.0),
                    size: 16,
                    strokeWidth: 1.9,
                  ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 10),
            Text(
              l10n.homePullQuickImportFetchingCourses,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: HyperosColors.primaryText(context),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
          if (isRunning) ...[
            const SizedBox(width: 10),
            Container(
              width: 0.8,
              height: 14,
              color: HyperosColors.dividerLine(context),
            ),
            const SizedBox(width: 10),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onCancel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.quickImportCancelImportAction,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: HyperosColors.primary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Frosted glass when a wallpaper is behind the grid, otherwise the solid
    // Miuix card above. Keep the blur cheap: single BackdropFilter on the pill
    // only, not the whole page.
    final decoratedPill = hasBackdrop
        ? ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              // ⚠️ `tileMode: clamp` 必须给：默认 decal 会让模糊结果在离边约 3σ
              // 的带里淡成透明黑，而这张圆角药丸的边是可见的 —— 那一圈会读成
              // 一圈深色描边。同款规则与修法见 `liquid_glass_surface.dart`。
              filter: ui.ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
                tileMode: ui.TileMode.clamp,
              ),
              child: pill,
            ),
          )
        : pill;

    return Positioned(
      top: indicatorTopInset,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, followY),
          child: Transform.scale(
            scale: scale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: opacity,
              child: decoratedPill,
            ),
          ),
        ),
      ),
    );
  }
}
