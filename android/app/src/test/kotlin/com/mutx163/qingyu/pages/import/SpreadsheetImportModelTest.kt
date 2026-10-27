package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 表格课表解析模型测试（P3-G1 · spreadsheet_course_import_screen.dart +
 * spreadsheet_import_service.dart + week_expression_parser.dart）。
 *
 * 期望值按 Dart 源手推，定向反例按 TEST-POLICY：空文件、超长、格式错、
 * 字段缺失、重复内容行（重复行各成课、坏行落警告）。
 *
 * 节次表用 Dart `TimetableSettings.defaults()`（10 节，第 1 节 08:00-08:45、
 * 第 2 节 08:55-09:40、第 3 节 10:00-10:45、第 4 节 10:55-11:40）。
 */
class SpreadsheetImportModelTest {

    private val settings = TimetableSettings.defaults()

    private fun csv(vararg lines: String): ByteArray = lines.joinToString("\r\n").toByteArray(Charsets.UTF_8)

    private val wakeupHeader = "课程名称,星期,开始节数,结束节数,老师,地点,周数"

    // ==========================================
    // 1. 空文件（定向反例）
    // ==========================================

    @Test
    fun `零字节 CSV 抛编码无法识别`() {
        try {
            SpreadsheetImportModel.parseBytes(ByteArray(0), "a.csv", settings)
            throw AssertionError("应抛出 FormatException")
        } catch (expected: com.mutx163.qingyu.core.FormatException) {
            assertEquals("spreadsheet_format_or_encoding_unrecognized", expected.message)
        }
    }

    @Test
    fun `只有空行的 CSV 抛格式无法识别`() {
        try {
            SpreadsheetImportModel.parseBytes("\r\n\r\n".toByteArray(Charsets.UTF_8), "a.csv", settings)
            throw AssertionError("应抛出 FormatException")
        } catch (expected: com.mutx163.qingyu.core.FormatException) {
            assertEquals("spreadsheet_format_unrecognized", expected.message)
        }
    }

    @Test
    fun `表头不认识的 CSV 抛格式无法识别`() {
        try {
            SpreadsheetImportModel.parseBytes(csv("随便,什么,列"), "a.csv", settings)
            throw AssertionError("应抛出 FormatException")
        } catch (expected: com.mutx163.qingyu.core.FormatException) {
            assertEquals("spreadsheet_format_unrecognized", expected.message)
        }
    }

    // ==========================================
    // 2. WakeUp 7 列格式
    // ==========================================

    @Test
    fun `WakeUp 七列基础行解析出完整课程`() {
        val bytes = csv(
            wakeupHeader,
            "高等数学,1,1,2,李老师,教学楼101,1-16",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(SpreadsheetImportModel.FORMAT_WAKEUP, result.format)
        assertTrue(result.warnings.isEmpty())
        assertEquals(1, result.courses.size)
        val course = result.courses[0]
        assertEquals("高等数学", course.name)
        assertEquals(1, course.dayOfWeek)
        assertEquals(1, course.startSection)
        assertEquals(2, course.endSection)
        assertEquals("李老师", course.teacher)
        assertEquals("教学楼101", course.location)
        // 时间取自默认节次表：第 1 节开始 08:00，**第 2 节结束** 09:40
        // （Dart spreadsheet_import_service.dart:631 `isStart ? startTime : endTime`：
        //  结束时间取的是 `sections[endSection-1].endTime`，不是开始节的结束时间）
        assertEquals("08:00", course.startTime)
        assertEquals("09:40", course.endTime)
        assertEquals((1..16).toList(), course.normalizedCustomWeeks)
        assertEquals(1, course.startWeek)
        assertEquals(16, course.endWeek)
        assertTrue(course.id.startsWith("spreadsheet-"))
        // Dart SpreadsheetImportResult.requiredSectionCount = max(endSection)，不是周数
        assertEquals(2, result.requiredSectionCount)
    }

    @Test
    fun `WakeUp 周数带单双周后缀按奇偶过滤`() {
        val bytes = csv(wakeupHeader, "大学英语,2,3,4,,,(单)3-5")
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        // 手推：(单) 为全局 parity、单 token → 3..5 里留奇数 → [3,5]
        assertEquals(listOf(3, 5), course.normalizedCustomWeeks)
        assertEquals(3, course.startWeek)
        assertEquals(5, course.endWeek)
        assertEquals("10:00", course.startTime) // 第 3 节开始
        assertEquals("11:40", course.endTime) // 第 4 节**结束**（Dart 同口径）
    }

    @Test
    fun `WakeUp 老师地点的无与横线归一为空串`() {
        val bytes = csv(wakeupHeader, "体育,3,5,6,无,-,1-2")
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        assertEquals("", course.teacher)
        assertEquals("", course.location)
    }

    @Test
    fun `重复数据行各成一条课`() {
        val bytes = csv(
            wakeupHeader,
            "高等数学,1,1,2,李老师,教学楼101,1-16",
            "高等数学,1,1,2,李老师,教学楼101,1-16",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(2, result.courses.size)
        assertTrue(result.warnings.isEmpty())
    }

    // ==========================================
    // 3. 字段缺失 / 值非法（定向反例）
    // ==========================================

    @Test
    fun `列数不足的行落行级警告且不中断后续行`() {
        val bytes = csv(
            wakeupHeader,
            "高等数学,1,1,2,李老师",
            "大学英语,2,3,4,王老师,楼201,3-5",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(1, result.courses.size)
        assertEquals(1, result.warnings.size)
        // Dart 的 _parseWakeUpDataRow 抛 FormatException(encodeServiceMessage(...))，
        // 外层按行 catch 后再包一层 `spreadsheet_row_warning|rowNumber=N|inner=<原码>`，
        // 原码自身也带 rowNumber/columnCount → inner 里出现重复的 rowNumber。
        // 这是服务层真实产出（spreadsheet_import_service.dart:330-335 + 行级捕获）。
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=spreadsheet_wakeup_insufficient_columns" +
                "|rowNumber=2|columnCount=5",
            result.warnings[0],
        )
        assertEquals(4, result.requiredSectionCount) // 只按成功行的 endSection（3-5 行末节 4）
    }

    @Test
    fun `课程名为空的行落警告`() {
        val bytes = csv(wakeupHeader, ",1,1,2,李老师,楼,1-2")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertTrue(result.courses.isEmpty())
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=course_name_required",
            result.warnings[0],
        )
    }

    @Test
    fun `星期越界的行落警告`() {
        val bytes = csv(wakeupHeader, "高等数学,8,1,2,李老师,楼,1-2")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=weekday_must_be_1_to_7",
            result.warnings[0],
        )
    }

    @Test
    fun `非整数的节次与起始节小于 1 的行落警告`() {
        val bytes = csv(wakeupHeader, "高等数学,一,1,2,李老师,楼,1-2")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=field_must_be_integer|field=weekday",
            result.warnings[0],
        )

        val bytes2 = csv(wakeupHeader, "高等数学,1,0,2,李老师,楼,1-2")
        val result2 = SpreadsheetImportModel.parseBytes(bytes2, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=field_must_be_at_least_1|field=start_section",
            result2.warnings[0],
        )

        val bytes3 = csv(wakeupHeader, "高等数学,1,3,2,李老师,楼,1-2")
        val result3 = SpreadsheetImportModel.parseBytes(bytes3, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=field_cannot_be_less_than|startField=start_section|endField=end_section",
            result3.warnings[0],
        )
    }

    @Test
    fun `周次为空或无法识别的行落警告`() {
        val bytes = csv(wakeupHeader, "高等数学,1,1,2,李老师,楼,")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=custom_weeks_required",
            result.warnings[0],
        )

        val bytes2 = csv(wakeupHeader, "高等数学,1,1,2,李老师,楼,abc")
        val result2 = SpreadsheetImportModel.parseBytes(bytes2, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=week_token_unrecognized|itemName=第 2 行周数|token=abc",
            result2.warnings[0],
        )
    }

    @Test
    fun `节次超出节次表的行落警告`() {
        val bytes = csv(wakeupHeader, "高等数学,1,11,12,李老师,楼,1-2")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=section_out_of_range|section=11|maxSection=10",
            result.warnings[0],
        )
    }

    @Test
    fun `小数形状的整数被收下`() {
        // Dart _readInt: 3.0 → 3；3.5 → null
        val bytes = csv(wakeupHeader, "高等数学,1,1.0,2.0,李老师,楼,1-2")
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        assertEquals(1, course.startSection)
        assertEquals(2, course.endSection)
    }

    // ==========================================
    // 4. 超长内容（定向反例）
    // ==========================================

    @Test
    fun `超长课程名与超长单元格不炸解析`() {
        val longName = "课".repeat(50_000)
        val longTeacher = "师".repeat(50_000)
        val bytes = csv(wakeupHeader, "$longName,1,1,2,$longTeacher,楼,1-2")
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        assertEquals(50_000, course.name.length)
        assertEquals(50_000, course.teacher.length)
    }

    // ==========================================
    // 5. mikcb 模板格式（列映射 / 表头识别）
    // ==========================================

    private val mikcbHeader = "课程名,星期,开始节,结束节,上课周,教师,教室,颜色,简称,备注"

    @Test
    fun `元信息行之后的表头被识别`() {
        val bytes = csv(
            "# mikcb-course-import-v1",
            mikcbHeader,
            "高数,1,1,2,1-8,李老师,教1,#F00,数,",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(SpreadsheetImportModel.FORMAT_MIKCB, result.format)
        val course = result.courses.single()
        assertEquals("高数", course.name)
        // #F00 → CSS 规则展开成 6 位
        assertEquals("#FF0000", course.color)
        assertEquals("数", course.shortName)
        assertEquals((1..8).toList(), course.normalizedCustomWeeks)
    }

    @Test
    fun `表头别名 课程名称 与 开始节数 同样识别`() {
        val bytes = csv(
            "课程名称,星期,开始节数,结束节数,周数",
            "高数,1,1,2,1-4",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(SpreadsheetImportModel.FORMAT_MIKCB, result.format)
        assertEquals(1, result.courses.size)
    }

    @Test
    fun `范围周次列带单双周与停课周`() {
        val bytes = csv(
            "课程名,星期,开始节,结束节,开始周,结束周,单周,停课周,颜色",
            "高数,1,1,2,1,9,是,3,#ABCDEF",
        )
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        assertEquals(1, course.startWeek)
        assertEquals(9, course.endWeek)
        assertTrue(course.isOddWeek)
        assertTrue(!course.isEvenWeek)
        assertEquals(listOf(3), course.normalizedSuspendedWeeks)
        assertEquals("#ABCDEF", course.color)
    }

    @Test
    fun `范围周次超学期被钳制并出警告`() {
        val bytes = csv(
            "课程名,星期,开始节,结束节,开始周,结束周",
            "高数,1,1,2,1,25",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        val course = result.courses.single()
        assertEquals(20, course.endWeek) // semesterWeekCount = 20
        assertEquals(
            "spreadsheet_end_week_clamped|rowNumber=2|endWeek=25|semesterWeekCount=20",
            result.warnings.single(),
        )
    }

    @Test
    fun `范围周次起始周非法的行落警告`() {
        val header = "课程名,星期,开始节,结束节,开始周,结束周"

        val startZero = SpreadsheetImportModel.parseBytes(csv(header, "高数,1,1,2,0,9"), "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=start_week_must_be_at_least_1",
            startZero.warnings.single(),
        )

        val exceeds = SpreadsheetImportModel.parseBytes(csv(header, "高数,1,1,2,21,25"), "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=start_week_exceeds_semester|startWeek=21|semesterWeekCount=20",
            exceeds.warnings.single(),
        )

        val inverted = SpreadsheetImportModel.parseBytes(csv(header, "高数,1,1,2,5,3"), "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=end_week_before_start_week",
            inverted.warnings.single(),
        )
    }

    @Test
    fun `单双周同时为真时保留单周并出警告`() {
        val bytes = csv(
            "课程名,星期,开始节,结束节,开始周,结束周,单周,双周",
            "高数,1,1,2,1,9,是,是",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        val course = result.courses.single()
        assertTrue(course.isOddWeek)
        assertTrue(!course.isEvenWeek)
        assertEquals("spreadsheet_odd_even_both|rowNumber=2", result.warnings.single())
    }

    @Test
    fun `既无上课周也无范围周的行落警告`() {
        // 表头必须带周次列（否则 _isMikcbFormat 判否、整表格式识别失败，
        // 根本走不到行级警告）；本用例要的是**数据行**该列为空。
        val bytes = csv("课程名,星期,开始节,结束节,上课周", "高数,1,1,2,")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=weeks_range_required",
            result.warnings.single(),
        )
    }

    @Test
    fun `自定义时间列畸形值回落节次表时间`() {
        val bytes = csv(
            "课程名,星期,开始节,结束节,上课周,开始时间,结束时间",
            "高数,1,1,2,1-4,25:00,8:5",
        )
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        // 25:00 解析失败 → 回落第 1 节开始 08:00；8:5 → 08:05
        assertEquals("08:00", course.startTime)
        assertEquals("08:05", course.endTime)
    }

    @Test
    fun `颜色列非法形状回落默认蓝`() {
        val header = "课程名,星期,开始节,结束节,上课周,颜色"
        val fiveHex = SpreadsheetImportModel.parseBytes(csv(header, "高数,1,1,2,1-4,#12345"), "a.csv", settings)
        assertEquals("#2196F3", fiveHex.courses.single().color)
        val none = SpreadsheetImportModel.parseBytes(csv(header, "高数,1,1,2,1-4,无"), "a.csv", settings)
        assertEquals("#2196F3", none.courses.single().color)
    }

    @Test
    fun `课程性质列识别选修`() {
        val bytes = csv(
            "课程名,星期,开始节,结束节,上课周,性质",
            "高数,1,1,2,1-4,选修",
            "英语,2,3,4,1-4,elective",
            "体育,3,5,6,1-4,必选",
        )
        val courses = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses
        assertEquals("ELECTIVE", courses[0].courseNature.name)
        assertEquals("ELECTIVE", courses[1].courseNature.name)
        assertEquals("REQUIRED", courses[2].courseNature.name)
    }

    @Test
    fun `空数据行被跳过`() {
        val bytes = csv(wakeupHeader, "", "高等数学,1,1,2,李老师,楼,1-2", "")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(1, result.courses.size)
        assertTrue(result.warnings.isEmpty())
    }

    // ==========================================
    // 6. CSV 引号语法（RFC4180）
    // ==========================================

    @Test
    fun `带引号字段内的逗号不当分隔符`() {
        // 对齐 Dart test/services/spreadsheet_import_service_test.dart:293-311。
        // WakeUp 7 列格式：课程名,星期,开始节数,结束节数,老师,地点,周数
        val bytes = csv(wakeupHeader, "数据结构进阶,1,1,2,\"王,老师\",C302,1-8")
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        assertEquals("数据结构进阶", course.name)
        assertEquals("王,老师", course.teacher)
        assertEquals("C302", course.location)
    }

    @Test
    fun `成对双引号转义为字面引号`() {
        // Dart 同例：`"编译原理""实验"` → 编译原理"实验
        val bytes = csv(wakeupHeader, "\"编译原理\"\"实验\",2,3,4,周老师,D001,1-8")
        val course = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings).courses.single()
        assertEquals("编译原理\"实验", course.name)
    }

    // ==========================================
    // 7. GBK 编码兜底
    // ==========================================

    @Test
    fun `GBK 编码的 UTF8 无法识别文件按 GBK 解析成功`() {
        val text = "$wakeupHeader\r\n高等数学,1,1,2,李老师,楼,1-2\r\n"
        val gbkBytes = text.toByteArray(charset("GBK"))
        val result = SpreadsheetImportModel.parseBytes(gbkBytes, "a.csv", settings)
        assertEquals(SpreadsheetImportModel.FORMAT_WAKEUP, result.format)
        assertEquals(1, result.courses.size)
        assertEquals("高等数学", result.courses[0].name)
    }

    // ==========================================
    // 8. xlsx 边界与 requiredSectionCount
    // ==========================================

    @Test
    fun `xlsx 字节流在模型层按未支持容器给出明确报错`() {
        // Kotlin 侧 xlsx（zip+XML 容器）解码不在纯逻辑层：容器解码属应用层，
        // 解码出的行矩阵走 parseRows。模型层对 .xlsx 字节输入给 Dart 同源的报错码。
        try {
            SpreadsheetImportModel.parseBytes(csv(wakeupHeader), "a.xlsx", settings)
            throw AssertionError("应抛出 FormatException")
        } catch (expected: com.mutx163.qingyu.core.FormatException) {
            assertTrue(expected.message!!.startsWith("spreadsheet_xlsx_parse_failed"))
        }
    }

    @Test
    fun `requiredSectionCount 取成功行的最大结束节`() {
        val bytes = csv(
            wakeupHeader,
            "高等数学,1,1,2,李老师,楼,1-2",
            "大学英语,2,3,7,王老师,楼,1-2",
        )
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertEquals(7, result.requiredSectionCount)
    }

    @Test
    fun `requiredSectionCount 空课表为 0`() {
        // 派生值直接钉：courses 为空 → 0（Dart SpreadsheetImportResult.requiredSectionCount）
        val result = SpreadsheetImportResult(emptyList(), emptyList(), SpreadsheetImportModel.FORMAT_WAKEUP)
        assertEquals(0, result.requiredSectionCount)
    }

    // ==========================================
    // 9. 周次表达式解析器（WeekExpressionParser）
    // ==========================================

    private fun parseWeeks(raw: String, weekCount: Int? = 20): List<Int> =
        WeekExpressionParser.parse(raw, itemName = "测试", semesterWeekCount = weekCount, warnings = null)

    @Test
    fun `周次表达式 基础区间与枚举`() {
        assertEquals((1..16).toList(), parseWeeks("1-16"))
        assertEquals(listOf(1, 3, 5), parseWeeks("1、3、5"))
        assertEquals(listOf(1, 3, 5), parseWeeks("1,3、5")) // 全半角逗号都是分隔符
        assertEquals(listOf(2), parseWeeks("2"))
    }

    @Test
    fun `周次表达式 节次方括号后缀被剥掉`() {
        assertEquals(listOf(1, 2), parseWeeks("1-2[3节]"))
        assertEquals(listOf(1, 2), parseWeeks("1-2【3节】"))
    }

    @Test
    fun `周次表达式 后缀单双字过滤`() {
        assertEquals(listOf(1, 3), parseWeeks("1-4单"))
        assertEquals(listOf(2, 4), parseWeeks("1-4双"))
    }

    @Test
    fun `周次表达式 多区间与括号单周不过滤全局`() {
        // 手推：modeMatch=(单)，anyTokenParity=false，但 token 数 = 2 > 1 → 不做全局过滤
        assertEquals((1..5).toList() + (7..11).toList(), parseWeeks("1-5、7-11(单)"))
    }

    @Test
    fun `周次表达式 全部关键字不过滤`() {
        assertEquals((1..5).toList(), parseWeeks("1-5(全部)"))
    }

    @Test
    fun `周次表达式 超学期钳制并出警告`() {
        val warnings = mutableListOf<String>()
        val weeks = WeekExpressionParser.parse("1-30", itemName = "第 2 行周数", semesterWeekCount = 20, warnings = warnings)
        assertEquals((1..20).toList(), weeks)
        assertEquals(
            "weeks_exceed_semester_clamped|itemName=第 2 行周数|semesterWeekCount=20|weeks=21、22、23、24、25、26、27、28、29、30",
            warnings.single(),
        )
    }

    @Test
    fun `周次表达式 非法输入抛 FormatException`() {
        val cases = mapOf(
            "0-5" to "week_start_invalid|itemName=测试",
            "5-3" to "week_range_invalid|itemName=测试",
            "1-99" to "week_range_too_large|itemName=测试",
            "abc" to "week_token_unrecognized|itemName=测试|token=abc",
        )
        for ((raw, expected) in cases) {
            try {
                parseWeeks(raw)
                throw AssertionError("表达式 '$raw' 应抛 FormatException")
            } catch (e: com.mutx163.qingyu.core.FormatException) {
                assertEquals("表达式 '$raw' 的报错码不符", expected, e.message)
            }
        }
    }

    @Test
    fun `周次表达式 空串返回空表`() {
        assertTrue(parseWeeks("").isEmpty())
    }

    // ==========================================
    // 10. 数值与周次边界（原先 0 覆盖：每一条都曾能穿透行级 catch 崩掉整表导入）
    // ==========================================

    @Test
    fun `超大 RANGE 周数报范围过大而不崩`() {
        // 旧的 groupValues[].toInt() 会抛 NumberFormatException——不是 FormatException，
        // parseBytes 的行级 catch（只接 FormatException）接不住，整表导入崩。
        // 结局：与 `1-99` 同一条 week_range_too_large，落行级警告。
        val hugeInLong = "2-99999999999" // > Int.MAX_VALUE，仍在 Long 内
        val beyondLong = "2-99999999999999999999999" // > Long.MAX_VALUE，连 Long 都装不下
        for (raw in listOf(hugeInLong, beyondLong)) {
            val bytes = csv(wakeupHeader, "高等数学,1,1,2,李老师,楼,$raw")
            val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
            assertTrue("'$raw' 不应产出课程", result.courses.isEmpty())
            assertEquals(
                "'$raw' 的行级警告不符",
                "spreadsheet_row_warning|rowNumber=2|inner=week_range_too_large|itemName=第 2 行周数",
                result.warnings.single(),
            )
        }
    }

    @Test
    fun `超大 RANGE 周数在解析器层抛 FormatException`() {
        try {
            parseWeeks("2-99999999999")
            throw AssertionError("应抛出 FormatException")
        } catch (expected: com.mutx163.qingyu.core.FormatException) {
            assertEquals("week_range_too_large|itemName=测试", expected.message)
        }
    }

    @Test
    fun `裸 token 超 Int 但与 Dart int64 一致被接受后钳制`() {
        // Dart: int.tryParse('3000000000') 在 64 位 int 下解得出来 → 收下 → 超学期被钳掉，
        // 结局是「周次为空 + 一条钳制警告」，不是 week_token_unrecognized。
        // 旧实现 toIntOrNull 直接返回 null → 误报 week_token_unrecognized，与 Dart 不一致。
        val warnings = mutableListOf<String>()
        val weeks = WeekExpressionParser.parse(
            "3000000000",
            itemName = "第 2 行周数",
            semesterWeekCount = 20,
            warnings = warnings,
        )
        assertTrue(weeks.isEmpty())
        assertEquals(
            "weeks_exceed_semester_clamped|itemName=第 2 行周数|semesterWeekCount=20|weeks=3000000000",
            warnings.single(),
        )

        // 行级：先出钳制警告，再因周次全被钳掉报 custom_weeks_required（Dart 同序）
        val bytes = csv(wakeupHeader, "高等数学,1,1,2,李老师,楼,3000000000")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertTrue(result.courses.isEmpty())
        assertEquals(
            listOf(
                "weeks_exceed_semester_clamped|itemName=第 2 行周数|semesterWeekCount=20|weeks=3000000000",
                "spreadsheet_row_warning|rowNumber=2|inner=custom_weeks_required",
            ),
            result.warnings,
        )
    }

    @Test
    fun `浮点整数超出 Int 范围回落 field_must_be_integer`() {
        // 旧的 Math.round(asDouble).let(Math::toIntExact) 对 1e18 抛 ArithmeticException
        // （不是 FormatException）→ 穿透行级 catch 崩掉整表导入。
        val bytes = csv(wakeupHeader, "高等数学,1,1e18,2,李老师,楼,1-2")
        val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
        assertTrue(result.courses.isEmpty())
        assertEquals(
            "spreadsheet_row_warning|rowNumber=2|inner=field_must_be_integer|field=start_section",
            result.warnings.single(),
        )
    }

    @Test
    fun `非有限浮点同样回落 field_must_be_integer`() {
        // 1e400 溢出成 Infinity、NaN 不是整数值：都不能让 round 抛出去
        for (raw in listOf("1e400", "-1e400", "Infinity", "NaN")) {
            val bytes = csv(wakeupHeader, "高等数学,1,$raw,2,李老师,楼,1-2")
            val result = SpreadsheetImportModel.parseBytes(bytes, "a.csv", settings)
            assertTrue("'$raw' 不应产出课程", result.courses.isEmpty())
            assertEquals(
                "'$raw' 的行级警告不符",
                "spreadsheet_row_warning|rowNumber=2|inner=field_must_be_integer|field=start_section",
                result.warnings.single(),
            )
        }
    }

    @Test
    fun `嵌套括号被整段剥掉`() {
        // 旧的字符类 [^（(）)] 把左括号也排除在外，`(备注(1)2-3` 只剥得掉 `(1)`，
        // 残留 `(备注2-3` 被当成无法识别的周次。Dart/calendar 参照物都是 [^)）]，
        // 从第一个左括号剥到第一个右括号 → `2-3`。
        assertEquals(listOf(2, 3), parseWeeks("(备注(1)2-3"))
        assertEquals(listOf(2, 3), parseWeeks("（备注（1）2-3"))
    }
}
