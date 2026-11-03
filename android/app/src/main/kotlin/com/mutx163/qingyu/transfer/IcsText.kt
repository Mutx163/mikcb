package com.mutx163.qingyu.transfer

import java.time.LocalDateTime

/**
 * ICS 文本原语（移植自 lib/services/ics_export_service.dart 与
 * lib/services/ics_import_service.dart 的**纯函数**部分，2026-10-26 快照）。
 *
 * 本文件只承载两条 ICS 链路共用、可直接从 Dart 逐行对拍的规则：
 * 转义/反转义、folding（75/74 字节）、时间解析与文件名清洗。
 * 触文件系统/HTTP 的部分不移植（清单见交付说明）。
 *
 * 对齐基准是 **Dart 实现的实际行为**，不是 RFC 5545 教条：
 * - 导出转义顺序是 反斜杠→分号→逗号→换行归一（`\r\n`→`\n`→`\\n`）；
 * - fold 首行 75 字节、续行载荷 74 字节（续行的引导空格占第 75 字节）；
 * - import 侧只对 TEXT 属性集合反转义，`DTSTART`/`RRULE` 原样入库。
 */

/** Dart `String.trim()`：去首尾空白。Dart 的空白清单含 U+00A0（不换行空格）、
 *  U+0085、U+2028/U+2029、U+FEFF 等，比 Kotlin `trim()` 宽，这里逐项列出，
 *  保证两侧对同一个串裁掉同样的字符。判定表一律用 \uXXXX 转义写死，
 *  避免不可见字面量混进 diff。 */
fun dartTrim(value: String): String {
    var start = 0
    var end = value.length
    while (start < end && isDartWhitespace(value[start])) start++
    while (end > start && isDartWhitespace(value[end - 1])) end--
    return value.substring(start, end)
}

/** Dart `String.trim` 的空白判定（Unicode White_Space 全表 + BOM U+FEFF）。 */
private fun isDartWhitespace(c: Char): Boolean = when (c.code) {
    0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, // \t \n \v \f \r 空格
    0x0085, 0x00A0,
    0x1680,
    0x2028, 0x2029, // 行/段分隔符（注意：不含 U+202A/U+202B 方向控制符）
    0x202F, 0x205F, 0x3000, 0xFEFF -> true
    in 0x2000..0x200A -> true // 各种宽度的空格
    else -> false
}

/** 导出侧 `_escapeText`（ics_export_service.dart:673-681）。 */
fun escapeIcsText(value: String): String {
    var out = value
    out = out.replace("\\", "\\\\")
    out = out.replace(";", "\\;")
    out = out.replace(",", "\\,")
    out = out.replace("\r\n", "\n")
    out = out.replace("\r", "\n")
    out = out.replace("\n", "\\n")
    return out
}

/**
 * 导入侧 `unescapeIcsText`（ics_import_service.dart:126-155）。
 * 逐字符一趟扫描：`\\,` = 字面反斜杠 + 普通逗号，replaceAll 链会错解优先级。
 * 结尾孤立反斜杠、未知转义（`\x`）原样保留。
 */
fun unescapeIcsText(value: String): String {
    if (!value.contains('\\')) return value
    val buffer = StringBuilder(value.length)
    var index = 0
    while (index < value.length) {
        val ch = value[index]
        if (ch == '\\' && index + 1 < value.length) {
            val next = value[index + 1]
            when (next) {
                'n', 'N' -> {
                    buffer.append('\n')
                    index += 2
                    continue
                }
                ',', ';', ':', '\\' -> {
                    buffer.append(next)
                    index += 2
                    continue
                }
            }
        }
        buffer.append(ch)
        index++
    }
    return buffer.toString()
}

/**
 * 导入侧折行展开（Dart `ics_import_service.dart` 的 unfold）：以空格/制表符
 * 开头的行拼回上一行（去掉折叠用的首字符）；`\r\n` 先归一到 `\n`。
 *
 * 从已删除的 `transfer/IcsImportParser` 副本挪来——该校验逻辑只有测试在用，
 * 统一收进本文件，避免同一规则再长出第二份实现。
 */
fun unfoldIcsLines(content: String): List<String> {
    val normalized = content.replace("\r\n", "\n")
    val unfolded = mutableListOf<String>()
    for (line in normalized.split("\n")) {
        if ((line.startsWith(" ") || line.startsWith("\t")) && unfolded.isNotEmpty()) {
            unfolded[unfolded.size - 1] = unfolded.last() + line.substring(1)
        } else {
            unfolded.add(line)
        }
    }
    return unfolded
}

/**
 * 导出侧 `_foldLine`（ics_export_service.dart:683-710）。
 * 首行上限 75 字节；一旦折过，后续每段载荷上限 74 字节（第 75 字节是续行
 * 引导空格）；按 UTF-8 字节计，多字节字符不被劈开；空行返回 `[""]`。
 */
fun foldIcsLine(line: String): List<String> {
    if (line.isEmpty()) return listOf("")

    val segments = mutableListOf<String>()
    val buffer = StringBuilder()
    var byteLength = 0
    var maxBytes = 75
    for (rune in codePoints(line)) {
        val character = String(Character.toChars(rune))
        val characterBytes = character.toByteArray(Charsets.UTF_8).size
        if (byteLength > 0 && byteLength + characterBytes > maxBytes) {
            segments.add(buffer.toString())
            buffer.setLength(0)
            byteLength = 0
            maxBytes = 74
        }
        buffer.append(character)
        byteLength += characterBytes
    }
    segments.add(buffer.toString())

    for (index in 1 until segments.size) {
        segments[index] = " ${segments[index]}"
    }
    return segments
}

private fun codePoints(value: String): IntArray {
    val points = IntArray(value.codePointCount(0, value.length))
    var i = 0
    var idx = 0
    while (idx < value.length) {
        val cp = value.codePointAt(idx)
        points[i++] = cp
        idx += Character.charCount(cp)
    }
    return points
}

/**
 * 导出侧 `_parseTime`（ics_export_service.dart:619-643）。
 * 形态 `H+(:mm)(:ss)` 前后空白放宽；只放行**恰好** `24:00`（当天结束）当结束
 * 时间用，`24:30`/`25:00` 一律拒收；24:00 当开始时间非法。
 */
fun parseIcsTime(raw: String, allowEndOfDay: Boolean = false): IcsTimeOfDay? {
    val m = Regex(
        "^[\\s]*(\\d{1,2}):(\\d{2})(?::(\\d{2}))?[\\s]*$"
            .replace("[\\s]", ECMASCRIPT_WS),
    ).find(raw) ?: return null
    val hour = m.groupValues[1].toIntOrNull() ?: return null
    val minute = m.groupValues[2].toIntOrNull() ?: return null
    val second = (m.groupValues[3].ifEmpty { "0" }).toIntOrNull() ?: return null
    if (allowEndOfDay && hour == 24 && minute == 0 && second == 0) {
        return IcsTimeOfDay(24, 0, 0)
    }
    if (hour > 23 || minute > 59 || second > 59) return null
    return IcsTimeOfDay(hour, minute, second)
}

data class IcsTimeOfDay(val hour: Int, val minute: Int, val second: Int)

/** Dart `_dateOnly`（ics_export_service.dart:579-580）。 */
fun icsDateOnly(value: LocalDateTime): LocalDateTime =
    LocalDateTime.of(value.year, value.monthValue, value.dayOfMonth, 0, 0, 0)

/** Dart `_addDays`（ics_export_service.dart:585-592）：日历日加，保留时分秒。 */
fun icsAddDays(date: LocalDateTime, days: Int): LocalDateTime =
    LocalDateTime.of(
        date.year, date.monthValue, 1,
        date.hour, date.minute, date.second,
    ).plusDays((date.dayOfMonth - 1 + days).toLong())

/** Dart `_formatCalendarDate`（ics_export_service.dart:645-649）。 */
fun formatIcsCalendarDate(date: LocalDateTime): String = String.format(
    "%04d-%02d-%02d", date.year, date.monthValue, date.dayOfMonth,
)

/** Dart `_formatCompactCalendarDate`（ics_export_service.dart:651-655）。 */
fun formatIcsCompactDate(date: LocalDateTime): String = String.format(
    "%04d%02d%02d", date.year, date.monthValue, date.dayOfMonth,
)

/** Dart `_formatClock`（ics_export_service.dart:657-661）。 */
fun formatIcsClock(date: LocalDateTime): String = String.format(
    "%02d:%02d:%02d", date.hour, date.minute, date.second,
)

/**
 * Dart `_formatUtcDateTime`（ics_export_service.dart:663-671）。
 * Dart 的 `toUtc()` 是**瞬时换算**：同一瞬间在 UTC 下的墙钟。等价实现是
 * systemDefault → UTC 的换算。
 */
fun formatIcsUtcDateTime(date: LocalDateTime): String {
    val utc = date.atZone(java.time.ZoneId.systemDefault())
        .withZoneSameInstant(java.time.ZoneId.of("UTC"))
    return String.format(
        "%04d%02d%02dT%02d%02d%02dZ",
        utc.year, utc.monthValue, utc.dayOfMonth, utc.hour, utc.minute, utc.second,
    )
}

// Dart RegExp 的 \s 是 ECMAScript 语义（含 NBSP/全角空格/零宽 BOM 等），
// JVM 正则的 \s 只有 ASCII 五个——涉及 \s 的正则一律用这个类显式展开。
internal const val ECMASCRIPT_WS = "[\\t\\n\\u000B\\f\\r \\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000\\uFEFF]"

/** Dart `_sanitizeFileNameSegment`（ics_export_service.dart:726-745）。 */
fun sanitizeIcsFileNameSegment(value: String): String {
    val normalized = dartTrim(value).replace(Regex("$ECMASCRIPT_WS+"), "_")
    val buffer = StringBuilder()
    for (rune in codePoints(normalized)) {
        val isControl = rune < 0x20
        val isUnsafe = rune in "<>:\"/\\|?*".codePoints().toArray()
        buffer.append(if (isControl || isUnsafe) "_" else String(Character.toChars(rune)))
    }
    var safe = buffer.toString().replace(Regex("""_+"""), "_")
    safe = safe.replaceFirst(Regex("""^[ ._]+"""), "")
    safe = safe.replaceFirst(Regex("""[ ._]+$"""), "")
    if (safe.isEmpty()) return "timetable"
    val runes = codePoints(safe)
    if (runes.size > 80) {
        safe = StringBuilder().apply {
            for (r in runes.take(80)) appendCodePoint(r)
        }.toString()
    }
    return safe
}
