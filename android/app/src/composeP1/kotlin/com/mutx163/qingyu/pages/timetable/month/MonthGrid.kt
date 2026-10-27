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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
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
 * 收起是**裁剪 + 平移**而不是隐藏行：42 格始终在树上。本组件接收两个量：
 * [visibleRows]（窗口行数，收起时=1）与 [rowOffset]（内容上移量）。表头固定、
 * 只裁剪平移行区 —— Dart 2026-10-21 实测过：把表头一起平移，收起后会露出
 * 半格上一行、表头也不见了。连续拖拽时页面每帧改这两个参数即可；行内的 7 个
 * 格子在 Compose 里参数不变会被跳过重组。
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
    visibleRows: Int = grid.rowsInMonth,
    rowOffset: Dp = 0.dp,
    showWeekNumbers: Boolean = true,
) {
    val dark = isSystemInDarkThemeSafe()
    // 表头与周次轨：压在白卡上，跟主题走。
    val mutedInk = Color(QingyuTheme.actionIcon(dark))
    val weekendInk = Color(QingyuTheme.secondaryText(dark))

    // 周次行标列：只在真的能算出周次时占位（学期未配置时整列收起）。
    val weekNumberColumnVisible = showWeekNumbers && grid.days.any { it.weekIndex != null }
    val rows = visibleRows.coerceIn(1, grid.rowsInMonth)
    val todayDay = dayOnly(today)
    val selectedDay = selectedDate?.let { dayOnly(it) }

    Column(modifier = modifier.fillMaxWidth()) {
        // 表头：钉在固定高度（与页面行高预算、裁剪窗口上沿同一个数）。
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
                        style = MiuixTheme.textStyles.footnote2,
                        fontWeight = FontWeight.SemiBold,
                        // 周末比工作日重一档（secondary vs tertiary），
                        // 扫读时才找得到「一周从哪儿开始」。
                        color = if (dayOfWeek >= 6) weekendInk else mutedInk,
                        maxLines = 1,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(bottom = 6.dp),
                    )
                }
            }
        }

        // 行区：表头固定，只裁剪平移这一块。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(rowHeight * rows)
                .clipToBounds(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .offset(y = -rowOffset),
            ) {
                for (row in 0 until rows) {
                    MonthWeekRow(
                        week = grid.weeks[row],
                        weekNumberColumnVisible = weekNumberColumnVisible,
                        mutedInk = mutedInk,
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
    mutedInk: Color,
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
                if (weekIndex != null) {
                    WeekRailLabel(
                        text = MonthText.weekRail(weekIndex.toInt()),
                        color = mutedInk,
                    )
                }
            }
        }
        for (day in week.days) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    // 格间留白：格子之间要透气。
                    .padding(MonthMetrics.CELL_GAP.dp),
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
            .padding(end = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        val maxWidthPx = constraints.maxWidth.toFloat()
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2,
            fontWeight = FontWeight.SemiBold,
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
