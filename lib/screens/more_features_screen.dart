import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';
import '../widgets/home_menu_catalog.dart';

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
    final entries = moreFeaturesEntries();
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeMenuMoreTitle),
      child: HyperosListView(
        children: [
          for (final category in HomeMenuEntryCategory.values)
            // 偏好设置分类整组跳过：设置子页的归宿是设置首页，不进功能目录。
            if (category != HomeMenuEntryCategory.preferences)
              if (entries.any((entry) => entry.category == category)) ...[
                const HyperosSectionGap(),
                HyperosSectionLabel(
                  text: homeMenuEntryCategoryLabel(l10n, category),
                ),
                HyperosListGroup(
                  children: [
                    for (final entry in entries.where(
                      (item) => item.category == category,
                    ))
                      HyperosNavTile(
                        icon: entry.icon,
                        iconAccent: _accentOf(category),
                        title: entry.title(l10n),
                        onTap: () => entry.open(context),
                      ),
                  ],
                ),
              ],
        ],
      ),
    );
  }

  /// 行图标徽章的强调色，按分类固定：与设置首页的分组配色同一套语言
  /// （功能蓝/数据青/偏好紫/关于橙），不逐条目配色。
  Color _accentOf(HomeMenuEntryCategory category) => switch (category) {
    HomeMenuEntryCategory.features => HyperosIconColors.blue,
    HomeMenuEntryCategory.data => HyperosIconColors.teal,
    HomeMenuEntryCategory.preferences => HyperosIconColors.purple,
    HomeMenuEntryCategory.about => HyperosIconColors.orange,
  };
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
