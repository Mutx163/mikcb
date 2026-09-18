import 'package:flutter/material.dart';

/// 日视图日程条目里的一行「图标 + 文字」信息。
///
/// 原本是 `timetable_screen.dart` 的私有方法 `_buildCurrentDayAgendaInfoRow`，
/// 因为要抽出天气行复用同一套排版而提到这里。**字号/间距/透明度任一改动都会
/// 同时影响课卡与日程卡**，且旧的私有方法已退化成一行转发，不存在第二份副本。
///
/// 颜色取调用方算好的 [ink]（卡片调色板按壁纸明暗翻转的前景色），所以玻璃卡
/// 与实体卡、深浅色壁纸都自动可读，这里不做任何额外对比度处理。
class DayAgendaInfoRow extends StatelessWidget {
  const DayAgendaInfoRow({
    super.key,
    required this.icon,
    required this.text,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: ink.withValues(alpha: 0.82)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink.withValues(alpha: 0.92),
              fontWeight: FontWeight.w400,
              fontSize: 11.5,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}
