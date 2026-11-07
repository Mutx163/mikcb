package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature

/**
 * 课程总览排序模式（对齐 `lib/screens/course_overview_screen.dart:_SortMode`，默认 added）。
 */
enum class CourseOverviewSortMode {
    NAME,
    SCHEDULE,
    ADDED;

    companion object {
        fun fromIndex(index: Int): CourseOverviewSortMode =
            entries.getOrNull(index) ?: ADDED
    }
}

/**
 * 同名课程聚合（对齐 `lib/utils/course_group.dart:CourseGroup`）。
 *
 * 纯 UI 层聚合：底层存储仍是独立的 [Course]。共享字段取自组内第一门课；
 * 最早星期/节次取全组最小值，供「按排课时间」排序。
 */
data class CourseGroup(
    val name: String,
    val courses: List<Course>,
) {
    val teacher: String get() = courses.first().teacher
    val color: String get() = courses.first().color
    val shortName: String? get() = courses.first().shortName
    val courseNature: CourseNature get() = courses.first().courseNature
    val description: String? get() = courses.first().description
    val note: String? get() = courses.first().note

    /** 全组最早的星期（1-7）。 */
    val earliestDayOfWeek: Int get() = courses.minOf { it.dayOfWeek }

    /** 全组最早的开始节次。 */
    val earliestStartSection: Int get() = courses.minOf { it.startSection }

    /** 课表摘要，如 ["周 三 5～6 节", "周 一 2～3 节"]（对齐 scheduleChipLabels）。 */
    fun scheduleChipLabels(): List<String> = courses.map { c ->
        CourseOverviewStrings.weekdaySectionSummary.filled(
            "weekday" to CourseOverviewStrings.weekdayShortLabel(c.dayOfWeek),
            "startSection" to c.startSection.toString(),
            "endSection" to c.endSection.toString(),
        )
    }

    /** 行标题：有短名时拼成「名称 (短名)」（对齐 `_displayName`，空串视同没有）。 */
    fun displayName(): String {
        val shortName = shortName
        return if (!shortName.isNullOrEmpty()) "$name ($shortName)" else name
    }

    /** 行副标题：「教师 · 摘要 · 摘要」；教师为空则只留摘要（对齐 `_subtitle`）。 */
    fun subtitle(): String {
        val schedules = scheduleChipLabels().joinToString(" · ")
        return if (teacher.isEmpty()) schedules else "$teacher · $schedules"
    }

    companion object {
        /** 按名字分组，保持课程在列表中的出现顺序（对齐 CourseGroup.buildFrom）。 */
        fun buildFrom(courses: List<Course>): List<CourseGroup> {
            val grouped = LinkedHashMap<String, MutableList<Course>>()
            for (course in courses) {
                grouped.getOrPut(course.name) { mutableListOf() }.add(course)
            }
            return grouped.map { (name, list) -> CourseGroup(name = name, courses = list.toList()) }
        }
    }
}

/**
 * 课程组行展示模型（`_CourseGroupTile` 渲染所需的全部数据，渲染层不再做计算）。
 */
data class CourseGroupRow(
    val group: CourseGroup,
    val displayName: String,
    val subtitle: String,
    val natureLabel: String,
    val hasConflict: Boolean,
)

/** 排序弹层选项（Dart 侧 `HyperosSelectPopup` 的 items：added → name → schedule）。 */
data class CourseSortOption(
    val mode: CourseOverviewSortMode,
    val label: String,
    val isSelected: Boolean,
)

/**
 * 课程总览页整页视图状态。
 */
data class CourseOverviewViewState(
    val rows: List<CourseGroupRow>,
    val sortMode: CourseOverviewSortMode,
    val sortOptions: List<CourseSortOption>,
    /** 冲突表条数（`conflictMap.length`）；> 0 时列表顶部出现冲突入口行。 */
    val conflictCount: Int,
    val isEmpty: Boolean,
    val emptyHint: String,
    val addCourseAction: String,
    val conflictEntryTitle: String,
    val conflictEntryDetail: String,
)

/**
 * 课程总览纯逻辑（排序、冲突标记、视图状态组装）。
 */
object CourseOverviewLogic {

    /**
     * 排序（对齐 `_sortGroups`）：
     * - NAME：课程名字典序；
     * - SCHEDULE：先比最早星期、平手比最早节次；
     * - ADDED：保持添加顺序。
     *
     * 返回新列表，不改入参顺序（Dart 侧作用在 `List.of` 复制上）。
     */
    fun sortGroups(
        groups: List<CourseGroup>,
        mode: CourseOverviewSortMode,
    ): List<CourseGroup> = when (mode) {
        CourseOverviewSortMode.NAME -> groups.sortedBy { it.name }
        CourseOverviewSortMode.SCHEDULE -> groups.sortedWith(
            compareBy({ it.earliestDayOfWeek }, { it.earliestStartSection }),
        )
        CourseOverviewSortMode.ADDED -> groups
    }

    /** 组内任一课程 id 命中冲突表即标冲突（对齐 `_groupHasConflict`）。 */
    fun groupHasConflict(
        group: CourseGroup,
        conflictMap: Map<String, List<Course>>,
    ): Boolean = group.courses.any { conflictMap.containsKey(it.id) }

    /** 课程性质标签（对齐 `lib/l10n/enum_localizations.dart:courseNatureLabel`）。 */
    fun courseNatureLabel(nature: CourseNature): String = when (nature) {
        CourseNature.REQUIRED -> CourseOverviewStrings.courseNatureRequired.text
        CourseNature.ELECTIVE -> CourseOverviewStrings.courseNatureElective.text
    }

    /**
     * 组装整页视图状态。
     *
     * @param courses 课表全量课程（provider.courseGroups 的输入口径）
     * @param conflictMap 冲突表（key = 课程 id），空 map 即无冲突入口
     * @param sortMode 当前排序档，默认按添加顺序（Dart `_SortMode.added` 初值）
     */
    fun buildViewState(
        courses: List<Course>,
        conflictMap: Map<String, List<Course>>,
        sortMode: CourseOverviewSortMode = CourseOverviewSortMode.ADDED,
    ): CourseOverviewViewState {
        val groups = sortGroups(CourseGroup.buildFrom(courses), sortMode)
        val rows = groups.map { group ->
            CourseGroupRow(
                group = group,
                displayName = group.displayName(),
                subtitle = group.subtitle(),
                natureLabel = courseNatureLabel(group.courseNature),
                hasConflict = groupHasConflict(group, conflictMap),
            )
        }
        val conflictCount = conflictMap.size

        // 弹层三项与 Dart `items` 字面量同序：added → name → schedule
        val sortOptions = listOf(
            CourseSortOption(
                mode = CourseOverviewSortMode.ADDED,
                label = CourseOverviewStrings.sortByAdded.text,
                isSelected = sortMode == CourseOverviewSortMode.ADDED,
            ),
            CourseSortOption(
                mode = CourseOverviewSortMode.NAME,
                label = CourseOverviewStrings.sortByName.text,
                isSelected = sortMode == CourseOverviewSortMode.NAME,
            ),
            CourseSortOption(
                mode = CourseOverviewSortMode.SCHEDULE,
                label = CourseOverviewStrings.sortBySchedule.text,
                isSelected = sortMode == CourseOverviewSortMode.SCHEDULE,
            ),
        )

        return CourseOverviewViewState(
            rows = rows,
            sortMode = sortMode,
            sortOptions = sortOptions,
            conflictCount = conflictCount,
            isEmpty = rows.isEmpty(),
            emptyHint = CourseOverviewStrings.emptyCourseOverviewHint.text,
            addCourseAction = CourseOverviewStrings.addNewCourseTooltip.text,
            conflictEntryTitle = CourseOverviewStrings.courseConflictDetailEntryTitle.text,
            conflictEntryDetail =
                CourseOverviewStrings.conflictCountLabel.filled("count", conflictCount.toString()),
        )
    }
}
