package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.day.DayViewStrings
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronBackward
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate

/**
 * 月视图的**卡顶导航行**：`‹ 2026年10月 › 今天`。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_view_toolbar.dart`（2026-10-27 快照）。
 * 高度由 [MonthCalendarChrome.NAV_HEIGHT] 定死（40 = 周/日视图星期栏同高，
 * 用户报过「三个视图顶栏不一样高」），本组件自身不设高。
 *
 * ## 墨色跟卡面走，不跟壁纸走
 *
 * 这一行现在躺在**白色日历卡**里（Dart 2026-10-23 把它从满宽玻璃带搬进卡内）。
 * 卡是实底的，所以文字一律按主题取（[QingyuTheme.primaryText] /
 * [QingyuTheme.actionIcon]），**不要**用「压在壁纸上该黑还是白」那套判据 ——
 * 暗壁纸下它会给出白字，白压白直接看不见。
 *
 * ## 标题跟着翻页连续滑动
 *
 * Dart 版读 `PageController` 的连续值，让两个月份各露一半。Compose 侧把
 * 「滑到几成」收成一个普通参数 [pageFraction]（0 = 当前月完全在位，1 = 下个月
 * 完全进来）：页面用 pager 的 `currentPageOffsetFraction` 驱动重组即可。
 * 参数化而不是传控制器，是因为翻页状态属于页面（月视图还有面板联动），
 * 渲染层不该反向持有它。
 */
@Composable
fun MonthViewToolbar(
    year: Int,
    month: Int,
    isCurrentMonth: Boolean,
    onPreviousMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onBackToCurrentMonth: () -> Unit,
    modifier: Modifier = Modifier,
    pageFraction: Float = 0f,
) {
    val dark = isSystemInDarkTheme()
    val ink = Color(QingyuTheme.primaryText(dark))
    val muted = Color(QingyuTheme.actionIcon(dark))

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = MonthMetrics.CARD_PADDING.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        MonthNavArrow(
            forward = false,
            contentDescription = MonthText.previousMonth.zh,
            tint = muted,
            onTap = onPreviousMonth,
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(MonthMetrics.CALENDAR_NAV_HEIGHT.dp),
            contentAlignment = Alignment.Center,
        ) {
            MonthNavTitle(
                year = year,
                month = month,
                ink = ink,
                muted = muted,
                fraction = pageFraction,
            )
        }
        MonthNavArrow(
            forward = true,
            contentDescription = MonthText.nextMonth.zh,
            tint = muted,
            onTap = onNextMonth,
        )
        // 尾部固定槽位：本月留空（同宽），非本月放「今天」。
        // 标题的可用宽度因此恒定，不会因为多出/少掉一个按钮而左右跳。
        Box(
            modifier = Modifier
                .width(MonthViewToolbarMetrics.TRAILING_SLOT_WIDTH.dp)
                .height(MonthMetrics.CALENDAR_NAV_HEIGHT.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (!isCurrentMonth) {
                MonthTodayPill(
                    label = MonthText.backToCurrentMonthShort.zh,
                    ink = ink,
                    onTap = onBackToCurrentMonth,
                )
            }
        }
    }
}

/** 卡顶导航行的几何常量（与 [MonthCalendarChrome] 同源，不另发明数值）。 */
object MonthViewToolbarMetrics {

    /** 左右箭头的**命中**尺寸（正方形）。视觉图标只有 20，命中区 40。 */
    const val ARROW_SIZE = 40.0

    /** 视觉图标尺寸。 */
    const val ICON_SIZE = 20.0

    /** 尾部槽位宽度：「今天」药丸与箭头同宽，本月空着时标题也不偏移。 */
    const val TRAILING_SLOT_WIDTH = 56.0

    /** 「今天」药丸圆角。 */
    const val TODAY_PILL_RADIUS = 13.0
}

/**
 * 卡内箭头：**无底**的可点图标（小米日历 / 系统日历在这一行都是裸箭头）。
 *
 * 卡本身已经是一块明确容器，再垫一圈圆底会在白卡顶部画出一排灰点。
 */
@Composable
private fun MonthNavArrow(
    forward: Boolean,
    contentDescription: String,
    tint: Color,
    onTap: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(MonthViewToolbarMetrics.ARROW_SIZE.dp)
            .clip(CircleShape)
            .clickable(onClick = onTap),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = if (forward) MiuixIcons.ChevronForward else MiuixIcons.ChevronBackward,
            contentDescription = contentDescription,
            tint = tint,
            modifier = Modifier.size(MonthViewToolbarMetrics.ICON_SIZE.dp),
        )
    }
}

/**
 * 月份标题：有翻页进度时同时画「当前页 / 下一页」两段，按比例横向平移。
 *
 * 两段都在 [clipToBounds] 里：进度为 0 时下一页整段落在裁剪区外，看不见；
 * 滑到一半时两个月各露一半 —— 翻页不是突变。
 */
@Composable
private fun MonthNavTitle(
    year: Int,
    month: Int,
    ink: Color,
    muted: Color,
    fraction: Float,
) {
    val clamped = fraction.coerceIn(0f, 1f)
    val next = nextMonthOf(year, month)
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .clipToBounds(),
    ) {
        val slotWidth = maxWidth
        Box(
            modifier = Modifier
                .fillMaxSize()
                .offset(x = -slotWidth * clamped),
            contentAlignment = Alignment.Center,
        ) {
            MonthNavTitleLabel(year, month, ink, muted)
        }
        if (clamped > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .offset(x = slotWidth * (1f - clamped)),
                contentAlignment = Alignment.Center,
            ) {
                MonthNavTitleLabel(next.first, next.second, ink, muted)
            }
        }
    }
}

/** `2026年` + `10月`：年份弱色小一号，月份是主体。 */
@Composable
private fun MonthNavTitleLabel(
    year: Int,
    month: Int,
    ink: Color,
    muted: Color,
) {
    Row {
        Text(
            text = MonthText.yearLabel(year),
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = muted,
            maxLines = 1,
            textAlign = TextAlign.Center,
            modifier = Modifier.alignByBaseline(),
        )
        Spacer(modifier = Modifier.width(3.dp))
        Text(
            text = MonthText.monthLabel(month),
            style = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.BOLD),
            color = ink,
            maxLines = 1,
            textAlign = TextAlign.Center,
            modifier = Modifier.alignByBaseline(),
        )
    }
}

/** 「今天」药丸：非本月时出现，点一下回到本月。 */
@Composable
private fun MonthTodayPill(
    label: String,
    ink: Color,
    onTap: () -> Unit,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(MonthViewToolbarMetrics.TODAY_PILL_RADIUS.dp))
            .background(ink.copy(alpha = MonthInk.FILL.toFloat()))
            .clickable(onClick = onTap)
            .padding(horizontal = 10.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = ink,
            maxLines = 1,
        )
    }
}

/** [year]/[month] 的下一个月（12 月 → 次年 1 月）。 */
private fun nextMonthOf(year: Int, month: Int): Pair<Int, Int> {
    val first = LocalDate.of(year, month, 1).plusMonths(1)
    return first.year to first.monthValue
}

/**
 * 月视图的 ARB 文案句柄（渲染层统一出口）。
 *
 * `MonthViewStrings` 已由 Lead 补上**逐键 accessor**（`monthViewTitle` 等），
 * 这里只做两件事：① 把渲染层常用的调用点收成好念的名字；② 提供带占位符的
 * 格式化函数（`yearLabel(2026)` → `2026年`），避免各卡片自己 `filled(...)`。
 *
 * **屏上不许出现中文字面量**：除语义标签的分隔标点外，所有文案都从这里出。
 * 共享层是只读的（Lead 生成），缺键只能在这里补映射。
 */
internal object MonthText {

    val title: ArbText get() = MonthViewStrings.monthViewTitle
    val previousMonth: ArbText get() = MonthViewStrings.monthViewPreviousMonth
    val nextMonth: ArbText get() = MonthViewStrings.monthViewNextMonth
    val backToCurrentMonthShort: ArbText get() = MonthViewStrings.monthViewBackToCurrentMonthShort
    val holidayBadge: ArbText get() = MonthViewStrings.monthViewHolidayBadge
    val adjustedWorkdayBadge: ArbText get() = MonthViewStrings.monthViewAdjustedWorkdayBadge
    val agendaEmpty: ArbText get() = MonthViewStrings.monthViewAgendaEmpty
    val emptyMonthTitle: ArbText get() = MonthViewStrings.monthViewEmptyMonthTitle
    val emptyMonthHint: ArbText get() = MonthViewStrings.monthViewEmptyMonthHint

    /** `2026年` */
    fun yearLabel(year: Int): String =
        MonthViewStrings.monthViewYearSegment.filled("year", year.toString())

    /** `10月` */
    fun monthLabel(month: Int): String =
        MonthViewStrings.monthViewMonthSegment.filled("month", month.toString())

    /** `10月5日`（格子无障碍标签的第一段）。 */
    fun dayLabel(month: Int, day: Int): String =
        MonthViewStrings.monthViewDaySemantics.filled(
            "month" to month.toString(),
            "day" to day.toString(),
        )

    /** `3节课` */
    fun courseCount(count: Int): String =
        MonthViewStrings.monthViewCourseCountSemantics.filled("count", count.toString())

    /** `1场考试` */
    fun examCount(count: Int): String =
        MonthViewStrings.monthViewExamCountSemantics.filled("count", count.toString())

    /** `2个日程` */
    fun scheduleCount(count: Int): String =
        MonthViewStrings.monthViewScheduleCountSemantics.filled("count", count.toString())

    /** 星期表头（`周一`…`周日`）：ARB 里是共享键，日视图那份句柄已经逐字对拍过。 */
    fun weekday(dayOfWeek: Int): String = DayViewStrings.weekdayLabel(dayOfWeek)

    /** `第 17 周`：周次轨文案，复用既有 ARB 键，不新增文案。 */
    fun weekRail(week: Int): String = DayViewStrings.weekLabel(week)
}
