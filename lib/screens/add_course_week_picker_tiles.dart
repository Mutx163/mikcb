import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../ui/hyperos/hyperos.dart';

/// 「哪些周上」选择器的选择模式：按范围（起止周 + 单双周）或逐周勾选。
///
/// 原先是 `add_course_screen.dart` 里的私有枚举 `_WeekSelectionMode`；2026-10-20
/// 随「弹层的三个纯构建小件挪出本文件」（页面行数棘轮）一起公开化——
/// 模式枚举与吃它的小件在同一处，`add_course_screen.dart` 经 import 使用。
enum WeekSelectionMode { range, custom }

/// 「哪些周上」弹层的三个纯构建小件，从 `add_course_screen.dart` 搬出：
/// 那里 2000+ 行、有只减不增的行数棘轮，而这三个小件只被弹层吃——
/// 搬到同级 screens 文件（widgets 层不许 import screens 的纪律不破），
/// 弹层本体与 `weeksFromRangeSelection` 判据仍留在原文件（冻结的接线测试
/// `add_course_week_range_intersection_test` 把它们钉在原文件源码里）。

/// 周网格里的单周按钮（Ready-made Miuix button；dense 变体按网格 / 胶囊布局调）。
Widget buildCourseWeekGridTile({
  required int week,
  required bool isSelected,
  required VoidCallback onPress,
}) {
  return HyperosButton(
    label: '$week',
    variant: isSelected
        ? HyperosButtonVariant.primary
        : HyperosButtonVariant.secondary,
    dense: true,
    onPressed: onPress,
  );
}

/// 模式选择组：按范围 / 逐周勾。
Widget buildCourseWeekModeTileGroup({
  required WeekSelectionMode tempMode,
  required AppLocalizations l10n,
  required ValueChanged<WeekSelectionMode> onSelect,
}) {
  return HyperosChoiceGroup(
    children: [
      HyperosChoiceTile(
        prefix: const Icon(Icons.linear_scale_rounded),
        title: l10n.rangeWeeksLabel,
        selected: tempMode == WeekSelectionMode.range,
        highlightSelectedText: true,
        onTap: () => onSelect(WeekSelectionMode.range),
      ),
      HyperosChoiceTile(
        prefix: const Icon(Icons.apps_rounded),
        title: l10n.customWeeksLabel,
        selected: tempMode == WeekSelectionMode.custom,
        highlightSelectedText: true,
        onTap: () => onSelect(WeekSelectionMode.custom),
      ),
    ],
  );
}

/// 单双周过滤组：全部 / 单周 / 双周。
Widget buildCourseWeekParityTileGroup({
  required AppLocalizations l10n,
  required bool isAllWeeks,
  required bool isOddWeek,
  required bool isEvenWeek,
  required VoidCallback onSelectAll,
  required VoidCallback onSelectOdd,
  required VoidCallback onSelectEven,
}) {
  return HyperosChoiceGroup(
    children: [
      HyperosChoiceTile(
        title: l10n.allWeeksFilter,
        selected: isAllWeeks,
        highlightSelectedText: true,
        onTap: onSelectAll,
      ),
      HyperosChoiceTile(
        title: l10n.oddWeeksFilter,
        selected: isOddWeek,
        highlightSelectedText: true,
        onTap: onSelectOdd,
      ),
      HyperosChoiceTile(
        title: l10n.evenWeeksFilter,
        selected: isEvenWeek,
        highlightSelectedText: true,
        onTap: onSelectEven,
      ),
    ],
  );
}
