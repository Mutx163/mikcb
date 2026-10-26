package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Dart `DateTime` 语义桥（本机时区、无时区偏移概念）。
 *
 * Dart 的 `DateTime` 是**本地墙上时刻**（不带时区），ISO 字符串在毫秒为 0 时
 * 省略 `.SSS`。Kotlin 侧用 [LocalDateTime] 承载同样的语义；一切加减按
 * **日历日**进行（plusDays），与 Dart `DateTime(y, m, d + n)` 的归一口径一致
 * —— 绝不用「24 小时 × 天数」的绝对时长（夏令时会挪天，见 week_calculator.dart
 * 头注释的事故记录）。
 *
 * Kotlin 侧实现按 JVM 精度只能到毫秒（Dart 有微秒），本族所有持久化字段
 * （toIso8601String 往返）都只到毫秒精度，够用。
 */
object DartTime {

    /** Dart DateTime(y, m, d, h, min[, s, ms])：各字段越界按日历顺延（2026-02-30 → 03-02）。 */
    fun dateTime(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0, millis: Int = 0): LocalDateTime =
        LocalDateTime.of(year, 1, 1, hour, minute, second, millis * 1_000_000)
            .plusMonths((month - 1).toLong())
            .plusDays((day - 1).toLong())

    /** Dart `dateTime.add(Duration(days: n))` 的**日历日**等价（保留时分秒）。 */
    fun addDays(t: LocalDateTime, days: Int): LocalDateTime = t.plusDays(days.toLong())

    fun addDays(t: LocalDateTime, days: Long): LocalDateTime = t.plusDays(days)

    /** Dart `weekday`：周一=1 … 周日=7（java.time 同口径）。 */
    fun dayOfWeekOf(t: LocalDateTime): Int = t.dayOfWeek.value

    /** Dart `DateTime.parse` / `tryParse` 的宽容子集：`yyyy-MM-ddTHH:mm:ss`（.SSS 可选）。 */
    fun tryParseIso(text: String?): LocalDateTime? {
        if (text.isNullOrBlank()) return null
        return try {
            LocalDateTime.parse(text.trim())
        } catch (_: Exception) {
            try {
                LocalDateTime.parse(text.trim(), DateTimeFormatter.ofPattern("yyyy-M-d H:m:s"))
            } catch (_: Exception) {
                try {
                    LocalDateParseOnly.parse(text.trim())
                } catch (_: Exception) {
                    null
                }
            }
        }
    }

    fun parseIso(text: String): LocalDateTime =
        tryParseIso(text) ?: throw DartFormatException("invalid ISO datetime: $text")

    /**
     * Dart `toIso8601String()`：`yyyy-MM-ddTHH:mm:ss.mmm`。
     *
     * ⚠️ Dart 的实现**恒定**输出 3 位毫秒（microsecond == 0 时省略的是微秒段，
     * 毫秒段 .mmm 永远在场），所以 `DateTime(2026,1,1).toIso8601String()` 是
     * `2026-01-01T00:00:00.000` 而不是 `…T00:00:00`。序列化契约按 Dart 逐字对齐。
     */
    fun toIso(t: LocalDateTime): String {
        val base = "%04d-%02d-%02dT%02d:%02d:%02d".format(
            t.year, t.monthValue, t.dayOfMonth, t.hour, t.minute, t.second,
        )
        val ms = t.nano / 1_000_000
        return "$base.${"%03d".format(ms)}"
    }

    /** 从 epoch 毫秒（系统默认时区）构造本地墙上时刻。 */
    fun fromEpochMillis(millis: Long): LocalDateTime =
        LocalDateTime.ofInstant(java.time.Instant.ofEpochMilli(millis), java.time.ZoneId.systemDefault())

    /** Dart `millisecondsSinceEpoch`：本地墙上时刻 → epoch 毫秒（系统默认时区）。 */
    fun toEpochMillis(t: LocalDateTime): Long =
        t.atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()

    private object LocalDateParseOnly {
        fun parse(text: String): LocalDateTime {
            val m = Regex("""^(\d{4})-(\d{1,2})-(\d{1,2})$""").find(text)
                ?: throw DartFormatException("bad date: $text")
            val (y, mo, d) = m.destructured
            return dateTime(y.toInt(), mo.toInt(), d.toInt())
        }
    }
}
