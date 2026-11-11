package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeManagementStrings
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDateTime

/**
 * 面板半独有的**三条类别标签**（概览卡里三个统计格下面那行小字）。
 *
 * 其余文案一律直接用 [MonthViewStrings] 的逐键 accessor（`monthOverview*` /
 * `monthViewAgendaTitle` / `monthViewAgendaAddCourse`），不再自带反查工具 ——
 * 2026-10-27 文案层补了逐键 accessor 之后，「按 key 反查」的小工具就该消失。
 *
 * ## 三条类别标签为什么不在 [MonthViewStrings] 里
 *
 * `MonthViewStrings` 只收 `monthView*` / `monthOverview*` 前缀的 21 条。而 Dart
 * 原件「本月概览」的三个小标签用的是**全局 ARB 键**：
 * `courseCountLabel` / `examBadgeLabel` / `scheduleBadgeLabel`。这里按**同一个 ARB
 * 键**去既有字符串表取原文（日视图与作息页已经各有一份逐字对拍的），不新增文案、
 * 也不写中文字面量。改 ARB 时这三处会一起被对拍测试抓到。
 *
 * ## 星期名同样复用
 *
 * 星期几的短名（`weekdayMon`..`weekdaySun`）走 [MonthText.weekday]，也是全局 ARB 键，
 * 由 `DayViewStrings` 逐字保管，本表不重复收录。
 *
 * > 给下一个改月视图的人：**这两类文案不是漏了，是刻意复用同名的全局 ARB 键**
 * > （`courseCountLabel` / `examBadgeLabel` / `scheduleBadgeLabel` / `weekdayMon`..`weekdaySun`）。
 * > 不往 [MonthViewStrings] 再抄一份，是因为多一份副本就多一处会漂；改 ARB 时这些
 * > 复用点由既有的对拍测试一起兜住（`DayViewStrings` / `TimeSchemeManagementStrings`
 * > 各有一份逐字对拍的用例）。
 */
internal object MonthPanelLabels {

    /** `课程`（ARB `courseCountLabel` —— Dart 原件用的就是这个键）。 */
    val course: String get() = TimeSchemeManagementStrings.courseCountLabel.text

    /** `考试`（ARB `examBadgeLabel`）。 */
    val exam: String get() = DayViewStrings.examBadgeLabel.text

    /** `日程`（ARB `scheduleBadgeLabel`）。 */
    val schedule: String get() = DayViewStrings.scheduleBadgeLabel.text
}

/**
 * 概览与预览行的**行内尺寸**（Dart `month_panel_overview.dart` 里的实测值）。
 *
 * 为什么不在 [MonthMetrics]：那几个是整页栅格常量；这里的是「一张卡内部」的
 * 行内间距与筹码尺寸，Dart 原件也是写在各 widget 里的。集中一处、逐条注明出处，
 * 是为了不让「46 / 11 / 7」这类数字散进布局代码。
 */
internal object MonthOverviewMetrics {

    /** 三个统计格之间的竖线宽度。 */
    const val STAT_DIVIDER_WIDTH = 1.0

    /** 竖线上下的缩进（`_StatDivider` 的 `symmetric(vertical: 6)`）。 */
    const val STAT_DIVIDER_INSET = 6.0

    /** 大数字与其标签之间的间距。 */
    const val STAT_NUMBER_GAP = 4.0

    /** 标签行里图标与文字的间距。 */
    const val STAT_ICON_GAP = 4.0

    /** 统计格的上下内边距。 */
    const val STAT_CELL_INSET = 2.0

    /** 数字行与「有安排 N 天」那条注脚之间。 */
    const val STAT_FOOTNOTE_GAP = 8.0

    /** 注脚图标与文字之间。 */
    const val FOOTNOTE_ICON_GAP = 5.0

    /** 统计格图标尺寸。 */
    const val STAT_ICON_SIZE = 12.0

    /** 注脚图标尺寸。 */
    const val FOOTNOTE_ICON_SIZE = 13.0

    /** 预览行的日期筹码宽度。 */
    const val CHIP_WIDTH = 46.0

    /** 筹码上下内边距。 */
    const val CHIP_VERTICAL = 7.0

    /** 筹码圆角。 */
    const val CHIP_RADIUS = 11.0

    /** 筹码与右侧文字之间。 */
    const val CHIP_GAP = 12.0

    /** 预览行主行与副行之间。 */
    const val ROW_TITLE_GAP = 2.0

    /** 预览行右侧箭头与文字之间。 */
    const val ROW_CHEVRON_GAP = 6.0

    /** 预览行的上下内边距。 */
    const val ROW_VERTICAL = 3.0

    /** 预览行的圆角（点按水波纹范围）。 */
    const val ROW_RADIUS = 10.0

    /** 预览行右侧箭头尺寸。 */
    const val ROW_CHEVRON_SIZE = 18.0

    /** 整月无安排时的空态图标尺寸。 */
    const val EMPTY_ICON_SIZE = 30.0

    /** 空态图标与标题之间。 */
    const val EMPTY_ICON_GAP = 10.0

    /** 空态标题与说明之间。 */
    const val EMPTY_HINT_GAP = 6.0

    /** 非填满模式下最多列几行预览（Dart `maxUpcoming` 的默认值）。 */
    const val FIXED_MAX_UPCOMING = 3
}

/**
 * 月视图下半屏在**没选中日期**时的内容：本月概览 + 本月有安排的日子。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_panel_overview.dart`（2026-10-27
 * 的 789 行那版）。结构是「一列卡，每张卡自带标题」：
 *
 * ```text
 * ┌ 本月概览 ─────────────────┐
 * │ 4 节       0 场      1 条  │
 * │ 有安排 3 天                │
 * └───────────────────────────┘
 * ┌ 本月有安排的日子 ─── 还有 2 天 ┐
 * │ [周五] 10月24日 2节课 · 1个日程 │
 * └───────────────────────────────┘
 * ```
 *
 * ## 填满模式（[fillHeight]）
 *
 * 收起日历后信息区变高，预览列表要**跟着多列几行**，而不是把腾出来的空间留成空白
 * （Dart 旧实现固定 3 行，收起态实测空出 304px = 35.7% 屏高：用户看到的是
 * 「上面收起来了、下面什么也没多给我」）。
 *
 * 实现方式是 `weight(1f)` + [BoxWithConstraints]：拿到「这张卡实际多高」再反算
 * 能列几行（[MonthPanelModel.upcomingSlice]），行数因此随高度自适应。
 * **父级必须给出确定高度**（页面里是 `weight`），否则无界高度下算不出行数。
 *
 * @param grid 当前聚焦月的网格（统计取自它的格子）。
 * @param upcoming 「本月有安排的日子」，顺序由页面按「从今天起轮转」排好
 *   （[MonthPanelModel.scheduledDays]）。
 * @param onDayTap 点一行预览 = 选中那一天。
 * @param fillHeight 是否填满可用高度（页面里恒为 true；组件级预览可关掉）。
 */
@Composable
fun MonthPanelOverview(
    grid: MonthGrid,
    upcoming: List<MonthDayEntry>,
    onDayTap: (LocalDateTime) -> Unit,
    modifier: Modifier = Modifier,
    fillHeight: Boolean = true,
) {
    val counts = MonthPanelModel.overviewCounts(grid)

    Column(modifier = modifier.fillMaxWidth()) {
        MonthPanelCard(title = MonthViewStrings.monthOverviewTitle.text) {
            if (counts.isEmpty) {
                // 整月没有任何安排：只留一块空态，不摆三个 0 ——
                // 「0 节课 / 0 场考试 / 0 个日程」读起来像加载失败。
                MonthEmptyMonthBody()
            } else {
                OverviewStatsBody(counts)
            }
        }

        if (!counts.isEmpty && upcoming.isNotEmpty()) {
            Spacer(Modifier.height(MonthMetrics.ITEM_GAP.dp))
            if (fillHeight) {
                BoxWithConstraints(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = true),
                ) {
                    // 卡高 → 内容区高（扣掉卡壳），再反算能列几行。
                    val slice = MonthPanelModel.upcomingSlice(
                        upcoming = upcoming,
                        contentHeightDp = MonthPanelChrome.contentHeight(maxHeight.value.toDouble()),
                    )
                    // 诊断探针：这段是 `BoxWithConstraints` 的子组合，卡高每变一点就重跑一次。
                    // 拖拽时它跟着帧数长，就说明「收起/展开每帧都在给概览卡重算行数」。
                    SideEffect { MonthScrollProbe.bump(MonthScrollProbe.C_OVERVIEW_SLICE) }
                    UpcomingCard(
                        slice = slice,
                        onDayTap = onDayTap,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            } else {
                // 固定模式（组件级预览 / 没有确定高度的宿主）：最多 3 行，高度按行数给足，
                // 免得容量算法把「正好这么多条」判成放不下。
                val taken = upcoming.take(MonthOverviewMetrics.FIXED_MAX_UPCOMING)
                UpcomingCard(
                    slice = MonthPanelModel.upcomingSlice(
                        upcoming = taken,
                        contentHeightDp = MonthMetrics.UPCOMING_ROW_HEIGHT * taken.size,
                    ),
                    onDayTap = onDayTap,
                )
            }
        }
    }
}

/** 「本月有安排的日子」那张卡（标题右端带「还有 N 天」）。 */
@Composable
private fun UpcomingCard(
    slice: MonthUpcomingSlice,
    onDayTap: (LocalDateTime) -> Unit,
    modifier: Modifier = Modifier,
) {
    val ink = MonthPanelSurface.ink()
    MonthPanelCard(
        title = MonthViewStrings.monthOverviewDaysTitle.text,
        modifier = modifier,
        // 「还有 N 天」放在标题右端：语义从「这是哪一节」变成「这一节还有多少没列」，
        // 信息量增加、高度不增。
        trailing = if (slice.remaining > 0) MonthViewStrings.monthOverviewMoreDays.filled("count", slice.remaining.toString()) else null,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(MonthMetrics.ROW_GAP.dp),
        ) {
            for (entry in slice.shown) {
                UpcomingDayRow(
                    entry = entry,
                    ink = ink,
                    onTap = { onDayTap(entry.date) },
                )
            }
        }
    }
}

/**
 * 「本月有安排的日子」里的**一行**（不是一张卡：卡由 [MonthPanelCard] 提供）。
 *
 * 点它等于选中那一天（下面立刻换成当日议程），所以右侧的箭头与当日议程行的
 * 箭头同一个语义。
 */
@Composable
private fun UpcomingDayRow(
    entry: MonthDayEntry,
    ink: Color,
    onTap: () -> Unit,
) {
    val mutedInk = MonthPanelSurface.muted(ink)
    MonthPanelRow(
        onClick = onTap,
        cornerRadius = MonthOverviewMetrics.ROW_RADIUS.dp,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = MonthOverviewMetrics.ROW_VERTICAL.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // 日期筹码：只放**周几**。
            //
            // ⚠️ 不放日号：右边那行标题已经是「10月19日」，同一个日号在一行里出现
            // 两遍是纯冗余（Dart 旧实现就是这样，读作「19 / 10月19日」说了两遍）。
            Box(
                modifier = Modifier
                    .width(MonthOverviewMetrics.CHIP_WIDTH.dp)
                    .background(
                        color = ink.copy(alpha = MonthInk.FILL.toFloat()),
                        shape = RoundedCornerShape(MonthOverviewMetrics.CHIP_RADIUS.dp),
                    )
                    .padding(vertical = MonthOverviewMetrics.CHIP_VERTICAL.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = MonthText.weekday(entry.date.dayOfWeek.value),
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = if (entry.isHoliday) {
                        MonthPanelAccents.holidayInk()
                    } else {
                        mutedInk
                    },
                    maxLines = 1,
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(Modifier.width(MonthOverviewMetrics.CHIP_GAP.dp))
            Column(modifier = Modifier.weight(1f)) {
                // 主行是**日期**、副行是**事项摘要** —— 与当日议程同一套读取顺序。
                // 一列「接下来几天」里，用户先找的是日子，再问那天有什么。
                Text(
                    text = MonthViewStrings.monthViewAgendaTitle.filled(
                        "month" to entry.date.monthValue.toString(),
                        "day" to entry.date.dayOfMonth.toString(),
                    ),
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(MonthOverviewMetrics.ROW_TITLE_GAP.dp))
                Text(
                    text = upcomingSummary(entry),
                    style = MiuixTheme.textStyles.footnote1,
                    color = mutedInk,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.width(MonthOverviewMetrics.ROW_CHEVRON_GAP.dp))
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = MonthPanelSurface.muted(ink, MonthInk.TERTIARY),
                modifier = Modifier.size(MonthOverviewMetrics.ROW_CHEVRON_SIZE.dp),
            )
        }
    }
}

/** 一行预览的摘要：`2节课 · 1个日程`（三类各自有就列，全空给空串）。 */
private fun upcomingSummary(entry: MonthDayEntry): String {
    val parts = buildList {
        if (entry.courseCount > 0) add(MonthText.courseCount(entry.courseCount))
        if (entry.examCount > 0) add(MonthText.examCount(entry.examCount))
        if (entry.scheduleCount > 0) add(MonthText.scheduleCount(entry.scheduleCount))
    }
    return parts.joinToString(" · ")
}

/** 概览卡的内容：三个数字 + 一行「有安排 N 天」。 */
@Composable
private fun OverviewStatsBody(counts: MonthOverviewCounts) {
    val ink = MonthPanelSurface.ink()
    val mutedInk = MonthPanelSurface.muted(ink)
    val divider = ink.copy(alpha = MonthInk.HAIRLINE.toFloat())
    val cardFill = MonthPanelSurface.fill()

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                // 三个统计格等高：分隔线要撑满这一行，不能靠 VerticalDivider（它在
                // Row 里没有交叉轴约束时高度是 0 —— Dart 旧实现因此一条线都没画出来）。
                .height(IntrinsicSize.Min),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            StatCell(
                value = counts.courseCount,
                label = MonthPanelLabels.course,
                ink = ink,
                mutedInk = mutedInk,
                cardFill = cardFill,
                icon = MiuixIcons.Notes,
                iconColor = MiuixTheme.colorScheme.primary,
                modifier = Modifier.weight(1f),
            )
            StatDivider(divider)
            StatCell(
                value = counts.examCount,
                label = MonthPanelLabels.exam,
                ink = ink,
                mutedInk = mutedInk,
                cardFill = cardFill,
                icon = MiuixIcons.Report,
                iconColor = MonthPanelAccents.examInk(),
                modifier = Modifier.weight(1f),
            )
            StatDivider(divider)
            StatCell(
                value = counts.scheduleCount,
                label = MonthPanelLabels.schedule,
                ink = ink,
                mutedInk = mutedInk,
                cardFill = cardFill,
                icon = MiuixIcons.Alarm,
                iconColor = MonthPanelAccents.scheduleInk(),
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(MonthOverviewMetrics.STAT_FOOTNOTE_GAP.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = MiuixIcons.Ok,
                contentDescription = null,
                tint = MonthPanelSurface.muted(ink, MonthInk.TERTIARY),
                modifier = Modifier.size(MonthOverviewMetrics.FOOTNOTE_ICON_SIZE.dp),
            )
            Spacer(Modifier.width(MonthOverviewMetrics.FOOTNOTE_ICON_GAP.dp))
            Text(
                // 「有安排 N 天」：回答「这个月忙不忙」，但不值得一条横线 + 23dp 竖距。
                text = MonthViewStrings.monthOverviewScheduledDays.filled("count", counts.scheduledDayCount.toString()),
                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = mutedInk,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** 统计格之间的竖线：显式给高，不依赖分隔线组件的交叉轴约束。 */
@Composable
private fun StatDivider(color: Color) {
    Box(
        modifier = Modifier
            .padding(vertical = MonthOverviewMetrics.STAT_DIVIDER_INSET.dp)
            .width(MonthOverviewMetrics.STAT_DIVIDER_WIDTH.dp)
            .fillMaxHeight()
            .background(color),
    )
}

/**
 * 概览卡里的一格：大数字 + 一枚语义色图标 + 小标签。
 *
 * ## 为什么标记是**图标**而不是圆点（Dart 2026-10-22 的结论）
 *
 * 旧实现用三颗 6dp 圆点做图例，配色是主题色 / 固定红 / 固定蓝 —— 逐像素量出来
 * 课程点与日程点的 RGB 只差 (−7, 0, +9)，对比度 **1.013:1**，6dp 上是同一个蓝。
 * 根因是「用颜色承担了全部语义」。用形状（书 / 考卷 / 时钟）区分是免费且不依赖
 * 配色的那一路。
 *
 * ## 为 0 的格子为什么「向卡面混色」而不是压 alpha
 *
 * alpha 一压，数字与卡面的亮度差一起被吃掉：Dart 实测「考试 0」那颗点只剩
 * **1.42:1**，读起来像禁用控件。混色只改颜色、不改不透明度，弱化成度可控。
 */
@Composable
private fun StatCell(
    value: Int,
    label: String,
    ink: Color,
    mutedInk: Color,
    cardFill: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconColor: Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(vertical = MonthOverviewMetrics.STAT_CELL_INSET.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = value.toString(),
            // 18dp = title4：概览数字比月份标题（20）低一级，避免三个统计数字
            // 和「这是哪个月」抢同一层；正文卡片标题仍是 14（body2）。
            style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.BOLD),
            color = if (value == 0) mixToward(ink, cardFill) else ink,
            maxLines = 1,
        )
        Spacer(Modifier.height(MonthOverviewMetrics.STAT_NUMBER_GAP.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (value == 0) mixToward(iconColor, cardFill, 0.5) else iconColor,
                modifier = Modifier.size(MonthOverviewMetrics.STAT_ICON_SIZE.dp),
            )
            Spacer(Modifier.width(MonthOverviewMetrics.STAT_ICON_GAP.dp))
            Text(
                text = label,
                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = mutedInk,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 整月无安排时的空态内容（标题由 [MonthPanelCard] 提供）。
 *
 * 用户口径（Dart 2026-10-21）：「下面信息区域看看怎么丰富一下，目前没有课程的
 * 时候下面就是纯空白」。空态至少要说清「这个月确实没事」并给一个去处。
 */
@Composable
private fun MonthEmptyMonthBody() {
    val ink = MonthPanelSurface.ink()
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = MiuixIcons.Months,
            contentDescription = null,
            tint = MonthPanelSurface.muted(ink, MonthInk.TERTIARY),
            modifier = Modifier.size(MonthOverviewMetrics.EMPTY_ICON_SIZE.dp),
        )
        Spacer(Modifier.height(MonthOverviewMetrics.EMPTY_ICON_GAP.dp))
        Text(
            text = MonthText.emptyMonthTitle.text,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = MonthPanelSurface.muted(ink),
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(MonthOverviewMetrics.EMPTY_HINT_GAP.dp))
        Text(
            text = MonthText.emptyMonthHint.text,
            style = MiuixTheme.textStyles.footnote1,
            color = MonthPanelSurface.muted(ink),
            textAlign = TextAlign.Center,
        )
    }
}

/** 把 [ink] 向 [cardFill] 混色（Dart `dimTowardCard` 的等价物）。 */
internal fun mixToward(ink: Color, cardFill: Color, amount: Double = 0.62): Color {
    val ratio = amount.coerceIn(0.0, 1.0).toFloat()
    return Color(
        red = ink.red * (1 - ratio) + cardFill.red * ratio,
        green = ink.green * (1 - ratio) + cardFill.green * ratio,
        blue = ink.blue * (1 - ratio) + cardFill.blue * ratio,
        alpha = ink.alpha,
    )
}

/**
 * 月视图的三枚类别语义色，全部取 `MiuixTheme.colorScheme` 槽（R5，不再写字面量）。
 *
 * 与 `MonthDayCell.kt` 里的格子色带**同槽同源**（error / primary），
 * 「格子里的考试红」与「议程行的考试红」天然同值；深浅色由主题桥接管。
 * error 不被种子色派生（`QingyuPageTheme` 只触碰 primary 族），考试红不随主题撞色。
 */
internal object MonthPanelAccents {

    /** 考试红：主题 error 槽。 */
    @Composable
    fun examInk(): Color = MiuixTheme.colorScheme.error

    /** 日程蓝：主题 primary，与课程统计图标（同文件 StatCell）同一槽。 */
    @Composable
    fun scheduleInk(): Color = MiuixTheme.colorScheme.primary

    /** 假期红（预览行筹码里的「周五」用）：主题 error 槽。 */
    @Composable
    fun holidayInk(): Color = MiuixTheme.colorScheme.error
}
