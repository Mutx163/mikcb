package com.mutx163.qingyu.statistics

import com.mutx163.qingyu.core.Course

/**
 * 统计卡片快照构建（移植自 lib/services/stats_widget_service.dart:10-104）。
 *
 * Dart 侧 StatsWidgetSnapshot 的消费方是原生 StatsWidgetSupport.kt（真机已验证），
 * JSON 键名逐字一致：profileName/currentWeek/weekSections/weekCourseCount/
 * deltaVsLastWeek/semesterDone/semesterTotal/requiredCount/electiveCount/longestStreak。
 * 本类只做「课表 → 快照」的纯装配；MethodChannel 推送（syncStatsSnapshot）是 IO，
 * 留给宿主接线层。
 *
 * 注意：这里的 WeekStats/SemesterStats 等来自泳道 B 的 CourseStub 口径
 * （statistics 包内部），与 core.Course 字段子集兼容——CourseStub 的构造
 * 需要 name/teacher/location 等，本入口直接收 core.Course 并就地换装。
 */
object StatsWidgetSnapshotBuilder {

    /** 快照值对象（Dart stats_widget_service.dart:10-33；JSON 键即 toJson 键）。 */
    data class StatsSnapshot(
        val profileName: String,
        val currentWeek: Int,
        val weekSections: Int,
        val weekCourseCount: Int,
        val deltaVsLastWeek: Int,
        val semesterDone: Int,
        val semesterTotal: Int,
        val requiredCount: Int,
        val electiveCount: Int,
        val longestStreak: Int,
    ) {
        fun toJson(): Map<String, Any?> = linkedMapOf(
            "profileName" to profileName,
            "currentWeek" to currentWeek,
            "weekSections" to weekSections,
            "weekCourseCount" to weekCourseCount,
            "deltaVsLastWeek" to deltaVsLastWeek,
            "semesterDone" to semesterDone,
            "semesterTotal" to semesterTotal,
            "requiredCount" to requiredCount,
            "electiveCount" to electiveCount,
            "longestStreak" to longestStreak,
        )
    }

    /** core.Course → CourseStub 的机械换装（Stub 只消费统计相关字段）。 */
    private fun Course.toStub() = com.mutx163.qingyu.statistics.CourseStub(
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        courseNature = courseNature,
    )

    /**
     * 从课表数据构建快照；无课时返回 null（stats_widget_service.dart:54-56：
     * 由调用方决定跳过还是清空）。
     */
    fun fromCourses(
        courses: List<Course>,
        currentWeek: Int,
        semesterWeekCount: Int,
        profileName: String,
    ): StatsSnapshot? {
        if (courses.isEmpty()) return null
        val stubs = courses.map { it.toStub() }
        val weekStats = StatisticsService.calculate(allCourses = stubs, week = currentWeek)
        val semesterStats = StatisticsService.calculateSemester(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )
        val progress = StatisticsService.calculateSemesterProgress(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )
        val comparison = StatisticsService.calculateWeeklyComparison(
            allCourses = stubs,
            currentWeek = currentWeek,
            semesterWeekCount = semesterWeekCount,
        )
        return StatsSnapshot(
            profileName = profileName,
            currentWeek = currentWeek,
            weekSections = weekStats.totalSections,
            weekCourseCount = weekStats.totalCourses,
            deltaVsLastWeek = comparison.deltaVsLastWeek,
            semesterDone = semesterStats.totalSections,
            semesterTotal = progress.sectionsTotal,
            requiredCount = semesterStats.natureStats.requiredCount,
            electiveCount = semesterStats.natureStats.electiveCount,
            longestStreak = semesterStats.longestStreak,
        )
    }
}
