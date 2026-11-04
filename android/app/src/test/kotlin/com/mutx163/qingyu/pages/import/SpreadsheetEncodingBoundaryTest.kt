package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 表格导入的编码 / 换行边界（2026-11-04，L1 表格导入）。
 *
 * 每条用例都写上 Dart 对应行为：
 * - 有对应实现 → 引 `table_parser-1.0.1/lib/src/csv.dart` 或
 *   `lib/services/spreadsheet_import_service.dart` 行号；
 * - 两侧同解 / 两侧都没有 → 直接写在用例注释里，避免下个人当缺口重做。
 */
class SpreadsheetEncodingBoundaryTest {

    private val settings = TimetableSettings.defaults()
    private val header = "课程名称,星期,开始节数,结束节数,老师,地点,周数"
    private val row = "高等数学,1,1,2,李老师,教学楼101,1-16"

    private fun parse(bytes: ByteArray) =
        SpreadsheetImportModel.parseBytes(bytes, "课表.csv", settings)

    /** 去掉随机 id 后的可对拍形状。 */
    private fun shape(course: Course): List<Any?> = listOf(
        course.name,
        course.teacher,
        course.location,
        course.dayOfWeek,
        course.startSection,
        course.endSection,
        course.startTime,
        course.endTime,
        course.startWeek,
        course.endWeek,
        course.activeWeeks.joinToString(","),
    )

    private fun shapes(bytes: ByteArray): List<List<Any?>> = parse(bytes).courses.map(::shape)

    // ------------------------------------------------------------------
    // 1. CRLF vs LF
    // ------------------------------------------------------------------

    @Test
    fun `CRLF 与 LF 的解析结果逐字段相同`() {
        // Dart `CsvDecoder._parseContent`：`_csvContent.split(RegExp(r'\r?\n'))`
        // （table_parser-1.0.1/lib/src/csv.dart:56）；Kotlin 同一句在
        // SpreadsheetImportModel.kt:343。两侧同解。
        val crlf = "$header\r\n$row\r\n".toByteArray(Charsets.UTF_8)
        val lf = "$header\n$row\n".toByteArray(Charsets.UTF_8)

        assertEquals(shapes(crlf), shapes(lf))
        assertEquals(1, parse(lf).courses.size)
    }

    // ------------------------------------------------------------------
    // 2. UTF-8 BOM
    // ------------------------------------------------------------------

    @Test
    fun `带 UTF-8 BOM 的 CSV 仍能识别表头`() {
        // Dart `String.trim()` 的空白清单含 BOM U+FEFF（dart-sdk `lib/core/string.dart:380-397`），
        // 所以 `_isHeaderRow` 里的 `row[i].trim()`（spreadsheet_import_service.dart:313）
        // 会把首格 BOM 去掉。Kotlin `String.trim()` 不含 U+FEFF，此前会误报
        // 「格式无法识别」——真差异已修：解码入口剥首字节 BOM（SpreadsheetImportModel.decodeCsvRows）。
        val withBom = "\uFEFF$header\r\n$row\r\n".toByteArray(Charsets.UTF_8)

        val result = parse(withBom)
        assertEquals(SpreadsheetImportModel.FORMAT_WAKEUP, result.format)
        assertEquals(1, result.courses.size)
        assertEquals(shapes(withBom), shapes("$header\r\n$row\r\n".toByteArray(Charsets.UTF_8)))
    }

    // ------------------------------------------------------------------
    // 3. GBK（无编码声明）
    // ------------------------------------------------------------------

    @Test
    fun `无编码声明的 GBK 文件按 GBK 兜底解析`() {
        // Dart：UTF-8 宽容解码认不出格式 → `gbk.decode(bytes)` 再试
        // （spreadsheet_import_service.dart:219-241）；Kotlin 同序
        // （SpreadsheetImportModel.kt:280-306）。两侧同解。
        val gbk = "$header\r\n$row\r\n".toByteArray(charset("GBK"))

        val result = parse(gbk)
        assertEquals(SpreadsheetImportModel.FORMAT_WAKEUP, result.format)
        assertEquals(1, result.courses.size)
        assertEquals("高等数学", result.courses.single().name)
        assertEquals("李老师", result.courses.single().teacher)
        assertEquals("教学楼101", result.courses.single().location)
    }

    // ------------------------------------------------------------------
    // 4. 末行无换行
    // ------------------------------------------------------------------

    @Test
    fun `末行没有换行符不影响解析`() {
        // 两侧都先 `split(RegExp(r'\r?\n'))`（csv.dart:56），split 不需要结尾分隔符。
        // 两侧同解，没有额外实现。
        val withTrailing = "$header\r\n$row\r\n".toByteArray(Charsets.UTF_8)
        val withoutTrailing = "$header\r\n$row".toByteArray(Charsets.UTF_8)

        assertEquals(shapes(withTrailing), shapes(withoutTrailing))
    }

    // ------------------------------------------------------------------
    // 5. 空文件
    // ------------------------------------------------------------------

    @Test
    fun `零字节文件报编码或格式无法识别`() {
        // Dart `_tryParseCsvContent`：`decoder.tables.isEmpty` → null
        // （spreadsheet_import_service.dart:260-262），UTF-8/GBK 都不成 →
        // throw `spreadsheet_format_or_encoding_unrecognized`（同文件 :240）。两侧同解。
        val error = runCatching { SpreadsheetImportModel.decodeCsvRows(ByteArray(0)) }.exceptionOrNull()

        assertTrue("必须是 FormatException，实际：$error", error is FormatException)
        assertEquals("spreadsheet_format_or_encoding_unrecognized", (error as FormatException).message)
    }

    // ------------------------------------------------------------------
    // 6. 只有表头
    // ------------------------------------------------------------------

    @Test
    fun `只有表头时识别出格式且课程为空`() {
        // Dart：`_detectFormat` 成功 → `detected.format` 原样返回，数据区间为空
        // （spreadsheet_import_service.dart:127-173）。两侧同解。
        val result = parse("$header\r\n".toByteArray(Charsets.UTF_8))

        assertEquals(SpreadsheetImportModel.FORMAT_WAKEUP, result.format)
        assertTrue(result.courses.isEmpty())
        assertTrue(result.warnings.isEmpty())
    }

    // ------------------------------------------------------------------
    // 7. 只有元信息行（补充，属「只有表头」的畸形变体）
    // ------------------------------------------------------------------

    @Test
    fun `只有元信息行时报格式无法识别`() {
        // Dart `_detectFormat`：`_isMetadataRow(rows.first)` 且 `rows.length < 2` → null
        // （spreadsheet_import_service.dart:180-184），外层抛 `spreadsheet_format_unrecognized`
        // （同文件 :129）。两侧同解。
        val markerOnly = "# mikcb-course-import-v1\r\n".toByteArray(Charsets.UTF_8)
        val error = runCatching { parse(markerOnly) }.exceptionOrNull()

        assertTrue("必须是 FormatException，实际：$error", error is FormatException)
        assertEquals("spreadsheet_format_unrecognized", (error as FormatException).message)
    }
}
