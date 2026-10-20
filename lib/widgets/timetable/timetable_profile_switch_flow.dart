import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/timetable_provider.dart';
import 'timetable_profile_quick_switch.dart';

/// 首页标题「切换课表」的完整流程（2026-10-20 从 `timetable_screen.dart` 的
/// `_showProfileQuickSwitchSheet` 搬出）。
///
/// 分工与 [`showTimetableProfileQuickSwitch`] 一致：弹层本体不读 provider，本
/// 函数把「打开弹层 → 切换档案 → 切完给一次触觉」串起来；「管理课表页」仍由
/// 调用方注入（要推屏幕，本文件不 import `screens/`）。
///
/// 触觉口径与原实现相同：只在真的换了档案时给一次 selectionClick，且读的是
/// **切换后**那份 settings（`switchProfile` 会换成新档案的偏好，原实现同样在
/// await 之后读）。
Future<void> showTimetableProfileQuickSwitchFlow(
  BuildContext context, {
  required TimetableProvider provider,
  required Rect Function(BuildContext buttonContext) popupSourceRect,
  required void Function(BuildContext hostContext, Rect sourceRect) openManagePage,
}) async {
  final selected = await showTimetableProfileQuickSwitch(
    context,
    profiles: provider.profiles,
    activeProfileId: provider.activeProfileId,
    popupSourceRect: popupSourceRect,
    // 弹层内容在根 Overlay 上，buttonContext 拿不到原路由 —— 先立即摘掉旧
    // 面板，再用仍然挂载的宿主 context 推管理页（细节见 widget 文件）。
    openManagePage: openManagePage,
  );

  if (!context.mounted || selected == null) {
    return;
  }
  if (selected == provider.activeProfileId) {
    return;
  }
  await provider.switchProfile(selected);
  if (!context.mounted) {
    return;
  }
  if (provider.settings.enableHaptics) {
    HapticFeedback.selectionClick();
  }
}
