import '../../ui/hyperos/hyperos.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';

/// 首页顶部标题（经典/品牌两套）兼「切换配置档」入口
/// （2026-10-20 从 `TimetableScreen` State 搬出）。
class TimetableProfileSwitcherTrigger extends StatelessWidget {
  final HomeTitleStyle style;
  final String? activeProfileName;
  final VoidCallback onTap;
  final Color foreground;
  final Color mutedForeground;
  final double leftPadding;

  const TimetableProfileSwitcherTrigger({
    super.key,
    required this.style,
    required this.activeProfileName,
    required this.onTap,
    required this.foreground,
    required this.mutedForeground,
    required this.leftPadding,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final foruiTheme = context.theme;
    final name = activeProfileName;
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: switch (style) {
        HomeTitleStyle.classic => GestureDetector(
          key: const ValueKey('profile_switcher_trigger'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            l10n.timetableAppName,
            style: foruiTheme.typography.display.xl.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.1,
              color: foreground,
            ),
          ),
        ),
        HomeTitleStyle.brand => GestureDetector(
          key: const ValueKey('profile_switcher_trigger'),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.timetableAppName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: foruiTheme.typography.display.lg.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: 0.1,
                  color: foreground,
                ),
              ),
              Text(
                (name == null || name.isEmpty) ? l10n.switchProfileHint : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: foruiTheme.typography.body.sm.copyWith(
                  color: mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}
