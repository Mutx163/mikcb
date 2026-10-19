import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/app_toast.dart';

/// 星期栏墨色对比提醒弹层。
///
/// 2026-10-19 从 `timetable_screen.dart` 的 `_showWeekdayInkContrastDialog`
/// 搬出：原来那 77 行里，只有「弹长什么样、两个动作各按什么」属于弹层自身，
/// 「该不该弹、弹过没有、恢复默认要写哪些设置」全归调用方。
///
/// 职责切分：
/// * **本文件**：文案选择（深/浅壁纸各一句）、正文 widget、两个
///   [HyperosDialogAction] 的接线；
/// * **调用方**（课表页 State）：prefs 去重签名、`_weekdayInkWarningShowing`
///   翻转、`provider.updateSettings` 落盘、失败 toast 与 mounted 判断。
///
/// widget 自己不读 provider、不持有页面状态；[onResetDefault] 返回是否**真的
/// 写成功**——失败时弹层不关，用户要看得见「没改成」（与 add_exam_screen 同口径）。
Future<void> showTimetableWeekdayInkContrastDialog(
  BuildContext context, {
  required bool wallpaperIsDark,
  required Future<bool> Function() onResetDefault,
}) async {
  final l10n = AppLocalizations.of(context)!;
  await showHyperosDialog<void>(
    context: context,
    title: l10n.weekdayInkContrastTitle,
    body: TimetableWeekdayInkContrastDialogBody(
      message: wallpaperIsDark
          ? l10n.weekdayInkContrastBodyDark
          : l10n.weekdayInkContrastBodyLight,
    ),
    actions: [
      HyperosDialogAction(
        label: l10n.gotItAction,
        onPressed: () => Navigator.pop(context),
      ),
      HyperosDialogAction(
        label: l10n.resetDefaultAction,
        isPrimary: true,
        onPressed: () async {
          final saved = await onResetDefault();
          // 失败（含 provider 回滚后 rethrow 被调用方接住）不关弹层。
          if (!saved || !context.mounted) {
            return;
          }
          Navigator.pop(context);
        },
      ),
    ],
  );
}

/// 对比度提醒弹层的正文：只做「深 / 浅壁纸换一句说明」。
///
/// 文案由弹层入口按 [AppLocalizations] 解析后传入，widget 不做 l10n 查找，
/// 方便单独渲染与复用。
class TimetableWeekdayInkContrastDialogBody extends StatelessWidget {
  const TimetableWeekdayInkContrastDialogBody({
    super.key,
    required this.message,
  });

  /// 已经按壁纸明暗选好的那句说明。
  final String message;

  @override
  Widget build(BuildContext context) => Text(message);
}

/// 把星期栏墨色改回默认（自动黑 / 白）。
///
/// 和弹层放在一起而不是留在课表页 State：「深色主题该写哪个字段」与「写失败
/// 怎么提示」都是这条警告的一部分。返回是否**真的写成功** —— 失败时弹层不关。
///
/// 只改这一个字段：读的是**实时** settings，弹层挂着的这段时间里设置可能已经
/// 变过，不能拿弹出前的快照整体覆盖。
Future<bool> resetTimetableWeekdayInkToDefault(
  BuildContext context, {
  required TimetableProvider provider,
  required bool isDarkTheme,
  required String defaultHex,
}) async {
  final current = provider.settings;
  try {
    await provider.updateSettings(
      isDarkTheme
          ? current.copyWith(weekdayBarFontColorDark: defaultHex)
          : current.copyWith(weekdayBarFontColorLight: defaultHex),
    );
  } catch (_) {
    // 失败不关弹层（与 add_exam_screen 同口径）：用户要看得见「没改成」。
    if (!context.mounted) {
      return false;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.saveFailed,
      kind: AppToastKind.error,
    );
    return false;
  }
  return true;
}
