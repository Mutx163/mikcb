package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDateTime

/**
 * 月历网格：星期表头 + 4~6 行 × 7 列日期格 + 每行学期周次行标。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_grid.dart`（2026-10-27 快照）。
 *
 * ## 数据恒 42 格，只画需要的行数
 *
 * [MonthGrid.weeks] 恒 6 行（翻月时网格不重建、行数不跳变），但尾部整行都是
 * 邻月补位格时不画 —— 判据在 [MonthGrid.rowsInMonth]（2026-10-25 用户口径：
 * 「永远六行」的代价是约一半月份尾部多一整行灰数字，白占 ~45dp）。
 *
 * ## 收起 / 拖拽
 *
 * 收起是**裁剪 + 平移**而不是隐藏行：表头固定，只裁剪平移行区 —— Dart
 * 2026-10-21 实测过：把表头一起平移，收起后会露出半格上一行、表头也不见了。
 * 本组件接收两个量：[visibleRows]（窗口行数，**含小数**，收起时≈1）与 [rowOffset]
 * （内容上移量），页面每帧改这两个参数即可。
 *
 * ⚠️ 与 Dart 的唯一差别：Dart 的 42 格**始终在树上**，是为了保住 `InkWell`
 * 的按压状态与 widget key；Compose 这边的格子是**无状态**的（选中/今天都由
 * 参数驱动），所以收起态只组出可见的那几行，展开时重建不丢任何交互状态。
 * 需要「行数恒定」的是**外部卡片高度账**（见 [MonthCalendarChrome]），不是树形。
 *
 * 墨色按**卡面**（主题）判，不按壁纸 —— 整块网格躺在一张不透明白卡里。
 */
@Composable
fun MonthGrid(
    grid: MonthGrid,
    today: LocalDateTime,
    selectedDate: LocalDateTime?,
    onDayTap: (LocalDateTime) -> Unit,
    rowHeight: Dp,
    modifier: Modifier = Modifier,
    /** 窗口露几行（**含小数**：拖拽时直线插值，收起态≈1）。**在测量阶段才读**（见 [heightDeferred]）。 */
    visibleRows: () -> Float = { grid.rowsInMonth.toFloat() },
    /**
     * 内容上移量（收起时把保留行顶到窗口顶端）。**在绘制阶段才读**（`graphicsLayer` lambda）。
     *
     * 这两个量都是拖拽进度的函数；写成普通参数会让页面每帧重组（并把版面账重算一遍），
     * 改成 lambda 后进度变化只让测量的那几层重新测量 / 重放绘图层，数值不变。
     */
    rowOffset: () -> Dp = { 0.dp },
    /** 是否画 24dp 的星期表头；嵌入 c1.week 时为 false（顶部带已经画了）。 */
    showHeader: Boolean = true,
    /** 是否无论有没有周次都保留 40dp 竖槽（嵌入态给顶部角格的月份用同一条列）。 */
    reserveRail: Boolean = false,
    showWeekNumbers: Boolean = true,
) {
    // 诊断探针：拖拽时这一层应为 0 次（42 格的状态都由参数驱动，不该每帧重组）。
    SideEffect { MonthScrollProbe.bump(MonthScrollProbe.C_GRID_COMPOSE) }

    val dark = isSystemInDarkThemeSafe()
    // 表头与周次轨：压在白卡上，跟主题走。
    //
    // 2026-11-07：七列**统一一色**。旧实现工作日用 `actionIcon`（40% 黑，亮色下
    // 正好等于 #999999），周末用 `secondaryText`（也是 #999999）——所谓「周末重
    // 一档」在亮色下根本没有发生；而且周末比工作日更重，与「周一为列首」的扫读
    // 锚点无关。现在统一用 SECONDARY（亮色约 5.7:1），11sp 小字也达标。
    val headerInk = Color(QingyuTheme.primaryText(dark))
        .copy(alpha = MonthInk.SECONDARY.toFloat())
    // 周次轨是索引，不是内容：比表头再降一档（11sp 约 3.2:1），
    // 并在它右侧画一条 12% 的细线，把“周次”与 7 列日期分开。
    val railInk = Color(QingyuTheme.primaryText(dark))
        .copy(alpha = MonthInk.TERTIARY.toFloat())
    val railRule = headerInk.copy(alpha = 0.18f)

    // 周次行标列：嵌入态强制保留（顶部角格的月份与周次共用同一条列）；
    // 普通页面仍按“有周次才占位”收列。
    val weekNumberColumnVisible = reserveRail ||
        (showWeekNumbers && grid.days.any { it.weekIndex != null })
    val todayDay = dayOnly(today)
    val selectedDay = selectedDate?.let { dayOnly(it) }

    val rootModifier = if (weekNumberColumnVisible) {
        modifier.fillMaxWidth().drawBehind {
            val x = MonthGridMetrics.WEEK_LABEL_WIDTH.dp.toPx()
            drawLine(
                color = railRule,
                start = Offset(x, 0f),
                end = Offset(x, size.height),
                strokeWidth = 1f,
            )
        }
    } else {
        modifier.fillMaxWidth()
    }

    // 诊断探针：只数「这一页网格画了几次」。非诊断包不挂这一层，正式包的绘制链不变。
    val probedModifier = if (MonthScrollProbe.enabled) {
        rootModifier.drawWithContent {
            MonthScrollProbe.bump(MonthScrollProbe.C_GRID_DRAW)
            drawContent()
        }
    } else {
        rootModifier
    }

    Column(modifier = probedModifier) {
        // 表头：钉在固定高度（与页面行高预算、裁剪窗口上沿同一个数）。
        if (showHeader) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(MonthGridMetrics.HEADER_HEIGHT.dp),
        ) {
            if (weekNumberColumnVisible) {
                Spacer(modifier = Modifier.width(MonthGridMetrics.WEEK_LABEL_WIDTH.dp))
            }
            for (dayOfWeek in 1..MonthGridModel.DAYS_PER_ROW) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = MonthText.weekday(dayOfWeek),
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = headerInk,
                        maxLines = 1,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(bottom = 6.dp),
                    )
                }
            }
        }
        }

        // 行区：表头固定，只裁剪平移这一块。
        //
        // 复刻 Dart `month_grid.dart`（ClipRect + SizedBox(visibleRows×rowHeight) +
        // OverflowBox(maxHeight=∞) + Transform.translate）：
        //  * 外层 Box 高度 = **窗口**高度（visibleRows 行，含小数 ⇒ 拖拽连续）；
        //  * 内层 Column 用 `requiredHeight(全部行)` **无视父级窗口约束**、按全部行满高
        //    布局，再整体上移 rowOffset，只靠外层 clip 露窗口那几行。
        //
        // ⚠️ 之前内层 Column 被父级高度约束（`Modifier.height` 会被窗口压回去），
        // 收起时 `offset(-rowOffset)` 把整块内容推出窗口 ⇒ **一行都不剩**——这就是
        // 「上滑收起后日期表格消失」的根因（keptRow>0 时必现）。用 requiredHeight 兜住，
        // 与 Dart 的 OverflowBox 同义。
        val windowRows = { visibleRows().coerceIn(1f, grid.rowsInMonth.toFloat()) }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                // 高度在**测量阶段**才读进度（见 [heightDeferred]）：拖拽时只重测这一层。
                .heightDeferred { rowHeight * windowRows() }
                .clipToBounds(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .requiredHeight(rowHeight * grid.rowsInMonth)
                    // 平移用 graphicsLayer（绘制期变换，不触发子项重新测量/布局）：
                    // 每帧只改这一个平移量，42 格不必逐帧重排；位移量同样在**绘制阶段**才读。
                    .graphicsLayer { translationY = -rowOffset().toPx() },
            ) {
                for (row in 0 until grid.rowsInMonth) {
                    MonthWeekRow(
                        week = grid.weeks[row],
                        weekNumberColumnVisible = weekNumberColumnVisible,
                        showWeekNumbers = showWeekNumbers,
                        headerInk = headerInk,
                        railInk = railInk,
                        isDark = dark,
                        rowHeight = rowHeight,
                        today = todayDay,
                        selectedDate = selectedDay,
                        onDayTap = onDayTap,
                    )
                }
            }
        }
    }
}

/** 一行 7 格（含左侧周次行标）。 */
@Composable
private fun MonthWeekRow(
    week: MonthWeek,
    weekNumberColumnVisible: Boolean,
    showWeekNumbers: Boolean,
    headerInk: Color,
    railInk: Color,
    isDark: Boolean,
    rowHeight: Dp,
    today: LocalDateTime,
    selectedDate: LocalDateTime?,
    onDayTap: (LocalDateTime) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(rowHeight),
    ) {
        if (weekNumberColumnVisible) {
            Box(
                modifier = Modifier
                    .width(MonthGridMetrics.WEEK_LABEL_WIDTH.dp)
                    .fillMaxHeight(),
                contentAlignment = Alignment.Center,
            ) {
                // 行标取**行内首个落在本月的日期**的周次；整行都在月外（首末行常见）
                // 时取行首那天的周次，仍能标出「这行属于第几周」。
                val anchor = week.days.firstOrNull { !it.isOutsideMonth } ?: week.days.firstOrNull()
                val weekIndex = anchor?.weekIndex
                if (showWeekNumbers && weekIndex != null) {
                    WeekRailLabel(
                        text = MonthText.weekRail(weekIndex.toInt()),
                        color = railInk,
                    )
                }
            }
        }
        for (day in week.days) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
            ) {
                MonthDayCell(
                    entry = day,
                    isToday = day.date == today,
                    isSelected = selectedDate != null && day.date == selectedDate,
                    onTap = { onDayTap(day.date) },
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}

/**
 * 周次轨：「第 17 周」必须压进 40dp 一行。
 *
 * 40dp 去掉右侧留白只剩 ~36dp，而「第 17 周」在 11sp 中文下约 44dp ——
 * Dart 用 `FittedBox(scaleDown)` 兜底。Compose 对应做法：先按**无界宽度**
 * 量一次，超宽就按比例缩放绘制（不折行、不省略）。
 */
@Composable
private fun WeekRailLabel(
    text: String,
    color: Color,
) {
    var scale by remember(text) { mutableFloatStateOf(1f) }
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .padding(end = 4.dp)
            // 与日号共享光学中心：日号下面恒有 8dp 标记槽，整块内容因此上移 4dp；
            // 周次轨也补同样的底边距，才不会被读成「比日号低一行」。
            .padding(bottom = MonthMetrics.CELL_MARK_SLOT_HEIGHT.dp),
        contentAlignment = Alignment.Center,
    ) {
        val maxWidthPx = constraints.maxWidth.toFloat()
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = color,
            maxLines = 1,
            softWrap = false,
            textAlign = TextAlign.Center,
            onTextLayout = { result ->
                val measured = result.size.width.toFloat()
                val next = if (maxWidthPx > 0f && measured > maxWidthPx) {
                    (maxWidthPx / measured).coerceIn(0.6f, 1f)
                } else {
                    1f
                }
                if (next != scale) scale = next
            },
            modifier = Modifier
                .wrapContentWidth(unbounded = true)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
        )
    }
}

/**
 * 顶部玻璃带里的月视图星期栏：只画 7 列周一…周日，左侧 40dp 角格留空，
 * 与月网格的「40dp 周次槽 + 7 列」严格对齐。
 *
 * 月份标题已上提到顶栏（与「轻屿课表」同一位置），所以角格不再放月份；
 * 这里只负责列头。字色按壁纸明暗自适应，避免深色壁纸上黑字看不见。
 */
@Composable
fun MonthWeekdayHeader(
    wallpaperLuminance: Double? = null,
    configuredInkArgb: Int? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkThemeSafe()
    val ink = Color(
        HomeBackgroundModel.inkOverWallpaperArgb(
            configuredArgb = configuredInkArgb,
            fallbackArgb = MiuixTheme.colorScheme.onSurface.toArgb(),
            wallpaperLuminance = wallpaperLuminance,
            builtInDefaultArgb = if (dark) 0xFFFFFFFF.toInt() else 0xFF000000.toInt(),
        ),
    )
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(MonthMetrics.CALENDAR_NAV_HEIGHT.dp),
    ) {
        Box(
            modifier = Modifier
                .width(MonthGridMetrics.WEEK_LABEL_WIDTH.dp)
                .fillMaxHeight(),
        )
        for (dayOfWeek in 1..MonthGridModel.DAYS_PER_ROW) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = MonthText.weekday(dayOfWeek),
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(
                        QingyuWeightDelta.SEMIBOLD,
                    ),
                    color = ink,
                    maxLines = 1,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/** 网格的几何常量（与 [MonthMetrics] 同源，不另发明数值）。 */
object MonthGridMetrics {

    /**
     * 星期表头行高度（标题 + 下内边距）。
     *
     * 页面算「可用高度 → 行高」时要扣掉它；收起态裁剪窗口的上沿也是它。
     */
    const val HEADER_HEIGHT = 24.0

    /**
     * 周次行标列宽（Dart 从 34 提到 40 的实测结论：34dp 里「第 17 周」会折成
     * 两行，读起来像误入的鬼影；再加宽就挤压 7 列格宽）。
     */
    const val WEEK_LABEL_WIDTH = 40.0

    /** 行高可读下限：再矮日号与色带会挤在一起。 */
    const val MIN_ROW_HEIGHT = 44.0

    /** 行高舒适上限：屏幕很高时别把格子拉成大方块。 */
    const val MAX_ROW_HEIGHT = 78.0

    /** 按可用宽度算行高（正方形目标），并钳在可读区间内。 */
    fun rowHeightFor(availableWidthDp: Double): Double =
        MonthMetrics.gridRowHeight(availableWidthDp, WEEK_LABEL_WIDTH)
            .coerceIn(MIN_ROW_HEIGHT, MAX_ROW_HEIGHT)
}

/** 日历卡的一行需要多少高度（表头 + N 行），页面算卡片高度时用。 */
fun monthCalendarGridHeight(rows: Int, rowHeight: Dp): Dp =
    MonthGridMetrics.HEADER_HEIGHT.dp + rowHeight * rows

/** 判断系统明暗（抽出来便于将来接「跟随主题」而不改调用点）。 */
@Composable
private fun isSystemInDarkThemeSafe(): Boolean = androidx.compose.foundation.isSystemInDarkTheme()

/** 归一到当天 00:00（日历日口径）。 */
private fun dayOnly(value: LocalDateTime): LocalDateTime =
    LocalDateTime.of(value.year, value.monthValue, value.dayOfMonth, 0, 0)

/**
 * 与 `Modifier.height(...)` 在**测量与摆放上等价**、但高度在**测量阶段才读**的高度修饰器。
 *
 * 月视图的卡高 / 表格窗口高都是拖拽进度的函数。写成 `Modifier.height(dp)`（组合期读值）
 * 会让每个指针事件都重组整页；换成这里的 measure lambda 之后，进度变化只让这几处
 * 重新测量 / 布局，不再牵连组合。测量/摆放语义与 `height(...)` 对齐：同样按父约束
 * 夹在 minHeight/maxHeight 之间，同样把子项钉成这个固定高，摆放尺寸同样取子项实测值。
 *
 * ## 限制：不参与 intrinsic 测量
 *
 * `Modifier.height` 是 `SizeElement`，它的布局节点会如实回答 intrinsic 查询；这里是
 * `Modifier.layout {}`，**不提供 intrinsic 查询能力**——上层若有 intrinsics 需求
 *（`IntrinsicSize.Min/Max`、`Modifier.height(IntrinsicSize.*)`、`Row`/`Column` 的
 * intrinsic 布局等），拿到的答案不可依赖。当前调用链（卡片与表格窗口的直接高度）
 * 没有任何 intrinsic 查询，所以安全；**新增用法时必须确认所在位置不做 intrinsic 查询**。
 *
 * 只用于「值由 lambda 给出」的场景；普通固定高度继续用 `Modifier.height`。
 */
internal fun Modifier.heightDeferred(height: () -> Dp): Modifier = layout { measurable, constraints ->
    // 按父约束夹一下（等价 `Modifier.height(...)` 的 constrain 行为）。这里用内联
    // `coerceIn` 而不是 `Constraints.constrainHeight`：本仓这个 Compose 版本的
    // `Constraints` 没有那个成员。
    val h = height().roundToPx().coerceIn(constraints.minHeight, constraints.maxHeight)
    val placeable = measurable.measure(constraints.copy(minHeight = h, maxHeight = h))
    layout(placeable.width, placeable.height) { placeable.place(0, 0) }
}
