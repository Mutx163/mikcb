import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../utils/month_cell_ink.dart';
import '../day_view/day_view_agenda_surface.dart';
import 'month_day_agenda.dart';
import 'month_day_cell.dart';
import 'month_metrics.dart';
import 'month_panel_surface.dart';

/// 月视图下半屏在**没选中日期**时的内容：本月概览 + 本月有安排的日子。
///
/// ## 2026-10-23 第二轮：标题也进卡、卡一律实底
///
/// 用户对着真机截图说「整体看起来非常诡异」。拆出来三条，两条在这一层：
///
/// 1. **小标题浮在壁纸上**（「本月概览」「本月有安排的日子」）。用户那张壁纸是
///    高饱和彩色斜带，深色小标题压在上面像散落的碎字，找不到归属 —— 现在它们
///    与内容**同在一张卡里**（卡内第一行），信息块因此有明确的边界。
/// 2. **卡片是玻璃的**。上一轮为了"跟课程卡材质走"去掉了 `forceSolid`，
///    卡片半透明、把满屏彩色壁纸透出来，读起来是"一块模糊的洞"而不是卡。
///    现在一律实底白（`forceSolid: true`），与上半那张日历卡同一档。
///
/// 结构因此变成「一列卡」，每张卡自带标题：
///
/// ```text
/// ┌ 本月概览 ─────────────────┐
/// │ 4 节       0 场      1 条  │
/// │ 有安排 3 天                │
/// └───────────────────────────┘
/// ┌ 本月有安排的日子 ─── 还有 2 天 ┐
/// │ [24 周五] 2 节课 · 1 条日程     │
/// └───────────────────────────────┘
/// ```
///
/// ## 为什么需要它（2026-10-21）
///
/// 用户口径：「下面信息区域，看看怎么丰富一下，目前没有课程的时候，下面就是
/// 纯空白」，同时要求删掉原来那句「点任意一天查看安排」。旧实现只有一句话：
/// 既没告诉用户这个月有多少事，也没提供任何去处。
///
/// ## 为什么统计数字来自 [MonthGridData.overview]
///
/// 这里是**渲染层**，拿不到 provider 的原始集合（那是页面的事），而网格数据
/// 已经跟着 build 一起传进来了。把月度累加放在域层（[MonthViewLogic]）而不是
/// 在这里 `for` 一遍 42 格：①补位格的排除规则只有一处；②缓存命中时不必再扫；
/// ③纯 Dart 可单测。
class MonthPanelOverview extends StatelessWidget {
  const MonthPanelOverview({
    super.key,
    required this.grid,
    required this.upcoming,
    required this.settings,
    required this.onDayTap,
    this.maxUpcoming = 3,
    this.radius = MonthMetrics.cardRadius,
    this.fillHeight = false,
  });

  /// 当前聚焦月的网格数据（统计取自它的 `overview`）。
  final MonthGridData grid;

  /// 「本月有安排的日子」预览（顺序由调用方按"从今天往后"排好，
  /// 见 [MonthViewLogic.scheduledDaysOfMonth]）。
  final List<MonthDayEntry> upcoming;

  final TimetableSettings settings;

  /// 点一行预览 = 选中那一天。
  final ValueChanged<DateTime> onDayTap;

  final double radius;

  /// 预览行最多几行（超出的部分在标题右端给一条「还有 N 天」交代）。
  ///
  /// 5 → 3（2026-10-22）：展开态信息区只有 390dp，5 行里只有 2 行完整可见。
  /// 为了"丰富"而塞进去的内容用户根本看不到，反倒把空白留在更下面。
  ///
  /// ⚠️ [fillHeight] 为 true 时**这个值不生效** —— 行数改由可用高度算出来
  /// （见 [fillHeight]）。它只服务"给不出确定高度"的调用方（组件级测试、
  /// 以及任何还没改成填满模式的宿主）。
  final int maxUpcoming;

  /// 是否**填满可用高度**：true 时这一列卡吃掉父级给的高度，其中
  /// 「本月有安排的日子」那张卡按**真实剩余高度**决定列几行。
  ///
  /// ## 为什么需要它（2026-10-25）
  ///
  /// 旧实现固定列 [maxUpcoming] = 3 行，而信息区高度是变的：把日历收起成
  /// 一行后，信息区从 429dp 涨到 652dp，可列表还是只画 3 行 —— 真机实测
  /// 内容之下空出 **304px（35.7% 屏高）**。用户看到的是"上面收起来了，
  /// 下面却没多给我任何东西"，那块空白正是他说"难受"的第二个来源。
  ///
  /// 现在收起多少就多列多少行：空间真的被用起来。
  ///
  /// ⚠️ 为 true 时**父级必须给确定高度**（`Expanded` / `SizedBox(height:)`）——
  /// 里面的 `Expanded` 在无界高度下会直接抛。
  final bool fillHeight;

  /// 按可用高度算能列几行（[fillHeight] 模式下用）。
  ///
  /// 判据是**行高**而不是"猜一个行数"：一行 = [MonthMetrics.upcomingRowHeight]，
  /// 行与行之间还有 [MonthMetrics.rowGap]。所以 n 行占
  /// `n * rowHeight + (n-1) * rowGap`，反推就是下面的式子。
  ///
  /// 下限 0（**不是 1**）、上限是真实条数。
  ///
  /// ## 为什么下限是 0（2026-10-27 实测）
  ///
  /// 这里算的是"内容区还剩多高"。剩余高度小于一整行时，一行也放不下 ——
  /// 硬给 1 行就是让卡片**画在自己外面**：`_InfoCard` 会被撑破跑到下一张卡
  /// 上面（矮窗口里实测到 44dp 的一行挤在 32dp 的空间里）。
  ///
  /// 那种情况更该发生在**上一步**：`month_grid_collapse.dart` 里
  /// [kMonthPanelMinHeight] 保证信息区至少有 `title + 1 行` 的高度，剩余高度
  /// 到不了 0。所以 0 只是"极端尺寸下的诚实答案"（列 0 行，卡片只剩标题），
  /// 不是常规路径 —— 常规路径由下面那条单调性测试钉住。
  @visibleForTesting
  static int rowsThatFit(double availableHeight, int total) {
    if (total <= 0) {
      return 0;
    }
    const unit = MonthMetrics.upcomingRowHeight + MonthMetrics.rowGap;
    final n = ((availableHeight + MonthMetrics.rowGap) / unit).floor();
    return n.clamp(0, total);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardInk = monthInfoCardInk(
      context: context,
      settings: settings,
      cardFill: monthInfoCardFill(context),
    );
    final overview = grid.overview;

    // 整月没有任何安排：只留一块空态，不摆三个 0 —— "0 节课 / 0 场考试 /
    // 0 个日程"读起来像加载失败，而不是"这个月确实没事"。
    if (overview.isEmpty) {
      return _InfoCard(
        settings: settings,
        radius: radius,
        ink: cardInk,
        title: l10n.monthOverviewTitle,
        child: _EmptyMonthBody(
          title: l10n.monthViewEmptyMonthTitle,
          hint: l10n.monthViewEmptyMonthHint,
          ink: cardInk,
        ),
      );
    }

    final days = upcoming.take(maxUpcoming).toList();
    final remaining = upcoming.length - days.length;

    // ② 那张卡：标题 + 若干行。两种模式下**只有"列几行"的来源不同**，
    // 内容与样式必须共用同一份构造，否则两处会漂。
    Widget upcomingCard({required List<MonthDayEntry> rows, int? more}) =>
        _InfoCard(
          settings: settings,
          radius: radius,
          ink: cardInk,
          title: l10n.monthOverviewDaysTitle,
          // 「还有 N 天」放在标题右端：语义从"这是哪一节"变成"这一节还有
          // 多少没列"，信息量增加、高度不增。
          trailing: (more ?? 0) > 0 ? l10n.monthOverviewMoreDays(more!) : null,
          trailingInk: cardInk.withValues(alpha: MonthInk.tertiary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: MonthMetrics.rowGap),
                _UpcomingDayRow(
                  entry: rows[i],
                  inkColor: cardInk,
                  onTap: () => onDayTap(rows[i].date),
                ),
              ],
            ],
          ),
        );

    // ── 填满模式：概览卡自然高、下面那张卡吃掉剩余高度，行数由卡内算 ──
    if (fillHeight) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoCard(
            settings: settings,
            radius: radius,
            ink: cardInk,
            title: l10n.monthOverviewTitle,
            child: _StatsBody(
              overview: overview,
              ink: cardInk,
              scheduledDaysLabel: l10n.monthOverviewScheduledDays(
                overview.scheduledDayCount,
              ),
            ),
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: MonthMetrics.itemGap),
            // ⚠️ Expanded 是这套"收起后多列几行"的全部机制：卡片拿到真实
            // 剩余高度，这里才能算出确切能放几行。
            //
            // 行数 = 卡高 − [_InfoCard.fillChrome]（卡自己的内边距 + 标题行 +
            // 标题与内容之间那段）。这个常数与 `_InfoCard` 的实现是**一处定义、
            // 两处消费**，漂开就会溢出或留白 —— `month_panel_style_test.dart`
            // 里那条"多档高度都不溢出、且行数随高度单调不减"就是防它漂的。
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rows = rowsThatFit(
                    constraints.maxHeight - _InfoCard.fillChrome,
                    upcoming.length,
                  );
                  final shown = upcoming.take(rows).toList();
                  return upcomingCard(
                    rows: shown,
                    more: upcoming.length - shown.length,
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ① 本月概览（标题在卡内）
        _InfoCard(
          settings: settings,
          radius: radius,
          ink: cardInk,
          title: l10n.monthOverviewTitle,
          child: _StatsBody(
            overview: overview,
            ink: cardInk,
            scheduledDaysLabel: l10n.monthOverviewScheduledDays(
              overview.scheduledDayCount,
            ),
          ),
        ),
        // ② 本月有安排的日子（同样是一张带标题的卡）
        if (days.isNotEmpty) ...[
          const SizedBox(height: MonthMetrics.itemGap),
          upcomingCard(rows: days, more: remaining),
        ],
      ],
    );
  }
}

/// 信息区的**通用卡壳**：实底白卡 + 卡内标题（+ 可选右端附属信息）+ 内容。
///
/// 把"标题 + 内容"收进同一张卡是这一轮的核心结构改动：标题浮在壁纸上时，
/// 用户在高饱和壁纸上读到的是一段找不到归属的碎字（2026-10-23 真机截图）。
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.settings,
    required this.radius,
    required this.ink,
    required this.title,
    required this.child,
    this.trailing,
    this.trailingInk,
  });

  final TimetableSettings settings;
  final double radius;
  final Color ink;
  final String title;
  final Widget child;
  final String? trailing;
  final Color? trailingInk;

  /// 卡内**上下内边距**（单边）。
  static const double padVertical = 13;

  /// 标题行与内容之间那段间距。
  static const double titleGap = 10;

  /// 标题行的行高：`MonthType.title`（15）按默认行高系数约 1.33 取整。
  ///
  /// 写成常数而不是 `MonthType.title * 1.33`：字号一改这里要跟着重算，
  /// 而"重算"这个动作必须看得见 —— 乘出来的浮点值会掩盖"标题换档了"。
  static const double titleLineHeight = 20;

  /// 卡片**内部**不属于内容的高度 = 上下内边距 + 标题行 + 标题与内容之间。
  ///
  /// ## 这个常量是给"按卡高反推能放几行"用的
  ///
  /// [MonthPanelOverview] 的填满模式要在建卡之前就知道内容区有多高，只能
  /// 拿卡高减掉它。所以**它必须与下面 `build` 里那几处真实占位同源**：
  /// `Padding` 用的是 [padVertical]、标题与内容之间用的是 [titleGap]。
  /// 三处一起改，否则行数会算多（`RenderFlex overflowed`）或算少（留白）。
  ///
  /// 防漂的手段是测试而不是注释：`month_panel_style_test.dart` 里那条
  /// 「多档高度都不溢出、且行数随高度单调不减」会在漂开时立刻红。
  static const double fillChrome = padVertical * 2 + titleLineHeight + titleGap;

  @override
  Widget build(BuildContext context) {
    return DayViewAgendaSurface(
      settings: settings,
      color: monthInfoCardFill(context),
      radius: radius,
      // 实底：玻璃会把屏级壁纸透进卡里，读成"一块模糊的洞"
      //（2026-10-23 真机截图，与 MonthDayAgenda 同一决定）。
      forceSolid: true,
      // ── 溢出兜底：卡被塞得比自己的内容还矮时**裁掉**，不要抛 ──
      //
      // 正常高度下这条兜底不生效：行数由 `rowsThatFit` 反算，内容本来就塞得下。
      // 但它挡的是"算不到的高度"——矮窗口（800×600 的测试视口就是）、横屏 /
      // 分屏、超大字号、玻璃坞给你扣掉的底部余量。这些情况下 `RenderFlex`
      // 会当场抛 `overflowed by N pixels` 并让整棵子树红屏，而这只是"最后
      // 一行被截了一点"，不值得整页崩掉。
      //
      // 口径与 `month_grid_collapse.dart` 里那条一致：宁可裁，不许溢出。
      // 两个容器的分工交给 [_TopClipOverflow]：高度有界时放开约束让里层按
      // 自然高排完、再裁在卡片圆角里；高度无界时按自然高排（无处可溢出）。
      child: _TopClipOverflow(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, padVertical, 14, padVertical),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: MonthType.title,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        trailing!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: MonthType.caption,
                          fontWeight: FontWeight.w500,
                          color:
                              trailingInk ??
                              ink.withValues(alpha: MonthInk.tertiary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: titleGap),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 「按自然高排完，再把超出卡片的那部分裁掉」。
///
/// ## 为什么不是一个裸 [OverflowBox]（2026-10-27 实测）
///
/// `OverflowBox(maxHeight: double.infinity)` 的收益是"父级给多高都不抛
/// `RenderFlex overflowed`"，代价是**它自己也要求父级给出有界高度**：
///
/// * 有界（线上路径：信息区被 `Expanded` 塞进确定的 390 / 652dp）——
///   放开高度给里层，里层按自然高排，`ClipRect` 裁掉露出来的那几像素；
/// * 无界（组件级测试、`SingleChildScrollView`、任何"多高都行"的宿主）——
///   `OverflowBox` 会把**无穷大当成自己的目标尺寸**，`performResize` 当场
///   抛 `RenderConstrainedOverflowBox ... infinite size during layout`。
///
/// 所以这里先问 [BoxConstraints.hasBoundedHeight]：无界时**不做任何放开**，
/// 直接把 child 交出去 —— 父级没给高度，就没有"溢出"这回事，自然高就是正解。
class _TopClipOverflow extends StatelessWidget {
  const _TopClipOverflow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) {
            return child;
          }
          return OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: child,
          );
        },
      ),
    );
  }
}

/// 概览卡的内容：三个数字 + 一行「有安排 N 天」。
class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.overview,
    required this.ink,
    required this.scheduledDaysLabel,
  });

  final MonthOverviewStats overview;
  final Color ink;
  final String scheduledDaysLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mutedInk = ink.withValues(alpha: MonthInk.secondary);
    final divider = ink.withValues(alpha: MonthInk.hairline);
    final cardFill = monthInfoCardFill(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 三个统计格。分隔线**必须自带高度**：`VerticalDivider` 在 Row 里没有
        // 交叉轴约束时高度是 0，旧实现因此一条线都没画出来。
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatCell(
                value: overview.courseCount,
                label: l10n.courseCountLabel,
                ink: ink,
                mutedInk: mutedInk,
                cardFill: cardFill,
                // 课程用课程卡同族的强调色，让"这是课"与另外两栏可分。
                markIcon: Icons.menu_book_rounded,
                markColor: Theme.of(context).colorScheme.primary,
              ),
              _StatDivider(color: divider),
              _StatCell(
                value: overview.examCount,
                label: l10n.examBadgeLabel,
                ink: ink,
                mutedInk: mutedInk,
                cardFill: cardFill,
                markIcon: Icons.assignment_rounded,
                markColor: monthExamAccent(Theme.of(context).colorScheme),
              ),
              _StatDivider(color: divider),
              _StatCell(
                value: overview.scheduleCount,
                label: l10n.scheduleBadgeLabel,
                ink: ink,
                mutedInk: mutedInk,
                cardFill: cardFill,
                markIcon: Icons.schedule_rounded,
                markColor: monthScheduleDotColor(Theme.of(context).colorScheme),
              ),
            ],
          ),
        ),
        // 「有安排 N 天」并入数字行下方的一条紧凑注脚：这条信息本身要留
        // （它回答"这个月忙不忙"），但不值得一条横线 + 23dp 的竖距。
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 13,
              color: ink.withValues(alpha: MonthInk.tertiary),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                scheduledDaysLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: MonthType.caption,
                  fontWeight: FontWeight.w500,
                  color: mutedInk,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 统计格之间的竖线：显式给高，不依赖 `VerticalDivider` 的交叉轴约束。
class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(width: 1, child: ColoredBox(color: color)),
    );
  }
}

/// 概览卡里的一格：大数字 + 小标签 + 一枚语义色图标。
///
/// ## 为什么标记从「圆点」换成「图标」（2026-10-22）
///
/// 旧实现的图例是**三颗 6dp 圆点**，配色分别是 `colorScheme.primary`、
/// 固定红、固定蓝。逐像素量出来：课程点和日程点的 RGB 只差 `(−7, 0, +9)`，
/// 对比度 **1.013:1** —— 两颗色相几乎相同的点在 6dp 尺寸下是同一个蓝。
///
/// 根因在于**用颜色承担了全部语义**，而颜色又被主题色绑住。三列本来就有明确的
/// 类别名，用**形状**区分是免费且不依赖配色的那一路：书 / 考卷 / 时钟。
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.ink,
    required this.mutedInk,
    required this.markIcon,
    required this.markColor,
    required this.cardFill,
  });

  final int value;
  final String label;
  final Color ink;
  final Color mutedInk;

  /// 类别图标（形状即语义，不依赖配色可辨）。
  final IconData markIcon;

  /// 图标颜色（与网格里该类标记同源）。
  final Color markColor;

  /// 概览卡的底色：为 0 的格子要**向它混色**来弱化（不压 alpha）。
  final Color cardFill;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              maxLines: 1,
              style: TextStyle(
                fontSize: MonthType.display,
                height: 1.1,
                fontWeight: FontWeight.w700,
                // 0 弱化：一栏里对比出来"这个月没考试"比三行等重的数字好读。
                //
                // ⚠️ 弱化手段是**向卡面混色**（不透明灰），不是乘 alpha。
                // alpha 一压，数字与卡面的亮度差一起被吃掉：旧实现里图例那颗
                // 「考试 0」的圆点只剩 **1.42:1**，读起来像禁用控件。
                color: value == 0 ? dimTowardCard(ink, cardFill) : ink,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  markIcon,
                  size: 12,
                  // 为 0 时向卡面混色、比例比数字更轻（0.5）：图标是辅助线索，
                  // 淡下去仍然靠形状可辨，而数字淡过头就读不出来了。
                  color: value == 0
                      ? dimTowardCard(markColor, cardFill, amount: 0.5)
                      : markColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MonthType.caption,
                      fontWeight: FontWeight.w500,
                      color: mutedInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 「本月有安排的日子」里的**一行**（不是一张卡：卡由 [_InfoCard] 提供）。
///
/// 点它等于选中那一天（下面立刻换成当日议程），所以右侧的箭头与当日议程行
/// 的箭头同一个语义。
class _UpcomingDayRow extends StatelessWidget {
  const _UpcomingDayRow({
    required this.entry,
    required this.inkColor,
    required this.onTap,
  });

  final MonthDayEntry entry;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final ink = inkColor;
    final mutedInk = ink.withValues(alpha: MonthInk.secondary);

    final parts = <String>[
      if (entry.courseCount > 0)
        l10n.monthViewCourseCountSemantics(entry.courseCount),
      if (entry.examCount > 0)
        l10n.monthViewExamCountSemantics(entry.examCount),
      if (entry.scheduleCount > 0)
        l10n.monthViewScheduleCountSemantics(entry.scheduleCount),
    ];

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              // 日期筹码：只放**周几**。
              //
              // ⚠️ 不放日号：右边那行标题已经是「10月19日」，同一个日号在一行
              // 里出现两遍是纯冗余（旧实现就是这样，读作"19 / 10月19日"说了
              // 两遍）。日号由标题承担，筹码只补标题里没有的"周几"。
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  // 与卡片同色时这块会消失；用墨色 6% 让它读作"日期筹码"。
                  color: ink.withValues(alpha: MonthInk.fill),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _weekdayLabel(l10n, entry.date.weekday),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MonthType.caption,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: entry.isHoliday
                        ? monthHolidayInk(colorScheme)
                        : mutedInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 主行是**日期**、副行是**事项摘要** —— 与当日议程同一套读取
                    // 顺序（那边也是「10月24日」当标题）。一列"接下来几天"里，
                    // 用户先找的是日子，再问那天有什么。
                    //
                    // 这个日期文本也是**可点入口的可读标签**（测试与无障碍都按它
                    // 找目标），不要为了紧凑把它并进下面的摘要。
                    Text(
                      l10n.monthViewAgendaTitle(
                        entry.date.month,
                        entry.date.day,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: MonthType.title,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: MonthType.body,
                        color: mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ink.withValues(alpha: MonthInk.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 整月无安排时的空态内容（标题由 [_InfoCard] 提供）。
class _EmptyMonthBody extends StatelessWidget {
  const _EmptyMonthBody({
    required this.title,
    required this.hint,
    required this.ink,
  });

  final String title;
  final String hint;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final mutedInk = ink.withValues(alpha: MonthInk.secondary);
    return Column(
      children: [
        Icon(
          Icons.calendar_month_outlined,
          size: 30,
          color: ink.withValues(alpha: MonthInk.tertiary),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: MonthType.title,
            fontWeight: FontWeight.w600,
            color: ink.withValues(alpha: MonthInk.secondary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: MonthType.body, color: mutedInk),
        ),
      ],
    );
  }
}

/// 星期几（1 = 周一）。与网格表头同一批 l10n 文案，不另写一套。
String _weekdayLabel(AppLocalizations l10n, int weekday) {
  return switch (weekday) {
    DateTime.monday => l10n.weekdayMon,
    DateTime.tuesday => l10n.weekdayTue,
    DateTime.wednesday => l10n.weekdayWed,
    DateTime.thursday => l10n.weekdayThu,
    DateTime.friday => l10n.weekdayFri,
    DateTime.saturday => l10n.weekdaySat,
    _ => l10n.weekdaySun,
  };
}
