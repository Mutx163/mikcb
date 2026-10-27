package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayResolver
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime

/**
 * 月历里一天的展示判定结果（纯数据，无 Android / Compose / IO 依赖）。
 *
 * 逐字段对齐 `lib/domain/month_view_logic.dart:MonthDayEntry`（2026-10-27 的
 * 554 行那版）。**语义一律不许简化**，尤其是 [courseCount]：
 *
 * > 只数当天**真实发生**的课（`dayOfWeek` 匹配 + `isInWeek` 命中），
 * > **不**走周网格那套「非本周淡化」扩展口径（`getCoursesForDay` 会把
 * > 「本周没课但之后还有课」的课程也返回）。月视图一格是一个具体日期，
 * > 用扩展口径会让一门课在它不上课的日子也占一格（重复计数）。
 */
data class MonthDayEntry(
    /** 当天 00:00 的本地日期（一律归一，勿带时分秒使用）。 */
    val date: LocalDateTime,

    /**
     * 真实日历周次（[WeekCalculator.getWeekIndex] 口径，**不按**
     * [TimetableSettings.semesterWeekCount] 钳制）。学期未配置或开学前为 null。
     */
    val weekIndex: Long?,

    /** [weekIndex] 落在配置学期内（1 ≤ 周次 ≤ semesterWeekCount）。 */
    val weekInSemester: Boolean,

    /** 当天实际有课的课程数。 */
    val courseCount: Int,

    /** 当天课程的去重颜色（hex 串，最多 3 个，保持出现顺序）。 */
    val courseColorHexes: List<String>,

    /** 未过期考试数（过期口径见 [MonthGridModel.examsOnDate]）。 */
    val examCount: Int,

    /** 日程实例数（含已暂停项——日视图也不过滤 `enabled`，两侧必须一致）。 */
    val scheduleCount: Int,

    /** 假期（[HolidayResolver.isHoliday] 全语义：调休优先、覆盖开关、标记开关都折算过）。 */
    val isHoliday: Boolean,

    /** 调休上班日（显示「班」标）。 */
    val isAdjustedWorkday: Boolean,

    /** 是否前后月补位格（固定 42 格里落在本月之外的日期）。 */
    val isOutsideMonth: Boolean,
) {
    /**
     * 这一天**有没有内容**（课 / 考试 / 日程任一）。
     *
     * 空白日不画卡片，网格因此退到背景里，一眼能看出哪几天忙。判据与面板
     * 「本月有安排的日子」是同一句话，两处不许各写一份。
     */
    val hasContent: Boolean
        get() = courseCount + examCount + scheduleCount > 0
}

/**
 * 月历的一行（7 格）。
 *
 * [weekIndex] 是该行首日的真实周次：同一自然周内 7 天的周次必然相同
 * （[WeekCalculator.getWeekIndex] 按周一起算的周序号），所以按行存一份。
 * 学期未配置时为 null，渲染层据此隐藏整列「第 N 周」。
 */
data class MonthWeek(
    val weekIndex: Long?,
    val days: List<MonthDayEntry>,
)

/**
 * 一个月的月历：**固定 6 行 × 7 列 = 42 格**（周一为列首，含前后月补位）。
 *
 * 固定 42 格而不按月裁 4~6 行：翻月时网格行数不跳变。真正要画几行由
 * [rowsInMonth] 给出（落在本月的最后一行），渲染层只画那几行。
 */
data class MonthGrid(
    val year: Int,
    val month: Int,

    /** 固定 6 行 × 7 列 = 42 格。 */
    val weeks: List<MonthWeek>,

    /** 本月内有内容的日子，按日期升序（不含前后月补位）。 */
    val busyDays: List<MonthDayEntry>,
) {

    /** 本月有安排的天数（= [busyDays] 的条数）。 */
    val busyDayCount: Int
        get() = busyDays.size

    /** 42 格按日期升序展开（渲染层遍历用；顺序与 [MonthGridModel.monthGridDates] 一致）。 */
    val days: List<MonthDayEntry>
        get() = weeks.flatMap { it.days }

    /**
     * 本月**真正需要画的行数**（4~6）。
     *
     * 对齐 Dart `MonthGridData.rowsInMonth`：判据是「最后一个属于本月的日期
     * 落在第几行」，不是「这个月跨几个自然周」—— 42 格的起点是含 1 号的那一周的
     * 周一，两者在月末落在周中时不等价。首行必然含 1 号，不需要同样处理。
     */
    val rowsInMonth: Int
        get() {
            val all = days
            var last = -1
            for (index in all.indices) {
                if (!all[index].isOutsideMonth) last = index
            }
            if (last < 0) {
                // 整屏都是邻月（数据异常）：退回固定行数，宁可多画一行也不要 0 行。
                return ((all.size + 6) / 7).coerceIn(1, MonthGridModel.ROW_COUNT)
            }
            return last / 7 + 1
        }

    /** [date] 对应的格子（归一到当天 00:00 后比较）；不在 42 格内返回 null。 */
    fun entryFor(date: LocalDateTime): MonthDayEntry? {
        val key = LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, 0, 0)
        return weeks.asSequence().flatMap { it.days.asSequence() }.firstOrNull { it.date == key }
    }
}

/**
 * 月视图里的一条日程实例（对齐 Dart `ScheduleItemInstance` 的展示子集）。
 *
 * 只保留月视图真正用到的部分：显示日、稳定 occurrence id、是否为「系列例外
 * 覆盖」。跨天剪裁（00:00 / 23:59）属于日视图议程的展示口径，不在这里做。
 */
data class MonthScheduleInstance(
    val item: ScheduleItem,
    /** 显示日（当天 00:00）。 */
    val date: LocalDateTime,
    /** 稳定 occurrence id：系列 = `seriesRootId@yyyy-MM-dd`，一次性 = item.id。 */
    val occurrenceId: String,
    /** 是否为系列里被改期/修改的那一条（例外覆盖）。 */
    val isSeriesOverride: Boolean,
)

/**
 * 月视图领域服务：42 格网格的数据组装（纯 Kotlin，无 Android / IO 依赖）。
 *
 * 移植自 `lib/domain/month_view_logic.dart:MonthViewLogic.buildMonthGrid`
 * （2026-10-27 快照）。渲染层只画、不取数；面板半与本层共用同一份判据。
 */
object MonthGridModel {

    /** 一行几天（周一为列首）。 */
    const val DAYS_PER_ROW = 7

    /** 固定行数：6 行 × 7 列 = 42 格。 */
    const val ROW_COUNT = 6

    /** 固定格数。 */
    const val CELL_COUNT = DAYS_PER_ROW * ROW_COUNT

    /**
     * 固定 42 格（6 行 × 7 列，周一为列首）的日期序列，含前后月补位。
     *
     * 对齐 Dart `MonthViewLogic.monthGridDates`：从「含 1 号的那一周的周一」起算
     * 42 天。月份越界按 Dart `DateTime(year, month)` 的口径日历顺延
     * （13 月 → 次年 1 月），这样翻页器不必自己兜边界。
     */
    fun monthGridDates(year: Int, month: Int): List<LocalDateTime> {
        val first = DartTime.dateTime(year, month, 1)
        val gridStart = WeekCalculator.startOfWeek(first)
        return (0 until CELL_COUNT).map { WeekCalculator.addDays(gridStart, it) }
    }

    /**
     * [date]（开学配置下）当天真实发生的课程。
     *
     * 周次取 [WeekCalculator.getWeekIndex]（开学前 null → 无课程可映射）；
     * 学期配置了但该周超出 [TimetableSettings.semesterWeekCount] 时仍按真实周次
     * 匹配（课程 startWeek/endWeek 不会超出，自然为空）。
     *
     * ⚠️ **刻意不用周网格的 `getCoursesForDay`**：那套带「非本周淡化」扩展
     * （未落在本周、但本周之后还有课的课程也会返回），是给周网格用的。
     * 月视图一格是具体日期，只承认当天真实发生的课。
     */
    fun coursesOnDate(
        courses: List<Course>,
        date: LocalDateTime,
        semesterStart: LocalDateTime?,
    ): List<Course> {
        if (semesterStart == null) return emptyList()
        val normalized = dayOnly(date)
        val weekIndex = WeekCalculator.getWeekIndex(normalized, semesterStart) ?: return emptyList()
        val week = weekIndex.toInt()
        return courses.filter { course ->
            course.dayOfWeek == normalized.dayOfWeek.value && course.isInWeek(week)
        }
    }

    /**
     * [date] 的未过期考试，按开始时刻升序。
     *
     * 过期口径与 `Exam.isExpired` 完全一致（`endTime` 缺省 23:59），只是把
     * `now` 收成参数，让领域逻辑可测。
     */
    fun examsOnDate(
        exams: List<Exam>,
        date: LocalDateTime,
        now: LocalDateTime,
    ): List<Exam> {
        val normalized = dayOnly(date)
        return exams.filter { exam ->
            val examDate = dayOnly(exam.dateTime)
            if (examDate != normalized) return@filter false
            !now.isAfter(examEnd(exam))
        }.sortedWith(Comparator { left, right ->
            DayClock.compare(left.startTime, right.startTime)
        })
    }

    /**
     * [date] 的日程实例（去重口径同 Dart `ScheduleItemExpander.instancesForDate`）。
     *
     * 判据：
     * 1. `ScheduleItem.occursOn(date)` 命中（含重复规则、起止区间、例外日期）；
     * 2. 同一 `seriesRootId@显示日` 只留一份——**系列例外优先于原系列实例**；
     * 3. 两条不同的例外被移到同一天时**都保留**（用 occurrenceId 做兄弟键）：
     *    它们是两个真实存在、可分别撤销的条目，丢一条会让界面上少一张卡。
     *
     * 不过滤 `enabled`：日视图也不过滤，两侧必须一致。
     */
    fun scheduleInstancesOnDate(
        scheduleItems: List<ScheduleItem>,
        date: LocalDateTime,
    ): List<MonthScheduleInstance> {
        val day = dayOnly(date)
        val kept = LinkedHashMap<String, MonthScheduleInstance>()
        for (item in scheduleItems) {
            if (!item.occursOn(day)) continue
            val isOverride = item.seriesId != null
            val sourceItemId = item.seriesId ?: item.id
            val occurrenceDate = if (isOverride) (item.occurrenceDate ?: day) else day
            val occurrenceId = if (item.isRecurring || item.seriesId != null) {
                ScheduleItem.buildOccurrenceId(sourceItemId, occurrenceDate)
            } else {
                item.id
            }
            val instance = MonthScheduleInstance(
                item = item,
                date = day,
                occurrenceId = occurrenceId,
                isSeriesOverride = isOverride,
            )
            putByDisplayDate(kept, instance, sourceItemId)
        }
        return kept.values.toList()
    }

    /**
     * 聚合一个月的月历数据（42 格逐日判定）。
     *
     * @param semesterStart 开学日（日历日；Null = 学期未配置，周次全为 null）。
     *   与 [TimetableSettings.semesterStartDate] 同源，由调用方取出传入——本函数
     *   不接受一处配置两处读法。
     * @param today 聚合时刻的「今天」（只需日期部分）。
     * @param holidayOverrideEnabled / @param holidayMarkingEnabled
     *   假期两个开关：Kotlin 的 [TimetableSettings] 目前只移植了时间/周次子集，
     *   这两个字段由调用方按键从设置存档读出后传入。默认值与 Dart 一致
     *   （`holidayOverrideEnabled = false`、`enableHolidayMarking = true`）。
     */
    fun build(
        semesterStart: LocalDateTime?,
        settings: TimetableSettings,
        courses: List<Course>,
        exams: List<Exam>,
        scheduleItems: List<ScheduleItem>,
        holidayData: HolidayData?,
        today: LocalDateTime,
        year: Int,
        month: Int,
        holidayOverrideEnabled: Boolean = false,
        holidayMarkingEnabled: Boolean = true,
    ): MonthGrid {
        val dates = monthGridDates(year, month)
        val examCountsByDate = examCountsByDate(exams, today)
        val busyDays = mutableListOf<MonthDayEntry>()
        val entries = ArrayList<MonthDayEntry>(dates.size)

        for (raw in dates) {
            val date = dayOnly(raw)
            val weekIndex = semesterStart?.let { WeekCalculator.getWeekIndex(date, it) }
            val weekInSemester =
                weekIndex != null && weekIndex >= 1 && weekIndex <= settings.semesterWeekCount

            val dayCourses = coursesOnDate(courses, date, semesterStart)
            val colorHexes = mutableListOf<String>()
            for (course in dayCourses) {
                val hex = course.color.trim()
                if (hex.isNotEmpty() && !colorHexes.contains(hex)) {
                    colorHexes.add(hex)
                }
                if (colorHexes.size >= 3) break
            }

            val examCount = examCountsByDate[date] ?: 0
            val scheduleCount = scheduleInstancesOnDate(scheduleItems, date).size
            val isOutsideMonth = date.monthValue != month || date.year != year

            val entry = MonthDayEntry(
                date = date,
                weekIndex = weekIndex,
                weekInSemester = weekInSemester,
                courseCount = dayCourses.size,
                courseColorHexes = colorHexes.toList(),
                examCount = examCount,
                scheduleCount = scheduleCount,
                isHoliday = HolidayResolver.isHoliday(
                    date,
                    data = holidayData,
                    overrideEnabled = holidayOverrideEnabled,
                    markingEnabled = holidayMarkingEnabled,
                ),
                isAdjustedWorkday = HolidayResolver.isAdjustedWorkday(date, data = holidayData),
                isOutsideMonth = isOutsideMonth,
            )
            entries.add(entry)
            if (!isOutsideMonth && entry.hasContent) {
                busyDays.add(entry)
            }
        }

        val weeks = (0 until ROW_COUNT).map { row ->
            val rowDays = entries.subList(row * DAYS_PER_ROW, (row + 1) * DAYS_PER_ROW)
            MonthWeek(weekIndex = rowDays.first().weekIndex, days = rowDays.toList())
        }

        return MonthGrid(
            year = year,
            month = month,
            weeks = weeks,
            busyDays = busyDays,
        )
    }

    // ------------------------------------------------------------------
    // 内部实现
    // ------------------------------------------------------------------

    /** 归一到当天 00:00（日历日口径，不做时长加减）。 */
    private fun dayOnly(value: LocalDateTime): LocalDateTime =
        LocalDateTime.of(value.year, value.monthValue, value.dayOfMonth, 0, 0)

    /**
     * 考试结束时刻（`endTime` 缺省 23:59）——过期判定的另一半。
     *
     * 与 Dart `Exam.parseTimeOfDayParts(endTime, fallbackHour: 23, fallbackMinute: 59)`
     * 同口径：`endTime` 非法时按当天 23:59 算，绝不把一场考试判成已过期。
     */
    private fun examEnd(exam: Exam): LocalDateTime {
        val (hour, minute) = Exam.parseTimeOfDayParts(
            exam.endTime,
            fallbackHour = 23,
            fallbackMinute = 59,
        )
        val date = dayOnly(exam.dateTime)
        return LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, hour, minute)
    }

    /** 未过期考试按日期分桶（一次成型，42 格逐日查表）。 */
    private fun examCountsByDate(
        exams: List<Exam>,
        now: LocalDateTime,
    ): Map<LocalDateTime, Int> {
        val counts = HashMap<LocalDateTime, Int>()
        for (exam in exams) {
            if (now.isAfter(examEnd(exam))) continue
            val key = dayOnly(exam.dateTime)
            counts[key] = (counts[key] ?: 0) + 1
        }
        return counts
    }

    /**
     * 按显示日去重（对齐 Dart `ScheduleItemExpander.putByDisplayDate`）。
     *
     * key = `sourceItemId@yyyy-MM-dd`；系列例外覆盖同日的原系列实例；两条例外
     * 撞在同一天时用 `#occurrenceId` 做兄弟键各留一份。
     */
    private fun putByDisplayDate(
        kept: LinkedHashMap<String, MonthScheduleInstance>,
        instance: MonthScheduleInstance,
        sourceItemId: String,
    ) {
        val key = "$sourceItemId@${ScheduleItem.formatCalendarDate(instance.date)}"
        val existing = kept[key]
        when {
            existing == null -> kept[key] = instance
            instance.isSeriesOverride && !existing.isSeriesOverride -> kept[key] = instance
            existing.isSeriesOverride && instance.isSeriesOverride ->
                kept["$key#${instance.occurrenceId}"] = instance
            // 同为非例外的同系列同显示日 = 同一个自然实例被展开两次，丢弃即正确。
        }
    }
}

/**
 * 月视图内部用的钟点比较（对齐 `lib/domain/clock_order.dart:compareClockText`）。
 *
 * ⚠️ 为什么不直接用日视图的 `DayAgendaLogic.compareClockText`：L0 只编译
 * `pages/timetable/month` + 共享模型目录（`core/`、`calendar/` 等），
 * 跨到 `pages/timetable/day` 会让模块单测直接编不过。语义与那份逐行一致，
 * 改动时两边一起改。
 */
internal object DayClock {

    /** "HH:mm" / "H:m" → 当天分钟数；"24:00" 合法；解析失败 null。 */
    fun parseMinutes(text: String?): Int? {
        val value = text?.trim().orEmpty()
        if (value.isEmpty()) return null
        val parts = value.split(':')
        if (parts.size != 2) return null
        val hour = parts[0].trim().toIntOrNull() ?: return null
        val minute = parts[1].trim().toIntOrNull() ?: return null
        if (minute !in 0..59) return null
        if (hour == 24 && minute == 0) return 24 * 60
        if (hour !in 0..23) return null
        return hour * 60 + minute
    }

    /** 解析不出来的值排在能解析的值之后；两个都解析不出来时退回字典序。 */
    fun compare(left: String?, right: String?): Int {
        val a = parseMinutes(left)
        val b = parseMinutes(right)
        if (a == null && b == null) return left.orEmpty().compareTo(right.orEmpty())
        if (a == null) return 1
        if (b == null) return -1
        return a.compareTo(b)
    }
}
