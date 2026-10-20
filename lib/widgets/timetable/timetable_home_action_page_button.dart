import 'package:flutter/material.dart';

import 'timetable_home_action_button.dart';
import 'timetable_open_only_route.dart';

/// 首页「+」弹层里的三宫格动作按钮（2026-10-20 从课表页搬出）。
class TimetableHomeActionPageButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final WidgetBuilder pageBuilder;
  final Route<dynamic>? sheetRoute;

  const TimetableHomeActionPageButton({
    super.key,
    required this.icon,
    required this.title,
    required this.pageBuilder,
    required this.sheetRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return TimetableHomeActionButtonBody(
          icon: icon,
          title: title,
          onTap: () => openTimetablePopupActionPage(
            buttonContext,
            pageBuilder: pageBuilder,
            sheetRoute: sheetRoute,
          ),
        );
      },
    );
  }
}

Rect popupActionSourceRect(BuildContext buttonContext) {
  final renderBox = buttonContext.findRenderObject() as RenderBox?;
  final buttonOffset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  final buttonSize = renderBox?.size ?? const Size(80, 80);
  return buttonOffset & buttonSize;
}

void openTimetablePopupActionPage(
  BuildContext context, {
  required WidgetBuilder pageBuilder,
  Rect? sourceRect,
  Route<dynamic>? sheetRoute,
}) {
  final resolvedSourceRect = sourceRect ?? popupActionSourceRect(context);
  final navigator = Navigator.of(context);

  navigator.push(
    TimetableOpenOnlyContainerPageRoute<void>(
      sourceRect: resolvedSourceRect,
      builder: pageBuilder,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (sheetRoute != null && sheetRoute.isActive) {
      navigator.removeRoute(sheetRoute);
    }
  });
}
