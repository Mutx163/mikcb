package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import java.time.Duration
import java.time.LocalDateTime

/**
 * 「课表自动更新」判定真源（P3-G1 · 移植
 * `lib/domain/course_auto_refresh_decision.dart` + `course_timetable_signature.dart`
 * + `course_auto_refresh_store.dart` 的纯逻辑部分）。
 *
 * 这里只有纯 Kotlin（不 import Compose/Android），因为「上一次成功是什么时候 →
 * 现在该不该跑」这类逻辑一旦写在页面里就只能靠真机调时间验证。
 *
 * ## 为什么判据是「上次成功」而不是「上次尝试」
 *
 * 判据取「上次成功」+ 独立的失败冷却：只看尝试时间的话，一次网络抖动就把
 * 整个时间窗推后一整天；只看成功时间、不设失败冷却，则失败后每次切回前台
 * 都重试，教务那边会被反复登录。
 */
enum class CourseAutoRefreshMode(val serialName: String) {
    /** 每次打开软件时。 */
    EVERY_LAUNCH("everyLaunch"),

    /** 每隔 N 小时（距上次成功）。 */
    INTERVAL_HOURS("intervalHours"),

    /** 每天固定时刻之后。 */
    DAILY_AT("dailyAt");

    companion object {
        fun fromName(name: String?): CourseAutoRefreshMode =
            entries.firstOrNull { it.serialName == name } ?: EVERY_LAUNCH
    }
}

/** 判定结论。 */
enum class CourseAutoRefreshDecision {
    /** 该抓了。 */
    RUN,

    /** 还没到点（或冷却中），本次跳过。 */
    WAIT,

    /** 用户没开这个功能。 */
    DISABLED,
}

/** 一次自动更新的结局（与判定分开：没到点=安静跳过，跑失败=该提示用户）。 */
enum class CourseAutoRefreshOutcome {
    /** 功能关着。 */
    DISABLED,

    /** 还没到时间窗（或失败冷却中），本次没跑。 */
    NOT_DUE,

    /** 本机没有可用的快捷导入记录（用户还没录制过宏），静默跳过。必须与 FAILED 分开。 */
    NO_SOURCE,

    /** 上一次自动更新还没结束。 */
    BUSY,

    /** 跑完了，课表内容没有变化。 */
    UNCHANGED,

    /** 跑完了，课表内容确实变了。 */
    UPDATED,

    /** 跑了但失败（教务不可达、需要手动登录、会话超时等）。 */
    FAILED,
}

/** 自动更新的一份配置（与存储解耦的值对象）。 */
data class CourseAutoRefreshSchedule(
    val enabled: Boolean = false,
    val mode: CourseAutoRefreshMode = CourseAutoRefreshMode.EVERY_LAUNCH,
    val intervalHours: Int = CourseAutoRefreshModel.DEFAULT_INTERVAL_HOURS,
    val dailyMinuteOfDay: Int = CourseAutoRefreshModel.DEFAULT_DAILY_MINUTE,
) {

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "enabled" to enabled,
        "mode" to mode.serialName,
        "intervalHours" to intervalHours,
        "dailyMinuteOfDay" to dailyMinuteOfDay,
    )

    companion object {
        /**
         * 容错解析：任何一项坏了都退回默认值，绝不让一条脏配置把整个功能变成
         * 「永远不跑」或「每次打开都跑」。
         */
        fun fromJson(raw: Any?): CourseAutoRefreshSchedule {
            if (raw !is Map<*, *>) {
                return CourseAutoRefreshSchedule()
            }
            val hours = raw["intervalHours"]
            val minute = raw["dailyMinuteOfDay"]
            return CourseAutoRefreshSchedule(
                enabled = raw["enabled"] == true,
                mode = CourseAutoRefreshMode.fromName(raw["mode"] as? String),
                intervalHours = CourseAutoRefreshModel.clampIntervalHours(
                    (hours as? Long)?.toInt() ?: CourseAutoRefreshModel.DEFAULT_INTERVAL_HOURS,
                ),
                dailyMinuteOfDay = CourseAutoRefreshModel.clampDailyMinute(
                    (minute as? Long)?.toInt() ?: CourseAutoRefreshModel.DEFAULT_DAILY_MINUTE,
                ),
            )
        }

        fun fromJsonString(text: String): CourseAutoRefreshSchedule =
            fromJson(MiniJson.tryParse(text))
    }
}

object CourseAutoRefreshModel {

    /** 「每次打开」模式的冷却：距上次成功不足这段时间就不再抓。 */
    val LAUNCH_COOLDOWN: Duration = Duration.ofMinutes(30)

    /** 失败后的重试冷却：冷却期内一律安静等待。 */
    val RETRY_COOLDOWN: Duration = Duration.ofMinutes(30)

    /** 间隔模式的小时上下限与默认值。 */
    const val MIN_INTERVAL_HOURS = 1
    const val MAX_INTERVAL_HOURS = 168
    const val DEFAULT_INTERVAL_HOURS = 24

    /** 每天定时的默认时刻（分钟数，从 0 点起算）：07:30。 */
    const val DEFAULT_DAILY_MINUTE = 7 * 60 + 30

    /** 把用户给的间隔小时夹进合法区间（存档损坏 / 手改 JSON 都走这里）。 */
    fun clampIntervalHours(hours: Int): Int = hours.coerceIn(MIN_INTERVAL_HOURS, MAX_INTERVAL_HOURS)

    /** 把用户给的「一天中的第几分钟」归一成 0..1439。 */
    fun clampDailyMinute(minuteOfDay: Int): Int = minuteOfDay.coerceIn(0, 24 * 60 - 1)

    /**
     * 判定：现在该不该跑一次自动更新。
     *
     * [now] / [lastSuccess] / [lastAttempt] 一律是**同一时区的本地时间**。
     */
    fun decideCourseAutoRefresh(
        schedule: CourseAutoRefreshSchedule,
        now: LocalDateTime,
        lastSuccess: LocalDateTime?,
        lastAttempt: LocalDateTime?,
    ): CourseAutoRefreshDecision {
        if (!schedule.enabled) {
            return CourseAutoRefreshDecision.DISABLED
        }

        // 上一次尝试失败（尝试晚于成功）：冷却期内不再打扰。
        val lastAttemptFailed =
            lastAttempt != null &&
                (lastSuccess == null || lastAttempt.isAfter(lastSuccess))
        if (lastAttemptFailed &&
            Duration.between(lastAttempt, now) < RETRY_COOLDOWN
        ) {
            return CourseAutoRefreshDecision.WAIT
        }

        return when (schedule.mode) {
            CourseAutoRefreshMode.EVERY_LAUNCH -> {
                if (lastSuccess != null && Duration.between(lastSuccess, now) < LAUNCH_COOLDOWN) {
                    CourseAutoRefreshDecision.WAIT
                } else {
                    CourseAutoRefreshDecision.RUN
                }
            }
            CourseAutoRefreshMode.INTERVAL_HOURS -> {
                if (lastSuccess == null) {
                    CourseAutoRefreshDecision.RUN
                } else if (Duration.between(lastSuccess, now) < Duration.ofHours(schedule.intervalHours.toLong())) {
                    CourseAutoRefreshDecision.WAIT
                } else {
                    CourseAutoRefreshDecision.RUN
                }
            }
            CourseAutoRefreshMode.DAILY_AT -> {
                val target = mostRecentDailySlot(now, schedule.dailyMinuteOfDay)
                if (lastSuccess == null) {
                    CourseAutoRefreshDecision.RUN
                } else if (lastSuccess.isBefore(target)) {
                    CourseAutoRefreshDecision.RUN
                } else {
                    CourseAutoRefreshDecision.WAIT
                }
            }
        }
    }

    /**
     * 最近一次已经过去的当日时刻（含今天这一档；今天还没到就用昨天那一档）。
     *
     * 跨零点后要用**昨天**的档去比上次成功，否则 0:00～07:29 这段时间里
     * 「今天那一档还没到」会被读成「已经跑过了」，一整天都不再更新。
     */
    fun mostRecentDailySlot(now: LocalDateTime, minuteOfDay: Int): LocalDateTime {
        val startOfToday = LocalDateTime.of(now.year, now.monthValue, now.dayOfMonth, 0, 0)
        val todaySlot = startOfToday.plusMinutes(minuteOfDay.toLong())
        return if (now.isBefore(todaySlot)) {
            todaySlot.minusDays(1)
        } else {
            todaySlot
        }
    }

    /**
     * 下一次「到点」的时刻（界面用来显示「下次约 …」）。
     * 返回 null 表示不会自动跑（功能关着）。
     */
    fun nextRunAt(
        schedule: CourseAutoRefreshSchedule,
        lastSuccessAt: LocalDateTime?,
        now: LocalDateTime,
    ): LocalDateTime? {
        if (!schedule.enabled) {
            return null
        }
        return when (schedule.mode) {
            CourseAutoRefreshMode.EVERY_LAUNCH -> {
                if (lastSuccessAt == null) now else lastSuccessAt.plus(LAUNCH_COOLDOWN)
            }
            CourseAutoRefreshMode.INTERVAL_HOURS -> {
                if (lastSuccessAt == null) {
                    now
                } else {
                    lastSuccessAt.plus(Duration.ofHours(schedule.intervalHours.toLong()))
                }
            }
            CourseAutoRefreshMode.DAILY_AT -> {
                val startOfToday = LocalDateTime.of(now.year, now.monthValue, now.dayOfMonth, 0, 0)
                val todaySlot = startOfToday.plusMinutes(schedule.dailyMinuteOfDay.toLong())
                // 已经抓过今天这一档：下次就是明天同一时刻。
                if (lastSuccessAt != null && !lastSuccessAt.isBefore(todaySlot)) {
                    todaySlot.plusDays(1)
                } else {
                    todaySlot
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 课表内容指纹
    // ------------------------------------------------------------------

    /**
     * 课表内容的**内容指纹**：判断「这次自动更新到底有没有改到课表」。
     *
     * 只收**用户看得见、且教务会改**的字段；刻意不收 id/颜色/备注——这些是
     * 本机编辑物或随机分配物，收进来会让「只是重新导入了一遍颜色」被判成
     * 「有新课程」。顺序无关（先排序再拼）。
     */
    fun timetableContentSignature(courses: List<Course>): String {
        if (courses.isEmpty()) {
            return "empty"
        }
        val rows = courses.map { course ->
            listOf(
                course.name.trim(),
                course.teacher.trim(),
                course.location.trim(),
                course.dayOfWeek.toString(),
                course.startSection.toString(),
                course.endSection.toString(),
                course.startWeek.toString(),
                course.endWeek.toString(),
                if (course.isOddWeek) "o" else "-",
                if (course.isEvenWeek) "e" else "-",
                weeks(course.customWeeks),
                weeks(course.suspendedWeeks),
                if (course.hasCustomTime) "${course.startTime}-${course.endTime}" else "-",
            ).joinToString("|")
        }.sorted()
        return "${rows.size}#${fnv1a32(rows.joinToString("\n"))}"
    }

    private fun weeks(weeks: List<Int>?): String {
        if (weeks.isNullOrEmpty()) {
            return "-"
        }
        return weeks.sorted().joinToString(",")
    }

    /**
     * FNV-1a 32 位。**不用 `String.hashCode`**：JVM/Dart 的字符串哈希都不保证
     * 跨进程稳定，既写不进测试期望值，也认不出「隔一次启动一比就全都不一样」
     * 这种假变化。逐 UTF-16 码元计算，与 Dart `codeUnits` 遍历同口径。
     */
    private fun fnv1a32(text: String): String {
        var hash = 0x811c9dc5L
        for (unit in text) { // Char = 一个 UTF-16 码元
            hash = hash xor unit.code.toLong()
            hash = hash * 0x01000193L and 0xffffffffL
        }
        return "%08x".format(hash)
    }
}
