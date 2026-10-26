package com.mutx163.qingyu.transfer

import java.time.LocalDateTime

/**
 * ICS VCALENDAR 序列化（移植自 lib/services/ics_export_service.dart 的
 * `_serializeCalendar`，ics_export_service.dart:492-538）。
 *
 * 纯函数：只做「头部 + 事件 + 尾部 → 文本」的拼装。头部的 GENERATED-AT 与
 * DTSTAMP 由调用方传入（Dart 侧 generatedAt 显式注入或时钟兜底，这里把时钟
 * 留在 IO 层），行间一律 CRLF，文件以 CRLF 结尾。
 */
object IcsSerializer {

    const val PRODID = "-//Mutx163//Qingyu Timetable//EN"

    /**
     * 序列化课程事件为完整 VCALENDAR 文本。
     *
     * [calendarName] 对应 Dart 的 `'${profile.name.trim()} $from - $to'.trim()`
     * （profile 名已 trim 的形态由调用方拼好传入；这里只做转义）。
     */
    fun serializeCalendar(
        calendarName: String,
        fromDate: LocalDateTime,
        toDate: LocalDateTime,
        generatedAt: LocalDateTime,
        events: List<IcsCalendarEvent>,
    ): String {
        val from = formatIcsCalendarDate(fromDate)
        val to = formatIcsCalendarDate(toDate)
        val lines = mutableListOf(
            "BEGIN:VCALENDAR",
            "PRODID:$PRODID",
            "VERSION:2.0",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-TIMEZONE:UTC",
            "X-MIKCB-SOURCE:Qingyu Timetable",
            "X-MIKCB-GENERATED-AT:${formatIcsUtcDateTime(generatedAt)}",
            "X-MIKCB-DATE-RANGE:$from/$to",
            "X-WR-CALNAME:${escapeIcsText(calendarName)}",
        )

        for (event in events) {
            lines.add("BEGIN:VEVENT")
            lines.add("UID:${event.uid}")
            lines.add("DTSTAMP:${formatIcsUtcDateTime(generatedAt)}")
            lines.add("DTSTART:${formatIcsUtcDateTime(event.start)}")
            lines.add("DTEND:${formatIcsUtcDateTime(event.end)}")
            lines.add("SUMMARY:${escapeIcsText(event.summary)}")
            if (icsHasText(event.location)) {
                lines.add("LOCATION:${escapeIcsText(dartTrim(event.location!!))}")
            }
            if (icsHasText(event.description)) {
                lines.add("DESCRIPTION:${escapeIcsText(dartTrim(event.description!!))}")
            }
            lines.add("X-MIKCB-EVENT-TYPE:${event.kind.value}")
            lines.add("END:VEVENT")
        }
        lines.add("END:VCALENDAR")

        val folded = mutableListOf<String>()
        for (line in lines) {
            folded.addAll(foldIcsLine(line))
        }
        return folded.joinToString("\r\n") + "\r\n"
    }
}
