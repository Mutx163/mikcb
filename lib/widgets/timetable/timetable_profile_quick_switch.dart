import 'package:flutter/material.dart';

import '../../models/timetable_profile.dart';
import '../../ui/hyperos/hyperos.dart';
import '../profile_quick_switch_sheet.dart';

/// 首页「切换课表」弹层的宿主封装。
///
/// 2026-10-19 从 `timetable_screen.dart` 的 `_showProfileQuickSwitchSheet` 搬出：
/// 那 61 行里真正属于「弹层」的是两件事 —— 过滤出可切换的课表、把「管理课表」
/// 回调接成「先收弹层、再推页」，其余（读 provider、切换 profile、点击音效）
/// 都归调用方。
///
/// widget 自己不读 provider：
/// * [profiles] / [activeProfileId] 由调用方从 provider 取；
/// * [popupSourceRect] 把弹层内按钮的 `BuildContext` 换算成源矩形 —— 弹层内容
///   挂在根 Overlay 上，推页要从这块矩形长出来；
/// * [openManagePage] 用**宿主** context 推「课表管理」页。
///
/// 返回用户选中的 profile id（没选返回 null）。切换动作、点击音效由调用方做。
Future<String?> showTimetableProfileQuickSwitch(
  BuildContext context, {
  required List<TimetableProfile> profiles,
  required String? activeProfileId,
  required Rect Function(BuildContext buttonContext) popupSourceRect,
  required void Function(BuildContext hostContext, Rect sourceRect) openManagePage,
}) {
  // TA 课表是覆盖层叠加，不是切换对象；switchProfile 对它静默守卫，
  // 列出来只会造成「点了没反应」。
  final switchable = profiles
      .where((profile) => !profile.isPartnerImported)
      .toList(growable: false);
  MiuixBottomSheetClose? closeSheet;
  return showProfileQuickSwitchSheet(
    context,
    profiles: switchable,
    activeProfileId: activeProfileId,
    closeRef: (close) => closeSheet = close,
    onManageTimetables: (buttonContext) {
      // MiuixWindowBottomSheet 的内容挂在根 Overlay 上，buttonContext 拿不到
      // 原来的 ModalRoute；不能靠猜路由来收弹层。记录源按钮的位置，让
      // close(immediate:) 先摘掉根 Overlay 条目，再用宿主 context 推页。
      final sourceRect = popupSourceRect(buttonContext);
      final close = closeSheet;
      if (close == null) {
        return;
      }
      close(
        immediate: true,
        afterDismiss: () {
          if (!context.mounted) {
            return;
          }
          openManagePage(context, sourceRect);
        },
      );
    },
  );
}
