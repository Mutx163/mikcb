package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 自检预设课合成纯逻辑的端口测试（移植 lib/services/live_testing_fixture_service.dart
 * 的 buildPresetCourses / buildTimedTestCourse / buildHourlySections / formatClock）。
 *
 * 期望值来源：test/services/live_testing_fixture_service_test.dart 既有用例（[Dart抄录]）。
 */
class LiveTestingFixtureTest {

    private val base: LocalDateTime = LocalDateTime.of(2026, 3, 23, 10, 15) // 周一

    @Test
    fun presetCoursesAreBackToBack() { // [Dart抄录] A: +1..+4, B: +5..+8
        val presets = LiveTestingFixtureData.buildPresetCourses(base, targetWeek = 1, semesterWeekCount = 20)
        assertEquals(2, presets.size)
        assertEquals("live_test_preset_a", presets[0].id)
        assertEquals("live_test_preset_b", presets[1].id)
        assertEquals("10:16", presets[0].startTime)
        assertEquals("10:19", presets[0].endTime)
        assertEquals("10:20", presets[1].startTime)
        assertEquals("10:23", presets[1].endTime)
        assertTrue(presets.all { it.dayOfWeek == base.dayOfWeek.value })
        assertTrue(presets.all { LiveTestingFixtureData.isPresetCourse(it) })
        assertTrue(presets.all { LiveTestingFixtureData.isFixtureCourse(it) })
    }

    @Test
    fun presetWeekSpanCoversPreSemesterAndAfterTerm() { // [Dart抄录]
        val pre = LiveTestingFixtureData.buildPresetCourses(base, targetWeek = 0, semesterWeekCount = 20)
        assertTrue(pre.all { it.isInWeek(0) })
        assertTrue(pre.all { it.isInWeek(1) })

        val after = LiveTestingFixtureData.buildPresetCourses(base, targetWeek = 25, semesterWeekCount = 20)
        assertTrue(after.all { it.isInWeek(25) })
        assertTrue(after.none { it.isInWeek(26) })
    }

    @Test(expected = IllegalStateException::class)
    fun presetCoursesRejectMidnightCrossing() { // [Dart抄录] 23:58 + 1min 必抛
        LiveTestingFixtureData.buildPresetCourses(LocalDateTime.of(2026, 3, 23, 23, 58), targetWeek = 1, semesterWeekCount = 20)
    }

    @Test
    fun timedCourseShiftsClockKeepsSections() { // [Dart抄录] buildTimedTestCourse
        val sections = listOf(SectionTimeData("08:00", "08:45"), SectionTimeData("08:55", "09:40"), SectionTimeData("10:00", "10:45"))
        val template = LiveTestingFixtureData.buildSlotTemplate(
            sectionNumber = 3,
            section = sections[2],
            dayOfWeek = base.dayOfWeek.value,
            semesterWeekCount = 20,
        )
        val timed = LiveTestingFixtureData.buildTimedTestCourse(template, base, leadMinutes = 3)
        assertEquals("10:18", timed.startTime)
        assertEquals("10:21", timed.endTime)
        assertEquals(3, timed.startSection)
        assertEquals(3, timed.endSection)
        assertEquals(base.dayOfWeek.value, timed.dayOfWeek)
    }

    @Test(expected = IllegalStateException::class)
    fun timedCourseRejectsMidnightCrossing() { // [Dart抄录] 23:59 + 1min 必抛
        val template = LiveTestingFixtureData.buildSlotTemplate(
            sectionNumber = 24,
            section = SectionTimeData("23:00", "23:59"),
            dayOfWeek = 1,
            semesterWeekCount = 20,
        )
        LiveTestingFixtureData.buildTimedTestCourse(template, LocalDateTime.of(2026, 3, 23, 23, 58), leadMinutes = 1)
    }

    @Test
    fun hourlySectionsSpanWholeDay() { // [Dart抄录] 24 段 00:00-01:00 … 23:00-23:59
        val sections = LiveTestingFixtureData.buildHourlySections()
        assertEquals(24, sections.size)
        assertEquals("00:00", sections[0].startTime)
        assertEquals("01:00", sections[0].endTime)
        assertEquals("10:00", sections[10].startTime)
        assertEquals("11:00", sections[10].endTime)
        assertEquals("23:00", sections[23].startTime)
        assertEquals("23:59", sections[23].endTime)
    }

    @Test
    fun sectionNumberForTimePrefersProgressThenUpcoming() { // [Dart抄录]
        val sections = listOf(
            SectionTimeData("08:00", "08:45"),
            SectionTimeData("08:55", "09:40"),
            SectionTimeData("10:00", "10:45"),
            SectionTimeData("10:55", "11:40"),
            SectionTimeData("14:00", "14:45"),
        )
        assertEquals(1, LiveTestingFixtureData.sectionNumberForTime(LocalDateTime.of(2026, 3, 23, 7, 30), sections))
        assertEquals(1, LiveTestingFixtureData.sectionNumberForTime(LocalDateTime.of(2026, 3, 23, 8, 10), sections))
        assertEquals(3, LiveTestingFixtureData.sectionNumberForTime(LocalDateTime.of(2026, 3, 23, 10, 20), sections))
        assertEquals(5, LiveTestingFixtureData.sectionNumberForTime(LocalDateTime.of(2026, 3, 23, 22, 0), sections))
    }

    @Test
    fun nextSectionNumberWrapsAfterLast() { // [Dart抄录]
        val sections = listOf(
            SectionTimeData("08:00", "08:45"),
            SectionTimeData("08:55", "09:40"),
            SectionTimeData("10:00", "10:45"),
            SectionTimeData("10:55", "11:40"),
            SectionTimeData("14:00", "14:45"),
        )
        assertEquals(1, LiveTestingFixtureData.nextSectionNumberForTime(LocalDateTime.of(2026, 3, 23, 14, 10), sections))
        assertEquals(2, LiveTestingFixtureData.nextSectionNumberForTime(LocalDateTime.of(2026, 3, 23, 8, 10), sections))
    }

    @Test
    fun formatClockPadsMinute() { // [Dart推演] HH:mm 补零
        assertEquals("10:15", WidgetDataClock.formatClock(base))
        assertEquals("08:05", WidgetDataClock.formatClock(LocalDateTime.of(2026, 3, 23, 8, 5)))
    }

    @Test
    fun presetCourseDisplayFieldsAreStable() { // [Dart抄录] 与速览兜底副本同源
        val presets = LiveTestingFixtureData.buildPresetCourses(base, targetWeek = 1, semesterWeekCount = 20)
        assertEquals("自检预设课 A", presets[0].name)
        assertEquals("自检A", presets[0].shortName)
        assertEquals("自检教师", presets[0].teacher)
        assertEquals("自检教室 A", presets[0].location)
        assertEquals("自检预设课 B", presets[1].name)
        assertEquals("自检B", presets[1].shortName)
    }

    private fun Course.c(): Course = this
}
