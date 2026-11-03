package com.mutx163.qingyu.statistics

import java.util.Locale

/**
 * "HH:MM" 时钟串的容错解析（源：lib/utils/clock_time.dart，逐行移植）。
 *
 * 为什么要单独收口：全仓同类解析几乎都带 parts.length != 2 + int.tryParse
 * 守卫，唯写作息管理页与「快速生成作息」抽屉是裸 int.parse(parts[0])。而
 * SectionTime.fromJson 只要求"非空字符串"，"08.30"、"8"、"上午8点" 都能进库
 * —— 这些值一到 UI 就抛异常。统计侧消费本解析做「按分钟数比较」，
 * 绝不用 String.compareTo（空串比任何值都小、未补零的 8:00 又比 08:00 大）。
 */
data class ClockTime(val hour: Int, val minute: Int) {

    /** 相对当天 00:00 的分钟数，供排序与跨度比较使用（clock_time.dart:51）。 */
    val totalMinutes: Int get() = hour * 60 + minute

    /** 规范化文本形态 HH:MM（clock_time.dart:54-55）。 */
    val formatted: String
        get() = String.format(Locale.ROOT, "%02d:%02d", hour, minute)

    companion object {
        /**
         * 解析失败（缺列、非数字、越界）返回 null，由调用方决定兜底值
         * （clock_time.dart:24-48）。
         *
         * [allowEndOfDay] 只额外放行 `24:00` 这一个值：作息表里晚自习/末节课常写成
         * 24:00 表示「当天结束」，它不是一个合法的钟表时刻，但换算成日期是精确的
         * （次日 00:00）。其余 hour=24 的组合（`24:30`）以及 25 点、60 分一律拒绝 ——
         * 它们会被日期构造**静默归一**到别的日子（25:00 → 次日 01:00、08:75 → 09:15），
         * 界面看不出来，用户却按错的时间到教室。
         */
        fun tryParse(value: String?, allowEndOfDay: Boolean = false): ClockTime? {
            val text = value?.trim() ?: ""
            if (text.isEmpty()) {
                return null
            }
            val parts = text.split(":")
            if (parts.size != 2) {
                return null
            }
            val hour = parts[0].trim().toIntOrNull()
            val minute = parts[1].trim().toIntOrNull()
            if (hour == null || minute == null) {
                return null
            }
            if (minute < 0 || minute > 59) {
                return null
            }
            if (allowEndOfDay && hour == 24 && minute == 0) {
                return ClockTime(24, 0)
            }
            if (hour < 0 || hour > 23) {
                return null
            }
            return ClockTime(hour, minute)
        }
    }
}
