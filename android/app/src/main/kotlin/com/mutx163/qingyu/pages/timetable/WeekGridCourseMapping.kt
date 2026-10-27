package com.mutx163.qingyu.pages.timetable

import kotlin.math.max
import kotlin.math.min

/**
 * 课表周视图统一课程模型。
 */
data class TimetableCourse(
    val id: String,
    val name: String,
    val teacher: String = "",
    val location: String = "",
    val dayOfWeek: Int, // 1..7（周一到周日）
    val startSection: Int,
    val endSection: Int,
    val weeks: List<Int> = emptyList(),
    val color: String = "#2196F3",
    val textColor: String? = null,
    val isSuspended: Boolean = false,
    val suspendedWeeks: List<Int> = emptyList(),
) {
    val sectionCount: Int
        get() = (endSection - startSection + 1).coerceAtLeast(1)

    fun isActiveInWeek(week: Int): Boolean {
        if (isSuspended || suspendedWeeks.contains(week)) return false
        return weeks.contains(week)
    }
}

/**
 * 周网格课卡渲染模型。
 * 包含重叠冲突计算后的列分配（colIndex 与 totalCols），供 Compose 布局切分宽度。
 */
data class WeekCourseCardModel(
    val course: TimetableCourse,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val sectionSpan: Int,
    val isCurrentWeek: Boolean,
    val isConflicting: Boolean = false,
    val colIndex: Int = 0,
    val totalCols: Int = 1,
    val displayColor: String = course.color,
    val opacity: Float = 1.0f,
)

/**
 * 周视图某一天的列模型。
 */
data class WeekDayColumn(
    val dayOfWeek: Int,
    val dayName: String = TimetableStrings.formatWeekday(dayOfWeek),
    val isToday: Boolean = false,
    val courses: List<WeekCourseCardModel> = emptyList(),
)

object WeekGridCourseMapping {

    const val NON_CURRENT_WEEK_COLOR_HEX = "#94A3B8"
    const val NON_CURRENT_WEEK_OPACITY = 0.62f
    const val CONFLICT_COURSE_OPACITY = 0.85f

    /**
     * 将课程列表按周次过滤并计算同天重叠节次的列分配（colIndex, totalCols）。
     *
     * @param courses 全部课程
     * @param week 当前查看的周次（1-based）
     * @param showNonCurrentWeeks 是否包含非本周课程（非本周课程以灰卡淡化展示）
     * @return 映射表：星期 1..7 -> 该日课卡模型列表
     */
    fun filterAndPlaceCoursesForWeek(
        courses: List<TimetableCourse>,
        week: Int,
        showNonCurrentWeeks: Boolean = true,
    ): Map<Int, List<WeekCourseCardModel>> {
        val result = LinkedHashMap<Int, MutableList<WeekCourseCardModel>>()
        for (day in 1..7) {
            result[day] = mutableListOf()
        }

        // 1. 过滤有效课程
        val eligibleCourses = courses.filter { course ->
            course.dayOfWeek in 1..7 &&
                course.startSection <= course.endSection &&
                course.startSection >= 1 &&
                (showNonCurrentWeeks || course.isActiveInWeek(week))
        }

        // 2. 按天分组处理
        val coursesByDay = eligibleCourses.groupBy { it.dayOfWeek }

        for (day in 1..7) {
            val dayCourses = coursesByDay[day] ?: emptyList()
            if (dayCourses.isEmpty()) continue

            // 排序：开始节次升序 -> 本周优先 -> 结束节次升序 -> id 升序
            val sorted = dayCourses.sortedWith(
                compareBy(
                    { it.startSection },
                    { !it.isActiveInWeek(week) },
                    { it.endSection },
                    { it.id },
                )
            )

            // 3. 将当天课程切分为重叠连通块（Cluster）
            val clusters = buildOverlapClusters(sorted)

            // 4. 为每个连通块分配列轨道
            for (cluster in clusters) {
                val models = assignColumnsToCluster(cluster, week)
                result[day]?.addAll(models)
            }
        }

        return result
    }

    /**
     * 判断两门课在节次上是否有重叠交集。
     */
    fun isSectionOverlapping(c1: TimetableCourse, c2: TimetableCourse): Boolean {
        return max(c1.startSection, c2.startSection) <= min(c1.endSection, c2.endSection)
    }

    /**
     * 将按开始节次排好序的课程划分为多个互不相交的连通块。
     * 若后一门课的 startSection <= 当前块的最大 endSection，则属于同一连通块。
     */
    private fun buildOverlapClusters(sortedCourses: List<TimetableCourse>): List<List<TimetableCourse>> {
        if (sortedCourses.isEmpty()) return emptyList()

        val clusters = mutableListOf<MutableList<TimetableCourse>>()
        var currentCluster = mutableListOf<TimetableCourse>()
        var clusterMaxEnd = -1

        for (course in sortedCourses) {
            if (currentCluster.isEmpty()) {
                currentCluster.add(course)
                clusterMaxEnd = course.endSection
            } else if (course.startSection <= clusterMaxEnd) {
                // 重叠或紧密衔接处于同一连续时段
                currentCluster.add(course)
                clusterMaxEnd = max(clusterMaxEnd, course.endSection)
            } else {
                clusters.add(currentCluster)
                currentCluster = mutableListOf(course)
                clusterMaxEnd = course.endSection
            }
        }

        if (currentCluster.isNotEmpty()) {
            clusters.add(currentCluster)
        }

        return clusters
    }

    /**
     * 贪心区间着色：为连通块内的课程分配互不碰撞的列索引（0 until totalCols）。
     */
    private fun assignColumnsToCluster(
        cluster: List<TimetableCourse>,
        week: Int,
    ): List<WeekCourseCardModel> {
        if (cluster.isEmpty()) return emptyList()

        // trackEndSections[col] 记录当前列轨道上最后一门课的 endSection
        val trackEndSections = mutableListOf<Int>()
        val assignedColIndices = mutableListOf<Int>()

        for (course in cluster) {
            var placedCol = -1
            for (col in trackEndSections.indices) {
                if (trackEndSections[col] < course.startSection) {
                    placedCol = col
                    trackEndSections[col] = course.endSection
                    break
                }
            }
            if (placedCol == -1) {
                placedCol = trackEndSections.size
                trackEndSections.add(course.endSection)
            }
            assignedColIndices.add(placedCol)
        }

        val totalCols = max(1, trackEndSections.size)

        return cluster.mapIndexed { index, course ->
            val colIndex = assignedColIndices[index]
            val isCurrentWeek = course.isActiveInWeek(week)
            val hasActualOverlap = cluster.any { other ->
                other != course && isSectionOverlapping(course, other)
            }
            val isConflicting = hasActualOverlap

            val displayColor = if (isCurrentWeek) course.color else NON_CURRENT_WEEK_COLOR_HEX
            val opacity = when {
                !isCurrentWeek -> NON_CURRENT_WEEK_OPACITY
                isConflicting -> CONFLICT_COURSE_OPACITY
                else -> 1.0f
            }

            WeekCourseCardModel(
                course = course,
                dayOfWeek = course.dayOfWeek,
                startSection = course.startSection,
                endSection = course.endSection,
                sectionSpan = course.sectionCount,
                isCurrentWeek = isCurrentWeek,
                isConflicting = isConflicting,
                colIndex = colIndex,
                totalCols = totalCols,
                displayColor = displayColor,
                opacity = opacity,
            )
        }
    }

    /**
     * 构建包含 7 天完整信息的周日列列表。
     */
    fun buildWeekDayColumns(
        coursesByDay: Map<Int, List<WeekCourseCardModel>>,
        todayDayOfWeek: Int? = null,
    ): List<WeekDayColumn> {
        return (1..7).map { day ->
            WeekDayColumn(
                dayOfWeek = day,
                dayName = TimetableStrings.formatWeekday(day),
                isToday = (day == todayDayOfWeek),
                courses = coursesByDay[day] ?: emptyList(),
            )
        }
    }
}
