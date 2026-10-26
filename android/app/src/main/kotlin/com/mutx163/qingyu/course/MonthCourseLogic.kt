package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * 月视图课程侧纯函数子集（族3）。
 *
 * Dart 源：lib/domain/month_view_logic.dart（554 行）中与课程直接相关的纯函数。
 * 考试/日程/节假日展开（HolidayResolver/ScheduleItemExpander/SectionTime 混排）
 * 归 calendar 族（第一团队），本族不碰、不复制：
 * 这里只收"只用课程 + 学期 + 日历日就能算"的四条：
 * - monthGridDates：固定 42 格（周一为列首）日期序列；
 * - coursesOnDate：当天真实发生的课程（dayOfWeek + isInWeek，学期外为空）；
 * - rowsInMonth：本月真正需要画的行数（尾行含本月日期即保留）；
 * - courseColorHexes：当天课程去重颜色（最多 3 个，保持出现顺序）。
 *
 * 签名刻意收敛：不引入 Exam/ScheduleItem/HolidayData，避免与 calendar 族的
 * 模型重复；buildMonthGrid 整屏聚合由 calendar 族移植时补齐。
 */
object MonthCourseLogic {

    /** 固定 42 格（6 行×7 列，周一为列首）的日期序列，含前后月补位。 */
    fun monthGridDates(year: Int, month: Int): List<LocalDateTime> {
        val first = LocalDateTime.of(year, month, 1, 0, 0)
        val gridStart = WeekCalculator.startOfWeek(first)
        return List(42) { i -> WeekCalculator.addDays(gridStart, i) }
    }

    /**
     * [date]（开学配置下）当天真实发生的课程。
     * 周次取 WeekCalculator.getWeekIndex（开学前 null → 无课程可映射）。
     */
    fun coursesOnDate(
        courses: List<Course>,
        date: LocalDateTime,
        settings: TimetableSettings,
    ): List<Course> {
        val normalized = LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, 0, 0)
        val semesterStart = settings.semesterStartDate ?: return emptyList()
        val weekIndex = WeekCalculator.getWeekIndex(normalized, semesterStart) ?: return emptyList()
        return courses.filter { it.dayOfWeek == normalized.dayOfWeek.value && it.isInWeek(weekIndex.toInt()) }
    }

    /**
     * 本月真正需要画的行数（4~6）。判据是最后一个属于本月的日期落在第几行；
     * 整屏皆为邻月（异常数据）退回 6 行。
     *
     * [isOutsideMonth] 与 monthGridDates 同序、长度一致（true=前后月补位格）。
     */
    fun rowsInMonth(isOutsideMonth: List<Boolean>): Int {
        var last = -1
        for (i in isOutsideMonth.indices) {
            if (!isOutsideMonth[i]) last = i
        }
        if (last < 0) return (isOutsideMonth.size / 7).coerceIn(1, 6)
        return (last / 7) + 1
    }

    /** 当天课程的去重颜色（hex 串，最多 3 个，保持出现顺序；空串跳过）。 */
    fun courseColorHexes(dayCourses: List<Course>): List<String> {
        val hexes = mutableListOf<String>()
        for (course in dayCourses) {
            val hex = course.color.trim()
            if (hex.isNotEmpty() && !hexes.contains(hex)) hexes.add(hex)
            if (hexes.size >= 3) break
        }
        return hexes
    }
}
