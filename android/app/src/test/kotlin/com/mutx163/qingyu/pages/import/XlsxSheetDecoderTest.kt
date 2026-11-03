package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.TimetableSettings
import java.io.ByteArrayOutputStream
import java.util.TimeZone
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `.xlsx` 最小解码器的行为测试（F07 · 2026-10-29）。
 *
 * 本仓**没有** xlsx 解码库，容器解码由 [XlsxSheetDecoder] 自己啃 zip + XML。
 * 这类手写解析最容易悄悄坏（列错位、共享字符串下标错、空列不补），所以这里用
 * **内存里现拼的 zip** 把形状钉死——不依赖任何外部文件，也不用起设备。
 *
 * 覆盖：
 * 1. 共享字符串（`t="s"`）/ 内联字符串（`t="inlineStr"`）/ 数字（无 `t`）；
 * 2. 中间空列要**补空串**（不补就整行左移，课程名会跑到星期列）；
 * 3. XML 实体（`&amp;`）反转义；
 * 4. 坏容器 / 没有工作表的容器 ⇒ `spreadsheet_xlsx_parse_failed`（不返回空表）。
 */
class XlsxSheetDecoderTest {

    @Test
    fun `共享字符串 内联字符串 数字 与空列补齐`() {
        val shared = listOf("课程名", "高数 &amp; 线代")
        val sheet = worksheet(
            row(1, cell(1, 1, sharedIndex = 0), cell(2, 1, inline = "星期"), cell(3, 1, raw = "1")),
            // B2 是空的：只写 A2 与 C2，解码后 B2 必须补成空串而不是让 C2 顶到第 2 列。
            row(2, cell(1, 2, sharedIndex = 1), cell(3, 2, raw = "2")),
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, shared))
        assertEquals(2, rows.size)
        assertEquals(listOf("课程名", "星期", "1"), rows[0])
        assertEquals(listOf("高数 & 线代", "", "2"), rows[1])
    }

    @Test
    fun `行号缺档保留空行 与 Dart 的 rowNumber 口径一致`() {
        val shared = listOf("课程名")
        val sheet = worksheet(
            row(1, cell(1, 1, sharedIndex = 0)),
            // 第 2 行整行没写：Dart `_parseRow` 会补一个空行占位，行号不能塌缩。
            row(3, cell(1, 3, raw = "1")),
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, shared))
        assertEquals(3, rows.size)
        assertEquals(listOf("课程名"), rows[0])
        // 归一化后所有行补齐到表宽：缺档行是「一个空串列」，但仍占行号。
        assertEquals(listOf(""), rows[1])
        assertEquals(listOf("1"), rows[2])
    }

    @Test
    fun `尾部短行按全表最右非空列补齐`() {
        val headers = listOf("课程名称", "星期", "开始节数", "结束节数", "老师", "地点", "周数")
        val shared = headers + listOf("高数")
        val sheet = worksheet(
            row(
                1,
                *headers.indices
                    .map { cell(column = it + 1, rowIndex = 1, sharedIndex = it) }
                    .toTypedArray(),
            ),
            // 数据行只写到第 5 列；Dart `_normalizeTable` 会补到 7 列。
            row(2, cell(1, 2, sharedIndex = 7), cell(2, 2, raw = "1"), cell(5, 2, inline = "李老师")),
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, shared))
        assertEquals(7, rows[1].size)
        assertEquals(listOf("高数", "1", "", "", "李老师", "", ""), rows[1])
        // 补齐后列数检查不再误报「列不足」，而是落到具体字段解析（这里节次为空）。
        val result = SpreadsheetImportModel.parseRows(rows, "课表.xlsx", TimetableSettings.defaults())
        val messages = result.warnings
        assertTrue(messages.toString(), messages.none { "insufficient_columns" in it })
        assertTrue(messages.toString(), messages.any { "field_must_be_integer" in it })
    }

    @Test
    fun `尾部空行裁掉 布尔按 Dart 小写`() {
        val sheet = worksheet(
            row(1, cell(1, 1, raw = "1"), cell(2, 1, boolean = "1")),
            row(2, cell(1, 2, raw = "2"), cell(2, 2, boolean = "0")),
            "<row r=\"3\"></row>",
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, emptyList()))
        assertEquals(2, rows.size)
        assertEquals(listOf("1", "true"), rows[0])
        assertEquals(listOf("2", "false"), rows[1])
    }

    @Test
    fun `解出来的行矩阵能直接喂给表格模型`() {
        // 用 WakeUp 同列的 7 列格式，验证「解码 → parseRows」这条链路端到端成立。
        val headers = listOf("课程名称", "星期", "开始节数", "结束节数", "老师", "地点", "周数")
        val shared = headers + listOf("高等数学", "李老师", "楼A")
        val sheet = worksheet(
            row(
                1,
                *headers.indices
                    .map { cell(column = it + 1, rowIndex = 1, sharedIndex = it) }
                    .toTypedArray(),
            ),
            row(
                2,
                cell(1, 2, sharedIndex = 7),
                cell(2, 2, raw = "1"),
                cell(3, 2, raw = "1"),
                cell(4, 2, raw = "2"),
                cell(5, 2, sharedIndex = 8),
                cell(6, 2, sharedIndex = 9),
                cell(7, 2, inline = "1-16"),
            ),
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, shared))
        val result = SpreadsheetImportModel.parseRows(rows, "课表.xlsx", TimetableSettings.defaults())
        assertEquals(1, result.courses.size)
        val course = result.courses.single()
        assertEquals("高等数学", course.name)
        assertEquals(1, course.dayOfWeek)
        assertEquals(1, course.startSection)
        assertEquals(2, course.endSection)
        assertEquals("李老师", course.teacher)
        assertEquals("楼A", course.location)
        assertEquals(16, course.endWeek)
    }

    @Test
    fun `日期样式按 numFmt 转本地 ISO 基准 1899-12-30 且不认 date1904`() {
        // Dart `XlsxDecoder._parseCell`（`xlsx.dart:409-437`）：
        //   DateTime(1899, 12, 30).add(serial 天).toIso8601String()
        // 基准固定 1900 系统，Dart 根本不读 workbook 的 date1904，这里也必须一致。
        val sheet = worksheet(
            row(
                1,
                cell(1, 1, raw = "0", style = 1),
                cell(2, 1, raw = "60", style = 1),
                cell(3, 1, raw = "61", style = 1),
            ),
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(
            buildXlsx(sheet, emptyList(), stylesXml = styles(0, 14), date1904 = true),
        )
        assertEquals(
            listOf(
                // serial 0：基准当天
                "1899-12-30T00:00:00.000",
                // serial 60：Dart 走公历，没有 Excel 的 1900-02-29 幻影日 → 2 月 28 日
                "1900-02-28T00:00:00.000",
                // serial 61 → 1900-03-01
                "1900-03-01T00:00:00.000",
            ),
            rows[0],
        )
    }

    @Test
    fun `同一个序列号 纯数字与日期样式输出不同`() {
        val sheet = worksheet(
            row(
                1,
                cell(1, 1, raw = "61"),
                cell(2, 1, raw = "61", style = 0),
                cell(3, 1, raw = "61", style = 1),
                cell(4, 1, raw = "1.50"),
                cell(5, 1, raw = "1e3"),
            ),
        )
        val rows = XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, emptyList(), stylesXml = styles(0, 14)))
        assertEquals(
            listOf("61", "61", "1900-03-01T00:00:00.000", "1.5", "1000"),
            rows[0],
        )
    }

    @Test
    fun `时间样式走 HH_mm_ss 且与默认时区无关`() {
        // Dart `DateTime(0)` 是本地零点，取 date.hour/minute/second 拼 HH:mm:ss；
        // Kotlin 用 LocalDateTime 纯日历运算，不查时区，换默认时区结果不变。
        val previous = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Pacific/Kiritimati")) // UTC+14，最容易暴露 Z/本地混用
            val sheet = worksheet(
                row(
                    1,
                    cell(1, 1, raw = "0.5", style = 1),
                    cell(2, 1, raw = "1.25", style = 1),
                    cell(3, 1, raw = "0", style = 1),
                ),
            )
            val rows = XlsxSheetDecoder.decodeFirstSheet(
                buildXlsx(sheet, emptyList(), stylesXml = styles(0, 20)),
            )
            assertEquals(listOf("12:00:00", "06:00:00", "00:00:00"), rows[0])
        } finally {
            TimeZone.setDefault(previous)
        }
    }

    @Test
    fun `日期样式的非法序列号整份报 xlsx 解析失败`() {
        // Dart `num.parse(_parseValue(content))` 抛 FormatException ⇒ 整个 xlsx 解析失败；
        // 不要改成本地兜底成空串，否则多缺陷包的报错优先级与 Dart 不一致。
        val sheet = worksheet(row(1, cell(1, 1, raw = "abc", style = 1)))
        val error = runCatching {
            XlsxSheetDecoder.decodeFirstSheet(buildXlsx(sheet, emptyList(), stylesXml = styles(0, 14)))
        }.exceptionOrNull()
        assertTrue("必须是 FormatException，实际：$error", error is FormatException)
        assertTrue(error!!.message!!.startsWith("spreadsheet_xlsx_parse_failed"))
        assertTrue(error.message!!.contains("invalid numeric cell"))
    }

    @Test
    fun `坏容器报 xlsx 解析失败而不是空表`() {
        val error = runCatching {
            XlsxSheetDecoder.decodeFirstSheet("这不是一个 zip".toByteArray(Charsets.UTF_8))
        }.exceptionOrNull()
        assertTrue("必须是 FormatException，实际：$error", error is FormatException)
        assertTrue(
            "错误码应该是 spreadsheet_xlsx_parse_failed，实际：${error?.message}",
            error!!.message!!.startsWith("spreadsheet_xlsx_parse_failed"),
        )
    }

    @Test
    fun `没有工作表的 zip 也明确报错`() {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            zip.putNextEntry(ZipEntry("docProps/app.xml"))
            zip.write("<app/>".toByteArray(Charsets.UTF_8))
            zip.closeEntry()
        }
        val error = runCatching { XlsxSheetDecoder.decodeFirstSheet(out.toByteArray()) }
            .exceptionOrNull()
        assertTrue(error is FormatException)
        assertTrue(error!!.message!!.startsWith("spreadsheet_xlsx_parse_failed"))
        assertTrue("原因要说清是「找不到工作表」", error.message!!.contains("no worksheet"))
    }

    // ------------------------------------------------------------------
    // zip / xml 拼装（形状与真实 xlsx 一致：`<c r="B2" t="s"><v>3</v></c>`）
    // ------------------------------------------------------------------

    private fun cell(
        column: Int,
        rowIndex: Int,
        sharedIndex: Int? = null,
        inline: String? = null,
        raw: String? = null,
        boolean: String? = null,
        style: Int? = null,
    ): String {
        val ref = "${columnLetter(column)}$rowIndex"
        val styleAttr = style?.let { " s=\"$it\"" }.orEmpty()
        return when {
            sharedIndex != null -> "<c r=\"$ref\" t=\"s\"><v>$sharedIndex</v></c>"
            inline != null -> "<c r=\"$ref\" t=\"inlineStr\"><is><t>$inline</t></is></c>"
            boolean != null -> "<c r=\"$ref\" t=\"b\"><v>$boolean</v></c>"
            raw != null -> "<c r=\"$ref\"$styleAttr><v>$raw</v></c>"
            else -> ""
        }
    }

    /** `cellXfs` 里第 i 个 `xf` 的 `numFmtId`，对应单元格 `s="i"`（与 Dart `_parseStyles` 同构）。 */
    private fun styles(vararg numFmtIds: Int): String =
        "<?xml version=\"1.0\"?><styleSheet><cellXfs count=\"${numFmtIds.size}\">" +
            numFmtIds.joinToString("") { "<xf numFmtId=\"$it\" xfId=\"0\"/>" } +
            "</cellXfs></styleSheet>"

    private fun workbook(workbookPr: String): String =
        "<?xml version=\"1.0\"?><workbook><workbookPr$workbookPr/></workbook>"

    private fun row(index: Int, vararg cells: String): String =
        "<row r=\"$index\">${cells.joinToString("")}</row>"

    private fun worksheet(vararg rows: String): String =
        "<?xml version=\"1.0\"?><worksheet><sheetData>${rows.joinToString("")}</sheetData></worksheet>"

    private fun columnLetter(column: Int): String {
        var value = column
        val letters = StringBuilder()
        while (value > 0) {
            val remainder = (value - 1) % 26
            letters.insert(0, ('A' + remainder))
            value = (value - 1) / 26
        }
        return letters.toString()
    }

    private fun buildXlsx(
        sheetXml: String,
        sharedStrings: List<String>,
        stylesXml: String? = null,
        date1904: Boolean = false,
    ): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            fun put(name: String, content: String) {
                zip.putNextEntry(ZipEntry(name))
                zip.write(content.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
            put("docProps/app.xml", "<app/>")
            put(
                "xl/sharedStrings.xml",
                "<sst>${sharedStrings.joinToString("") { "<si><t>$it</t></si>" }}</sst>",
            )
            if (stylesXml != null) put("xl/styles.xml", stylesXml)
            // date1904 只影响 Excel 自己的显示；Dart 不读它，这里也塞进去做「不认」的负向验证。
            put(
                "xl/workbook.xml",
                workbook(if (date1904) " date1904=\"1\"" else ""),
            )
            put("xl/worksheets/sheet1.xml", sheetXml)
        }
        return out.toByteArray()
    }
}
