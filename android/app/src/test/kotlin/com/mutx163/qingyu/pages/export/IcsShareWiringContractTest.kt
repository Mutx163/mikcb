package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.transfer.IcsCalendarEvent
import com.mutx163.qingyu.transfer.IcsExportEventKind
import com.mutx163.qingyu.transfer.IcsSerializer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.TimeZone

/**
 * ICS「生成 → 分享」接线层（[IcsShareWiring] / [IcsShareRequest]）的**契约测试** —— I3。
 *
 * 钉的是「页面把生成的 .ics 交给分享适配器时，**分享请求载荷**长什么样」：
 * 正文（IcsSerializer 产物）/ MIME（`text/calendar`）/ 建议文件名，直接断言实例字段，
 * 不走 UI、不碰 Android。这一层断言的正是 `platform/` 适配器（进不了单测 classpath）无法覆盖的配对。
 *
 * **期望值全部手推，不从 Kotlin 实现里抄**：
 * - ICS 正文：`IcsSerializer.serializeCalendar` 的头部顺序 + RFC 5545 常量手写在
 *   `expectedEmptyCalendar()` 里（日期 `yyyy-MM-dd`、`GENERATED-AT` 是 UTC 紧凑时刻）；
 * - 建议文件名：Dart `buildFileName` 规则手推（"2026 春" 的空格折 `_` → `2026_春`，日期 `yyyyMMdd`）；
 * - MIME：`text/calendar` 是 RFC 5545 给 iCalendar 的标准类型。
 */
class IcsShareWiringContractTest {

    private val appId = "com.mutx163.qingyu"

    // 2026-03-02 是周一，2026-07-05 是周日（与 IcsShareLogicTest 同一组区间，便于对照文件名）。
    private val from = LocalDate.of(2026, 3, 2)
    private val to = LocalDate.of(2026, 7, 5)

    // 固定时钟，避免 GENERATED-AT / DTSTAMP 依赖真实时间。
    private val generatedAt = LocalDateTime.of(2026, 3, 1, 12, 0, 0)

    /** 与序列化器口径一致的空日历正文；逐行手写，行间 CRLF，文件以 CRLF 收尾。 */
    private fun expectedEmptyCalendar(calendarName: String): String = listOf(
        "BEGIN:VCALENDAR",
        "PRODID:-//Mutx163//Qingyu Timetable//EN",
        "VERSION:2.0",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-TIMEZONE:UTC",
        "X-MIKCB-SOURCE:Qingyu Timetable",
        // generatedAt = 2026-03-01 12:00 的 UTC 紧凑形态（测试里把默认时区固定成 UTC，见 inUtc）。
        "X-MIKCB-GENERATED-AT:20260301T120000Z",
        "X-MIKCB-DATE-RANGE:2026-03-02/2026-07-05",
        "X-WR-CALNAME:$calendarName",
        "END:VCALENDAR",
    ).joinToString("\r\n") + "\r\n"

    /** 把默认时区临时固定成 UTC，让 GENERATED-AT / DTSTAMP 的 UTC 换算可复现。 */
    private fun <T> inUtc(block: () -> T): T {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
            return block()
        } finally {
            TimeZone.setDefault(original)
        }
    }

    // ── 1. 正文：序列化产物逐字节进入分享请求 ──

    @Test
    fun `分享请求的正文就是序列化产物（逐字节、含空日历头部）`() {
        val request = inUtc {
            IcsShareWiring.requestFromEvents(
                calendarName = "2026 春",
                fromDateTime = from.atStartOfDay(),
                toDateTime = to.atStartOfDay(),
                generatedAt = generatedAt,
                events = emptyList(),
                applicationId = appId,
                profileName = "2026 春",
                from = from,
                to = to,
            )
        }
        // 整串相等：头部顺序、CRLF、结尾换行都要对得上，任何一处漂移都红。
        assertEquals(expectedEmptyCalendar("2026 春"), request.content)
        assertTrue(request.content.startsWith("BEGIN:VCALENDAR\r\n"))
        assertTrue(request.content.endsWith("END:VCALENDAR\r\n"))
    }

    @Test
    fun `正文不做 trim，结尾 CRLF 必须保留`() {
        // 序列化器产出以 CRLF 收尾；若接线层顺手 trim()，目标应用会打不开/排版错。
        val content = "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"
        val request = IcsShareWiring.requestFromSerialized(content, appId, "任意", from, to)
        assertEquals(content, request.content)
        assertTrue(request.content.endsWith("\r\n"))
    }

    @Test
    fun `事件逐条进入正文（SUMMARY 与 UID 都在）`() {
        val event = IcsCalendarEvent(
            uid = "uid-1@qingyu-timetable.local",
            kind = IcsExportEventKind.COURSE,
            start = LocalDateTime.of(2026, 3, 2, 8, 0, 0),
            end = LocalDateTime.of(2026, 3, 2, 9, 40, 0),
            summary = "高等数学",
            location = "教1-101",
        )
        val request = inUtc {
            IcsShareWiring.requestFromEvents(
                calendarName = "2026 春",
                fromDateTime = from.atStartOfDay(),
                toDateTime = to.atStartOfDay(),
                generatedAt = generatedAt,
                events = listOf(event),
                applicationId = appId,
                profileName = "2026 春",
                from = from,
                to = to,
            )
        }
        assertTrue(request.content.contains("BEGIN:VEVENT"))
        assertTrue(request.content.contains("UID:uid-1@qingyu-timetable.local"))
        assertTrue(request.content.contains("SUMMARY:高等数学"))
    }

    @Test
    fun `两个入口（先序列化再组装 与 一步到位）产出的正文一致`() {
        val viaEvents = inUtc {
            IcsShareWiring.requestFromEvents(
                calendarName = "2026 春",
                fromDateTime = from.atStartOfDay(),
                toDateTime = to.atStartOfDay(),
                generatedAt = generatedAt,
                events = emptyList(),
                applicationId = appId,
                profileName = "2026 春",
                from = from,
                to = to,
            )
        }
        val serialized = inUtc {
            IcsSerializer.serializeCalendar(
                calendarName = "2026 春",
                fromDate = from.atStartOfDay(),
                toDate = to.atStartOfDay(),
                generatedAt = generatedAt,
                events = emptyList(),
            )
        }
        val viaSerialized = IcsShareWiring.requestFromSerialized(serialized, appId, "2026 春", from, to)
        assertEquals(viaSerialized.content, viaEvents.content)
        assertEquals(viaSerialized, viaEvents)
    }

    // ── 2. 类型：恒为 text/calendar ──

    @Test
    fun `分享请求的类型恒为 text-calendar`() {
        val request = IcsShareWiring.requestFromSerialized(
            "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n",
            appId,
            "2026 春",
            from,
            to,
        )
        assertEquals("text/calendar", request.mimeType)
        assertEquals("text/calendar", request.spec.mimeType)
    }

    // ── 3. 建议文件名：由课表名 + 区间派生 ──

    @Test
    fun `建议文件名由课表名加起止日期派生`() {
        val request = IcsShareWiring.requestFromSerialized(
            "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n",
            appId,
            "2026 春",
            from,
            to,
        )
        // "2026 春" 的空格按 Dart 规则折成下划线 → 2026_春；日期补零成 8 位
        assertEquals("2026_春-20260302-20260705.ics", request.fileName)
        // 落盘相对路径必须落在 provider 覆盖的 ics-export/ 目录里
        assertEquals("ics-export/2026_春-20260302-20260705.ics", request.spec.localRelativePath)
    }

    // ── 4. 空正文：拒绝组装（不把空文件交给适配器） ──

    @Test
    fun `空正文被拒绝组装`() {
        assertThrows(IllegalArgumentException::class.java) {
            IcsShareWiring.requestFromSerialized("", appId, "2026 春", from, to)
        }
        assertThrows(IllegalArgumentException::class.java) {
            IcsShareWiring.requestFromSerialized("   \r\n  ", appId, "2026 春", from, to)
        }
    }

    // ── 5. 契约其余字段与适配器口径对齐 ──

    @Test
    fun `请求契约的 authority 与文案跟适配器口径一致`() {
        val request = IcsShareWiring.requestFromSerialized(
            "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n",
            appId,
            "2026 春",
            from,
            to,
        )
        // manifest 里 ${applicationId}.fileprovider 的口径
        assertEquals("com.mutx163.qingyu.fileprovider", request.spec.providerAuthority)
        // ARB 里已存在的分享附言 / 主题（本批不新造文案）
        assertEquals("这是来自轻屿课表的日历文件", request.spec.text)
        assertEquals("轻屿课表日历", request.spec.subject)
        assertEquals("text/calendar", request.spec.mimeType)
    }
}
