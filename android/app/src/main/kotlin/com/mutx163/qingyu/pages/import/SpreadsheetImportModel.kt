package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.ServiceMessage
import com.mutx163.qingyu.core.TimetableSettings
import java.util.Locale
import java.util.UUID

/**
 * 表格课表解析结果（对齐 Dart `SpreadsheetImportResult`）。
 */
data class SpreadsheetImportResult(
    val courses: List<Course>,
    val warnings: List<String>,
    val format: String,
) {
    /** 成功行里最大的结束节，供「要不要自动补齐节次」判定。 */
    val requiredSectionCount: Int
        get() = courses.map { it.endSection }.maxOrNull() ?: 0
}

/**
 * 周次表达式解析（移植 `lib/services/week_expression_parser.dart`）。
 *
 * 处理 `1-16`、`1、3、5`、`1-4单`、`(单)3-5`、`1-2[3节]` 等形状；
 * 越界/非法抛 [FormatException]（消息 = service message payload），
 * 超学期周数钳制并写警告。
 */
object WeekExpressionParser {

    private val BRACKET_SECTION_SUFFIX = Regex("""\[[^\]]*节]""")
    private val FULLWIDTH_BRACKET_SECTION_SUFFIX = Regex("""【[^】]*节】""")
    private val PARITY_MODE = Regex("""[（(](全部|单|双)[)）]""")
    private val PARENTHETICAL = Regex("""[（(][^)）]*[)）]""")
    private val TOKEN_SEPARATOR = Regex("""[，,、]""")
    private val RANGE = Regex("""^(\d+)-(\d+)$""")

    fun parse(
        raw: String,
        itemName: String,
        semesterWeekCount: Int?,
        warnings: MutableList<String>?,
    ): List<Int> {
        var normalized = raw.trim()
        if (normalized.isEmpty()) return emptyList()

        normalized = normalized
            .replace(" ", "")
            .replace(BRACKET_SECTION_SUFFIX, "")
            .replace(FULLWIDTH_BRACKET_SECTION_SUFFIX, "")

        val modeMatch = PARITY_MODE.find(normalized)?.groupValues?.get(1)
        normalized = normalized.replace(PARENTHETICAL, "")

        // 周次用 Long 累积：Dart 的 `int` 是 64 位，`int.tryParse('3000000000')` 能解出，
        // 到 [clampToSemesterWeekCount] 才被学期周数钳掉；用 Int 会在解析阶段就把它当成
        // 「无法识别」整行丢掉，与 Dart 结局不一致。
        val result = sortedSetOf<Long>()
        val parts = normalized.split(TOKEN_SEPARATOR)
        var nonEmptyTokenCount = 0
        var anyTokenParity = false
        for (part in parts) {
            var token = part.trim()
            if (token.isEmpty()) continue
            nonEmptyTokenCount += 1

            var tokenParity: String? = null
            if (token.endsWith("单")) {
                tokenParity = "单"
                token = token.substring(0, token.length - 1)
                anyTokenParity = true
            } else if (token.endsWith("双")) {
                tokenParity = "双"
                token = token.substring(0, token.length - 1)
                anyTokenParity = true
            }

            val rangeMatch = RANGE.find(token)
            if (rangeMatch != null) {
                val start = rangeMatch.groupValues[1].toLongOrNull()
                val end = rangeMatch.groupValues[2].toLongOrNull()
                // 连 Long 都装不下（> 9.2e18）的数字必然远大于 30 周，按同一族
                // 「范围过大」报错；此处不抛 NumberFormatException，否则行级 catch
                //（只接 FormatException）接不住，整表导入崩掉。
                if (start == null || end == null) {
                    throw FormatException(
                        ServiceMessage.encode("week_range_too_large", mapOf("itemName" to itemName)),
                    )
                }
                if (start < 1) {
                    throw FormatException(
                        ServiceMessage.encode("week_start_invalid", mapOf("itemName" to itemName)),
                    )
                }
                if (start > end) {
                    throw FormatException(
                        ServiceMessage.encode("week_range_invalid", mapOf("itemName" to itemName)),
                    )
                }
                if (end > 30) {
                    throw FormatException(
                        ServiceMessage.encode("week_range_too_large", mapOf("itemName" to itemName)),
                    )
                }
                result.addAll(applyParity((start..end).toList(), tokenParity))
                continue
            }

            val parsed = token.toLongOrNull()
            if (parsed == null || parsed < 1) {
                throw FormatException(
                    ServiceMessage.encode(
                        "week_token_unrecognized",
                        mapOf("itemName" to itemName, "token" to token),
                    ),
                )
            }
            result.addAll(applyParity(listOf(parsed), tokenParity))
        }

        var weeks = result.toList()
        // 全局（单）/（双）只作用于单 token 表达式：`1-5、7-11(单)` 这种多区间
        // 不能被整体过滤
        val applyGlobalParity = modeMatch != null && !anyTokenParity && nonEmptyTokenCount <= 1
        if (applyGlobalParity && modeMatch == "单") {
            weeks = weeks.filter { it % 2 != 0L }
        } else if (applyGlobalParity && modeMatch == "双") {
            weeks = weeks.filter { it % 2 == 0L }
        }

        return clampToSemesterWeekCount(weeks, semesterWeekCount, itemName, warnings)
    }

    private fun clampToSemesterWeekCount(
        weeks: List<Long>,
        semesterWeekCount: Int?,
        itemName: String,
        warnings: MutableList<String>?,
    ): List<Int> {
        if (semesterWeekCount == null || semesterWeekCount < 1 || weeks.isEmpty()) {
            // 没有学期周数可钳时，超出 Int 表示范围的周（只可能来自天文数字裸 token）
            // 在 List<Int> 契约里放不下，丢弃；Dart 的 int 是 64 位会原样带出。
            return weeks.filter { it <= Int.MAX_VALUE }.map { it.toInt() }
        }
        val over = weeks.filter { it > semesterWeekCount }
        if (over.isEmpty()) return weeks.map { it.toInt() }
        warnings?.add(
            ServiceMessage.encode(
                "weeks_exceed_semester_clamped",
                mapOf(
                    "itemName" to itemName,
                    "semesterWeekCount" to semesterWeekCount,
                    "weeks" to over.joinToString("、"),
                ),
            ),
        )
        return weeks.filter { it <= semesterWeekCount }.map { it.toInt() }
    }

    private fun applyParity(weeks: List<Long>, parity: String?): List<Long> = when (parity) {
        "单" -> weeks.filter { it % 2 != 0L }
        "双" -> weeks.filter { it % 2 == 0L }
        else -> weeks
    }
}

/**
 * 表格课表解析模型（P3-G1 · 移植 `lib/services/spreadsheet_import_service.dart`）。
 *
 * ## 移植边界
 *
 * - **CSV 全链路在本层**：字节 → 编码探测（UTF-8 优先、GBK 兜底）→
 *   逐行解析（引号字段、`""` 转义、引号内逗号不当分隔符；**引号内换行按 Dart
 *   `table_parser` 的真实行为切成两行**）→ 格式识别 → 行解析。
 * - **xlsx（zip+XML 容器）解码不在纯逻辑层**：Dart 侧由 `table_parser` 包完成，
 *   Kotlin 侧容器解码属应用层职责——解码出的行矩阵走 [parseRows]。
 *   [parseBytes] 对 `.xlsx` 字节输入抛同源报错码
   * `spreadsheet_xlsx_parse_failed|error=...`。
 */
object SpreadsheetImportModel {

    const val FORMAT_MIKCB = "mikcb_course_v1"
    const val FORMAT_WAKEUP = "wakeup_compatible"
    const val FORMAT_UNKNOWN = "unknown"

    /** 导入体积上限（20 MB）：xlsx 是 zip 容器，磁盘大小严重低估展开后的内存量。 */
    const val MAX_FILE_BYTES = 20 * 1024 * 1024

    private const val MIKCB_METADATA_MARKER = "# mikcb-course-import-v1"
    private const val DEFAULT_COLOR = "#2196F3"

    private val NAME_ALIASES = listOf("课程名称")
    private val START_SECTION_ALIASES = listOf("开始节数")
    private val END_SECTION_ALIASES = listOf("结束节数")
    private val CUSTOM_WEEKS_ALIASES = listOf("周数")
    private val TEACHER_ALIASES = listOf("老师")
    private val LOCATION_ALIASES = listOf("地点", "上课地点")
    private val COURSE_NATURE_ALIASES = listOf("课程性质")
    private val TIME_SCHEME_ALIASES = listOf("时间模板ID")

    private val WAKEUP_HEADERS = listOf(
        "课程名称", "星期", "开始节数", "结束节数", "老师", "地点", "周数",
    )

    // ------------------------------------------------------------------
    // 入口
    // ------------------------------------------------------------------

    /**
     * 解析表格字节流。`.csv` 走编码探测 + CSV 解析；`.xlsx` 见头注释
     * （容器解码不在本层，抛同源报错码）。
     */
    fun parseBytes(bytes: ByteArray, fileName: String, settings: TimetableSettings): SpreadsheetImportResult {
        val lowerName = fileName.lowercase()
        if (lowerName.endsWith(".xlsx")) {
            throw FormatException(
                ServiceMessage.encode(
                    "spreadsheet_xlsx_parse_failed",
                    mapOf("error" to "xlsx container decoding is not available in the pure model layer"),
                ),
            )
        }
        return parseRows(decodeCsvRows(bytes), fileName, settings)
    }

    /**
     * 解析已解码的行矩阵（xlsx 解码方 / 测试注入口）。格式识别不出时抛
     * `spreadsheet_format_unrecognized`。
     */
    fun parseRows(rows: List<List<String>>, fileName: String, settings: TimetableSettings): SpreadsheetImportResult {
        if (rows.isEmpty()) {
            return SpreadsheetImportResult(courses = emptyList(), warnings = emptyList(), format = FORMAT_UNKNOWN)
        }

        val detected = detectFormat(rows)
            ?: throw FormatException("spreadsheet_format_unrecognized")

        val courses = mutableListOf<Course>()
        val warnings = mutableListOf<String>()
        val dataStartIndex = detected.headerRowIndex + 1
        val columnMap = if (detected.format == FORMAT_MIKCB) {
            SpreadsheetColumnMap(rows[detected.headerRowIndex])
        } else {
            null
        }

        for (rowIndex in dataStartIndex until rows.size) {
            val rowNumber = rowIndex + 1
            val row = rows[rowIndex]
            if (isEmptyRow(row)) continue

            try {
                val course = if (detected.format == FORMAT_WAKEUP) {
                    parseWakeUpDataRow(row, rowNumber, settings, warnings)
                } else {
                    parseMikcbDataRow(row, rowNumber, settings, columnMap!!, warnings)
                }
                if (course != null) {
                    courses.add(course)
                }
            } catch (error: FormatException) {
                warnings.add(encodeServiceRowWarning(rowNumber, error.message ?: ""))
            }
        }

        return SpreadsheetImportResult(courses = courses, warnings = warnings, format = detected.format)
    }

    // ------------------------------------------------------------------
    // CSV 字节流 → 行矩阵
    // ------------------------------------------------------------------

    /**
     * 编码探测：UTF-8（宽容解码）解析出可识别格式就用它；否则试 GBK；
     * 都不行时 UTF-8 能解析就返回 UTF-8 结果（外层按「格式无法识别」报错），
     * 连 CSV 语法都解析不了才抛「编码无法识别」。
     */
    fun decodeCsvRows(bytes: ByteArray): List<List<String>> {
        val utf8Content = String(bytes, Charsets.UTF_8) // 宽容解码：坏字节 → U+FFFD
        val utf8Rows = tryParseCsvContent(utf8Content)
        if (utf8Rows != null && detectFormat(utf8Rows) != null) {
            return utf8Rows
        }

        // GBK 解码/兜底解析失败均继续走 UTF-8 兜底，最终统一抛
        // 「无法识别」错误。此分支属编码探测的正常路径。
        val gbkCharset = try {
            charset("GBK")
        } catch (_: Exception) {
            null
        }
        if (gbkCharset != null) {
            val gbkContent = String(bytes, gbkCharset)
            val gbkRows = tryParseCsvContent(gbkContent)
            if (gbkRows != null && detectFormat(gbkRows) != null) {
                return gbkRows
            }
        }

        if (utf8Rows != null) {
            return utf8Rows
        }
        throw FormatException("spreadsheet_format_or_encoding_unrecognized")
    }

    /**
     * CSV 解析，逐字对齐 Dart `table_parser-1.0.1` 的 `CsvDecoder._parseContent`
     * （`lib/src/csv.dart:48-75` + `lib/src/table.dart:237-255`）：
     *
     * - **先按行切，再解析每行引号语法**：`split(RegExp(r'\r?\n'))` 发生在引号处理之前，
     *   所以「引号内的换行」**不会**把字段拼回来——它会变成两行（第二行照常参与导入）。
     *   **这是有意退回 Dart，不是退步**：早期 Kotlin 实现支持过 RFC4180 跨行字段，
     *   现已按 Dart 真值退回「先切行再解析」。**后续不要重新实现跨行支持**——
     *   要支持跨行属于产品决策，必须先改 Dart 侧的 `CsvDecoder._parseContent`。
     * - **空白行整行跳过**（`line.trim().isEmpty`）：行号因此只数非空行，警告里的
     *   `rowNumber` 与 Dart 一致。
     * - **空白内容（含全空格）没有表** → [tryParseCsvContent] 返回 null，外层落到
     *   「编码无法识别」，与 Dart 的 tables 为空同解。
     * - 行内引号：`""` 转义成一个字面引号，引号内的逗号不当分隔符。
     */
    fun tryParseCsvContent(content: String): List<List<String>>? = try {
        val rows = parseCsv(content)
        if (rows.isEmpty()) null else rows
    } catch (_: Exception) {
        null
    }

    private fun parseCsv(content: String): List<List<String>> {
        // Dart `_csvContent.trim().isEmpty` → tables 为空。
        if (content.trim().isEmpty()) return emptyList()
        val rows = mutableListOf<List<String>>()
        for (line in content.split(Regex("""\r?\n"""))) {
            if (line.trim().isEmpty()) continue
            rows.add(parseCsvLine(line))
        }
        return rows
    }

    private fun parseCsvLine(line: String): List<String> {
        val fields = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            if (c == '"') {
                if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
                    // `""` → 一个字面引号（Dart csv.dart:88-92）
                    current.append('"')
                    i += 2
                    continue
                }
                inQuotes = !inQuotes
                i += 1
                continue
            }
            if (!inQuotes && c == ',') {
                fields.add(stripOuterQuotes(current.toString()))
                current.setLength(0)
                i += 1
                continue
            }
            current.append(c)
            i += 1
        }
        fields.add(stripOuterQuotes(current.toString()))
        return fields
    }

    /**
     * Dart `_parseValue`（`shouldParseNumbers: false`）只做一件事：字段同时以引号
     * 开头和结尾时剥掉一层。通常行内解析已把引号去干净，这里主要覆盖转义残留。
     * 单字符 `"` 会像 Dart 的 `substring(1, 0)` 一样抛下标越界 → 整份 CSV 判为
     * 解析失败（外层 catch 折成 null）。
     */
    private fun stripOuterQuotes(value: String): String =
        if (value.length >= 1 && value.startsWith('"') && value.endsWith('"')) {
            value.substring(1, value.length - 1)
        } else {
            value
        }

    // ------------------------------------------------------------------
    // 格式识别
    // ------------------------------------------------------------------

    private fun detectFormat(rows: List<List<String>>): DetectedFormat? {
        var headerRowIndex = 0
        if (isMetadataRow(rows.first())) {
            if (rows.size < 2) return null
            headerRowIndex = 1
        }

        val headerRow = rows[headerRowIndex]
        if (isHeaderRow(headerRow, WAKEUP_HEADERS)) {
            return DetectedFormat(headerRowIndex, FORMAT_WAKEUP)
        }
        if (isMikcbFormat(headerRow)) {
            return DetectedFormat(headerRowIndex, FORMAT_MIKCB)
        }
        return null
    }

    private fun isMikcbFormat(headerRow: List<String>): Boolean {
        val columns = SpreadsheetColumnMap(headerRow)
        if (!columns.hasColumn("课程名", NAME_ALIASES)) return false
        if (!columns.hasColumn("星期", emptyList())) return false
        if (!columns.hasColumn("开始节", START_SECTION_ALIASES)) return false
        if (!columns.hasColumn("结束节", END_SECTION_ALIASES)) return false

        val hasCustomWeeks = columns.hasColumn("上课周", CUSTOM_WEEKS_ALIASES)
        val hasRangeWeeks =
            columns.hasColumn("开始周", emptyList()) &&
                columns.hasColumn("结束周", emptyList())
        return hasCustomWeeks || hasRangeWeeks
    }

    private fun isMetadataRow(row: List<String>): Boolean =
        row.isNotEmpty() && row.first().trim() == MIKCB_METADATA_MARKER

    private fun isHeaderRow(row: List<String>, expectedHeaders: List<String>): Boolean {
        if (row.size < expectedHeaders.size) return false
        for (i in expectedHeaders.indices) {
            if (row[i].trim() != expectedHeaders[i]) return false
        }
        return true
    }

    private fun isEmptyRow(row: List<String>): Boolean = row.all { it.trim().isEmpty() }

    // ------------------------------------------------------------------
    // 行解析
    // ------------------------------------------------------------------

    private fun parseWakeUpDataRow(
        row: List<String>,
        rowNumber: Int,
        settings: TimetableSettings,
        warnings: MutableList<String>,
    ): Course? {
        if (row.size < 7) {
            throw FormatException(
                ServiceMessage.encode(
                    "spreadsheet_wakeup_insufficient_columns",
                    linkedMapOf("rowNumber" to rowNumber, "columnCount" to row.size),
                ),
            )
        }
        val name = row[0].trim()
        if (name.isEmpty()) {
            throw FormatException("course_name_required")
        }

        val dayOfWeek = readRequiredInt(row[1], "weekday")
        if (dayOfWeek < 1 || dayOfWeek > 7) {
            throw FormatException("weekday_must_be_1_to_7")
        }

        val startSection = readRequiredInt(row[2], "start_section")
        val endSection = readRequiredInt(row[3], "end_section")
        validateSections(startSection, endSection, "start_section", "end_section")

        val teacher = normalizeOptionalField(row[4])
        val location = normalizeOptionalField(row[5])

        val customWeeks = WeekExpressionParser.parse(
            row[6],
            itemName = "第 $rowNumber 行周数",
            semesterWeekCount = settings.semesterWeekCount,
            warnings = warnings,
        )
        if (customWeeks.isEmpty()) {
            throw FormatException("custom_weeks_required")
        }

        val startTime = timeFromSection(settings, startSection, isStart = true)
        val endTime = timeFromSection(settings, endSection, isStart = false)

        return Course(
            id = "spreadsheet-${UUID.randomUUID()}",
            name = name,
            teacher = teacher,
            location = location,
            dayOfWeek = dayOfWeek,
            startSection = startSection,
            endSection = endSection,
            startTime = startTime,
            endTime = endTime,
            startWeek = customWeeks.first(),
            endWeek = customWeeks.last(),
            customWeeks = customWeeks,
        )
    }

    private fun parseMikcbDataRow(
        row: List<String>,
        rowNumber: Int,
        settings: TimetableSettings,
        columns: SpreadsheetColumnMap,
        warnings: MutableList<String>,
    ): Course? {
        // 用字段代码而不是中文表头报错：表头是「课程名」还是「课程名称」
        // 不影响字段本身，两者都归到同一个代码。
        val nameField = "course_name"
        val name = columns.cell(row, "课程名", NAME_ALIASES).trim()
        if (name.isEmpty()) {
            throw FormatException(
                ServiceMessage.encode("field_cannot_be_empty", mapOf("field" to nameField)),
            )
        }

        val dayOfWeek = readRequiredInt(columns.cell(row, "星期", emptyList()), "weekday")
        if (dayOfWeek < 1 || dayOfWeek > 7) {
            throw FormatException("weekday_must_be_1_to_7")
        }

        val startSection = readRequiredInt(columns.cell(row, "开始节", START_SECTION_ALIASES), "start_section")
        val endSection = readRequiredInt(columns.cell(row, "结束节", END_SECTION_ALIASES), "end_section")
        validateSections(startSection, endSection, "start_section", "end_section")

        val teacher = if (columns.hasColumn("教师", TEACHER_ALIASES)) {
            normalizeOptionalField(columns.cell(row, "教师", TEACHER_ALIASES))
        } else {
            ""
        }
        val location = if (columns.hasColumn("教室", LOCATION_ALIASES)) {
            normalizeOptionalField(columns.cell(row, "教室", LOCATION_ALIASES))
        } else {
            ""
        }

        val customWeeksRaw = columns.cell(row, "上课周", CUSTOM_WEEKS_ALIASES).trim()
        val hasRangeWeekColumns =
            columns.hasColumn("开始周", emptyList()) &&
                columns.hasColumn("结束周", emptyList())

        var customWeeks: List<Int>? = null
        var startWeek = 1
        var endWeek = 16
        var isOddWeek = false
        var isEvenWeek = false

        if (customWeeksRaw.isNotEmpty()) {
            val parsedWeeks = WeekExpressionParser.parse(
                customWeeksRaw,
                itemName = "第 $rowNumber 行上课周",
                semesterWeekCount = settings.semesterWeekCount,
                warnings = warnings,
            )
            if (parsedWeeks.isEmpty()) {
                throw FormatException("class_weeks_required")
            }
            customWeeks = parsedWeeks
            startWeek = parsedWeeks.first()
            endWeek = parsedWeeks.last()
        } else if (hasRangeWeekColumns) {
            startWeek = readRequiredInt(columns.cell(row, "开始周", emptyList()), "start_week")
            endWeek = readRequiredInt(columns.cell(row, "结束周", emptyList()), "end_week")
            if (startWeek < 1) {
                throw FormatException("start_week_must_be_at_least_1")
            }
            if (startWeek > settings.semesterWeekCount) {
                throw FormatException(
                    ServiceMessage.encode(
                        "start_week_exceeds_semester",
                        linkedMapOf(
                            "startWeek" to startWeek,
                            "semesterWeekCount" to settings.semesterWeekCount,
                        ),
                    ),
                )
            }
            if (endWeek < startWeek) {
                throw FormatException("end_week_before_start_week")
            }
            if (endWeek > settings.semesterWeekCount) {
                warnings.add(
                    ServiceMessage.encode(
                        "spreadsheet_end_week_clamped",
                        linkedMapOf(
                            "rowNumber" to rowNumber,
                            "endWeek" to endWeek,
                            "semesterWeekCount" to settings.semesterWeekCount,
                        ),
                    ),
                )
                endWeek = settings.semesterWeekCount
            }
            if (columns.hasColumn("单周", emptyList())) {
                isOddWeek = readOptionalBool(columns.cell(row, "单周", emptyList()))
            }
            if (columns.hasColumn("双周", emptyList())) {
                isEvenWeek = readOptionalBool(columns.cell(row, "双周", emptyList()))
            }
            if (isOddWeek && isEvenWeek) {
                warnings.add(
                    ServiceMessage.encode(
                        "spreadsheet_odd_even_both",
                        mapOf("rowNumber" to rowNumber),
                    ),
                )
                isEvenWeek = false
            }
        } else {
            throw FormatException("weeks_range_required")
        }

        val startTime = if (columns.hasColumn("开始时间", emptyList())) {
            normalizeTimeOrDefault(
                columns.cell(row, "开始时间", emptyList()),
                timeFromSection(settings, startSection, isStart = true),
            )
        } else {
            timeFromSection(settings, startSection, isStart = true)
        }
        val endTime = if (columns.hasColumn("结束时间", emptyList())) {
            normalizeTimeOrDefault(
                columns.cell(row, "结束时间", emptyList()),
                timeFromSection(settings, endSection, isStart = false),
            )
        } else {
            timeFromSection(settings, endSection, isStart = false)
        }

        val color = if (columns.hasColumn("颜色", emptyList())) {
            normalizeColor(columns.cell(row, "颜色", emptyList()))
        } else {
            DEFAULT_COLOR
        }

        var suspendedWeeks: List<Int>? = null
        if (columns.hasColumn("停课周", emptyList())) {
            val suspendedRaw = columns.cell(row, "停课周", emptyList()).trim()
            if (suspendedRaw.isNotEmpty() && suspendedRaw != "无" && suspendedRaw != "-") {
                suspendedWeeks = WeekExpressionParser.parse(
                    suspendedRaw,
                    itemName = "第 $rowNumber 行停课周",
                    semesterWeekCount = settings.semesterWeekCount,
                    warnings = warnings,
                )
            }
        }

        val courseNature = if (columns.hasColumn("性质", COURSE_NATURE_ALIASES)) {
            parseCourseNature(columns.cell(row, "性质", COURSE_NATURE_ALIASES))
        } else {
            CourseNature.REQUIRED
        }

        val shortName = if (columns.hasColumn("简称", emptyList())) {
            normalizeNullableField(columns.cell(row, "简称", emptyList()))
        } else {
            null
        }
        val description = if (columns.hasColumn("简介", emptyList())) {
            normalizeNullableField(columns.cell(row, "简介", emptyList()))
        } else {
            null
        }
        val note = if (columns.hasColumn("备注", emptyList())) {
            normalizeNullableField(columns.cell(row, "备注", emptyList()))
        } else {
            null
        }
        val timeSchemeIdOverride = if (columns.hasColumn("时间模板", TIME_SCHEME_ALIASES)) {
            normalizeNullableField(columns.cell(row, "时间模板", TIME_SCHEME_ALIASES))
        } else {
            null
        }

        return Course(
            id = "spreadsheet-${UUID.randomUUID()}",
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
    }

    private fun validateSections(startSection: Int, endSection: Int, startField: String, endField: String) {
        if (startSection < 1) {
            throw FormatException(
                ServiceMessage.encode("field_must_be_at_least_1", mapOf("field" to startField)),
            )
        }
        if (endSection < startSection) {
            throw FormatException(
                ServiceMessage.encode(
                    "field_cannot_be_less_than",
                    mapOf("startField" to startField, "endField" to endField),
                ),
            )
        }
    }

    private fun timeFromSection(settings: TimetableSettings, section: Int, isStart: Boolean): String {
        if (section < 1 || section > settings.sections.size) {
            throw FormatException(
                ServiceMessage.encode(
                    "section_out_of_range",
                    linkedMapOf("section" to section, "maxSection" to settings.sections.size),
                ),
            )
        }
        val sectionInfo = settings.sections[section - 1]
        return if (isStart) sectionInfo.startTime else sectionInfo.endTime
    }

    /** `''`/`无`/`-` 回落节次表时间；其余必须解得出 `HH:mm`，解不出也回落。 */
    private fun normalizeTimeOrDefault(raw: String, fallback: String): String {
        val trimmed = raw.trim()
        if (trimmed.isEmpty() || trimmed == "无" || trimmed == "-") {
            return fallback
        }
        val parsed = tryParseClockTime(trimmed, allowEndOfDay = true)
        return parsed ?: fallback
    }

    /**
     * `HH:MM` 容错解析（对齐 Dart `ClockTime.tryParse`）：缺列/非数字/越界返回
     * null；`allowEndOfDay` 只额外放行 `24:00`。归一输出补零 `HH:MM`。
     */
    private fun tryParseClockTime(value: String, allowEndOfDay: Boolean): String? {
        val text = value.trim()
        if (text.isEmpty()) return null
        val parts = text.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].trim().toIntOrNull() ?: return null
        val minute = parts[1].trim().toIntOrNull() ?: return null
        if (minute < 0 || minute > 59) return null
        if (allowEndOfDay && hour == 24 && minute == 0) return "24:00"
        if (hour < 0 || hour > 23) return null
        return String.format(Locale.ROOT, "%02d:%02d", hour, minute)
    }

    /**
     * 只放行**渲染侧解得出来**的形状：6 位十六进制原样收下（补 `#`），
     * 3 位按 CSS 规则展开成 6 位，其余一律回落默认蓝。
     */
    private fun normalizeColor(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.isEmpty() || trimmed == "无" || trimmed == "-") {
            return DEFAULT_COLOR
        }
        val hex = if (trimmed.startsWith("#")) trimmed.substring(1) else trimmed
        if (hex.length == 3 && Regex("""^[0-9a-fA-F]{3}$""").matches(hex)) {
            val buffer = StringBuilder("#")
            for (digit in hex) {
                buffer.append(digit).append(digit)
            }
            return buffer.toString()
        }
        if (!Regex("""^[0-9a-fA-F]{6}$""").matches(hex)) {
            return DEFAULT_COLOR
        }
        return "#$hex"
    }

    private fun parseCourseNature(raw: String): CourseNature {
        val trimmed = raw.trim().lowercase()
        if (trimmed.isEmpty() || trimmed == "无" || trimmed == "-") {
            return CourseNature.REQUIRED
        }
        if (trimmed == "选修" || trimmed == "elective") {
            return CourseNature.ELECTIVE
        }
        return CourseNature.REQUIRED
    }

    private fun readOptionalBool(raw: String): Boolean {
        val trimmed = raw.trim().lowercase()
        if (trimmed.isEmpty() || trimmed == "无" || trimmed == "-") {
            return false
        }
        return trimmed == "是" || trimmed == "1" || trimmed == "单" || trimmed == "true" || trimmed == "yes"
    }

    private fun normalizeNullableField(raw: String): String? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty() || trimmed == "无" || trimmed == "-") {
            return null
        }
        return trimmed
    }

    private fun normalizeOptionalField(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed == "无" || trimmed == "-") {
            return ""
        }
        return trimmed
    }

    private fun readRequiredInt(raw: String, fieldName: String): Int {
        val parsed = readInt(raw)
        if (parsed == null) {
            throw FormatException(
                ServiceMessage.encode("field_must_be_integer", mapOf("field" to fieldName)),
            )
        }
        return parsed
    }

    /** 整数直读；带小数时只有整数值（`3.0`）才收，`3.5` 拒绝。 */
    private fun readInt(raw: String): Int? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        val direct = trimmed.toIntOrNull()
        if (direct != null) return direct
        val asDouble = trimmed.toDoubleOrNull()
        // `1e18` / `1e400` 这类浮点整数值能过「取值 == 四舍五入值」的相等判真，
        // 但 `Math.toIntExact` 会抛 ArithmeticException——不是 FormatException，
        // parseBytes 的行级 catch 接不住，整个导入随之崩掉。先按 Int 表示区间判，
        // 装不下就当作「读不出整数」，上层落 field_must_be_integer。
        // 判据用区间而不是 `abs() > Int.MAX_VALUE`：后者会连带拒掉刚好能装下的
        // Int.MIN_VALUE。
        if (asDouble != null &&
            !asDouble.isInfinite() &&
            asDouble == kotlin.math.round(asDouble) &&
            asDouble <= Int.MAX_VALUE &&
            asDouble >= Int.MIN_VALUE
        ) {
            return Math.round(asDouble).toInt()
        }
        return null
    }

    /** 行级警告 payload：`spreadsheet_row_warning|rowNumber=N|inner=<code>|...`。 */
    private fun encodeServiceRowWarning(rowNumber: Int, code: String): String =
        ServiceMessage.encode(
            "spreadsheet_row_warning",
            linkedMapOf("rowNumber" to rowNumber, "inner" to code),
        )

    /** 格式识别结果（表头行下标 + 格式码）。 */
    private data class DetectedFormat(val headerRowIndex: Int, val format: String)
}

/**
 * 表头列映射（对齐 Dart `_SpreadsheetColumnMap`）：表头 trim 后入表，
 * 空表头不占位、重复表头**后者覆盖前者**（Dart map 字面量同键覆盖语义）；
 * [indexOf] 先查规范名再逐个查别名；越行的单元格回默认值。
 */
class SpreadsheetColumnMap(headers: List<String>) {

    private val indices: Map<String, Int> = buildMap {
        for (i in headers.indices) {
            val trimmed = headers[i].trim()
            if (trimmed.isNotEmpty()) put(trimmed, i)
        }
    }

    fun indexOf(canonical: String, aliases: List<String>): Int? {
        indices[canonical]?.let { return it }
        for (alias in aliases) {
            indices[alias]?.let { return it }
        }
        return null
    }

    fun hasColumn(canonical: String, aliases: List<String>): Boolean =
        indexOf(canonical, aliases) != null

    fun cell(row: List<String>, canonical: String, aliases: List<String>, defaultValue: String = ""): String {
        val idx = indexOf(canonical, aliases) ?: return defaultValue
        if (idx >= row.size) return defaultValue
        return row[idx]
    }
}
