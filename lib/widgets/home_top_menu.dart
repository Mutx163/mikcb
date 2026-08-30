import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixBadge;
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 八宫格候选入口的分类（编辑器分组展示用；也是列表弹窗的分组依据）。
enum HomeMenuEntryCategory { features, data, preferences, about }

String homeMenuEntryCategoryLabel(
  AppLocalizations l10n,
  HomeMenuEntryCategory category,
) => switch (category) {
  HomeMenuEntryCategory.features => l10n.homeMenuCategoryFeatures,
  HomeMenuEntryCategory.data => l10n.homeMenuCategoryData,
  HomeMenuEntryCategory.preferences => l10n.homeMenuCategoryPreferences,
  HomeMenuEntryCategory.about => l10n.homeMenuCategoryAbout,
};

/// 一个可放入首页右上角八宫格的入口：应用内任意二级页面或功能。
///
/// [id] 是持久化主键（设置里的 homeGridMenuActions 存的就是它），
/// 内置九项沿用旧列表菜单的动作名以兼容旧数据；[open] 负责从
/// 当前 context 导航，由目录统一提供实现。
/// [visible] 是构建模式等环境可见性门控：返回 false 的条目不进八宫格、
/// 不进编辑器候选，已持久化的 id 也会在解析时被丢弃——调试/性能版
/// 工具绝不能经目录泄漏给正式版用户。
class HomeMenuEntry {
  const HomeMenuEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    required this.open,
    this.visible = _alwaysVisible,
  });

  static bool _alwaysVisible() => true;

  final String id;
  final String Function(AppLocalizations l10n) title;
  final IconData icon;
  final HomeMenuEntryCategory category;
  final Future<void> Function(BuildContext context) open;
  final bool Function() visible;
}

/// 目录条目的标准导航壳：与首页顶部菜单同一条 Hyperos 页面转场路径。
Future<void> pushHomeMenuPage(BuildContext context, Widget page) {
  return Navigator.of(
    context,
  ).push<void>(HyperosPageRoute<void>(builder: (_) => page));
}

/// Shows the home screen top-right action menu as a small anchored Miuix list
/// popup — the same chrome as every other anchored popup in the app: spring
/// reveal, glass surface, tap-outside to dismiss.
///
/// Rows are plain text only, matching the MIUI/HyperOS top-right menu
/// convention (icons are reserved for in-page actions, not overflow menus).
///
/// [entries] 与八宫格共享同一份自定义排列（`resolveHomeGridMenuEntries`
/// 的结果）；相邻条目分类变化时插入 8dp 分组间隔，自定义排列后分组
/// 仍然自然。返回被点条目的 [HomeMenuEntry.id]，由调用方经目录分发
/// 导航（与八宫格形态同一条回传路径）。
///
/// [anchorKey] must be the key of the top-right "more" button; the popup is
/// positioned just below it via [hyperosPopupPositionBelow].
Future<String?> showHomeTopMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
  required List<HomeMenuEntry> entries,
  required GlobalKey anchorKey,
  Color? foregroundColor,
}) {
  final l10n = AppLocalizations.of(context)!;
  final position = hyperosPopupPositionBelow(context, anchorKey);

  return showHyperosListPopup<String>(
    context: context,
    position: position,
    foregroundColor: foregroundColor,
    items: [
      for (var index = 0; index < entries.length; index++)
        HyperosPopupMenuItem<String>(
          label: entries[index].title(l10n),
          value: entries[index].id,
          // The trailing dot badge marks the pending update; rows stay text
          // only so the wallpaper-aware ink keeps the menu uniform.
          trailing:
              entries[index].id == 'update' && hasAvailableUpdate
                  ? const MiuixBadge()
                  : null,
          gapBefore:
              index > 0 &&
              entries[index].category != entries[index - 1].category,
        ),
    ],
  );
}

double _maxMenuTitleHeight({
  required List<String> titles,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  var maxHeight = 0.0;
  for (final title in titles) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 2,
      textAlign: TextAlign.center,
      textDirection: textDirection,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    maxHeight = math.max(maxHeight, painter.height);
  }
  return maxHeight;
}

/// 首页右上角「更多」菜单的八宫格形态——v2.0.5.5 已发布版本的底部弹层：
/// 4 列图标瓷贴、磨砂卡面、更新入口带角标。[entries] 是用户自定义后的
/// 排列（最多 [HomeGridMenu.maxSlots] 个），不足一行的尾行按同样宽度排布。
///
/// 返回被点条目的 [HomeMenuEntry.id]，由调用方经目录分发导航；
/// 点遮罩关闭返回 null。
Future<String?> showHomeTopGridMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
  required List<HomeMenuEntry> entries,
}) {
  return showHomeHyperosSheet<String>(
    context: context,
    builder: (sheetContext) =>
        _HomeTopGridMenuSheet(entries: entries, hasAvailableUpdate: hasAvailableUpdate),
  );
}

class _HomeTopGridMenuSheet extends StatelessWidget {
  const _HomeTopGridMenuSheet({
    required this.entries,
    required this.hasAvailableUpdate,
  });

  final List<HomeMenuEntry> entries;
  final bool hasAvailableUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    const tileSpacing = 10.0;
    const tileHorizontalPadding = 14.0;
    // Phone visual cap: tiles stay at most this wide so icon wells don't stretch.
    const maxTileWidth = 112.0;
    const minTileWidth = 64.0;
    const columnsPerRow = 4;

    final menuTitles = [
      for (final entry in entries) entry.title(l10n),
    ];
    final titleStyle = typo.body.xs2.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.15,
      color: colors.foreground,
    );

    return HyperosSheetFrame(
      frosted: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Width is already after floating outer inset + frame padding.
          final gapCount = columnsPerRow - 1;
          final availableWidth = constraints.maxWidth;
          final hasBoundedWidth = availableWidth.isFinite && availableWidth > 0;
          final rawItemWidth = hasBoundedWidth
              ? (availableWidth - tileSpacing * gapCount) / columnsPerRow
              : maxTileWidth;
          // Keep phone sizing: never grow past [maxTileWidth]. Extra sheet
          // width on tablets is distributed as equal gaps between tiles.
          final itemWidth = rawItemWidth.clamp(minTileWidth, maxTileWidth);
          final shouldSpreadAcrossWidth =
              hasBoundedWidth && rawItemWidth > maxTileWidth;
          // Explicit gap so the row's intrinsic width equals the sheet width
          // (spaceBetween alone fails when the Row shrink-wraps).
          final itemGap = shouldSpreadAcrossWidth
              ? (availableWidth - itemWidth * columnsPerRow) / gapCount
              : tileSpacing;
          final titleAreaHeight = menuTitles.isEmpty
              ? 0.0
              : _maxMenuTitleHeight(
                  titles: menuTitles,
                  style: titleStyle,
                  maxWidth: itemWidth - tileHorizontalPadding,
                  textDirection: Directionality.of(context),
                );

          Widget tile(HomeMenuEntry entry) {
            final isUpdateSlot =
                entry.id == 'update' && hasAvailableUpdate;
            return SizedBox(
              width: itemWidth,
              child: _HomeMenuActionTile(
                icon: entry.icon,
                title: entry.title(l10n),
                titleStyle: titleStyle,
                titleAreaHeight: titleAreaHeight,
                accentColor: isUpdateSlot ? colorScheme.primary : null,
                badgeText: isUpdateSlot ? l10n.updateLabel : null,
                onTap: () => Navigator.of(context).pop(entry.id),
              ),
            );
          }

          Widget menuRow(List<Widget> tiles) {
            // Phone: fixed 10px gaps (existing look).
            // Tablet: same tile width, larger equal gaps so the row fills width.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0) SizedBox(width: itemGap),
                  tiles[index],
                ],
              ],
            );
          }

          // 用户自定义排列按每行 [columnsPerRow] 个切行；行宽与默认满 8 个
          // 时完全一致，尾行不足时靠左排布，不拉伸瓷贴。
          final rows = <List<Widget>>[];
          for (var start = 0; start < entries.length; start += columnsPerRow) {
            rows.add([
              for (final entry in entries.sublist(
                start,
                math.min(start + columnsPerRow, entries.length),
              ))
                tile(entry),
            ]);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  if (index > 0) const SizedBox(height: tileSpacing),
                  menuRow(rows[index]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeMenuActionTile extends StatelessWidget {
  const _HomeMenuActionTile({
    required this.icon,
    required this.title,
    required this.titleStyle,
    required this.titleAreaHeight,
    required this.onTap,
    this.accentColor,
    this.badgeText,
  });

  final IconData icon;
  final String title;
  final TextStyle titleStyle;
  final double titleAreaHeight;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = accentColor ?? colorScheme.primary;
    const iconWellRadius = BorderRadius.all(Radius.circular(14));

    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: HyperosTheme.cardBorderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HyperosBadge(
                  label: badgeText,
                  show: (badgeText ?? '').isNotEmpty,
                  child: HyperosFrostedSurface(
                    borderRadius: iconWellRadius,
                    blurEnabled: false,
                    tint: HyperosBlurredHeader.accentSurfaceTintColor(
                      highlightColor,
                    ),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: Icon(icon, color: highlightColor, size: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: titleAreaHeight,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
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
