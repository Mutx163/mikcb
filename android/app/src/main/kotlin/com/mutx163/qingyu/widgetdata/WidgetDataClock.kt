package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.statistics.ClockTime
import java.time.LocalDateTime

/**
 * 钟点串纯逻辑（移植 lib/domain/clock_order.dart + LiveActivityLogic 的日期构造口径）。
 *
 * 全部零 IO；时间一律用 [LocalDateTime] 承载 Dart 本地墙上时刻语义（见
 * core/DartTime.kt 头注释），加减按日历日，绝不按 24 小时绝对时长。
 */
object WidgetDataClock {

    /**
     * 按**钟表分钟数**比较两个时间文本，而不是按字符串字典序
     * （clock_order.dart:18-25）。
     *
     * 模型边界不保证时间串是补零的 `HH:mm`（外来存档 `9:00` 常见），
     * 字符串序下 `"10:00" < "9:00"` 会把同节次课程排反。
     * 解析不出来的值排在能解析的值之后；两个都解析不出来时退回字典序，
     * 保证排序全序、稳定、不因一条坏数据抛异常。
     */
    fun compareClockText(left: String, right: String): Int {
        val a = ClockTime.tryParse(left, allowEndOfDay = true)
        val b = ClockTime.tryParse(right, allowEndOfDay = true)
        if (a == null && b == null) return left.compareTo(right)
        if (a == null) return 1
        if (b == null) return -1
        return a.totalMinutes.compareTo(b.totalMinutes)
    }

    /** 钟点串 → 当天分钟数；解析不出来返回 null（clock_order.dart:36-37）。 */
    fun clockTextToMinutes(value: String): Int? =
        ClockTime.tryParse(value, allowEndOfDay = true)?.totalMinutes

    /**
     * Dart `DateTime(date.year, date.month, date.day, h, m)` 口径
     * （LiveActivityLogic.buildCourseDateTime / 快照服务的 _buildCourseDateTime 同源）：
     *
     * - 越界的钟点串必须解析失败，不能交给日期构造静默归一 —— `25:00` 会变成
     *   **次日** 01:00，「下一节课/倒计时」的日期就挪了一天（home_widget_snapshot_service.dart:419-423 注释原文）；
     * - 唯一放行的越界值是 `24:00`（末节课「当天结束」），换算成次日零点，
     *   与 Dart `DateTime(y, m, d, 24, 0)` 的归一结果一致；
     * - 秒与毫秒清零（Dart 五参构造不保留 date 的时分秒）。
     */
    fun courseDateTimeOn(date: LocalDateTime, clock: String): LocalDateTime? {
        val parsed = ClockTime.tryParse(clock, allowEndOfDay = true) ?: return null
        return if (parsed.hour >= 24) {
            LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, 0, 0).plusDays(1)
        } else {
            LocalDateTime.of(date.year, date.monthValue, date.dayOfMonth, parsed.hour, parsed.minute)
        }
    }

    /** Dart `millisecondsSinceEpoch`（本地墙上时刻 → epoch 毫秒）。 */
    fun toEpochMillis(t: LocalDateTime): Long = DartTime.toEpochMillis(t)

    /** Dart `DateTime(y, m, d + 1)`：次日零点（日历日归一，Dart 快照服务 :377）。 */
    fun nextMidnight(now: LocalDateTime): LocalDateTime =
        LocalDateTime.of(now.year, now.monthValue, now.dayOfMonth, 0, 0).plusDays(1)

    /** Dart `LiveTestingFixtureService.formatClock` 的等价物：`HH:mm` 补零。 */
    fun formatClock(time: LocalDateTime): String =
        "%02d:%02d".format(time.hour, time.minute)
}
