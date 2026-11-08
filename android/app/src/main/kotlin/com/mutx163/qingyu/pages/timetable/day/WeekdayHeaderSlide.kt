package com.mutx163.qingyu.pages.timetable.day

/**
 * 星期栏跨周滑动的**纯几何**（对齐 Dart `timetable_weekday_header.dart:400-463`）。
 *
 * 日视图是一根全局连续的分页器：页号 = `(week - 1) * 可见天数 + 星期下标`
 * （见 [DayViewPaging]）。星期栏只做三件事：
 *
 * 1. **同一周内换日**：整条栏不动，只有选中指示条跟着页号小数平移；
 * 2. **跨周那一刻**（从本周最后一天滑向下一周第一天）：把「本周整行」与「下一周整行」
 *    叠在一起，按页号小数反向平移 —— 整条栏像周视图表头一样从手指下滑过去；
 * 3. 跨过中点后，选中指示条从滑出行交接到滑入行（Dart `extrasOnOutgoing = progress < 0.5`）。
 *
 * 这个对象只做换算，不碰 Compose，JVM 单测可直接钉住边界（见 `WeekdayHeaderSlideTest`）。
 */
data class WeekdayHeaderSlide(
    /** 当前页所在周的 0-based 下标。 */
    val weekIndex: Int,
    /** 是否正处在「本周最后一天 → 下一周第一天」的过渡段。 */
    val crossing: Boolean,
    /** 过渡进度 0..1；不在过渡段时恒 0。 */
    val progress: Float,
    /** 滑出行里选中指示的小数格位（0 .. 可见天数-1，越界已夹紧）。 */
    val outgoingSelection: Float,
    /** 滑入行里选中指示的小数格位（0 .. 可见天数-1，越界已夹紧）。 */
    val incomingSelection: Float,
) {
    /** 滑出行是第几周（1-based，直接喂给星期栏画日期）。 */
    val outgoingWeek: Int get() = weekIndex + 1

    /** 滑入行是第几周（1-based）。只在 [crossing] 为真时有意义。 */
    val incomingWeek: Int get() = weekIndex + 2

    /** 选中指示画在滑出行还是滑入行：过渡过半就交接（Dart 同一判据）。 */
    val showSelectionOnOutgoing: Boolean get() = progress < 0.5f
}

/**
 * [WeekdayHeaderSlide] 的唯一换算口径。
 *
 * 与 [DayViewPaging] 互逆：`resolve(globalPage(visibleDays, week, dayOfWeek).toFloat(), ...)`
 * 在静止时给出 `outgoingWeek == week`、`outgoingSelection == dayIndex`。
 */
object WeekdayHeaderSlideResolver {

    /**
     * @param pagePosition 分页器的连续页号（`currentPage + currentPageOffsetFraction`）。
     * @param visibleDayCount 可见星期数（隐藏周末 = 5，否则 7）。
     * @param totalWeeks 学期总周数（用于把页号夹在学期内，避免画到第 N+1 周）。
     */
    fun resolve(
        pagePosition: Float,
        visibleDayCount: Int,
        totalWeeks: Int,
    ): WeekdayHeaderSlide {
        require(visibleDayCount > 0) { "visibleDayCount must be positive: $visibleDayCount" }
        val page = when {
            pagePosition.isNaN() -> 0f
            pagePosition.isInfinite() -> 0f
            else -> pagePosition.coerceAtLeast(0f)
        }
        val lastWeekIndex = (totalWeeks - 1).coerceAtLeast(0)
        val weekIndex = kotlin.math.floor(page / visibleDayCount)
            .toInt()
            .coerceIn(0, lastWeekIndex)
        val inWeek = page - weekIndex * visibleDayCount
        val lastSlot = (visibleDayCount - 1).toFloat()
        // 只有「过了本周最后一格」才算跨周；恰好停在最后一格（静止在周日）不算。
        // 可见天数 = 1 时每一页都是新的一周，只要离开页首就在过渡。
        val crossing = if (visibleDayCount == 1) {
            inWeek > 0f
        } else {
            inWeek > lastSlot
        }
        val progress = if (crossing) (inWeek - lastSlot).coerceIn(0f, 1f) else 0f
        return WeekdayHeaderSlide(
            weekIndex = weekIndex,
            crossing = crossing,
            progress = progress,
            outgoingSelection = inWeek.coerceIn(0f, lastSlot),
            incomingSelection = (inWeek - visibleDayCount).coerceIn(0f, lastSlot),
        )
    }
}
