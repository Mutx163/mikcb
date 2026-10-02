package com.mutx163.qingyu

import java.util.Calendar

/**
 * 钟点文本的解析口径，与 Dart 侧 `lib/utils/clock_time.dart` 的
 * `ClockTime.tryParse(value, allowEndOfDay: true)` 一一对应。
 *
 * 为什么要单独收口：原生这五份解析
 * （`LiveUpdateScheduler.kt` 的 `liveSchedulerBuildCourseDateTimeMillis` /
 * `buildCourseDateTimeMillis` / `parseClockMinutes`，
 * `LiveUpdateService.kt` 的 `buildCourseTimeMillis`，
 * `TodayWidgetSupport.kt` 的 `buildCourseDateTimeMillis`）
 * 只查了"两段、能转成整数"，从不校验范围。`Calendar.set(HOUR_OF_DAY, 25)`
 * 与 `set(MINUTE, 75)` 是**宽松**的：它们把时间静默推进到
 * 次日 01:00 / 同日的下一小时，调用方拿到的仍是一个"成功"的毫秒数。
 * 于是存量的脏钟点（`SectionTime.fromJson` 只要求非空字符串，
 * 2026-10-02 之前 Dart 侧也没有范围校验）会让超级岛、闹钟与进度里程碑
 * 在错误的时刻触发，而且没有任何一处能看出来。
 *
 * 唯一额外放行的越界值是 `24:00`：作息表里晚自习/末节课用它表示"当天结束"，
 * 换算成日期是精确的（次日零点）。`24:30`、`25:00`、`08:75` 一律拒绝，
 * 返回 null 让调用方跳过这条提醒，而不是按归一后的错误时间排闹钟。
 */
internal object LiveClock {
    /** 一天的分钟数上限，用于 `24:00`。 */
    private const val MINUTES_PER_DAY = 24 * 60

    /**
     * 相对当天 00:00 的分钟数；`24:00` 记为 1440。
     * 不可解析或越界返回 null。
     */
    fun minutesOfDay(value: String?): Int? {
        val parts = value?.split(":") ?: return null
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].trim().toIntOrNull() ?: return null
        val minute = parts[1].trim().toIntOrNull() ?: return null
        if (minute < 0 || minute > 59) {
            return null
        }
        if (hour < 0 || hour > 24) {
            return null
        }
        if (hour == 24 && minute != 0) {
            return null
        }
        return hour * 60 + minute
    }

    /**
     * 把 [value] 落到 [dateCalendar] 那一天的毫秒（秒与毫秒清零）。
     * `24:00` 顺延到次日零点；不可解析或越界返回 null。
     */
    fun toMillis(dateCalendar: Calendar, value: String?): Long? {
        val minutes = minutesOfDay(value) ?: return null
        return Calendar.getInstance().apply {
            timeInMillis = dateCalendar.timeInMillis
            set(Calendar.HOUR_OF_DAY, if (minutes >= MINUTES_PER_DAY) 0 else minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (minutes >= MINUTES_PER_DAY) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }.timeInMillis
    }

    /** 把 [value] 落到 [baseMillis] 所在那一天的毫秒；语义同 [toMillis]。 */
    fun toMillis(baseMillis: Long, value: String?): Long? =
        toMillis(
            Calendar.getInstance().apply { timeInMillis = baseMillis },
            value,
        )

    /** 把 [value] 落到"今天"的毫秒；其余语义同 [toMillis]。 */
    fun toTodayMillis(value: String?): Long? {
        return toMillis(Calendar.getInstance(), value)
    }
}
