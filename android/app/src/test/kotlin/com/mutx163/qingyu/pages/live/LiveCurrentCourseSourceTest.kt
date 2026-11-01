package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 「设置页预览读真实课程」的纯逻辑单测。
 *
 * 期望值全部手推：开学日 2026-09-07（周一），用到的「现在」都落在 2026-09-14（第 2 周周一），
 * 不依赖运行当天的真时钟。
 *
 * 时间模板故意与课程存档里的原始钟点不同（08:10-09:50 vs 08:00-09:40），
 * 用来证明预览读的是**按作息解析后的真实钟点**，不是课程字段原值。
 */
class LiveCurrentCourseSourceTest {

    private val semesterStart: LocalDateTime = LocalDateTime.of(2026, 9, 7, 0, 0)
    private val mondayMorning: LocalDateTime = LocalDateTime.of(2026, 9, 14, 0, 0)

    private val scheme = TimeScheme(
        id = "scheme-a",
        name = "第 1 作息",
        sections = listOf(
            SectionTime("08:10", "09:50"),
            SectionTime("10:00", "11:40"),
            SectionTime("14:00", "15:40"),
        ),
        createdAt = semesterStart,
        updatedAt = semesterStart,
    )

    private fun snapshot(
        courses: List<Course>,
        schemes: List<TimeScheme> = listOf(scheme),
        activeSchemeId: String? = scheme.id,
        semesterStartDate: LocalDateTime? = semesterStart,
    ): TimetableSnapshot = TimetableSnapshot(
        courses = courses,
        settings = TimetableSettings(
            sections = listOf(
                SectionTime("08:00", "09:40"),
                SectionTime("10:00", "11:40"),
                SectionTime("14:00", "15:40"),
            ),
            activeTimeSchemeId = activeSchemeId,
            semesterWeekCount = 20,
            semesterStartDate = semesterStartDate,
        ),
        currentWeek = 2,
        semesterStartEpochDay = semesterStartDate?.toLocalDate()?.toEpochDay(),
        timeSchemes = schemes,
        activeTimeSchemeId = activeSchemeId,
    )

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 1,
        startTime: String = "08:00",
        endTime: String = "09:40",
        location: String = "三教-401",
        teacher: String = "张老师",
        shortName: String? = null,
        note: String? = null,
        overrideSchemeId: String? = null,
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
        note = note,
        timeSchemeIdOverride = overrideSchemeId,
    )

    @Test
    fun `上课中返回当前课程并按作息模板解析真实钟点`() {
        val math = course(
            id = "c1",
            name = "高等数学",
            shortName = "高数",
            note = "带教材",
        )

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(listOf(math)),
            now = mondayMorning.withHour(8).withMinute(30),
        )

        assertEquals(LivePreviewMoment.IN_CLASS, result.moment)
        assertEquals("高等数学", result.course?.name)
        // 模板写的是 08:10-09:50；课程存档是 08:00-09:40。预览必须取模板。
        assertEquals("08:10", result.startTime)
        assertEquals("09:50", result.endTime)
        assertEquals(millisAt(8, 10), result.startMillis)
        assertEquals(millisAt(9, 50), result.endMillis)

        val preview = result.toIslandPreviewInfo()
        assertEquals("高等数学", preview?.courseName)
        assertEquals("高数", preview?.courseShortName)
        assertEquals("三教-401", preview?.location)
        assertEquals("张老师", preview?.teacher)
        assertEquals("08:10", preview?.startTime)
        assertEquals("09:50", preview?.endTime)
        assertEquals("带教材", preview?.note)
        assertEquals(LivePreviewMoment.IN_CLASS, preview?.moment)
    }

    @Test
    fun `课间返回下一节并带上再下一节名字`() {
        val math = course(id = "c1", name = "高等数学", startSection = 1, endSection = 1)
        val physics = course(
            id = "c2",
            name = "大学物理",
            startSection = 2,
            endSection = 2,
            startTime = "10:00",
            endTime = "11:40",
            location = "二教-201",
        )
        val english = course(
            id = "c3",
            name = "大学英语",
            startSection = 3,
            endSection = 3,
            startTime = "14:00",
            endTime = "15:40",
        )

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(listOf(math, physics, english)),
            now = mondayMorning.withHour(9).withMinute(55),
        )

        assertEquals(LivePreviewMoment.BETWEEN_CLASSES, result.moment)
        assertEquals("大学物理", result.course?.name)
        assertEquals("二教-201", result.course?.location)
        // 上一节 09:50 已下课，下一节按模板 10:00 开始。
        assertEquals("10:00", result.startTime)
        assertEquals("11:40", result.endTime)
        assertEquals("大学英语", result.nextCourseName)
        assertTrue(result.startMillis!! < result.endMillis!!)
    }

    @Test
    fun `今天没有课时返回诚实空态而不是演示课程`() {
        val tomorrow = course(id = "c1", name = "高等数学", dayOfWeek = 2)

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(listOf(tomorrow)),
            now = mondayMorning.withHour(10),
        )

        assertEquals(LivePreviewMoment.NO_COURSE, result.moment)
        assertNull(result.course)
        assertNull(result.toIslandPreviewInfo())
    }

    @Test
    fun `今天的课都上完后也是空态`() {
        val math = course(id = "c1", name = "高等数学", startSection = 1, endSection = 2)

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(listOf(math)),
            now = mondayMorning.withHour(23),
        )

        assertEquals(LivePreviewMoment.NO_COURSE, result.moment)
        assertNull(result.course)
    }

    @Test
    fun `学期未设置直接空态并标记原因`() {
        val math = course(id = "c1", name = "高等数学")

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(listOf(math), semesterStartDate = null),
            now = mondayMorning.withHour(8).withMinute(30),
        )

        assertEquals(LivePreviewMoment.NO_COURSE, result.moment)
        assertTrue(result.semesterStartMissing)
        assertNull(result.toIslandPreviewInfo())
    }

    @Test
    fun `开学前不把第 1 周的课提前显示`() {
        val math = course(id = "c1", name = "高等数学")

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(listOf(math)),
            now = semesterStart.minusDays(3),
        )

        assertEquals(LivePreviewMoment.NO_COURSE, result.moment)
        assertNull(result.course)
    }

    @Test
    fun `课程手动绑定的副模板优先于档案默认模板`() {
        val override = TimeScheme(
            id = "override",
            name = "副模板",
            sections = listOf(SectionTime("07:30", "09:00")),
            createdAt = semesterStart,
            updatedAt = semesterStart,
        )
        val math = course(
            id = "c1",
            name = "高等数学",
            overrideSchemeId = override.id,
        )

        val result = LiveCurrentCourseSource.resolve(
            snapshot = snapshot(
                courses = listOf(math),
                schemes = listOf(scheme, override),
                activeSchemeId = scheme.id,
            ),
            now = mondayMorning.withHour(7).withMinute(45),
        )

        assertEquals(LivePreviewMoment.IN_CLASS, result.moment)
        assertEquals("07:30", result.startTime)
        assertEquals("09:00", result.endTime)
    }

    private fun millisAt(hour: Int, minute: Int): Long =
        LocalDate.of(2026, 9, 14)
            .atStartOfDay()
            .plusHours(hour.toLong())
            .plusMinutes(minute.toLong())
            .atZone(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
}
