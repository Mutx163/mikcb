package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * AI 识图导入课程结构。
 */
data class AiParsedCourse(
    val name: String,
    val teacher: String = "",
    val location: String = "",
    val dayOfWeek: Int = 1,
    val startSection: Int = 1,
    val endSection: Int = 1,
    val customWeeks: List<Int> = emptyList(),
    val courseNature: String = "",
    val note: String = "",
)

/**
 * AI 课表解析结果。
 */
data class AiCourseImportParseResult(
    val courses: List<AiParsedCourse> = emptyList(),
    val warnings: List<String> = emptyList(),
) {
    val requiredSectionCount: Int
        get() = if (courses.isEmpty()) 0 else courses.maxOf { it.endSection }

    val isValid: Boolean get() = courses.isNotEmpty()
}

/**
 * 工作流箭头标题拆分为步骤列表（支持 -> 或 → 符号）。
 */
fun splitWorkflowArrowTitle(title: String): List<String> {
    return title.split(Regex("""\s*(?:->|→)\s*"""))
        .map { it.trim() }
        .filter { it.isNotEmpty() }
}

/**
 * AI 识图提示词模板。
 */
const val AI_IMPORT_SYSTEM_PROMPT = """你是轻屿课表的专属视觉解析引擎，你的任务是精准识别课程表截图，并将其转化为严格的 JSON 数据供本地解析。

【核心阅读策略：按列与单元格读取】
图片是一个二维表格，表头是星期（周一至周日），左侧是节次。
你必须严格按照列（星期）逐个单元格进行读取，一个单元格内的一堆换行文字，代表一门课程的完整信息，绝不能跨列合并文字！

【数据结构与输出红线】
你只能输出一个纯粹的 JSON 对象，绝不能包含任何 markdown 标记（如 ```json ）、前言、后语或注释。

{
  "schema": "mikcb_ai_import_v1",
  "courses": [
    {
      "name": "课程名",
      "teacher": "教师",
      "location": "地点",
      "dayOfWeek": 1,
      "startSection": 1,
      "endSection": 4,
      "customWeeks": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      "courseNature": "必修",
      "note": ""
    }
  ],
  "warnings": []
}"""

/**
 * 提取并解析 AI 返回的 JSON 字符串（自动剥离 ```json 围栏）。
 */
fun parseAiImageImportJson(rawInput: String): AiCourseImportParseResult {
    val trimmed = rawInput.trim()
    if (trimmed.isEmpty()) {
        return AiCourseImportParseResult(warnings = listOf(WarehouseStrings.aiPasteJsonFirst.text))
    }

    // 剥离 ```json 或 ``` 围栏
    val jsonContent = if (trimmed.startsWith("```")) {
        val lines = trimmed.lines()
        val contentLines = lines.drop(1).dropLastWhile { it.trim().startsWith("```") || it.trim().isEmpty() }
        contentLines.joinToString("\n").trim()
    } else {
        trimmed
    }

    val parsed = runCatching { MiniJson.parse(jsonContent) }.getOrNull()
    if (parsed !is Map<*, *>) {
        return AiCourseImportParseResult(
            warnings = listOf(WarehouseStrings.aiParseFailedIncompleteJson.text)
        )
    }

    val schema = parsed["schema"] as? String
    val warnings = mutableListOf<String>()
    if (schema != "mikcb_ai_import_v1") {
        warnings.add("schema mismatch or missing: $schema")
    }

    val rawWarnings = parsed["warnings"]
    if (rawWarnings is List<*>) {
        for (w in rawWarnings) {
            if (w is String && w.isNotBlank()) warnings.add(w)
        }
    }

    val rawCourses = parsed["courses"]
    if (rawCourses !is List<*>) {
        return AiCourseImportParseResult(warnings = warnings)
    }

    val courseList = mutableListOf<AiParsedCourse>()
    for (item in rawCourses) {
        if (item !is Map<*, *>) continue
        val name = (item["name"] as? String)?.trim().orEmpty()
        if (name.isEmpty()) continue

        val teacher = (item["teacher"] as? String)?.trim().orEmpty()
        val location = (item["location"] as? String)?.trim().orEmpty()
        val dayOfWeek = (item["dayOfWeek"] as? Number)?.toInt() ?: 1
        val startSection = (item["startSection"] as? Number)?.toInt() ?: 1
        val endSection = (item["endSection"] as? Number)?.toInt() ?: maxOf(startSection, 1)
        val courseNature = (item["courseNature"] as? String)?.trim().orEmpty()
        val note = (item["note"] as? String)?.trim().orEmpty()

        val customWeeks = mutableListOf<Int>()
        val rawWeeks = item["customWeeks"]
        if (rawWeeks is List<*>) {
            for (w in rawWeeks) {
                if (w is Number) customWeeks.add(w.toInt())
            }
        }

        courseList.add(
            AiParsedCourse(
                name = name,
                teacher = teacher,
                location = location,
                dayOfWeek = dayOfWeek.coerceIn(1, 7),
                startSection = startSection.coerceAtLeast(1),
                endSection = endSection.coerceAtLeast(startSection),
                customWeeks = customWeeks,
                courseNature = courseNature,
                note = note,
            )
        )
    }

    return AiCourseImportParseResult(
        courses = courseList,
        warnings = warnings,
    )
}
