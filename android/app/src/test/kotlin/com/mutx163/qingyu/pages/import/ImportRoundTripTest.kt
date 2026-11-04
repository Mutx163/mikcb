package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.transfer.IcsSerializer
import com.mutx163.qingyu.transfer.collectCourseEvents
import com.mutx163.qingyu.transfer.compareIcsEvents
import java.io.ByteArrayOutputStream
import java.time.LocalDateTime
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 导入 → 导出 → 再导入的往返幂等（2026-11-04，L1 表格导入 · 收口批次）。
 *
 * 断言口径：第二次导入结果与第一次**逐字段相同**（课程数 / 名称 / 节次 / 周次 /
 * 教师 / 地点 / 钟点 / 开学日 / 学期周数），id 位置型字段除外（见各段注释）。
 *
 * 导出侧来源：
 * - ICS：本 App 真实导出实现 `transfer/IcsModel.kt#collectCourseEvents` +
 *   `transfer/IcsSerializer.kt`（只读引用，未改 transfer 域）；
 * - CSV / XLSX：**两侧都没有「课程 → CSV/XLSX」导出器**（Dart 侧也只在
 *   `import_template_model.dart` 里写死模板）。这里用与导入列契约等价的样例
 *   构造器 `exportMikcbCsv` 做往返，验证「导入能读回自己写出的全部字段」，
 *   并在下文注明这不是产品导出能力。
 */
class ImportRoundTripTest {

    private val settings = TimetableSettings.defaults()
    private val fixedNow = LocalDateTime.of(2026, 11, 4, 12, 0)

    // ==================================================================
    // 1. ICS：真实导出实现 → 导入 → 再导出 → 再导入
    // ==================================================================

    @Test
    fun `ICS 导出再导入逐字段幂等`() {
        // 源学期开学日是周三，导出侧按 Dart 同口径锚定到该周周一（ics_export_service.dart:284-343），
        // 导入侧 `semesterStart = startOfWeek(最早 DTSTART)`（ics_import_service.dart:94）——
        // 所以往返后的开学日是「周一」，这是两侧同解，不是漂移。
        val sourceSemesterStart = LocalDateTime.of(2026, 3, 4, 0, 0)
        val source = listOf(
            course(
                id = "src-a",
                name = "高等数学",
                teacher = "张老师",
                location = "教学楼A101",
                dayOfWeek = 1,
                startSection = 1,
                endSection = 2,
                startTime = "08:00",
                endTime = "09:40",
                startWeek = 1,
                endWeek = 16,
            ),
            course(
                id = "src-b",
                name = "大学英语",
                teacher = "王老师",
                location = "外语楼B203",
                dayOfWeek = 3,
                startSection = 3,
                endSection = 4,
                startTime = "10:00",
                endTime = "11:40",
                customWeeks = listOf(1, 3, 5, 7),
            ),
            course(
                id = "src-c",
                name = "体育",
                teacher = "刘老师",
                location = "体育馆",
                dayOfWeek = 5,
                startSection = 7,
                endSection = 8,
                startTime = "14:00",
                endTime = "15:40",
                customWeeks = listOf(5),
            ),
        )

        val first = IcsImportModel.parseWakeUpSchedule(exportIcs(source, sourceSemesterStart), fixedNow)
        val second = IcsImportModel.parseWakeUpSchedule(exportIcs(first.courses, first.semesterStart), fixedNow)

        // 导出侧「一门课 × 每个上课周 = 一个 VEVENT」，没有 RRULE；导入只合并间隔恰为 2 周的单周课
        // （ics_import_service.dart 的 mergeAlternating 同口径）。因此 1-16 连续周会被拆成 16 条单周课，
        // 1/3/5/7 会并成一条单周课。这是两侧同解的事实，钉住它防止谁把导出改成 RRULE 后无声改变语义。
        assertEquals(18, first.courses.size)
        assertEquals(first.courses.size, second.courses.size)
        assertEquals(first.courses.map(::icsShape), second.courses.map(::icsShape))

        assertEquals(LocalDateTime.of(2026, 3, 2, 0, 0), first.semesterStart)
        assertEquals(first.semesterStart, second.semesterStart)

        // 学期周数：上限只升不降（import_export_logic.dart:39 / SemesterWeekUplift），往返不变。
        assertEquals(20, ImportFlowModel.nextSemesterWeekCount(20, first.courses))
        assertEquals(20, ImportFlowModel.nextSemesterWeekCount(20, second.courses))
    }

    private fun exportIcs(courses: List<Course>, semesterStart: LocalDateTime): String {
        val collected = collectCourseEvents(
            profileId = "p1",
            courses = courses,
            semesterStartDate = semesterStart,
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 7, 1, 0, 0),
        )
        // 与 Dart 导出同序（ics_export_service.dart:540-554），保证第二次导入的事件下标稳定。
        val events = collected.events.sortedWith(Comparator { left, right -> compareIcsEvents(left, right) })
        return IcsSerializer.serializeCalendar(
            calendarName = "往返测试",
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 7, 1, 0, 0),
            generatedAt = fixedNow,
            events = events,
        )
    }

    /** id 是 `ics-<epoch>-<index>` 的位置型字段（ics_import_service.dart:308 同口径），不参与对拍。 */
    private fun icsShape(course: Course): List<Any?> = listOf(
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
        course.isOddWeek,
        course.isEvenWeek,
        course.customWeeks?.joinToString(","),
        course.suspendedWeeks?.joinToString(","),
        course.activeWeeks.joinToString(","),
        course.color,
        course.description,
        course.note,
    )

    // ==================================================================
    // 2. CSV：等价样例（两侧都没有导出器）→ 导入 → 再生成 → 再导入
    // ==================================================================

    @Test
    fun `CSV 等价样例往返后字段全部保留`() {
        val sourceCsv = exportMikcbCsv(sourceCoursesForSpreadsheet())

        val first = SpreadsheetImportModel.parseBytes(sourceCsv, "往返.csv", settings)
        val second = SpreadsheetImportModel.parseBytes(exportMikcbCsv(first.courses), "往返2.csv", settings)

        assertEquals(SpreadsheetImportModel.FORMAT_MIKCB, first.format)
        assertEquals(first.courses.size, second.courses.size)
        assertEquals(first.courses.map(::spreadsheetShape), second.courses.map(::spreadsheetShape))

        // CSV / XLSX 没有开学日与学期周数字段：Dart `spreadsheet_import_service.dart`
        // 也不产出 semesterStart（两侧都没有），学期周数只来自本地 settings，往返不改它。
        // 所以本段只对拍课程字段；开学日 / 学期周数的往返断言在 ICS 用例里。
    }

    // ==================================================================
    // 3. XLSX：同一份等价样例换容器，解码 + 解析后与 CSV 结果一致
    // ==================================================================

    @Test
    fun `XLSX 等价样例与 CSV 解析结果逐字段相同`() {
        val sourceCsv = exportMikcbCsv(sourceCoursesForSpreadsheet())
        val rows = SpreadsheetImportModel.decodeCsvRows(sourceCsv)

        val fromCsv = SpreadsheetImportModel.parseBytes(sourceCsv, "往返.csv", settings)
        val fromXlsx = SpreadsheetImportModel.parseRows(
            XlsxSheetDecoder.decodeFirstSheet(buildXlsx(rows)),
            "往返.xlsx",
            settings,
        )

        assertEquals(SpreadsheetImportModel.FORMAT_MIKCB, fromXlsx.format)
        assertEquals(fromCsv.courses.map(::spreadsheetShape), fromXlsx.courses.map(::spreadsheetShape))
    }

    private fun sourceCoursesForSpreadsheet(): List<Course> = listOf(
        // 自定义周 + 停课周：验证 上课周 / 停课周 两列往返后仍是同一组 activeWeeks。
        course(
            id = "csv-a",
            name = "高等数学",
            shortName = "高数",
            teacher = "李老师",
            location = "教学楼A101",
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            startTime = "08:00",
            endTime = "09:40",
            startWeek = 1,
            endWeek = 16,
            customWeeks = (1..16).toList(),
            suspendedWeeks = listOf(3, 5),
            color = "#4CAF50",
            courseNature = CourseNature.ELECTIVE,
            description = "共享简介",
            note = "旧备注",
            timeSchemeIdOverride = "scheme-a",
        ),
        // 开区间 + 双周：验证 开始周/结束周/双周 列往返后仍是 isEvenWeek。
        course(
            id = "csv-b",
            name = "大学英语",
            teacher = "王老师",
            location = "外语楼B203",
            dayOfWeek = 3,
            startSection = 3,
            endSection = 4,
            startTime = "10:00",
            endTime = "11:40",
            startWeek = 2,
            endWeek = 12,
            isEvenWeek = true,
        ),
        // 单周：验证单条 customWeeks 不被并成区间。
        course(
            id = "csv-c",
            name = "体育",
            teacher = "刘老师",
            location = "体育馆",
            dayOfWeek = 5,
            startSection = 7,
            endSection = 8,
            startTime = "14:00",
            endTime = "15:40",
            customWeeks = listOf(5),
            color = "#FF9800",
        ),
    )

    /** 等价于导入列契约的「课程 → CSV」样例生成器（产品无此导出能力，两侧都没有）。 */
    private fun exportMikcbCsv(courses: List<Course>): ByteArray {
        val header = listOf(
            "课程名", "星期", "开始节", "结束节",
            "上课周", "开始周", "结束周", "单周", "双周",
            "开始时间", "结束时间", "教师", "教室",
            "简称", "简介", "备注", "颜色", "时间模板", "性质", "停课周",
        )
        val lines = mutableListOf("# mikcb-course-import-v1", header.joinToString(","))
        for (course in courses) {
            val custom = course.customWeeks
            val cells = listOf(
                course.name,
                course.dayOfWeek.toString(),
                course.startSection.toString(),
                course.endSection.toString(),
                custom?.joinToString(",").orEmpty(),
                if (custom == null) course.startWeek.toString() else "",
                if (custom == null) course.endWeek.toString() else "",
                if (custom == null && course.isOddWeek) "是" else "否",
                if (custom == null && course.isEvenWeek) "是" else "否",
                course.startTime,
                course.endTime,
                course.teacher,
                course.location,
                course.shortName.orEmpty(),
                course.description.orEmpty(),
                course.note.orEmpty(),
                course.color,
                course.timeSchemeIdOverride.orEmpty(),
                if (course.courseNature == CourseNature.ELECTIVE) "选修" else "必修",
                course.suspendedWeeks?.joinToString(",").orEmpty(),
            )
            lines.add(cells.joinToString(",") { csvCell(it) })
        }
        return (lines.joinToString("\r\n") + "\r\n").toByteArray(Charsets.UTF_8)
    }

    private fun csvCell(value: String): String =
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
            "\"" + value.replace("\"", "\"\"") + "\""
        } else {
            value
        }

    /** id 由 `spreadsheet-<uuid>` 生成（随机），不参与对拍。 */
    private fun spreadsheetShape(course: Course): List<Any?> = listOf(
        course.name,
        course.shortName,
        course.teacher,
        course.location,
        course.dayOfWeek,
        course.startSection,
        course.endSection,
        course.startTime,
        course.endTime,
        course.color,
        course.startWeek,
        course.endWeek,
        course.isOddWeek,
        course.isEvenWeek,
        course.customWeeks?.joinToString(","),
        course.suspendedWeeks?.joinToString(","),
        course.activeWeeks.joinToString(","),
        course.courseNature.value,
        course.description,
        course.note,
        course.timeSchemeIdOverride,
    )

    // ==================================================================
    // 构造器
    // ==================================================================

    @Suppress("LongParameterList")
    private fun course(
        id: String,
        name: String,
        teacher: String,
        location: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        startTime: String,
        endTime: String,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        shortName: String? = null,
        color: String = "#2196F3",
        courseNature: CourseNature = CourseNature.REQUIRED,
        description: String? = null,
        note: String? = null,
        timeSchemeIdOverride: String? = null,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        courseNature = courseNature,
        description = description,
        note = note,
        timeSchemeIdOverride = timeSchemeIdOverride,
    )

    // xlsx 容器拼装（与 XlsxSheetDecoderTest 同构；只用 inlineStr，避免共享字符串下标干扰）。

    private fun buildXlsx(rows: List<List<String>>): ByteArray {
        val sheet = "<worksheet><sheetData>" +
            rows.mapIndexed { index, cells ->
                "<row r=\"${index + 1}\">" +
                    cells.mapIndexed { column, value ->
                        "<c r=\"${columnLetter(column + 1)}${index + 1}\" t=\"inlineStr\">" +
                            "<is><t>${xmlEscape(value)}</t></is></c>"
                    }.joinToString("") +
                    "</row>"
            }.joinToString("") +
            "</sheetData></worksheet>"
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            fun put(name: String, content: String) {
                zip.putNextEntry(ZipEntry(name))
                zip.write(content.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
            put("docProps/app.xml", "<app/>")
            put("xl/worksheets/sheet1.xml", sheet)
        }
        return out.toByteArray()
    }

    private fun xmlEscape(value: String): String =
        value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

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
}
