package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.pages.timetable.day.DayAgendaLogic
import java.time.LocalDate
import java.time.LocalDateTime

/** 周网格里落格的非课程事项类型（Dart `WeekGridAgendaEntry`：考试 / 日程）。 */
enum class WeekAgendaKind { EXAM, SCHEDULE }

/**
 * 周网格「考试 / 日程」卡（WakeUp 式落格）。
 *
 * 对应 Dart `lib/domain/week_grid_agenda_placement.dart` 的 `WeekGridAgendaEntry`：
 * 条目只带「类型 + 标题 + 颜色 + 钟点 + 覆盖节次」，文案与取色由渲染层按类型现取。
 */
data class WeekAgendaCardModel(
    val id: String,
    val kind: WeekAgendaKind,
    val title: String,
    val location: String?,
    /** 日程自身颜色（考试为 null，渲染层用主题错误红）。 */
    val colorHex: String?,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String,
    /** 跨天日程：前日续来或续到次日（整列卡，时刻画出来是噪音）。 */
    val isCrossDay: Boolean,
) {
    val sectionSpan: Int get() = (endSection - startSection + 1).coerceAtLeast(1)
}

/** 某天的日程实例（Dart `ScheduleItemInstance` 的最小对位件）。 */
data class WeekScheduleInstance(
    val item: ScheduleItem,
    val date: LocalDate,
    val occurrenceId: String,
    val isSeriesOverride: Boolean,
)

/**
 * 周网格「考试/日程卡」落格领域逻辑（纯 Kotlin）。
 *
 * 逐条对齐 Dart `WeekGridAgendaPlacement`（`lib/domain/week_grid_agenda_placement.dart`）：
 *
 * 1. **映射规则是「任一重叠即算」**，不做精确分钟裁切——精确裁切会与课程卡的
 *    「整行节次」模型打架（课程卡从不裁切）；
 * 2. 完全不重叠（晚间考试落在末节之后、早读落在第 1 节之前）钳到**距离最近**的节，
 *    距离按「区间与节区间的间隔分钟数」算，并列取更早的节；
 * 3. 考试过滤与日视图议程同口径：`!isExpired && 当天`；
 * 4. 日程**不过滤 `enabled`**（日视图也不过滤，两侧必须一致）；
 * 5. 跨天日程口径同日程卡：前日续来按 `00:00`、续到次日按 `23:59`；
 * 6. 排序：开始钟点 → 结束钟点 → 类型（日程在先、考试在后，同跨度考试叠最上层）→ id。
 */
object WeekAgendaLogic {

    /**
     * 把当天钟点区间映射到重叠的节次区间（节次从 1 起算，含首尾）。
     *
     * 返回 null 的三种情形：节次表为空；钟点串不可解析；节次表存在但全部条目不可解析。
     */
    fun sectionSpanForClockRange(
        startTime: String,
        endTime: String,
        sections: List<SectionTime>,
    ): IntRange? {
        if (sections.isEmpty()) return null
        val start = DayAgendaLogic.parseClockMinutes(startTime, allowEndOfDay = true) ?: return null
        val end = DayAgendaLogic.parseClockMinutes(endTime, allowEndOfDay = true) ?: return null
        // 容错：结束早于开始按单点算（外来数据可能反填），不抛异常。
        val effectiveEnd = if (end < start) start else end

        var overlapStart: Int? = null
        var overlapEnd: Int? = null
        var nearestIndex: Int? = null
        var nearestDistance: Int? = null

        sections.forEachIndexed { index, section ->
            val sectionStart = DayAgendaLogic.parseClockMinutes(section.startTime, allowEndOfDay = true)
            val sectionEnd = DayAgendaLogic.parseClockMinutes(section.endTime, allowEndOfDay = true)
            if (sectionStart == null || sectionEnd == null || sectionEnd <= sectionStart) {
                // 坏节次跳过："08.30" 这类值本来就能进库（Dart 同口径）。
                return@forEachIndexed
            }
            if (start <= sectionEnd && sectionStart <= effectiveEnd) {
                if (overlapStart == null) overlapStart = index + 1
                overlapEnd = index + 1
            }
            val distance = when {
                effectiveEnd < sectionStart -> sectionStart - effectiveEnd
                start > sectionEnd -> start - sectionEnd
                else -> 0
            }
            if (nearestDistance == null || distance < nearestDistance!!) {
                nearestIndex = index
                nearestDistance = distance
            }
        }

        if (overlapStart != null) return overlapStart!!..overlapEnd!!
        val fallback = nearestIndex ?: return null
        return (fallback + 1)..(fallback + 1)
    }

    /** 某天是否有未过期考试（星期栏红点判据）。 */
    fun hasExamOn(date: LocalDate, exams: List<Exam>, now: LocalDateTime): Boolean =
        exams.any { exam ->
            sameDay(exam.dateTime.toLocalDate(), date) && !isExamExpired(exam, now)
        }

    /** 某天是否有日程实例（星期栏圆点判据）。 */
    fun hasScheduleOn(date: LocalDate, scheduleItems: List<ScheduleItem>): Boolean =
        scheduleInstancesOnDate(scheduleItems, date).isNotEmpty()

    /**
     * [date] 的日程实例（去重口径同 Dart `ScheduleItemExpander.instancesForDate`，
     * `lib/domain/schedule_item_expander.dart:47-64` 的 `putByDisplayDate`）。
     *
     * 去重键是「系列 + 显示日」，**系列例外优先**；但例外与例外之间不互相覆盖：
     * 两条不同的例外被移到同一天是两条真实条目，各占一张卡（兄弟键用 `occurrenceId`）。
     * 不过滤 `enabled`。
     */
    fun scheduleInstancesOnDate(
        scheduleItems: List<ScheduleItem>,
        date: LocalDate,
    ): List<WeekScheduleInstance> {
        val day = LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, 0, 0)
        val kept = LinkedHashMap<String, WeekScheduleInstance>()
        for (item in scheduleItems) {
            if (!item.occursOn(day)) continue
            val isOverride = item.seriesId != null
            val sourceItemId = item.seriesId ?: item.id
            val occurrenceDate = if (isOverride) (item.occurrenceDate ?: day) else day
            val occurrenceId = if (item.isRecurring || isOverride) {
                ScheduleItem.buildOccurrenceId(sourceItemId, occurrenceDate)
            } else {
                item.id
            }
            val instance = WeekScheduleInstance(
                item = item,
                date = date,
                occurrenceId = occurrenceId,
                isSeriesOverride = isOverride,
            )
            val displayKey = "$sourceItemId@${ScheduleItem.formatCalendarDate(day)}"
            val existing = kept[displayKey]
            when {
                existing == null || (isOverride && !existing.isSeriesOverride) ->
                    kept[displayKey] = instance
                // 例外 vs 例外：用 occurrenceId 做兄弟键，两条不同的例外不会撞（Dart :59-62）。
                existing.isSeriesOverride && isOverride ->
                    kept["$displayKey#$occurrenceId"] = instance
                // 同系列同显示日的非例外重复展开 = 同一个自然实例，丢弃即正确。
            }
        }
        return kept.values.toList()
    }

    /**
     * 组装某一天（[date]）的周网格落格条目：考试 + 日程，已按节次映射并排序。
     */
    fun resolve(
        date: LocalDate,
        sections: List<SectionTime>,
        exams: List<Exam> = emptyList(),
        scheduleItems: List<ScheduleItem> = emptyList(),
        now: LocalDateTime = LocalDateTime.now(),
        showExams: Boolean = true,
        showSchedules: Boolean = true,
    ): List<WeekAgendaCardModel> {
        if (sections.isEmpty() || (!showExams && !showSchedules)) return emptyList()
        val entries = mutableListOf<WeekAgendaCardModel>()

        if (showExams) {
            for (exam in exams) {
                if (!sameDay(exam.dateTime.toLocalDate(), date) || isExamExpired(exam, now)) continue
                val span = sectionSpanForClockRange(exam.startTime, exam.endTime, sections) ?: continue
                entries.add(
                    WeekAgendaCardModel(
                        id = exam.id,
                        kind = WeekAgendaKind.EXAM,
                        title = exam.name,
                        location = exam.location?.takeIf { it.isNotBlank() },
                        colorHex = null,
                        startSection = span.first,
                        endSection = span.last,
                        startTime = exam.startTime,
                        endTime = exam.endTime,
                        isCrossDay = false,
                    ),
                )
            }
        }

        if (showSchedules) {
            for (instance in scheduleInstancesOnDate(scheduleItems, date)) {
                val item = instance.item
                val continuesFromPreviousDay = item.startDate.toLocalDate().isBefore(date)
                val continuesToNextDay = item.endDate.toLocalDate().isAfter(date)
                val startTime = if (continuesFromPreviousDay) "00:00" else item.startTime
                val endTime = if (continuesToNextDay) "23:59" else item.endTime
                val span = sectionSpanForClockRange(startTime, endTime, sections) ?: continue
                entries.add(
                    WeekAgendaCardModel(
                        id = instance.occurrenceId,
                        kind = WeekAgendaKind.SCHEDULE,
                        title = item.title,
                        location = item.location?.takeIf { it.isNotBlank() },
                        colorHex = item.color,
                        startSection = span.first,
                        endSection = span.last,
                        startTime = startTime,
                        endTime = endTime,
                        isCrossDay = continuesFromPreviousDay || continuesToNextDay,
                    ),
                )
            }
        }

        return entries.sortedWith(
            compareBy<WeekAgendaCardModel>(
                { DayAgendaLogic.parseClockMinutes(it.startTime, allowEndOfDay = true) ?: Int.MAX_VALUE },
                { DayAgendaLogic.parseClockMinutes(it.endTime, allowEndOfDay = true) ?: Int.MAX_VALUE },
                { if (it.kind == WeekAgendaKind.EXAM) 2 else 1 },
                { it.id },
            ),
        )
    }

    /** 考试是否已过期：`now` 晚于考试结束（结束钟点缺省 23:59），Dart `Exam.isExpired`。 */
    fun isExamExpired(exam: Exam, now: LocalDateTime): Boolean {
        val endMinutes = DayAgendaLogic.parseClockMinutes(exam.endTime, allowEndOfDay = true)
            ?: (23 * 60 + 59)
        val day = exam.dateTime.toLocalDate()
        val end = LocalDateTime.of(day.year, day.monthValue, day.dayOfMonth, 0, 0)
            .plusMinutes(endMinutes.toLong())
        return now.isAfter(end)
    }

    private fun sameDay(left: LocalDate, right: LocalDate): Boolean = left == right
}
