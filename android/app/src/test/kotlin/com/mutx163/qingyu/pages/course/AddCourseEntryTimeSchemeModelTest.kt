package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「时间模板行的生效解析」契约（发布版 `add_course_screen.dart:1300-1360`）。
 *
 * 钉三件事：优先级（覆盖 > 地点组 > 课表默认）、节数上界（C2：候选节次按解析模板算）、
 * 钟点提示（C1：显示保存后真正会用的钟点；适配脚本钉住的权威时间优先）。
 */
class AddCourseEntryTimeSchemeModelTest {

    private fun scheme(id: String, name: String, count: Int): TimeScheme {
        val now = LocalDateTime.of(2026, 11, 1, 8, 0)
        return TimeScheme(
            id = id,
            name = name,
            sections = (1..count).map { i ->
                val startMin = 8 * 60 + (i - 1) * 55
                SectionTime(
                    // 显式 Locale.ROOT：默认 Locale 会把数字本地化成非 ASCII 字形，
                    // 与断言里的 "08:00" 这类期望值不一致（LocaleFormatGuardTest 抓的）。
                    startTime = "%02d:%02d".format(Locale.ROOT, startMin / 60, startMin % 60),
                    endTime = "%02d:%02d".format(Locale.ROOT, (startMin + 45) / 60, (startMin + 45) % 60),
                )
            },
            createdAt = now,
            updatedAt = now,
        )
    }

    private fun settings(activeId: String?) = TimetableSettings(activeTimeSchemeId = activeId)

    private fun group(id: String, name: String, schemeId: String, keyword: String) = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = schemeId,
        keywords = listOf(LocationKeyword(pattern = keyword)),
    )

    @Test
    fun `显式覆盖优先于地点组与课表默认`() {
        val a = scheme("a", "A 模板", 12)
        val b = scheme("b", "B 模板", 18)
        val c = scheme("c", "C 模板", 10)
        val info = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = listOf(a, b, c),
            settings = settings("c"),
            locationTimeGroups = listOf(group("g1", "主楼组", "a", "主楼")),
            timeSchemeIdOverride = "b",
            location = "主楼302",
            startSection = 1,
            endSection = 2,
        )
        assertEquals("B 模板", info.effectiveSchemeName)
        assertEquals("覆盖模板的节数决定候选上界（C2）", 18, info.sectionCount)
        assertEquals(AddCourseEntryTimeSchemeSource.OVERRIDE, info.autoSource)
        assertEquals("第1~2节 08:00-09:40", "08:00-09:40", info.clockHint)
    }

    @Test
    fun `跟随自动且地点命中时按地点组解析`() {
        val a = scheme("a", "主楼模板", 16)
        val c = scheme("c", "课表模板", 12)
        val info = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = listOf(a, c),
            settings = settings("c"),
            locationTimeGroups = listOf(group("g1", "主楼组", "a", "主楼")),
            timeSchemeIdOverride = null,
            location = "主楼302",
            startSection = 1,
            endSection = 2,
        )
        assertEquals("主楼模板", info.effectiveSchemeName)
        assertEquals(AddCourseEntryTimeSchemeSource.LOCATION_GROUP, info.autoSource)
        assertEquals("主楼组", info.autoGroupName)
        assertEquals("主楼模板", info.autoSchemeName)
        assertEquals(16, info.sectionCount)
    }

    @Test
    fun `跟随自动且无地点命中时回落课表默认`() {
        val c = scheme("c", "课表模板", 12)
        val info = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = listOf(c),
            settings = settings("c"),
            timeSchemeIdOverride = null,
            location = "不知道在哪",
            startSection = 1,
            endSection = 2,
        )
        assertEquals("课表模板", info.effectiveSchemeName)
        assertEquals(AddCourseEntryTimeSchemeSource.TIMETABLE, info.autoSource)
        assertEquals(12, info.sectionCount)
    }

    @Test
    fun `解析不到模板时不显示钟点也不给节数上界`() {
        val info = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = emptyList(),
            settings = settings(null),
            timeSchemeIdOverride = null,
            location = "",
            startSection = 1,
            endSection = 2,
        )
        assertEquals(AddCourseEntryTimeSchemeSource.NONE, info.autoSource)
        assertEquals(0, info.sectionCount)
        assertNull(info.clockHint)
        assertNull(info.effectiveSchemeName)
    }

    @Test
    fun `适配脚本钉住的权威时间优先于模板铃点`() {
        val c = scheme("c", "课表模板", 12)
        val pinned = Course(
            id = "c-1",
            name = "高数",
            teacher = "",
            location = "主楼302",
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            startTime = "07:00",
            endTime = "07:40",
            hasCustomTime = true,
        )
        val info = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = listOf(c),
            settings = settings("c"),
            timeSchemeIdOverride = null,
            location = "主楼302",
            startSection = 1,
            endSection = 2,
            originalCourse = pinned,
        )
        assertEquals("钉住的权威钟点必须优先（C1）", "07:00-07:40", info.clockHint)
        val moved = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = listOf(c),
            settings = settings("c"),
            timeSchemeIdOverride = null,
            location = "主楼302",
            startSection = 2,
            endSection = 3,
            originalCourse = pinned,
        )
        assertTrue("节次一变就回模板铃点", moved.clockHint != "07:00-07:40")
    }

    @Test
    fun `节次越界时不给钟点提示`() {
        val c = scheme("c", "小模板", 2)
        val info = AddCourseEntryTimeSchemeLogic.resolve(
            schemes = listOf(c),
            settings = settings("c"),
            timeSchemeIdOverride = null,
            location = "",
            startSection = 1,
            endSection = 6,
        )
        assertNull("结束节次越过模板节数时不拼钟点", info.clockHint)
        assertEquals(2, info.sectionCount)
    }
}
