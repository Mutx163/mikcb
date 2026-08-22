import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixBadge;
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

enum HomeTopMenuAction {
  update,
  overview,
  statistics,
  addCourse,
  exams,
  importCourses,
  tasks,
  settings,
  support,
}

extension HomeTopMenuActionIdX on HomeTopMenuAction {
  /// 持久化 id（与 [HomeGridMenu.defaultActions] 里的字符串对应）。
  String get id => name;

  /// 从持久化 id 解析动作；未知 id 返回 null，由调用方丢弃。
  static HomeTopMenuAction? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final action in HomeTopMenuAction.values) {
      if (action.name == id) {
        return action;
      }
    }
    return null;
  }
}

/// 把设置里持久化的八宫格排列解析成动作序列：丢弃未知 id、保持用户
/// 排序；空表或全部失效时回退到 v2.0.5.5 的默认排列。
List<HomeTopMenuAction> resolveHomeGridMenuActions(
  TimetableSettings settings,
) {
  final resolved = <HomeTopMenuAction>[];
  for (final id in settings.homeGridMenuActions) {
    final action = HomeTopMenuActionIdX.fromId(id);
    if (action != null && !resolved.contains(action)) {
      resolved.add(action);
    }
  }
  if (resolved.isEmpty) {
    return HomeGridMenu.defaultActions
        .map(HomeTopMenuActionIdX.fromId)
        .whereType<HomeTopMenuAction>()
        .toList(growable: false);
  }
  return List.unmodifiable(resolved);
}

/// 八宫格瓷贴的图标。列表菜单不展示图标，只有瓷贴形态需要。
IconData homeTopMenuActionIcon(HomeTopMenuAction action) => switch (action) {
  HomeTopMenuAction.update => Icons.system_update_alt_rounded,
  HomeTopMenuAction.overview => Icons.dashboard_customize_rounded,
  HomeTopMenuAction.statistics => Icons.bar_chart_rounded,
  HomeTopMenuAction.addCourse => Icons.add_circle_outline_rounded,
  HomeTopMenuAction.exams => Icons.school_outlined,
  HomeTopMenuAction.importCourses => Icons.file_upload_outlined,
  HomeTopMenuAction.tasks => Icons.checklist_rounded,
  HomeTopMenuAction.settings => Icons.tune_rounded,
  HomeTopMenuAction.support => Icons.favorite_border_rounded,
};

/// 八宫格瓷贴的标题（复用列表菜单同一套文案）。
String homeTopMenuActionTitle(AppLocalizations l10n, HomeTopMenuAction action) =>
    switch (action) {
      HomeTopMenuAction.update => l10n.homeMenuUpdateTitle,
      HomeTopMenuAction.overview => l10n.homeMenuOverviewTitle,
      HomeTopMenuAction.statistics => l10n.homeMenuStatisticsTitle,
      HomeTopMenuAction.addCourse => l10n.homeMenuAddCourseTitle,
      HomeTopMenuAction.exams => l10n.examListTitle,
      HomeTopMenuAction.importCourses => l10n.homeMenuImportTitle,
      HomeTopMenuAction.tasks => l10n.homeMenuTasksTitle,
      HomeTopMenuAction.settings => l10n.homeMenuSettingsTitle,
      HomeTopMenuAction.support => l10n.homeMenuCoffeeTitle,
    };

/// Shows the home screen top-right action menu as a small anchored Miuix list
/// popup — the same chrome as every other anchored popup in the app: spring
/// reveal, glass surface, tap-outside to dismiss.
///
/// Rows are plain text only, matching the MIUI/HyperOS top-right menu
/// convention (icons are reserved for in-page actions, not overflow menus).
///
/// [anchorKey] must be the key of the top-right "more" button; the popup is
/// positioned just below it via [hyperosPopupPositionBelow].
Future<HomeTopMenuAction?> showHomeTopMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
  required GlobalKey anchorKey,
  Color? foregroundColor,
}) {
  final l10n = AppLocalizations.of(context)!;
  final position = hyperosPopupPositionBelow(context, anchorKey);

  HyperosPopupMenuItem<HomeTopMenuAction> item({
    required String title,
    required HomeTopMenuAction action,
    Widget? trailing,
    bool gapBefore = false,
  }) {
    return HyperosPopupMenuItem<HomeTopMenuAction>(
      label: title,
      value: action,
      trailing: trailing,
      gapBefore: gapBefore,
    );
  }

  return showHyperosListPopup<HomeTopMenuAction>(
    context: context,
    position: position,
    foregroundColor: foregroundColor,
    items: [
      item(
        title: l10n.homeMenuUpdateTitle,
        action: HomeTopMenuAction.update,
        // The trailing dot badge marks the pending update; rows stay text
        // only so the wallpaper-aware ink keeps the menu uniform.
        trailing: hasAvailableUpdate ? const MiuixBadge() : null,
      ),
      item(
        title: l10n.homeMenuOverviewTitle,
        action: HomeTopMenuAction.overview,
      ),
      item(
        title: l10n.homeMenuStatisticsTitle,
        action: HomeTopMenuAction.statistics,
      ),
      item(
        title: l10n.homeMenuAddCourseTitle,
        action: HomeTopMenuAction.addCourse,
      ),
      item(title: l10n.examListTitle, action: HomeTopMenuAction.exams),
      item(
        title: l10n.homeMenuImportTitle,
        action: HomeTopMenuAction.importCourses,
      ),
      item(
        title: l10n.homeMenuTasksTitle,
        action: HomeTopMenuAction.tasks,
        gapBefore: true,
      ),
      item(
        title: l10n.homeMenuSettingsTitle,
        action: HomeTopMenuAction.settings,
      ),
      item(
        title: l10n.homeMenuCoffeeTitle,
        action: HomeTopMenuAction.support,
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
/// 4 列图标瓷贴、磨砂卡面、更新入口带角标。[actions] 是用户自定义后的
/// 排列（最多 [HomeGridMenu.maxSlots] 个），不足一行的尾行按同样宽度排布。
Future<HomeTopMenuAction?> showHomeTopGridMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
  required List<HomeTopMenuAction> actions,
}) {
  return showHomeHyperosSheet<HomeTopMenuAction>(
    context: context,
    builder: (sheetContext) =>
        _HomeTopGridMenuSheet(actions: actions, hasAvailableUpdate: hasAvailableUpdate),
  );
}

class _HomeTopGridMenuSheet extends StatelessWidget {
  const _HomeTopGridMenuSheet({
    required this.actions,
    required this.hasAvailableUpdate,
  });

  final List<HomeTopMenuAction> actions;
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
      for (final action in actions) homeTopMenuActionTitle(l10n, action),
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

          Widget tile({
            required IconData icon,
            required String title,
            required HomeTopMenuAction action,
            Color? accentColor,
            String? badgeText,
          }) {
            return SizedBox(
              width: itemWidth,
              child: _HomeMenuActionTile(
                icon: icon,
                title: title,
                titleStyle: titleStyle,
                titleAreaHeight: titleAreaHeight,
                accentColor: accentColor,
                badgeText: badgeText,
                onTap: () => Navigator.of(context).pop(action),
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
          for (var start = 0; start < actions.length; start += columnsPerRow) {
            final slice = actions.sublist(
              start,
              math.min(start + columnsPerRow, actions.length),
            );
            rows.add([
              for (final action in slice)
                tile(
                  icon: homeTopMenuActionIcon(action),
                  title: homeTopMenuActionTitle(l10n, action),
                  action: action,
                  badgeText:
                      action == HomeTopMenuAction.update && hasAvailableUpdate
                      ? l10n.updateLabel
                      : null,
                  accentColor:
                      action == HomeTopMenuAction.update && hasAvailableUpdate
                      ? colorScheme.primary
                      : null,
                ),
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
