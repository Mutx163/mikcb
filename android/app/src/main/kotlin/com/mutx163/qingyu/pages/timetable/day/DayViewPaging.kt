package com.mutx163.qingyu.pages.timetable.day

/**
 * 日视图目标定位（周次 + 星期几）。
 */
data class DayViewPageTarget(
    val week: Int,
    val dayOfWeek: Int,
)

/**
 * 日视图分页与可见星期的唯一换算口径。
 *
 * 对齐 `lib/domain/day_view_paging.dart`：
 * 首页日视图是一根全局连续的 PageView：页号 = `(week - 1) * visibleDaysCount + dayIndex`。
 * 保证「页号 → (周次, 星期)」与「(周次, 星期) → 页号」严格互逆。
 */
object DayViewPaging {

    /**
     * 周次与在可见星期列表中的下标 → 全局连续页号。
     *
     * @param week 周次（从 1 开始）
     * @param dayIndex 在可见星期中的下标（0 .. visibleDaysCount - 1）
     * @param visibleDaysCount 可见星期天数（如 5 或 7）
     */
    fun pageFromWeekDay(week: Int, dayIndex: Int, visibleDaysCount: Int): Int {
        require(visibleDaysCount > 0) { "visibleDaysCount must be positive: $visibleDaysCount" }
        require(week >= 1) { "week must be >= 1: $week" }
        require(dayIndex in 0 until visibleDaysCount) {
            "dayIndex must be in 0 until $visibleDaysCount, but was $dayIndex"
        }
        return (week - 1) * visibleDaysCount + dayIndex
    }

    /**
     * 全局连续页号 → (周次, 下标) 元组，[pageFromWeekDay] 的严格逆运算。
     *
     * @param page 全局页号（>= 0）
     * @param visibleDaysCount 可见星期天数（如 5 或 7）
     * @return Pair(周次, dayIndex)
     */
    fun weekDayFromPage(page: Int, visibleDaysCount: Int): Pair<Int, Int> {
        require(visibleDaysCount > 0) { "visibleDaysCount must be positive: $visibleDaysCount" }
        require(page >= 0) { "page must be non-negative: $page" }
        val week = page / visibleDaysCount + 1
        val dayIndex = page % visibleDaysCount
        return Pair(week, dayIndex)
    }

    /**
     * 将一个可能越界的星期归一到 [visibleDays] 内。
     *
     * 已在列表里就原样返回；不在就回落到第一个可见日（对齐 Dart `normalizeDayOfWeekForVisibleDays`）。
     */
    fun normalizeDayOfWeek(visibleDays: List<Int>, dayOfWeek: Int): Int {
        if (visibleDays.isEmpty() || visibleDays.contains(dayOfWeek)) {
            return dayOfWeek
        }
        return visibleDays.first()
    }

    /**
     * 星期 → 全局页号。越界星期先归一再算，与 [targetForGlobalPage] 互逆。
     */
    fun globalPage(visibleDays: List<Int>, week: Int, dayOfWeek: Int): Int {
        require(visibleDays.isNotEmpty()) { "visibleDays must not be empty" }
        val normalized = normalizeDayOfWeek(visibleDays, dayOfWeek)
        val dayIndex = visibleDays.indexOf(normalized)
        return pageFromWeekDay(week, dayIndex, visibleDays.size)
    }

    /**
     * 全局页号 → (周次, 星期)，[globalPage] 的逆运算。
     *
     * 若 [visibleDays] 为空或 [page] 负数则返回 null。
     */
    fun targetForGlobalPage(visibleDays: List<Int>, page: Int): DayViewPageTarget? {
        if (visibleDays.isEmpty() || page < 0) return null
        val (week, dayIndex) = weekDayFromPage(page, visibleDays.size)
        return DayViewPageTarget(week = week, dayOfWeek = visibleDays[dayIndex])
    }
}
