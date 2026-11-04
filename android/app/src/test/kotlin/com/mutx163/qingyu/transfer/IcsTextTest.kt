package com.mutx163.qingyu.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * ICS 文本原语端口测试（dart 源：lib/services/ics_export_service.dart、
 * lib/services/ics_import_service.dart；抄录用例：test/services/ics_export_service_test.dart、
 * test/services/ics_text_unescape_test.dart、test/services/ics_export_end_of_day_test.dart）。
 *
 * 期望值来源标注：[Dart抄录] = 从既有 Dart 测试原样搬；
 * [Dart推演] = 按 Dart 实现手工推演；[人推] = 独立人工推算。
 */
class IcsTextTest {

    // ------------------------------------------------------------------
    // escapeIcsText（ics_export_service.dart:673-681）
    // ------------------------------------------------------------------

    @Test
    fun escape_comma_semicolon_backslash_newline() {
        // [Dart抄录] ics_export_service_test.dart:266-268
        assertEquals("中文\\,课程\\;专题\\\\路径", escapeIcsText("中文,课程;专题\\路径"))
        assertEquals("A101\\,主楼\\;\\\\南区", escapeIcsText("A101,主楼;\\南区"))
        // [Dart抄录] :269-271 —— \r\n 先归一成 \n，再转义成字面 \\n
        assertEquals("第一行\\n第二行\\,备注\\;\\\\路径", escapeIcsText("第一行\n第二行,备注;\\路径"))
        // [Dart推演] 单独的 \r（老 Mac 风格）同样归一
        assertEquals("a\\nb", escapeIcsText("a\rb"))
    }

    @Test
    fun escape_plain_text_verbatim() {
        // [人推] 无特殊字符时原样返回
        assertEquals("高等数学", escapeIcsText("高等数学"))
        assertEquals("", escapeIcsText(""))
    }

    // ------------------------------------------------------------------
    // unescapeIcsText（ics_import_service.dart:126-155）
    // ------------------------------------------------------------------

    @Test
    fun unescape_restores_comma_semicolon_colon_newline() {
        // [Dart抄录] ics_text_unescape_test.dart:32-45（该期望值是走完整解析链
        // 含 cleanSummary 后的课程名；裸 unescape 不剥 [16][必修] 尾巴，
        // 那是 cleanSummary 的职责（由 IcsImportModel 负责，见 pages/import 的用例）
        assertEquals("高等数学, 实验[16][必修]", unescapeIcsText("高等数学\\, 实验[16][必修]"))
        assertEquals("教一, 202", unescapeIcsText("教一\\, 202"))
        assertEquals("王;老师", unescapeIcsText("王\\;老师"))
        // [Dart抄录] :47-62 —— \n 转真换行
        assertEquals("a\nb", unescapeIcsText("a\\nb"))
        // [Dart推演] 大写 \N 也是合法换行转义（Dart switch 有 'N' 分支）
        assertEquals("a\nb", unescapeIcsText("a\\Nb"))
        // [Dart推演] \: 在 TEXT 值里转冒号
        assertEquals("a:b", unescapeIcsText("a\\:b"))
    }

    @Test
    fun unescape_double_backslash_stops_escape_chain() {
        // [Dart抄录] ics_text_unescape_test.dart:65-76 —— `\\n` 是字面反斜杠 + n
        assertEquals("编译原理\\n实验", unescapeIcsText("编译原理\\\\n实验"))
        assertEquals("C\\主楼", unescapeIcsText("C\\主楼"))
    }

    @Test
    fun unescape_unknown_and_trailing_backslash_verbatim() {
        // [Dart抄录] ics_text_unescape_test.dart:78-85
        assertEquals("高等数学[16][必修]", unescapeIcsText("高等数学[16][必修]"))
        assertEquals("无转义 A101", unescapeIcsText("无转义 A101"))
        assertEquals("尾反斜杠\\", unescapeIcsText("尾反斜杠\\"))
        assertEquals("\\x", unescapeIcsText("\\x"))
    }

    @Test
    fun unescape_is_inverse_of_escape_for_text() {
        // [人推] 转义→反转义应还原原文（含换行）
        val original = "高数,线代;C楼\\101\n第二行"
        assertEquals(original, unescapeIcsText(escapeIcsText(original)))
    }

    // ------------------------------------------------------------------
    // foldIcsLine（ics_export_service.dart:683-710）
    // ------------------------------------------------------------------

    @Test
    fun fold_empty_line_returns_single_empty_segment() {
        // [Dart抄录] ics_export_service.dart:684-686
        assertEquals(listOf(""), foldIcsLine(""))
    }

    @Test
    fun fold_short_line_stays_unfolded() {
        // [Dart推演] 75 字节以内不折
        val line = "A".repeat(75)
        assertEquals(listOf(line), foldIcsLine(line))
    }

    @Test
    fun fold_breaks_at_octet_boundary_with_leading_space() {
        // [Dart推演] 76 字节 → 首段 75 字节，续行 " " + 剩 1 字节
        val folded = foldIcsLine("A".repeat(76))
        assertEquals(2, folded.size)
        assertEquals("A".repeat(75), folded[0])
        assertEquals(" " + "A", folded[1])
    }

    @Test
    fun fold_multibyte_characters_never_split() {
        // [Dart推演] 「长」3 字节：首段 25 字（75 字节），此后每段 24 字（72 字节）
        val line = "长".repeat(120)
        val folded = foldIcsLine(line)
        assertEquals(25, folded[0].length)
        assertEquals(75, folded[0].toByteArray(Charsets.UTF_8).size)
        for (segment in folded.drop(1)) {
            assertTrue(segment.startsWith(" "))
            assertTrue(segment.toByteArray(Charsets.UTF_8).size <= 75)
        }
        // 每段载荷（去引导空格）不超过 74 字节
        for (segment in folded.drop(1)) {
            assertTrue(
                segment.substring(1).toByteArray(Charsets.UTF_8).size <= 74,
            )
        }
        // 拼回去 = 原文（续行剥掉引导空格）
        val joined = folded[0] + folded.drop(1).joinToString("") { it.substring(1) }
        assertEquals(line, joined)
    }

    @Test
    fun fold_segments_byte_budget() {
        // [Dart推演] 长行折出的每一段（含续行空格）都不超过 75 字节
        val line = "SUMMARY:" + "备注内容".repeat(80)
        for (segment in foldIcsLine(line)) {
            assertTrue(segment.toByteArray(Charsets.UTF_8).size <= 75)
        }
    }

    // ------------------------------------------------------------------
    // parseIcsTime（ics_export_service.dart:619-643）
    // ------------------------------------------------------------------

    @Test
    fun parseTime_plain_forms() {
        // [Dart抄录] ics_export_service_test.dart:216-217（事件用 09:00/11:00）
        assertEquals(IcsTimeOfDay(9, 0, 0), parseIcsTime("09:00"))
        assertEquals(IcsTimeOfDay(8, 0, 0), parseIcsTime("08:00"))
        // [Dart推演] 带秒
        assertEquals(IcsTimeOfDay(23, 30, 45), parseIcsTime("23:30:45"))
        // [Dart推演] 正则 \s 放宽首尾空白
        assertEquals(IcsTimeOfDay(8, 5, 0), parseIcsTime(" 8:05 "))
    }

    @Test
    fun parseTime_end_of_day_rules() {
        // [Dart抄录] ics_export_end_of_day_test.dart:65-85
        assertEquals(IcsTimeOfDay(24, 0, 0), parseIcsTime("24:00", allowEndOfDay = true))
        assertNull("24:00 当开始时间非法", parseIcsTime("24:00"))
        assertNull("24:30 任何位置都非法", parseIcsTime("24:30", allowEndOfDay = true))
        assertNull("25:00 非法", parseIcsTime("25:00", allowEndOfDay = true))
    }

    @Test
    fun parseTime_malformed_rejected() {
        // [Dart推演] 分钟必须两位；非数字；缺列
        assertNull(parseIcsTime("8:5"))
        assertNull(parseIcsTime("上午8点"))
        assertNull(parseIcsTime("08.30"))
        assertNull(parseIcsTime(""))
        assertNull(parseIcsTime("08:75"))
        assertNull(parseIcsTime("08:00:61"))
    }

    // ------------------------------------------------------------------
    // 日期/时刻格式化
    // ------------------------------------------------------------------

    @Test
    fun formatCalendarDate_and_compact_and_clock() {
        // [Dart推演] padLeft 对齐行为
        assertEquals("2026-03-02", formatIcsCalendarDate(LocalDateTime.of(2026, 3, 2, 0, 0)))
        assertEquals("20260302", formatIcsCompactDate(LocalDateTime.of(2026, 3, 2, 0, 0)))
        assertEquals("08:05:09", formatIcsClock(LocalDateTime.of(2026, 3, 2, 8, 5, 9)))
    }

    @Test
    fun formatUtcDateTime_matches_instant_conversion() {
        // [语义锚] Dart toUtc() 是瞬时换算；期望值用 java.time 独立换算
        // （不经过被测函数），两者一致即通过。
        val local = LocalDateTime.of(2026, 4, 1, 12, 34, 56)
        val expected = java.time.ZonedDateTime.of(local, java.time.ZoneId.systemDefault())
            .withZoneSameInstant(java.time.ZoneId.of("UTC"))
        val expectedText = String.format(
            "%04d%02d%02dT%02d%02d%02dZ",
            expected.year, expected.monthValue, expected.dayOfMonth,
            expected.hour, expected.minute, expected.second,
        )
        assertEquals(expectedText, formatIcsUtcDateTime(local))
        // [人推] UTC 时刻的尾标 Z 恒在
        assertTrue(formatIcsUtcDateTime(local).endsWith("Z"))
    }

    // ------------------------------------------------------------------
    // sanitizeIcsFileNameSegment（ics_export_service.dart:726-745）
    // ------------------------------------------------------------------

    @Test
    fun sanitize_replaces_whitespace_and_unsafe_chars() {
        // [Dart抄录] ics_export_service_test.dart:274-303 的文件名断言素材
        // （名字里含 / : ? 空格）
        assertEquals("主课表_2026_秋季", sanitizeIcsFileNameSegment("主课表/2026: 秋季?"))
        // [Dart推演] 反斜杠与竖线同样替换
        assertEquals("a_b_c", sanitizeIcsFileNameSegment("a\\b|c"))
    }

    @Test
    fun sanitize_edge_cases() {
        // [Dart推演] 空/全空白 → timetable
        assertEquals("timetable", sanitizeIcsFileNameSegment(""))
        assertEquals("timetable", sanitizeIcsFileNameSegment("   "))
        // [Dart推演] 首尾的空格/点/下划线被剥掉
        assertEquals("课表", sanitizeIcsFileNameSegment("  .课表._ "))
        // [Dart推演] 连续下划线压缩
        assertEquals("a_b", sanitizeIcsFileNameSegment("a____b"))
        // [Dart推演] 保留超过 80 个码点 → 截到 80（码点数，不是字节）
        val longName = "课".repeat(100)
        assertEquals(80, sanitizeIcsFileNameSegment(longName).length)
        // [Dart推演] 控制字符（<0x20）替换为下划线
        assertEquals("a_b", sanitizeIcsFileNameSegment("a\u0007b"))
    }

    // ------------------------------------------------------------------
    // dartTrim（Dart String.trim 语义）
    // ------------------------------------------------------------------

    @Test
    fun dartTrim_trims_dart_whitespace() {
        // [人推] Dart "  a  ".trim() == "a"
        assertEquals("a", dartTrim("  a  "))
        // [Dart推演] U+00A0（不换行空格）是 Dart 的空白，Kotlin trim() 也裁，
        // 但 U+2028/U+2029/U+FEFF 只有 Dart 语义裁；这里至少钉住 U+00A0。
        assertEquals("a", dartTrim("\u00A0a\u00A0"))
        // [Dart推演] Kotlin trim 会裁 \u000B/\u000C 之外还裁 \u001C-\u001F，
        // Dart 不裁这些——钉一个反例防实现偷用 trim()。
        assertEquals("\u001Fa", dartTrim("\u001Fa"))
        assertFalse(dartTrim("\u2028a\u2029").let { it.contains('\u2028') || it.contains('\u2029') })
    }
}
