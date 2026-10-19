import 'package:flutter/material.dart';

import '../../ui/hyperos/hyperos.dart';

/// 首页快捷入口按钮的视觉体（2026-10-19 从 timetable_screen 的库级私有类搬出）。
///
/// 只负责玻璃底 + 图标/文字布局；点按行为由 [onTap] 注入，`enabled` 目前恒为
/// true，保留它是为了与旧调用点逐像素一致。
class TimetableHomeActionButtonBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  const TimetableHomeActionButtonBody({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  }) : enabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = context.theme.colors;
    final highlightColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: HyperosTheme.cardBorderRadius,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HyperosFrostedSurface(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  blurEnabled: false,
                  tint: HyperosBlurredHeader.accentSurfaceTintColor(
                    highlightColor,
                  ),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(child: Icon(icon, color: highlightColor)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                    color: enabled ? null : colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
