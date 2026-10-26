package com.mutx163.qingyu.statistics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * StatsWidgetSnapshotBuilder 端口测试。
 * 期望值来源：[Dart抄录] stats_widget_service.dart 的装配逻辑 + 既有统计口径；
 * [人推] 独立推的边界值。
 */
class StatsWidgetSnapshotBuilderTest {

    private fun course(
        id: String,
        dayOfWeek: Int = 1,
        nature: CourseNature = CourseNature.REQUIRED,
        startWeek: Int = 1,
        endWeek: Int = 16,
        customWeeks: List<Int>? = null,
    ) = Course(
        id = id, name = "课$id", teacher = "师", location = "地",
        dayOfWeek = dayOfWeek, startSection = 1, endSection = 2,
        startTime = "08:00", endTime = "09:40",
        startWeek = startWeek, endWeek = endWeek, courseNature = nature,
        customWeeks = customWeeks,
    )

    @Test
    fun emptyCourses_returnsNull() { // [Dart抄录] :54-56 无课返回 null
        assertNull(StatsWidgetSnapshotBuilder.fromCourses(emptyList(), 1, 20, "主课表"))
    }

    @Test
    fun jsonKeys_matchDartContract() { // [Dart抄录] :35-49 toJson 键序逐字
        val snapshot = StatsWidgetSnapshotBuilder.fromCourses(
            listOf(course("a")), currentWeek = 5, semesterWeekCount = 20, profileName = "主课表",
        )!!
        assertEquals(
            listOf(
                "profileName", "currentWeek", "weekSections", "weekCourseCount",
                "deltaVsLastWeek", "semesterDone", "semesterTotal",
                "requiredCount", "electiveCount", "longestStreak",
            ),
            snapshot.toJson().keys.toList(),
        )
    }

    @Test
    fun singleWeekOneCourse_counts() { // [人推] 一门课一周 2 节：weekSections=2
        val snapshot = StatsWidgetSnapshotBuilder.fromCourses(
            listOf(course("a", dayOfWeek = 3, startWeek = 1, endWeek = 20)),
            currentWeek = 5, semesterWeekCount = 20, profileName = "p",
        )!!
        // 第 5 周：该课活跃 → 本周课时 2（1 节课占 2 节），本周门数 1
        assertEquals(2, snapshot.weekSections)
        assertEquals(1, snapshot.weekCourseCount)
        assertEquals("p", snapshot.profileName)
        assertEquals(5, snapshot.currentWeek)
    }

    @Test
    fun natureSplit_requiredVsElective() { // [人推] 必修/选修分桶
        val snapshot = StatsWidgetSnapshotBuilder.fromCourses(
            listOf(
                course("r1", nature = CourseNature.REQUIRED),
                course("e1", nature = CourseNature.ELECTIVE),
            ),
            currentWeek = 3, semesterWeekCount = 16, profileName = "p",
        )!!
        assertEquals(1, snapshot.requiredCount)
        assertEquals(1, snapshot.electiveCount)
    }

    @Test
    fun customWeeks_courseOutsideCurrentWeek_excludedFromWeek() { // [人推] 本周不在 customWeeks → 本周课时 0
        val snapshot = StatsWidgetSnapshotBuilder.fromCourses(
            listOf(course("a", customWeeks = listOf(2))),
            currentWeek = 5, semesterWeekCount = 16, profileName = "p",
        )!!
        assertEquals(0, snapshot.weekSections)
        assertEquals(0, snapshot.weekCourseCount)
    }
}
