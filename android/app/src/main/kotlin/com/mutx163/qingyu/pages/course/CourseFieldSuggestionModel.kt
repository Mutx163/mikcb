package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course

/**
 * 「已有教师 / 地点」候选清单（发布版 `timetable_provider.dart` 的
 * `uniqueTeachers` / `uniqueLocations`，见 `add_course_screen.dart:917/:933` 与
 * `course_followup_sheets.dart:421` 的 `locationSuggestions`）。
 *
 * 发布版的数据源是「持久化历史记录 + 当前课程」两份；本仓没有那两份历史记录表，
 * **已知差异**：候选只从现有课程（教师 / 地点）与日程地点去重导出，不伪造历史。
 *
 * 口径对齐 Dart：
 * - 空值剔除（Dart `isNotEmpty`；这里再补一道 `isBlank`，纯空格也不进候选）；
 * - **精确去重、不做大小写折叠**（Dart 是 `Set<String>` 精确比对；「A101」与「a101」
 *   在发布版也是两条，这里照抄，不自己发明合并规则）；
 * - 自然序 `sort()`（Dart `..sort()` 同为 UTF-16 码元序）。
 */
data class CourseFieldSuggestions(
    val teachers: List<String>,
    val locations: List<String>,
) {
    companion object {
        /** 空候选（宿主没接线 / 新用户）：弹层只留手输。 */
        val EMPTY = CourseFieldSuggestions(emptyList(), emptyList())
    }
}

object CourseFieldSuggestionLogic {

    /**
     * 从课程与日程导出候选：
     * - 教师：只来自课程（日程没有教师字段）；
     * - 地点：课程 + 日程地点（由调用方拍平成 `List<String?>`；本层不依赖日程模型，L0 可编）。
     */
    fun build(
        courses: List<Course>,
        scheduleLocations: List<String?> = emptyList(),
    ): CourseFieldSuggestions {
        val teachers = sortedNonBlank(courses.map { it.teacher })
        val locationPool = buildList {
            courses.forEach { add(it.location) }
            scheduleLocations.forEach { location -> location?.let { add(it) } }
        }
        return CourseFieldSuggestions(
            teachers = teachers,
            locations = sortedNonBlank(locationPool),
        )
    }

    /** 去空、精确去重、自然序——三个步骤与 Dart 的 `Set` + `sort` 一一对应。 */
    private fun sortedNonBlank(values: List<String>): List<String> =
        values.filter { it.isNotBlank() }.toSet().toList().sorted()
}
