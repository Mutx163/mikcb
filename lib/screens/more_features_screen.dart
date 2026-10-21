import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/home_top_menu.dart' show resolveHomeGridMenuAccent;

/// 「更多功能」页：只收「别处没有固定入口」的功能页。
///
/// ## 这个页面是什么（2026-10-21 定位纠正）
///
/// 用户反馈「这个页面定位有点错误，现在变成了页面大杂烩」。原收录标准是
/// **从八宫格候选目录全量推导**，于是 32 个格子把三类不该出现的东西也平铺了
/// 进去：与设置页重复的目的地、创建动作、关于类页面。
///
/// 根因是混淆了两个不同的收录标准：[kHomeMenuCatalog] 是**首页快捷位的候选池**，
/// 判据是「点进去就有用的任意目标」；本页是**功能目录**，判据只能是
/// 「这个目的地在别处有没有固定入口」。用候选池当目录 = 把「可选的」当成
/// 「该列的」。
///
/// ## 收录标准：白名单（[kMoreFeaturesEntryIds]）
///
/// 只收**没有其他固定入口**的功能页。每条都注明「为什么它进得来」，除非别处
/// 的入口真的被删了，否则这条不会被悄悄改动——新增功能页默认**不进**本页，
/// 要进必须在这里显式加一行并写清理由。
///
/// 排除的几类（都不再靠「分类 == preferences」隐式排除，而是显式理由）：
/// - **设置首页已有一级行**：课表管理、时间模板、数据传输、云同步、局域网编辑、
///   情侣课表、使用指南——设置页那份还带回显状态（当前课表名 / 时间模板名 /
///   云同步状态），本页的同名瓷贴没有状态，严格劣于设置页那一份；
/// - **关于页二级重复**：版本更新、支持作者、关于、更新日志、反馈、开源许可——
///   关于页五组齐备，本页平铺是第三份入口；
/// - **创建动作**：添加课程/考试/任务/日程，各自都有对应列表页的「+」，混进
///   导航目录会让用户无法预测点下去是「去一个地方」还是「发生一件事」；
/// - **瞬时弹层动作**：重新配色、分享课表、切换课表——同上，它们是动作不是目的地；
/// - **藏在配置页里的**：地点作息匹配、日程日期规则（时间模板页首组）、ICS 导出
///   （数据传输页内）——它们不是没地方去，是该由宿主页负责提示。
///
/// 页脚给一句「其余都在课表设置里」的说明：砍掉 23 条之后，用户翻完会以为功能
/// 被删了，必须告诉他去哪找。这句话是这次改动的**必需部分**，不是装饰。
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
          // 页脚说明这次是**必需部分**：本页从 32 条砍到 9 条之后，用户翻完
          // 会以为功能被删了，必须当场告诉他其余都在课表设置里。
          const HyperosSectionGap(),
          HyperosSectionDescription(text: l10n.homeMenuMoreScopedHint),
        ],
      ),
    );
  }

  /// 分类下的一句描述（段落说明，帮用户不点进去就知道这组是什么）。
  ///
  /// 现状：白名单里的 9 条全部属于 `features`，所以页面上**只会渲染一个组**，
  /// `data` / `about` 两个分支当下走不到。保留它们是为了以后往白名单加一条
  /// 数据类条目时不用改这里；switch 要求 enum 全覆盖，删掉也编译不过。
  String _categoryDescription(
    AppLocalizations l10n,
    HomeMenuEntryCategory category,
  ) => switch (category) {
    HomeMenuEntryCategory.features => l10n.homeMenuMoreFeaturesDesc,
    HomeMenuEntryCategory.data => l10n.homeMenuMoreDataDesc,
    // 不可达：偏好设置分类整组不进白名单（设置子页的归宿是设置首页）。
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

/// 本页收录的目录条目 id：**只有别处没有固定入口的功能页**。
///
/// 每条都写明「为什么它在这儿」；别处的入口真被删了才该动这里。顺序即展示
/// 顺序（同一分类内按此先后排）。
///
/// 判据是**目的地有没有其他固定入口**，不是「它在不在八宫格候选池里」——
/// 后者是首页快捷位的判据（点进去就有用的任意目标），两者混用正是本页
/// 一度变成大杂烩的根因，见类注释。
const List<String> kMoreFeaturesEntryIds = [
  // ── 全应用唯一入口 ──────────────────────────────────────
  // 取件码：只有本页与八宫格/底栏的候选，别处没有任何固定入口。
  'pickupCode',
  // 月视图：同上。课表首页只有周/日两种视图模式
  // （`TimetableHomeViewMode`），月视图是独立页，没有常驻入口。
  'monthView',
  // 课程统计：设置里的「统计设置」只是它的配置子页，统计页本身别处没有。
  'statistics',
  // 考试列表：考试页的「+」能加考试，但列表页本身没有固定入口。
  'exams',
  // 日程安排：日程列表页本身没有固定入口（添加日程的入口在它内部）。
  'scheduleList',
  // 导入课程：仅有的另一处是 `main.dart` 的外部分享/深链流程（用户从别的
  // App 分享文件过来才会经过），以及首次启动的使用指南——都不是可回访入口。
  'importCourses',

  // ── 入口存在但实际找不到（链式断裂）──────────────────────
  // 课程总览：另一处入口在使用指南「设置课程简称」那颗按钮里
  // （`user_guide_screen.dart` 的 `/courses/overview` 推入）——语义是
  // 「去设简称」，没人会当总览入口用。
  'overview',
  // 任务清单：日视图任务条只在「逾期超 3 条被折叠」时给一个「还有 N 条」的
  // 跳转（`day_view_task_band.dart`，阈值见 `day_task_band_logic.dart`）——
  // 用户得先开着日视图、还得攒够逾期作业。八宫格/底栏默认排列含 tasks，
  // 但那是用户可移除的收藏位，移掉后这里必须是兜底。
  'tasks',
  // 冲突详情：唯一入口是总览页的冲突提示条（`course_overview_screen.dart`
  // 的 `conflictScheduleCount > 0` 分支，仅当有冲突才渲染），而总览页
  // 自己又没有固定入口——**两层断裂，等于没有**。它也是修课表冲突的唯一
  // 去处，留着。
  'courseConflict',
];

/// 汇总页收录的目录条目（纯函数，契约测试直接断言它）。
///
/// 从 [kMoreFeaturesEntryIds] 白名单映射到目录条目，并照常过 `visible()`
/// 门控（调试版专属条目在正式版仍被丢弃）。
///
/// 未知 id 不会出现在结果里（目录里没有就没有）。新增功能页**默认不进**
/// 本页——要进必须在白名单里显式加一行并写清「为什么别处没有」。
List<HomeMenuEntry> moreFeaturesEntries() {
  final byId = <String, HomeMenuEntry>{
    for (final entry in kHomeMenuCatalog) entry.id: entry,
  };
  return [
    for (final id in kMoreFeaturesEntryIds)
      if (byId[id] case final entry? when entry.visible()) entry,
  ];
}
