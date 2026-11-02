package com.mutx163.qingyu.core

import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 一条写入**系统时钟**的闹钟计划（`AlarmClock.ACTION_SET_ALARM` 的 payload）。
 *
 * 与 Dart `SystemAlarmPlan`（`lib/services/system_alarm_service.dart:7-29`）同一形状：
 * 系统时钟 App 拥有这枚闹钟，本应用刻意不留句柄（无公开 API 读删系统时钟条目）。
 */
data class ClassAlarmPlan(
    val hour: Int,
    val minute: Int,
    /** 交给系统时钟的标签（不含应用名前缀；宿主拼接）。 */
    val label: String,
    /** 重复星期（Calendar 口径：周日=1 … 周六=7）。 */
    val repeatDays: List<Int>,
    /** true = 跳过系统时钟的保存页直接落闹钟。 */
    val skipUi: Boolean,
)

/**
 * 「这节课闹钟」的**纯计算层**——逐条移植 Dart `SystemAlarmLogic`
 * （`lib/services/system_alarm_service.dart:84-152`）与课程操作弹层的
 * `_isAlarmAvailable`（`lib/widgets/course_action_sheet.dart:1145-1167`），
 * 不改语义。无 Android / Compose 依赖，JVM 单测可直接跑。
 *
 * Dart 的「单节课提醒」现状（2026-10 迁移保留）：写入走**系统时钟**每周重复闹钟；
 * 旧版「课程×真实日期」一次性本地通知条目只读不写。本层只管前者。
 *
 * 位置说明（2026-11-02 自 `pages/course/` 下沉到 `core/`）：`app/` 是每个 L0 模块
 * 都收编的共享目录，`CourseActionDispatcher` 需要引用 [ClassAlarmPlanLogic]，
 * 共享层不得反向依赖页面域（`pages/` 只在 `-Module pages/course` 时才进 classpath），
 * 故纯逻辑落共享层。对外形状（类型名 / 签名）不变。
 */
object ClassAlarmPlanLogic {

    /** `"HH:mm"` → 当日分钟数；越界 / 非数字 / 格式不对 ⇒ null（Dart `parseClockMinutes`）。 */
    fun parseClockMinutes(value: String): Int? {
        val parts = value.trim().split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return hour * 60 + minute
    }

    /** 分钟数 → `HH:mm`（负数与跨日按 1440 取模归一，Dart `formatClock`）。 */
    fun formatClock(minutes: Int): String {
        var normalized = minutes % 1440
        if (normalized < 0) normalized += 1440
        return "%02d:%02d".format(normalized / 60, normalized % 60)
    }

    /** ISO 1=周一..7=周日 → Calendar 周日=1..周六=7（Dart `calendarWeekday`）。 */
    fun calendarWeekday(dayOfWeek: Int): Int = when (dayOfWeek) {
        1 -> 2
        2 -> 3
        3 -> 4
        4 -> 5
        5 -> 6
        6 -> 7
        7 -> 1
        else -> 0
    }

    /** Calendar 周日=1..周六=7 → ISO 1=周一..7=周日（Dart `isoWeekdayFromCalendar`）。 */
    fun isoWeekdayFromCalendar(calendarDay: Int): Int = when (calendarDay) {
        1 -> 7
        2 -> 1
        3 -> 2
        4 -> 3
        5 -> 4
        6 -> 5
        7 -> 6
        else -> 0
    }

    /** 提前量夹带：0..120（Dart `clampLeadMinutes`）。 */
    fun clampLeadMinutes(minutes: Int): Int = minutes.coerceIn(0, 120)

    /**
     * 为单门课生成**每周重复**闹钟计划（Dart `buildCourseWeeklyPlan`）：
     * 响点 = `startTime - leadMinutes`，越过午夜则重复星期**前移一天**。
     * 上课时间解析不了 / 星期非法 ⇒ null。
     */
    fun buildCourseWeeklyPlan(
        dayOfWeek: Int,
        startTime: String,
        label: String,
        leadMinutes: Int = 30,
        skipUi: Boolean = false,
    ): ClassAlarmPlan? {
        val start = parseClockMinutes(startTime)
        val calendarDay = calendarWeekday(dayOfWeek)
        if (start == null || calendarDay == 0) return null
        val rawRing = start - clampLeadMinutes(leadMinutes)
        val ring = ((rawRing % 1440) + 1440) % 1440
        val ringDay = if (rawRing < 0) (if (dayOfWeek == 1) 7 else dayOfWeek - 1) else dayOfWeek
        return ClassAlarmPlan(
            hour = ring / 60,
            minute = ring % 60,
            label = label,
            repeatDays = listOf(calendarWeekday(ringDay)),
            skipUi = skipUi,
        )
    }

    /**
     * 用户自选响点的最终计划（Dart `_addSystemAlarm` 的 `minuteOfDay >= 0` 分支，
     * `class_reminder_sheet.dart:101-108`）：钟点用用户选的，**重复星期仍取提前量计划
     * 的响点日**（提前量把响点挪过午夜时，闹钟落在前一 days 而不是上课日）。
     */
    fun planForPickedMinute(
        minuteOfDay: Int,
        course: Course,
        resolvedStartTime: String,
        label: String,
        leadMinutes: Int,
        skipUi: Boolean,
    ): ClassAlarmPlan? {
        val weekly = buildCourseWeeklyPlan(
            dayOfWeek = course.dayOfWeek,
            startTime = resolvedStartTime,
            label = label,
            leadMinutes = leadMinutes,
            skipUi = skipUi,
        ) ?: return null
        if (minuteOfDay < 0) return weekly
        return weekly.copy(hour = minuteOfDay / 60, minute = minuteOfDay % 60)
    }

    /**
     * 闹钟入口是否该出现（Dart `_isAlarmAvailable`，`course_action_sheet.dart:1145-1167`）：
     * 这节课的日期算不出来 ⇒ 不出现；已过去的日期 ⇒ 不出现；未来日期 ⇒ 出现；
     * **就是今天** ⇒ 开课前出现、开课后消失。
     *
     * @param courseDate 这节课在本周的真实日期（学期开始日推算；没设开学日 = null）。
     * @param startMinutes 该课在生效作息下的开始钟点（解析失败 = null）。
     */
    fun isAvailable(
        courseDate: LocalDate?,
        startMinutes: Int?,
        now: LocalDateTime,
    ): Boolean {
        if (courseDate == null) return false
        val today = now.toLocalDate()
        return when {
            courseDate.isBefore(today) -> false
            courseDate.isAfter(today) -> true
            else -> startMinutes != null &&
                (now.hour * 60 + now.minute) < startMinutes
        }
    }

    /** 周次摘要（Dart `_weeksSummary`，`class_reminder_sheet.dart:51-56`）：8 周内全列，超过取前 8 加省略号。 */
    fun weeksSummary(course: Course): String {
        val weeks = course.activeWeeks
        if (weeks.isEmpty()) return "—"
        if (weeks.size <= 8) return weeks.joinToString(", ")
        return weeks.take(8).joinToString(", ") + "…"
    }

    /** 确认文案里的「提前 N 分钟」（Dart `_addSystemAlarm` 的 `computedLead` / `effectiveLead`）。 */
    fun effectiveLead(pickedMinuteOfDay: Int, startMinutes: Int, clampedLead: Int): Int =
        if (pickedMinuteOfDay < 0) {
            clampedLead
        } else {
            (startMinutes - pickedMinuteOfDay).coerceIn(0, 120)
        }

    // ---------- 设置键读取（`timetable_settings` 的两个提醒键；读口径 Dart :1746-1747） ----------

    /** `classAlarmLeadMinutes`（缺键 / 非数值回落 30）。 */
    fun leadMinutesFromSettings(settings: Map<*, *>?): Int =
        (settings?.get("classAlarmLeadMinutes") as? Number)?.toInt() ?: 30

    /** `classAlarmSkipUi`（缺键回落 false；非 Boolean 按 false，Dart `lenientBool` 不猜真值）。 */
    fun skipUiFromSettings(settings: Map<*, *>?): Boolean =
        settings?.get("classAlarmSkipUi") as? Boolean ?: false
}

/**
 * 「这节课闹钟」子弹层抛给宿主的事件（弹层自身不起 Intent、不写库）。
 *
 * 与 `CourseActionEvent`（`pages/course` 包，弹层动作事件）分开：这两个动作**不写课程库**，
 * 只碰系统时钟；宿主（壳）负责拼应用名前缀、调 `SystemAlarmHelper` 并弹 toast。
 */
sealed interface ClassAlarmEvent {

    /**
     * 往系统时钟写一枚每周重复闹钟（Dart `SystemAlarmService.addAlarm` 的参数面）。
     *
     * @param courseLabel 交给系统时钟的标签正文（短课名优先，Dart `label`）；
     *   应用名前缀（`轻屿 · `）由宿主拼——渲染层与纯逻辑层都不写应用名字面量。
     */
    data class SetSystemAlarm(
        val hour: Int,
        val minute: Int,
        val courseLabel: String,
        val repeatDays: List<Int>,
        val skipUi: Boolean,
    ) : ClassAlarmEvent

    /** 打开系统时钟的闹钟列表（Dart `SystemAlarmService.openSystemAlarms`）。 */
    object OpenSystemClock : ClassAlarmEvent
}
