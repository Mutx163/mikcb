package com.mutx163.qingyu.pages.import

/**
 * 导入域的「服务层机器码 → 屏上文案」（移植 `lib/l10n/service_message_localizer.dart`
 * 里 **导入相关的那些 case**）。
 *
 * ## 为什么需要它
 *
 * [SpreadsheetImportModel] 与 [WeekExpressionParser] 抛的是机器码
 * （`course_name_required`），行级提醒更是一层套一层的
 * `spreadsheet_row_warning|rowNumber=5|inner=field_cannot_be_empty|field=课程名称`。
 * 把这些串原样摆在「导入提醒」对话框里，用户看到的是一串下划线——而导入失败
 * 恰恰是**最需要说清哪一行、哪个字段**的场合。
 *
 * ## 判据照抄 Dart，不自己发明
 *
 * 1. **外层行级警告**：`spreadsheet_row_warning` 渲染成「第 {rowNumber} 行：{message}」，
 *    {message} 是**内层码**递归本地化的结果（`serviceMsgSpreadsheetRowWarning`）。
 * 2. **内层参数是平铺的**：Dart 的 `encodeServiceRowWarning` 把内层 payload 塞进外层
 *    `inner=` 里，两层共用 `|` 分隔符，于是解析外层时内层的 `field=` / `value=` 会自动
 *    平铺进同一张参数表。本实现照这个形状解析，并在递归时**把外层参数带下去**——
 *    否则 `field_cannot_be_empty` 会渲染成「 不能为空」（字段名丢了）。
 * 3. **字段名要本地化**（`_localizeFieldName`）：`weekday` → 「星期」。未登记的字段码
 *    原样透传（Dart 的 default 分支就是 `return fieldCode ?? ''`）。
 * 4. **未登记的码**：命中「像内部错误码」的正则
 *    `^[a-z][a-z0-9_]*(:[A-Za-z0-9._-]+)?$` ⇒ 兜底「发生未知错误」；不像机器码
 *    （中文、`Bad state: …`、大写开头的 `ImportFileTooLarge`）⇒ 原样透传。
 *
 * ## 与 Dart 的已知差异（有意）
 *
 * - 只登记**导入这三页真会遇到的码**（表格解析 / 周次表达式 / 学期映射）。云同步、
 *   时间模板、教务导入等其它域的码不在这里，走第 4 条的兜底。
 * - Dart 的 switch 有 100+ case，全量移植属独立的 l10n 批，本批不顺手做。
 *
 * 文案逐字抄自 `lib/l10n/app_zh.arb`，由 [ImportServiceMessagesParityTest] 与 ARB
 * 机械对拍——键抄错、值被改写、占位符丢失都会红。
 */
object ImportServiceMessages {

    /** 兜底文案（Dart 借用 `quickImportUnknownError` 的措辞，本实现照抄）。 */
    private val unknownError = ImportArbText("quickImportUnknownError", "发生未知错误")

    /** 行级警告外壳：`第 {rowNumber} 行：{message}`。 */
    private val rowWarning = ImportArbText("serviceMsgSpreadsheetRowWarning", "第 {rowNumber} 行：{message}")

    /**
     * 码 → 文案模板。键是 Dart `localizeServiceMessage` 的 `case` 字面量，
     * 值是 ARB 里的原句（含 `{占位符}`）。
     */
    private val templates: Map<String, ImportArbText> = linkedMapOf(
        // 表格整体格式
        "spreadsheet_format_unrecognized" to ImportArbText(
            "spreadsheetFormatUnrecognized",
            "未识别表格格式，请使用轻屿课表模板；也兼容 WakeUp 等同列格式",
        ),
        "spreadsheet_format_or_encoding_unrecognized" to ImportArbText(
            "serviceMsgSpreadsheetFormatOrEncodingUnrecognized",
            "无法识别表格格式或编码，请将 CSV 另存为 UTF-8 后重试",
        ),
        "spreadsheet_xlsx_parse_failed" to ImportArbText(
            "serviceMsgSpreadsheetXlsxParseFailed",
            "XLSX 文件解析失败：{error}",
        ),
        "spreadsheet_wakeup_insufficient_columns" to ImportArbText(
            "serviceMsgSpreadsheetWakeupInsufficientColumns",
            "WakeUp 格式需要至少 7 列，但第 {rowNumber} 行只有 {columnCount} 列",
        ),
        // 单元格级
        "course_name_required" to ImportArbText("serviceMsgCourseNameRequired", "课程名称不能为空"),
        "weekday_must_be_1_to_7" to ImportArbText("serviceMsgWeekdayMustBe1To7", "星期必须是 1～7"),
        "custom_weeks_required" to ImportArbText("serviceMsgCustomWeeksRequired", "周数不能为空"),
        "class_weeks_required" to ImportArbText("serviceMsgClassWeeksRequired", "上课周不能为空"),
        "start_week_must_be_at_least_1" to ImportArbText(
            "serviceMsgStartWeekMustBeAtLeast1",
            "开始周必须大于等于1",
        ),
        "start_week_exceeds_semester" to ImportArbText(
            "serviceMsgStartWeekExceedsSemester",
            "开始周 {startWeek} 超过学期周数 {semesterWeekCount}",
        ),
        "end_week_before_start_week" to ImportArbText(
            "serviceMsgEndWeekBeforeStartWeek",
            "结束周不能小于开始周",
        ),
        "weeks_range_required" to ImportArbText(
            "serviceMsgWeeksRangeRequired",
            "上课周或开始周+结束周必须填写",
        ),
        "field_must_be_at_least_1" to ImportArbText(
            "serviceMsgFieldMustBeAtLeast1",
            "{field} 必须大于等于 1",
        ),
        "field_cannot_be_less_than" to ImportArbText(
            "serviceMsgFieldCannotBeLessThan",
            "{endField} 不能小于 {startField}",
        ),
        "section_out_of_range" to ImportArbText(
            "serviceMsgSectionOutOfRange",
            "节次 {section} 超出作息范围 1 至 {maxSection}",
        ),
        "field_must_be_integer" to ImportArbText("serviceMsgFieldMustBeInteger", "{field} 必须是整数"),
        "field_cannot_be_empty" to ImportArbText("serviceMsgFieldCannotBeEmpty", "{field} 不能为空"),
        "spreadsheet_end_week_clamped" to ImportArbText(
            "serviceMsgSpreadsheetEndWeekClamped",
            "第 {rowNumber} 行：结束周 {endWeek} 超过学期周数 {semesterWeekCount}，已调整为 {semesterWeekCount}",
        ),
        "spreadsheet_odd_even_both" to ImportArbText(
            "serviceMsgSpreadsheetOddEvenBoth",
            "第 {rowNumber} 行：单周与双周不能同时勾选，已按单周处理",
        ),
        // 周次表达式
        "week_start_invalid" to ImportArbText("serviceMsgWeekStartInvalid", "{itemName} 周次起始值不合法"),
        "week_range_invalid" to ImportArbText("serviceMsgWeekRangeInvalid", "{itemName} 周次范围不合法"),
        "week_range_too_large" to ImportArbText(
            "serviceMsgWeekRangeTooLarge",
            "{itemName} 周次范围过大，请检查",
        ),
        "week_token_unrecognized" to ImportArbText(
            "serviceMsgWeekTokenUnrecognized",
            "{itemName} 含有无法识别的周次：{token}",
        ),
        "weeks_exceed_semester_clamped" to ImportArbText(
            "serviceMsgWeeksExceedSemesterClamped",
            "{itemName} 包含超出学期周数 {semesterWeekCount} 的周次 {weeks}，超出部分已忽略",
        ),
    )

    /** 字段码 → 字段名（Dart `_localizeFieldName` 的登记表）。 */
    private val fieldNames: Map<String, ImportArbText> = linkedMapOf(
        "weekday" to ImportArbText("serviceMsgFieldWeekday", "星期"),
        "start_section" to ImportArbText("serviceMsgFieldStartSection", "开始节数"),
        "end_section" to ImportArbText("serviceMsgFieldEndSection", "结束节数"),
        "custom_weeks" to ImportArbText("serviceMsgFieldCustomWeeks", "周数"),
        "class_weeks" to ImportArbText("serviceMsgFieldClassWeeks", "上课周"),
        "start_week" to ImportArbText("serviceMsgFieldStartWeek", "开始周"),
        "end_week" to ImportArbText("serviceMsgFieldEndWeek", "结束周"),
        "course_name" to ImportArbText("serviceMsgFieldCourseName", "课程名称"),
    )

    /** 单测对拍用：本对象用到的全部 ARB 文案。 */
    val allTexts: List<ImportArbText>
        get() = listOf(unknownError, rowWarning) + templates.values + fieldNames.values

    /**
     * 把服务层消息（裸码或 `code|k=v|…` 载荷）渲染成屏上文案。
     *
     * null / 空白 ⇒ 兜底文案（Dart 入参不可空；宿主拿到的可能是丢了的异常消息，
     * 空白渲染成「发生未知错误」比崩或显示空串安全）。
     */
    fun localize(raw: String?): String {
        if (raw.isNullOrBlank()) {
            return unknownError.text
        }
        val text = raw.trim()
        val parsed = parse(text)
        return render(parsed.code, parsed.args) ?: fallback(parsed.code, text)
    }

    /** 一条解析后的载荷：码 + 平铺参数。 */
    data class Payload(val code: String, val args: Map<String, String>)

    /**
     * 按 Dart `parseServiceMessage` 的形状切：第一个 `|` 前是码，其后每段 `k=v`。
     * 没有 `=` 的段直接忽略（Dart 同口径：解析不出参数的段不产生键）。
     */
    fun parse(text: String): Payload {
        val parts = text.split('|')
        val code = parts.first()
        val args = LinkedHashMap<String, String>()
        for (part in parts.drop(1)) {
            val index = part.indexOf('=')
            if (index > 0) {
                args[part.substring(0, index)] = part.substring(index + 1)
            }
        }
        return Payload(code = code, args = args)
    }

    /**
     * 渲染一条「码 + 参数」。未登记返回 null（由 [localize] 决定兜底还是透传）。
     *
     * 行级警告在这里递归：内层码带着**外层平铺参数**再走一遍本函数，
     * 这样 `field_cannot_be_empty|field=课程名称` 才能显示出字段名。
     */
    fun render(code: String, args: Map<String, String>): String? {
        if (code == ROW_WARNING_CODE) {
            val rowNumber = args["rowNumber"] ?: "0"
            val innerCode = args["inner"].orEmpty()
            val message = render(innerCode, args)
                ?: if (innerCode.isBlank()) unknownError.text else fallback(innerCode, innerCode)
            return rowWarning.filled("rowNumber" to rowNumber, "message" to message)
        }
        val template = templates[code] ?: return null
        return when (code) {
            "spreadsheet_format_unrecognized" -> template.text
            "spreadsheet_format_or_encoding_unrecognized" -> template.text
            "course_name_required" -> template.text
            "weekday_must_be_1_to_7" -> template.text
            "custom_weeks_required" -> template.text
            "class_weeks_required" -> template.text
            "start_week_must_be_at_least_1" -> template.text
            "end_week_before_start_week" -> template.text
            "weeks_range_required" -> template.text
            "spreadsheet_xlsx_parse_failed" -> template.filled("error", args["error"].orEmpty())
            "spreadsheet_wakeup_insufficient_columns" -> template.filled(
                "rowNumber" to (args["rowNumber"] ?: "0"),
                "columnCount" to (args["columnCount"] ?: "0"),
            )
            "start_week_exceeds_semester" -> template.filled(
                "startWeek" to (args["startWeek"] ?: "0"),
                "semesterWeekCount" to (args["semesterWeekCount"] ?: "0"),
            )
            "field_must_be_at_least_1" -> template.filled("field", fieldName(args["field"]))
            "field_must_be_integer" -> template.filled("field", fieldName(args["field"]))
            "field_cannot_be_empty" -> template.filled("field", fieldName(args["field"]))
            "field_cannot_be_less_than" -> template.filled(
                "startField" to fieldName(args["startField"]),
                "endField" to fieldName(args["endField"]),
            )
            "section_out_of_range" -> template.filled(
                "section" to (args["section"] ?: "0"),
                "maxSection" to (args["maxSection"] ?: "0"),
            )
            "spreadsheet_end_week_clamped" -> template.filled(
                "rowNumber" to (args["rowNumber"] ?: "0"),
                "endWeek" to (args["endWeek"] ?: "0"),
                "semesterWeekCount" to (args["semesterWeekCount"] ?: "0"),
            )
            "spreadsheet_odd_even_both" -> template.filled("rowNumber", args["rowNumber"] ?: "0")
            "week_start_invalid" -> template.filled("itemName", args["itemName"].orEmpty())
            "week_range_invalid" -> template.filled("itemName", args["itemName"].orEmpty())
            "week_range_too_large" -> template.filled("itemName", args["itemName"].orEmpty())
            "week_token_unrecognized" -> template.filled(
                "itemName" to args["itemName"].orEmpty(),
                "token" to args["token"].orEmpty(),
            )
            "weeks_exceed_semester_clamped" -> template.filled(
                "itemName" to args["itemName"].orEmpty(),
                "semesterWeekCount" to (args["semesterWeekCount"] ?: "0"),
                "weeks" to args["weeks"].orEmpty(),
            )
            else -> template.text
        }
    }

    /** 字段码 → 字段名；未登记原样透传（Dart `default: return fieldCode ?? ''`）。 */
    fun fieldName(code: String?): String = fieldNames[code]?.text ?: code.orEmpty()

    /**
     * 未登记的码：像内部机器码就兜底，像人话就原样（Dart 的正则逐字照抄）。
     *
     * `Bad state: xxx` 带空格与大写 ⇒ 不命中 ⇒ 透传；
     * `settings_mirror_snapshot_invalid:key1` ⇒ 命中 ⇒ 兜底。
     */
    private fun fallback(code: String, original: String): String =
        if (INTERNAL_CODE_PATTERN.matches(code)) unknownError.text else original

    /** Dart `_internalCodePattern`。 */
    private val INTERNAL_CODE_PATTERN = Regex("""^[a-z][a-z0-9_]*(:[A-Za-z0-9._-]+)?$""")

    /** 行级警告外壳的码（[SpreadsheetImportModel] 的 `encodeServiceRowWarning` 用它）。 */
    const val ROW_WARNING_CODE = "spreadsheet_row_warning"
}
