import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';
import '../widgets/home_menu_catalog.dart';

/// 「更多功能」汇总页：一页收齐「没有其他固定入口」的隐藏功能。
///
/// ## 这个页面是什么
///
/// 任务清单、日程安排、取件码、月视图、冲突详情、地点作息匹配、日期作息规则、
/// 导出日历、统计设置、课程卡天气——这些页面/设置在全应用里**只有首页菜单
/// （八宫格/底栏/右上角菜单）一处可达**，且不在默认排列里：用户不知道「设置 →
/// 首页与导航」的编辑器存在，就永远发现不了它们。本页把它们收成一页，用户
/// 只要在底栏/八宫格添加「更多功能」这一个入口，就能从这里到达全部。
///
/// ## 为什么是精选清单、不是全部倒进去
///
/// 右上角菜单已有的常用项（软件更新、加课、导入课程、数据传输这些默认
/// 能看到的不列）不重复；组件展示页/测试夹具/内存监控是调试版专属
/// （正式版门控），不收。清单写死在 [kMoreFeaturesEntryIds]：可控、不馁。
/// 以后新增隐藏页要在这里补一行 id——如果哪天嫌烦，再考虑给目录条目加
/// 标记自动收录（二期）。
///
/// ## 数据从哪来（不维护第二份清单）
///
/// 行的图标/标题/点击行为全部来自 `kHomeMenuCatalog` 的目录条目
/// （[homeMenuEntryById] 按 id 查，[HomeMenuEntry.open] 负责导航）：
/// 页面只维护「收哪些 id」，元数据仍归目录条目一处真源——与八宫格编辑器
/// 的取数路径完全一致。
///
/// ## 两种展示形态
///
/// 推入路由（`morePage`，八宫格/右上角菜单点进来）与底栏玻璃坞内嵌页
/// （`more`，坞保持悬浮）共用本页：返回键由 [HyperosSubpage] 按
/// `HyperosSubpageNoBack` 自动抑制，内嵌态不渲染返回键，无须逐页适配；
/// 底部余量由坞宿主的滚动余量 scope 统一注入。
class MoreFeaturesScreen extends StatelessWidget {
  const MoreFeaturesScreen({super.key});

  /// 汇总页收录的目录条目 id（精选清单，与 `kHomeMenuCatalog` 对齐）。
  ///
  /// 每个都必须是目录里存在的 id：漏登记/改名的 id 在渲染时被就地丢弃
  /// （与编辑器种子阶段同一条口径），契约测试会在 CI 阶段先拦下。
  static const List<String> kMoreFeaturesEntryIds = [
    // 功能入口
    'tasks',
    'scheduleList',
    'pickupCode',
    'monthView',
    'courseConflict',
    'locationTimeMatch',
    'scheduleDateRule',
    'icsExport',
    // 偏好设置
    'statisticsSettings',
    'weatherSettings',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _resolveEntries();
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeMenuMoreTitle),
      child: HyperosListView(
        children: [
          for (final category in HomeMenuEntryCategory.values)
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

  /// 按 id 查目录条目：未知 id（改名/下线）就地丢弃，与八宫格编辑器同一条
  /// 口径；visible() 门控让调试版专属条目在正式版不出现（清单里当前没有
  /// 这类条目，门控为将来收录留口）。
  List<HomeMenuEntry> _resolveEntries() {
    final entries = <HomeMenuEntry>[];
    for (final id in kMoreFeaturesEntryIds) {
      final entry = homeMenuEntryById(id);
      if (entry != null && entry.visible()) {
        entries.add(entry);
      }
    }
    return entries;
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
