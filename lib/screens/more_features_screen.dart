import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/home_menu_catalog.dart';

/// 「全部功能」页：全应用整页入口的**完整索引**，带搜索。
///
/// ## 三版定位的演变（读这一页先读这段）
///
/// 1. **初版（全量平铺）**：从八宫格候选目录全量推导，32 个瓷贴。用户反馈
///    「变成了页面大杂烩」——因为候选池的判据是「点进去就有用的任意目标」，
///    里面混着创建动作、瞬时弹层、关于类页面。
/// 2. **第二版（孤儿页白名单）**：只收「别处没有固定入口」的 9 条。用户反馈
///    「外观编辑页面都没有显示在这里」——因为它的判据是**技术可达**（设置 →
///    外观与配色 → 往下找一行就算有入口），而用户的实际感受是**体感可达**
///    （三层跳转等于没有）。这一版把判据的错位暴露了出来。
/// 3. **现版（完整索引 + 搜索 + 任务分组）**：承认这一页的职责就是
///    「我知道要什么，帮我跳过去」，所以它必须是**全集**。两版都把「完整」
///    和「不杂」当成取舍，其实二者不矛盾——iOS 18 重排设置就是靠「首页砍短 +
///    二级分组 + 搜索索引」同时做到的。
///
/// ## 收录判据（三条，替代前两版的相互矛盾）
///
/// 1. **是整页**，不是开关/选择器。主题色、字体大小这类「改一个参数」属于
///    设置项，不是导航目的地——它们留在各自的设置页里。
/// 2. **是「去一个地方」**，不是「发生一件事」。添加课程/考试/任务、分享课表、
///    重新配色都是动作，混进导航目录会让用户无法预测点下去的后果
///    （Apple HIG：导航容器只用于导航，不执行动作；WinUI 明文禁止把流程命令
///    放进设置页）。
/// 3. **过可见性门控**。调试页/演示页/测试台靠各条目自己的 `visible()`
///    挡在正式版外，本页不额外维护排除表。
///
/// 与前两版最大的不同：**不再用「别处有没有入口」当判据**。那条判据的失败
/// 方式无从预料——它把一个真实存在、用户点名要的页面（外观编辑）判成了
/// 「有入口、不必列」，因为代码无法衡量「三层跳转」和「一行入口」的体感差别。
///
/// ## 版式：为什么从瓷贴网格换成行式列表
///
/// Material 的判据：网格适合**同质数据**（图片、等长名字）并优化「视觉识别」；
/// 文字是主角、或条目长短不一，就该用列表。本页每条都要显示**当前值**
/// （当前课表名 / 时间模板 / 主题 / 同步状态），瓷贴塞不下第二行字——
/// 第二版丢掉的正是这个信息，而它恰恰是「看起来像设计过的」和「看起来像
/// 一堆图标」的差别。NN/g 另有量化结论：只用文字找东西比「图标+颜色」慢
/// 37%–57%，所以每行仍保留图标徽章。
///
/// 分组用**用户任务**（课表 / 课表显示 / 提醒与桌面 / 应用 / 数据与共享 /
/// 关于），不用目录里的 `HomeMenuEntryCategory`——那是编辑器给候选池分组的
/// 维度（按数据形态：功能/数据/偏好/关于），不是用户心智。
///
/// ## 两种展示形态
///
/// 推入路由（`morePage`，八宫格/右上角菜单点进来）与底栏玻璃坞内嵌页
/// （`more`，坞保持悬浮）共用本页：返回键由 [HyperosSubpage] 按
/// `HyperosSubpageNoBack` 自动抑制，内嵌态不渲染返回键，无须逐页适配；
/// 底部余量由坞宿主的滚动余量 scope 统一注入。
class MoreFeaturesScreen extends StatefulWidget {
  const MoreFeaturesScreen({super.key});

  @override
  State<MoreFeaturesScreen> createState() => _MoreFeaturesScreenState();
}

class _MoreFeaturesScreenState extends State<MoreFeaturesScreen> {
  /// 搜索是否展开。官方 `MiuixSearchBar` 的形态就是**原地展开**：折叠时只是
  /// 一个胶囊，点开后在原位置变成输入框 + 右侧滑出「取消」+ 结果区，全程
  /// 不换页（见 `SearchBar.md` 移植说明的 `expanded` 语义）。
  ///
  /// 早先这里推了个独立搜索页，用户当场问「为什么点击搜索框要跳转新的页面去，
  /// 原本的页面不行吗」——那条路是我图省事：跳页少写一套展开/收起状态，代价是
  /// 用户丢掉「还在这页」的空间感，返回还曾因此卡死（见提交 ac0f7ffd）。
  bool _searchExpanded = false;
  String _query = '';

  void _expandSearch() {
    if (!_searchExpanded) {
      setState(() => _searchExpanded = true);
    }
  }

  /// 收起：清空搜索词，回到全量列表。
  void _collapseSearch() {
    if (!_searchExpanded) {
      return;
    }
    setState(() {
      _searchExpanded = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // watch：副文本要显示当前课表名 / 时间模板 / 情侣绑定状态，这些随
    // provider 通知变化（切换课表后回到本页必须是最新值）。
    final provider = context.watch<TimetableProvider>();
    final groups = buildMoreFeatureGroups(
      l10n,
      activeProfileName: provider.activeProfile?.name.trim(),
      activeTimeSchemeName: provider.activeTimeScheme?.name,
    );
    // 未展开时永远显示全量（收起时也会清掉 _query，这里再兜一层）。
    final visible = _searchExpanded
        ? filterMoreFeatureGroups(groups, _query, l10n)
        : groups;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeMenuMoreTitle),
      child: HyperosListView(
        children: [
          _buildSearchBar(l10n),
          if (visible.isEmpty)
            HyperosEmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.homeMenuMoreSearchEmptyTitle,
              subtitle: l10n.homeMenuMoreSearchEmptyHint,
            )
          else
            for (final group in visible) ...[
              const HyperosSectionGap(),
              HyperosSettingsBlock(
                title: group.title,
                child: HyperosListGroup(
                  children: [
                    for (final item in group.items) _MoreFeatureRow(item: item),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// 官方 `MiuixSearchBar`：折叠 = 胶囊；展开 = 输入框 + 右侧「取消」。
  ///
  /// 折叠态为什么包 `IgnorePointer` + 透明手势层：官方移动端就这么用
  /// （`miuix_showcase_screen.dart` 的 `_buildHomeSearchBar`）——折叠态搜索框
  /// **不该持有焦点、不该弹键盘**，点它应当进搜索态。胶囊视觉不变，只是不接
  /// 输入。
  Widget _buildSearchBar(AppLocalizations l10n) {
    final bar = MiuixSearchBar(
      expanded: _searchExpanded,
      onExpandedChange: (expanded) {
        if (!expanded) {
          _collapseSearch();
        }
      },
      // 展开时右侧滑入的「取消」（官方 `outsideEndAction` 槽）。
      outsideEndAction: _searchExpanded
          ? GestureDetector(
              onTap: _collapseSearch,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Text(
                  l10n.cancelAction,
                  style: HyperosTypography.listDetail(
                    context,
                  ).copyWith(color: context.theme.colors.primary),
                ),
              ),
            )
          : null,
      // 结果直接长在页面列表里（下方 groups），不再额外挂 content——
      // 让结果与全量列表共用同一套分区样式，展开/收起时不跳版式。
      content: const SizedBox.shrink(),
      // 官方 insideMargin 左右各 12 是给展开时的「取消」让位的。这里两个
      // 状态下都不需要它：折叠态没有尾部按钮；展开态的「取消」自己带 end: 16
      // 内边距。留着它叠上列表左右 16，胶囊会比内容卡窄一圈（用户点过名）。
      insideMargin: EdgeInsets.zero,
      inputField: MiuixInputField(
        query: _query,
        onQueryChange: (value) => setState(() => _query = value),
        onSearch: (_) {},
        expanded: _searchExpanded,
        onExpandedChange: (expanded) {
          if (expanded) {
            _expandSearch();
          }
        },
        label: l10n.homeMenuMoreSearchHint,
      ),
    );
    if (_searchExpanded) {
      return bar;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _expandSearch,
      child: IgnorePointer(child: bar),
    );
  }
}

/// 一个功能条目：**目的地**（整页），不是动作。
///
/// [subtitle] 返回「当前值」而不是描述（AOSP 设置规范：副文本只显示当前
/// 状态）。拿不到值时返回 null，行就退化成单行标题。
class MoreFeatureItem {
  const MoreFeatureItem({
    required this.entry,
    this.subtitle,
    this.keywords = const [],
  });

  /// 目录条目：标题、图标、打开方式全部复用，不维护第二份元数据。
  final HomeMenuEntry entry;

  /// 副文本：当前值（如「晨雾主题」「第 3 套」）。null = 不显示。
  final String? subtitle;

  /// 搜索同义词。AOSP 通用搜索要求索引写「用户会搜、但界面上看不到」的词
  /// （官方举例：搜「静音」能命中「音量」）。中文用户会搜「换肤」「皮肤」
  /// 找外观编辑，这些词标题里一个都没有——不录就等于搜不到。
  final List<String> keywords;
}

/// 一个分区：标题 + 条目。
class MoreFeatureGroup {
  const MoreFeatureGroup({required this.title, required this.items});

  final String title;
  final List<MoreFeatureItem> items;
}

/// 全量索引的构造入口（纯函数，契约测试直接断言）。
///
/// 收录判据见类注释三条。这里**显式列 id** 而不是从候选目录全量推导：
/// 候选池里有 3 条是弹层动作（重新配色/分享课表/切换课表），全量推导会把
/// 它们带进来；而「补一条新页」的操作成本就是加一行——远比一遍遍修
/// 「怎么自动排除动作」便宜。
///
/// 分组顺序 = 用户从「我要动课表」到「我要管理这个 App」的自然顺序。
/// 分组只依赖三个**状态值**，不依赖 [TimetableProvider] 实例本身。
///
/// 这样它能被纯函数测试直接调用（真实 provider 构造要读 shared_preferences，
/// 在测试环境里跑不起来），也让「这一页需要什么数据」变成看得见的三个参数。
List<MoreFeatureGroup> buildMoreFeatureGroups(
  AppLocalizations l10n, {
  String? activeProfileName,
  String? activeTimeSchemeName,
}) {
  final byId = <String, HomeMenuEntry>{
    for (final entry in kHomeMenuCatalog) entry.id: entry,
  };

  /// 按 id 取条目组一个 [MoreFeatureItem]；目录里没有或不可见就跳过。
  MoreFeatureItem? item(
    String id, {
    String? subtitle,
    List<String> keywords = const [],
  }) {
    final entry = byId[id];
    if (entry == null || !entry.visible()) {
      return null;
    }
    return MoreFeatureItem(
      entry: entry,
      subtitle: subtitle,
      keywords: keywords,
    );
  }

  final groups = <MoreFeatureGroup>[
    // ── 课表内容：课程与安排本身 ──────────────────────────────
    MoreFeatureGroup(
      title: l10n.settingsTimetableSectionTitle,
      items: [
        item(
          'overview',
          keywords: const ['课程', '简称', '颜色'],
        ),
        item(
          'profiles',
          subtitle: activeProfileName,
          keywords: const ['多套', '切换', '档案'],
        ),
        item(
          'timeSchemes',
          subtitle: activeTimeSchemeName,
          keywords: const ['作息', '节次', '上下课'],
        ),
        item(
          'locationTimeMatch',
          keywords: const ['楼栋', '教室', '作息'],
        ),
        item(
          'scheduleDateRule',
          keywords: const ['季节', '假期', '换作息'],
        ),
        item('exams', keywords: const ['考试', '倒计时', '成绩']),
        item('tasks', keywords: const ['作业', '待办', '截止']),
        item('scheduleList', keywords: const ['日程', '非课程']),
        item('monthView', keywords: const ['日历', '整月', '哪天']),
        item('pickupCode', keywords: const ['快递', '取件', '包裹']),
      ].whereType<MoreFeatureItem>().toList(growable: false),
    ),

    // ── 课表显示：课表长什么样 ────────────────────────────────
    MoreFeatureGroup(
      title: l10n.settingsDisplayAppearanceSectionTitle,
      items: [
        // 用户点名的那一条：它是「整页微缩的首页预览，直接在上面调壁纸和
        // 材质」，是真·整页目的地，且别处要三层跳转才摸得到。
        item(
          'appearanceEditor',
          // 副文本写「当前值」：主题 seed 是外观编辑页里最常被改的东西。
          // （`themeSeedColor` 非空且带默认值 #3482FF，不存在「未设置」。）
          subtitle: l10n.appearanceEditorEntrySubtitle,
          keywords: const ['换肤', '皮肤', '壁纸', '材质', '主题'],
        ),
        item('appearanceSettings', keywords: const ['主题', '深色', '换肤']),
        item('timetablePageSettings', keywords: const ['格子', '排版']),
        item('courseCardSettings', keywords: const ['课程卡', '字色']),
        item('weatherSettings', keywords: const ['天气', '城市']),
        item('holidaySettings', keywords: const ['调休', '放假']),
      ].whereType<MoreFeatureItem>().toList(growable: false),
    ),

    // ── 提醒与桌面：课表之外的呈现面 ──────────────────────────
    MoreFeatureGroup(
      title: l10n.settingsReminderDesktopSectionTitle,
      items: [
        item('liveSettings', keywords: const ['超级岛', '灵动岛', '通知']),
        item('homeWidgetSettings', keywords: const ['小组件', '桌面']),
      ].whereType<MoreFeatureItem>().toList(growable: false),
    ),

    // ── 应用：App 自身的行为 ──────────────────────────────────
    MoreFeatureGroup(
      title: l10n.settingsAppSectionTitle,
      items: [
        // 「首页与导航」管的就是「首页放哪些入口」，它自己此前不在任何
        // 目录里——用户想改底栏/八宫格必须先摸到设置。这是清点时发现的
        // 第二个盲区。
        item('homeNavigation', keywords: const ['底栏', '八宫格', '菜单']),
        item('generalSettings', keywords: const ['语言', '动画', '触感']),
        item('statisticsSettings', keywords: const ['统计', '算不算']),
      ].whereType<MoreFeatureItem>().toList(growable: false),
    ),

    // ── 数据与共享 ────────────────────────────────────────────
    MoreFeatureGroup(
      title: l10n.settingsDataShareSectionTitle,
      items: [
        item('importCourses', keywords: const ['教务', '表格', 'ics']),
        item('icsExport', keywords: const ['导出', '日历', 'ics']),
        item('dataTransfer', keywords: const ['备份', '恢复', '换机']),
        item('cloudSync', keywords: const ['webdav', '云端']),
        item('lanEdit', keywords: const ['局域网', '电脑']),
        item('coupleTimetable', keywords: const ['情侣', 'ta']),
      ].whereType<MoreFeatureItem>().toList(growable: false),
    ),

    // ── 关于与支持 ────────────────────────────────────────────
    MoreFeatureGroup(
      title: l10n.settingsAboutSectionTitle,
      items: [
        item('aboutApp', keywords: const ['版本', '信息']),
        item('userGuide', keywords: const ['教程', '新手']),
        item('diagnosticsSettings', keywords: const ['日志', '排查', '自检']),
        item('changelog', keywords: const ['更新记录', '版本']),
        item('feedback', keywords: const ['意见', '问题']),
        item('openSourceLicenses', keywords: const ['许可', '开源']),
        item('support', keywords: const ['捐赠', '请喝咖啡']),
      ].whereType<MoreFeatureItem>().toList(growable: false),
    ),
  ];

  // 空分区不渲染（例如诊断包门控之外的条目全被 visible() 挡掉）。
  return [
    for (final group in groups)
      if (group.items.isNotEmpty) group,
  ];
}

/// 按搜索词过滤分区：命中标题、同义词或分区名。
///
/// 同时搜**分区名**（AOSP：搜索必须能搜到分区本身，不只搜叶子条目），
/// 所以输入「数据」会把整个「数据与共享」区露出来。
///
/// [l10n] 显式传入而不是从 context 取：本函数要能被纯函数测试直接调用
/// （同 `buildMoreFeatureGroups`），不依赖 widget 树。
List<MoreFeatureGroup> filterMoreFeatureGroups(
  List<MoreFeatureGroup> groups,
  String rawQuery,
  AppLocalizations l10n,
) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) {
    return groups;
  }
  final result = <MoreFeatureGroup>[];
  for (final group in groups) {
    final groupHit = group.title.toLowerCase().contains(query);
    final hits = groupHit
        ? group.items
        : group.items
              .where(
                (item) =>
                    item.entry.title(l10n).toLowerCase().contains(query) ||
                    item.keywords.any(
                      (keyword) => keyword.toLowerCase().contains(query),
                    ),
              )
              .toList(growable: false);
    if (hits.isNotEmpty) {
      result.add(MoreFeatureGroup(title: group.title, items: hits));
    }
  }
  return result;
}

/// 一行：图标徽章 + 标题 + 「当前值」副文本 + 右箭头。
class _MoreFeatureRow extends StatelessWidget {
  const _MoreFeatureRow({required this.item});

  final MoreFeatureItem item;

  @override
  Widget build(BuildContext context) {
    return HyperosListTile(
      icon: item.entry.icon,
      title: item.entry.title(AppLocalizations.of(context)!),
      // 副文本是「当前值」不是描述：描述在用户已经知道要点什么的时候
      // 只是噪音，而当前值让他不必点进去就知道现状。
      subtitle: item.subtitle,
      onTap: () => item.entry.open(context),
    );
  }
}
