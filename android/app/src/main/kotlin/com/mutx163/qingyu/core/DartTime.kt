package com.mutx163.qingyu.core

import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.util.Locale

/**
 * Dart `DateTime` 语义桥（本机时区、无时区偏移概念）。
 *
 * Dart 的 `DateTime` 是**本地墙上时刻**（不带时区），ISO 字符串在毫秒为 0 时
 * 省略 `.SSS`。Kotlin 侧用 [LocalDateTime] 承载同样的语义；一切加减按
 * **日历日**进行（plusDays），与 Dart `DateTime(y, m, d + n)` 的归一口径一致
 * —— 绝不用「24 小时 × 天数」的绝对时长（夏令时会挪天，见 week_calculator.dart
 * 头注释的事故记录）。
 *
 * 读入口径（D2：双向放宽，历史脏数据都要能读出来）：
 * 1. Dart 会写的格式：`yyyy-MM-ddTHH:mm[:ss][.ffffff]`、基础格式 `yyyyMMdd` /
 *    `yyyyMMddTHHmmss`、带 `Z` / `±HH:mm` / `±HHMM` 时区偏移；
 * 2. 本项目历史上额外容忍的宽松格式：`yyyy-M-d[ H:m[:s]]`、首尾空格。
 *
 * 带偏移的输入按 **本机时区**折算成墙上时刻（`OffsetDateTime.atZoneSameInstant`），
 * 与 Dart `DateTime.parse(...).toLocal()` 同参考系；写出时一律本地、无偏移。
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

    /**
     * Dart `DateTime.tryParse` 的超集：除 Dart 会产出的 ISO 形状（含基础格式与
     * 时区偏移）外，还兼容本项目历史上容忍的空格分隔 / 单数字月日 / 首尾空格。
     * 解析失败返回 null，绝不抛。
     */
    fun tryParseIso(text: String?): LocalDateTime? {
        if (text.isNullOrBlank()) return null
        val raw = text.trim()
        // 基础格式（yyyyMMdd[THH[mm[ss]]]）先展开成扩展 ISO，再走同一套解析，
        // 这样 `20260101T00`、`20260101T00Z`、`20260101 000000` 都能吃下。
        val candidates = listOfNotNull(raw, expandBasicIso(raw)).map { normalizeOffset(it) }
        for (s in candidates) {
            // 1) 标准 ISO 本地时刻（含任意位小数秒），Dart 会写的形状之一。
            runCatching { return LocalDateTime.parse(s) }
            // 2) 带 Z / ±HH:mm / ±HHMM：Dart 视为 UTC 实例，.toLocal() 得到本地墙上时刻。
            runCatching {
                return OffsetDateTime.parse(s)
                    .atZoneSameInstant(ZoneId.systemDefault())
                    .toLocalDateTime()
            }
        }
        // 3) 历史宽松格式（yyyy-M-d[ H[:m[:s]]][.fff]）；月份/日越界按 Dart 构造函数顺延。
        for (s in candidates) {
            LOOSE_ISO.find(s)?.let { m ->
                val (y, mo, d) = m.destructured
                val base = dateTime(
                    y.toInt(),
                    mo.toInt(),
                    d.toInt(),
                    m.groupValues[4].ifEmpty { "0" }.toInt(),
                    m.groupValues[5].ifEmpty { "0" }.toInt(),
                    m.groupValues[6].ifEmpty { "0" }.toInt(),
                )
                return base.withNano(fractionToNanos(m.groupValues[7]))
            }
        }
        return null
    }

    /**
     * 基础 ISO 展开：`20260101` → `2026-01-01`，`20260101T00` → `2026-01-01T00:00`。
     * 非基础格式返回 null（原串继续按扩展/宽松规则解析）。
     */
    private fun expandBasicIso(s: String): String? {
        val m = BASIC_ISO.find(s) ?: return null
        val (y, mo, d) = m.destructured
        val h = m.groupValues[4]
        val mi = m.groupValues[5]
        val sec = m.groupValues[6]
        val frac = m.groupValues[7]
        val offset = m.groupValues[8]
        if (h.isEmpty()) return "$y-$mo-$d"
        val time = buildString {
            append(h).append(':')
            append(if (mi.isEmpty()) "00" else mi).append(':')
            append(if (sec.isEmpty()) "00" else sec)
            if (frac.isNotEmpty()) append('.').append(frac)
        }
        return "$y-$mo-${d}T$time$offset"
    }

    fun parseIso(text: String): LocalDateTime =
        tryParseIso(text) ?: throw DartFormatException("invalid ISO datetime: $text")

    /**
     * Dart `toIso8601String()`：`yyyy-MM-ddTHH:mm:ss.mmm`，微秒非零时输出 6 位。
     *
     * ⚠️ Dart 的实现**恒定**输出毫秒段（`.000`），且在 `microsecond != 0` 时补到
     * 6 位（`DateTime(2026,1,1,0,0,0,0,123456)` → `…T00:00:00.123456`）。Dart
     * 落盘的历史数据就带这种 6 位微秒，Kotlin 必须按同规则写出，否则往返字节不一致。
     * 用 `Locale.ROOT` 固定数字字形（默认 Locale 可能输出本地数字）。
     */
    fun toIso(t: LocalDateTime): String {
        val base = String.format(
            Locale.ROOT,
            "%04d-%02d-%02dT%02d:%02d:%02d",
            t.year, t.monthValue, t.dayOfMonth, t.hour, t.minute, t.second,
        )
        val micros = t.nano / 1_000
        val fraction = if (micros % 1_000 == 0) {
            String.format(Locale.ROOT, "%03d", micros / 1_000)
        } else {
            String.format(Locale.ROOT, "%06d", micros)
        }
        return "$base.$fraction"
    }

    /** 从 epoch 毫秒（系统默认时区）构造本地墙上时刻。 */
    fun fromEpochMillis(millis: Long): LocalDateTime =
        LocalDateTime.ofInstant(java.time.Instant.ofEpochMilli(millis), ZoneId.systemDefault())

    /** Dart `millisecondsSinceEpoch`：本地墙上时刻 → epoch 毫秒（系统默认时区）。 */
    fun toEpochMillis(t: LocalDateTime): Long =
        t.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

    /** 小数秒原文 → 纳秒；超过 6 位按 Dart 的微秒精度截断（再补三个 0）。 */
    private fun fractionToNanos(frac: String): Int {
        if (frac.isEmpty()) return 0
        return frac.padEnd(6, '0').take(6).padEnd(9, '0').toInt()
    }

    /**
     * `+HHMM` → `+HH:MM`：java 的 `ISO_OFFSET_DATE_TIME` 只吃带冒号的偏移，
     * 而 Dart `DateTime.tryParse` 两种都吃（实测 `-0500` 可解析）。
     */
    private fun normalizeOffset(s: String): String {
        val m = OFFSET_NO_COLON.find(s) ?: return s
        val sign = m.groupValues[1]
        val hour = m.groupValues[2]
        val minute = m.groupValues[3]
        return s.substring(0, m.range.first) + sign + hour + ":" + minute
    }

    private val OFFSET_NO_COLON = Regex("""([+-])(\d{2})(\d{2})$""")

    private val BASIC_ISO = Regex(
        """^(\d{4})(\d{2})(\d{2})(?:[T ](\d{2})(\d{2})?(\d{2})?(?:\.(\d{1,9}))?)?(Z|[+-]\d{2}(?::?\d{2})?)?$""",
    )

    private val LOOSE_ISO = Regex(
        """^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2})(?::(\d{1,2})(?::(\d{1,2})(?:\.(\d{1,9}))?)?)?)?$""",
    )
}
