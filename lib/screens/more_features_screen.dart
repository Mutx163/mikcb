import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/home_top_menu.dart' show resolveHomeGridMenuAccent;

/// 「更多功能」汇总页：一页收齐全应用的功能入口（设置子页除外）。
///
/// ## 这个页面是什么
///
/// 用户在底栏/八宫格添加「更多功能」这一个入口，就能从这一页到达全部功能
/// 页面——任务清单（作业列表）、日程安排、月视图、统计、考试、课程总览、
/// 数据传输、取件码……包括不在默认八宫格排列里的（统计/总览被移出首页后，
/// 这里仍是它们的入口）与藏在其他页面深处的（冲突详情、地点作息匹配等）。
///
/// ## 收录标准：全量、自动，不维护手工清单
///
/// 收 [kHomeMenuCatalog] 里**除「偏好设置」分类外**的全部可见条目：
/// - 设置子页（统计设置、天气设置、通用……）有设置首页这个固定归宿，
///   不进功能目录——把统计设置收进来是错的：该收的是统计页本身，设置
///   藏在统计页里（用户 2026-10-21 点名）；
/// - 「更多功能」自身排除（不自我收录）；
/// - visible() 门控照常生效（调试版专属条目不进正式版）。
/// 新增目录条目自动出现在本页，无手工清单要维护——此前按「有没有其他
/// 固定入口」手筛 10 条的方案已废弃：漏了总览/统计/考试这些「默认排列里
/// 有、但被用户移出后就没处找」的页，还把统计设置误收了进来。
///
/// ## 版式
///
/// 每个分类一个 [HyperosSettingsBlock]（标题 + 一句描述）+ 分类瓷贴网格：
/// 瓷贴与首页八宫格同一套视觉语言（磨砂卡面、主题色图标井、两行标题、
/// 4 列砖宽 64-112 平板不拉伸），强调色走用户主题 seed（与首页八宫格
/// 同一条取色路径）。
///
/// ## 两种展示形态
///
/// 推入路由（`morePage`，八宫格/右上角菜单点进来）与底栏玻璃坞内嵌页
/// （`more`，坞保持悬浮）共用本页：返回键由 [HyperosSubpage] 按
/// `HyperosSubpageNoBack` 自动抑制，内嵌态不渲染返回键，无须逐页适配；
/// 底部余量由坞宿主的滚动余量 scope 统一注入。
class MoreFeaturesScreen extends StatelessWidget {
  const MoreFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeSeedHex = context
        .watch<TimetableProvider>()
        .settings
        .themeSeedColor;
    final entries = moreFeaturesEntries();
    final sections = HomeMenuEntryCategory.values
        .where((category) => category != HomeMenuEntryCategory.preferences)
        .where(
          (category) => entries.any((entry) => entry.category == category),
        )
        .toList(growable: false);
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeMenuMoreTitle),
      child: HyperosListView(
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) const HyperosSectionGap(),
            HyperosSettingsBlock(
              title: homeMenuEntryCategoryLabel(l10n, sections[index]),
              description: _categoryDescription(l10n, sections[index]),
              gapBeforeChild: 10,
              child: _MoreTileGrid(
                entries: entries
                    .where((entry) => entry.category == sections[index])
                    .toList(growable: false),
                themeSeedHex: themeSeedHex,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 分类下的一句描述（段落说明，帮用户不点进去就知道这组是什么）。
  String _categoryDescription(
    AppLocalizations l10n,
    HomeMenuEntryCategory category,
  ) => switch (category) {
    HomeMenuEntryCategory.features => l10n.homeMenuMoreFeaturesDesc,
    HomeMenuEntryCategory.data => l10n.homeMenuMoreDataDesc,
    // 不可达：偏好设置分类整组跳过，不会进到这里。
    HomeMenuEntryCategory.preferences => '',
    HomeMenuEntryCategory.about => l10n.homeMenuMoreAboutDesc,
  };
}

/// 分类瓷贴网格：与首页八宫格同一套瓷贴语言。
///
/// 4 列、砖宽 64-112（平板上砖不拉伸，多余宽度摊成等距间隙）、10px 间距、
/// 尾行左对齐；标题区按全组标题统一量高，砖高一致不参差。
class _MoreTileGrid extends StatelessWidget {
  const _MoreTileGrid({required this.entries, required this.themeSeedHex});

  final List<HomeMenuEntry> entries;

  /// 用户主题 seed（`TimetableSettings.themeSeedColor`）：图标井与图标色随
  /// 主题走，与首页八宫格同一条取色路径（[resolveHomeGridMenuAccent]）。
  final String? themeSeedHex;

  static const _tileSpacing = 10.0;
  static const _tileHorizontalPadding = 14.0;
  static const _maxTileWidth = 112.0;
  static const _minTileWidth = 64.0;
  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.theme.typography.body.xs2.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.15,
      color: context.theme.colors.foreground,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final hasBoundedWidth = availableWidth.isFinite && availableWidth > 0;
        const gapCount = _columns - 1;
        final rawItemWidth = hasBoundedWidth
            ? (availableWidth - _tileSpacing * gapCount) / _columns
            : _maxTileWidth;
        final itemWidth = rawItemWidth.clamp(_minTileWidth, _maxTileWidth);
        final shouldSpread = hasBoundedWidth && rawItemWidth > _maxTileWidth;
        final itemGap = shouldSpread
            ? (availableWidth - itemWidth * _columns) / gapCount
            : _tileSpacing;
        final titleAreaHeight = _measureTitleAreaHeight(
          context,
          style: titleStyle,
          maxWidth: itemWidth - _tileHorizontalPadding,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var start = 0; start < entries.length; start += _columns) ...[
              if (start > 0) const SizedBox(height: _tileSpacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = start;
                      index < math.min(start + _columns, entries.length);
                      index++) ...[
                    if (index > start) SizedBox(width: itemGap),
                    SizedBox(
                      width: itemWidth,
                      child: _MoreActionTile(
                        entry: entries[index],
                        titleStyle: titleStyle,
                        titleAreaHeight: titleAreaHeight,
                        themeSeedHex: themeSeedHex,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// 全组标题统一量高（与首页八宫格同一套 TextPainter 算法）：砖高一致，
  /// 两行标题不把个别砖撑高。
  double _measureTitleAreaHeight(
    BuildContext context, {
    required TextStyle style,
    required double maxWidth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final textDirection = Directionality.of(context);
    var maxHeight = 0.0;
    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(text: entry.title(l10n), style: style),
        maxLines: 2,
        textAlign: TextAlign.center,
        textDirection: textDirection,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      maxHeight = math.max(maxHeight, painter.height);
    }
    return maxHeight;
  }
}

/// 一块功能瓷贴：磨砂卡面 + 主题色图标井 + 两行标题，与首页八宫格同款。
class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({
    required this.entry,
    required this.titleStyle,
    required this.titleAreaHeight,
    required this.themeSeedHex,
  });

  final HomeMenuEntry entry;
  final TextStyle titleStyle;
  final double titleAreaHeight;
  final String? themeSeedHex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = resolveHomeGridMenuAccent(context, themeSeedHex);
    const iconWellRadius = BorderRadius.all(Radius.circular(14));
    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      // 页面是不透明底：磨砂采不到东西，静态卡面等效且省每帧重采样。
      blurEnabled: false,
      tint: HyperosColors.card(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: HyperosTheme.cardBorderRadius,
          onTap: () => entry.open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HyperosFrostedSurface(
                  borderRadius: iconWellRadius,
                  blurEnabled: false,
                  tint: HyperosBlurredHeader.accentSurfaceTintColor(accent),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      child: Icon(entry.icon, color: accent, size: 24),
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
                      entry.title(l10n),
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

/// 汇总页收录的目录条目（纯函数，契约测试直接断言它）。
///
/// 收录标准见类注释：除「偏好设置」分类（设置子页的归宿是设置首页）与
/// 「更多功能」自身（不自我收录）外的全部可见条目。未知条目不存在于
/// 目录就不会出现——本函数从目录推导，无手工清单可漂移。
List<HomeMenuEntry> moreFeaturesEntries() {
  return [
    for (final entry in kHomeMenuCatalog)
      if (entry.category != HomeMenuEntryCategory.preferences &&
          entry.id != 'more' &&
          entry.visible())
        entry,
  ];
}
