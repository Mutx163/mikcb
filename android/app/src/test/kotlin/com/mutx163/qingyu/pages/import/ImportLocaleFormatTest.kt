package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入落盘键的 Locale 守卫（行为层，配套 `LocaleFormatGuardTest` 的结构扫描）。
 *
 * ## 为什么只测这四处
 *
 * 导入域的日期键 / 时刻键 / 课表指纹会进课表与哈希比较，**一旦跟随系统 Locale
 * 变成阿拉伯数字（ar-EG 的 `٢٠٢٦`、`٠٨:٠٠`），落盘字节就和 Dart 的
 * `padLeft`/`toStringAsFixed` 对不上**，跨端逐字节对拍会静默失败。
 *
 * 对应实现：
 * - `ImportSharedModel.importFormatDate`（学期开始日期键）
 * - `CourseAutoRefreshModel.timetableContentSignature`（课表指纹，内含 `%08x`）
 * - `IcsImportModel` 的 `formatTime`（经公开 `parseWakeUpSchedule` 观察）
 * - `SpreadsheetImportModel.tryParseClockTime`（经公开 `parseBytes` 观察）
 *
 * 每个用例都在 `ar-EG`（阿拉伯数字 Locale）下取产物，**断言仍是 ASCII**，
 * 并在 `finally` 里还原原默认 Locale，避免污染同 JVM 的其他用例。
 */
class ImportLocaleFormatTest {

    private val arabicEgypt = Locale.forLanguageTag("ar-EG")

    /** 在指定默认 Locale 下执行，结束后一定还原（含断言失败时）。 */
    private fun <T> withDefaultLocale(locale: Locale, block: () -> T): T {
        val previous = Locale.getDefault()
        Locale.setDefault(locale)
        return try {
            block()
        } finally {
            Locale.setDefault(previous)
        }
    }

    private fun assertAscii(label: String, text: String) {
        assertTrue("$label 出现非 ASCII 字符：$text", text.all { it.code in 0x00..0x7F })
    }

    private fun course(): Course = Course(
        id = "c1",
        name = "高等数学",
        teacher = "李老师",
        location = "教学楼101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    @Test
    fun `ar-EG 下导入日期键仍是 ASCII`() {
        val text = withDefaultLocale(arabicEgypt) {
            ImportSharedModel.importFormatDate(LocalDateTime.of(2026, 3, 2, 8, 0))
        }
        assertEquals("2026-03-02", text)
        assertAscii("导入日期键", text)
    }

    @Test
    fun `ar-EG 下课表指纹仍是 ASCII 且与 ROOT 同值`() {
        val courses = listOf(course())
        val baseline = withDefaultLocale(Locale.ROOT) {
            CourseAutoRefreshModel.timetableContentSignature(courses)
        }
        val arabic = withDefaultLocale(arabicEgypt) {
            CourseAutoRefreshModel.timetableContentSignature(courses)
        }
        // 同值 = 哈希没有因 Locale 漂移；ASCII = 十六进制没用本地数字。
        assertEquals(baseline, arabic)
        assertTrue("指纹形状不对：$arabic", arabic.matches(Regex("""\d+#[0-9a-f]{8}""")))
        assertAscii("课表指纹", arabic)
    }

    @Test
    fun `ar-EG 下 ICS 时刻仍是 ASCII`() {
        val content = buildString {
            append("BEGIN:VCALENDAR\r\n")
            append("BEGIN:VEVENT\r\n")
            append("SUMMARY:高等数学\r\n")
            append("DTSTART:20260302T080000\r\n")
            append("DTEND:20260302T094000\r\n")
            append("DESCRIPTION:第 1-2 节\\n教学楼101\\n李老师\r\n")
            append("END:VEVENT\r\n")
            append("END:VCALENDAR\r\n")
        }
        val course = withDefaultLocale(arabicEgypt) {
            IcsImportModel.parseWakeUpSchedule(
                content = content,
                now = LocalDateTime.of(2026, 10, 27, 12, 0),
            ).courses.single()
        }
        assertEquals("08:00", course.startTime)
        assertEquals("09:40", course.endTime)
        assertAscii("ICS 开始时刻", course.startTime)
        assertAscii("ICS 结束时刻", course.endTime)
    }

    @Test
    fun `ar-EG 下表格导入时刻仍是 ASCII`() {
        val bytes = listOf(
            "课程名称,星期,开始节数,结束节数,老师,地点,周数",
            "高等数学,1,1,2,李老师,教学楼101,1-16",
        ).joinToString("\r\n").toByteArray(Charsets.UTF_8)
        val course = withDefaultLocale(arabicEgypt) {
            SpreadsheetImportModel.parseBytes(bytes, "a.csv", TimetableSettings.defaults()).courses.single()
        }
        // 第 1 节 08:00-08:45、第 2 节 08:55-09:40（Dart TimetableSettings.defaults）
        assertEquals("08:00", course.startTime)
        assertEquals("09:40", course.endTime)
        assertAscii("表格开始时刻", course.startTime)
        assertAscii("表格结束时刻", course.endTime)
    }
}
