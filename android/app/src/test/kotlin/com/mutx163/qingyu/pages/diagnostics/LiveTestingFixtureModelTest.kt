package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.widgetdata.LiveTestingFixtureData
import com.mutx163.qingyu.widgetdata.SectionTimeData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 临时测试课程页模型测试（源：`lib/screens/live_testing_fixture_screen.dart`）。
 *
 * 期望值从 Dart 源手推：
 * - 当前/下一节次：`LiveTestingFixtureService.sectionNumberForTime/nextSectionNumberForTime`
 *   （Phase 2 已迁到 `LiveTestingFixtureData`，这里只验页面口径）；
 * - 各行文案与可用性：build 里 70-200 行（安装中/清除中、`$fixtureCount/$sectionCount`、
 *   `$fixtureCount 门`、`未安装`）；
 * - 网格单元徽标：`isCurrent ? '现在' : '已装'`，都不是则不显示；
 * - 档位：`supportedLeadMinutes = [1, 3, 5, 8]`，tabs 为 `'$minutes 分钟'`，
 *   下标越界回落 0；
 * - toast：`已套用 <方案> 并添加 <n> 门测试课，星期<1-7>`。
 */
class LiveTestingFixtureModelTest {

    private val now = LocalDateTime.of(2026, 10, 27, 10, 30) // 周二 10:30

    private fun hourlySections(): List<SectionTimeData> = (0 until 24).map { hour ->
        val endHour = if (hour == 23) 23 else hour + 1
        val endMinute = if (hour == 23) 59 else 0
        SectionTimeData(
            startTime = "%02d:00".format(hour),
            endTime = "%02d:%02d".format(endHour, endMinute),
        )
    }

    private fun fixtureCourse(sectionNumber: Int): Course = Course(
        id = LiveTestingFixtureData.fixtureIdForSection(sectionNumber),
        name = "测试 第${sectionNumber}节",
        teacher = "测试教师",
        location = "测试教室",
        dayOfWeek = 2,
        startSection = sectionNumber,
        endSection = sectionNumber,
        startTime = "08:00",
        endTime = "09:00",
    )

    private fun normalCourse(): Course = Course(
        id = "course_1",
        name = "高等数学",
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 2,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun state(
        sections: List<SectionTimeData> = hourlySections(),
        courses: List<Course> = emptyList(),
        schemeName: String? = "默认方案",
        leadMinutes: Int = 1,
        isInstalling: Boolean = false,
        isClearing: Boolean = false,
    ): LiveFixtureViewState = buildLiveFixtureViewState(
        sections = sections,
        courses = courses,
        activeSchemeName = schemeName,
        now = now,
        leadMinutes = leadMinutes,
        isInstalling = isInstalling,
        isClearing = isClearing,
    )

    @Test
    fun `当前节次是进行中的那一节 下一节紧随其后`() {
        val viewState = state()

        // 24 段整点节次：第 11 节 = 10:00–11:00，10:30 落在其中。
        assertEquals(11, viewState.currentSection)
        assertEquals(12, viewState.nextSection)
        assertEquals("10:00", viewState.currentStart)
        assertEquals("11:00", viewState.nextStart)
        assertTrue(viewState.canTrigger)
    }

    @Test
    fun `节次边界是左闭右开 整点落在下一节`() {
        // 24 段整点节次：第 12 节 = 11:00–12:00（end 不含），所以 12:00 整点属于第 13 节。
        // 与 Dart `sectionNumberForTime` 的 `minutes < endMinutes` 同口径。
        val noon = buildLiveFixtureViewState(
            sections = hourlySections(),
            courses = emptyList(),
            activeSchemeName = null,
            now = LocalDateTime.of(2026, 10, 27, 12, 0),
        )
        assertEquals(13, noon.currentSection)
        assertEquals(14, noon.nextSection)
        assertEquals("12:00", noon.currentStart)

        val halfPastNoon = buildLiveFixtureViewState(
            sections = hourlySections(),
            courses = emptyList(),
            activeSchemeName = null,
            now = LocalDateTime.of(2026, 10, 27, 12, 30),
        )
        assertEquals(13, halfPastNoon.currentSection)
        assertEquals(14, halfPastNoon.nextSection)
    }

    @Test
    fun `没有节次表时不能触发且钟点是占位符`() {
        val viewState = state(sections = emptyList())

        assertFalse(viewState.canTrigger)
        assertEquals("--:--", viewState.currentStart)
        assertEquals("--:--", viewState.nextStart)
        assertTrue(viewState.gridCells.isEmpty())
        assertTrue(viewState.sendRows.none { it.enabled })
        assertEquals("安装后这里会列出全部节次", viewState.gridEmptyText)
    }

    @Test
    fun `只数测试课并且每节知道自己装没装`() {
        val viewState = state(courses = listOf(fixtureCourse(3), fixtureCourse(11), normalCourse()))

        assertEquals(2, viewState.fixtureCount)
        assertTrue(viewState.hasFixtures)
        assertEquals(24, viewState.gridCells.size)
        assertEquals(2, viewState.gridCells.count { it.installed })
        assertTrue(viewState.gridCells[2].installed)   // 第 3 节
        assertTrue(viewState.gridCells[10].installed)  // 第 11 节
    }

    @Test
    fun `网格单元徽标当前节优先于已装`() {
        val viewState = state(courses = listOf(fixtureCourse(11), fixtureCourse(5)))

        val current = viewState.gridCells[10] // 第 11 节，当前节
        assertEquals("第11节", current.title)
        assertTrue(current.isCurrent)
        assertEquals("现在", current.badgeLabel)

        val installedNotCurrent = viewState.gridCells[4] // 第 5 节
        assertEquals("已装", installedNotCurrent.badgeLabel)

        assertNull(viewState.gridCells[0].badgeLabel)
        assertEquals("00:00", viewState.gridCells[0].startTime)
    }

    @Test
    fun `安装行的取值随节次数与进行中状态变化`() {
        val empty = state(courses = emptyList())
        assertEquals("安装 24 时段测试课表", empty.installTitle)
        assertEquals("0/24", empty.installDetails)
        assertTrue(empty.installEnabled)

        val installing = state(isInstalling = true)
        assertEquals("正在安装…", installing.installTitle)
        assertNull(installing.installDetails)
        assertFalse(installing.installEnabled)

        val noSections = state(sections = emptyList())
        assertEquals("未安装", noSections.installDetails)
    }

    @Test
    fun `清除行只在有测试课时可用`() {
        val none = state(courses = listOf(normalCourse()))
        assertNull(none.clearDetails)
        assertFalse(none.clearEnabled)
        assertEquals("清除测试课表", none.clearTitle)

        val two = state(courses = listOf(fixtureCourse(1), fixtureCourse(2)))
        assertEquals("2 门", two.clearDetails)
        assertTrue(two.clearEnabled)

        val clearing = state(
            courses = listOf(fixtureCourse(1)),
            isClearing = true,
        )
        assertEquals("正在清除…", clearing.clearTitle)
        assertFalse(clearing.clearEnabled)
    }

    @Test
    fun `档位是 1 3 5 8 分钟且越界回落第一档`() {
        assertEquals(listOf(1, 3, 5, 8), liveFixtureLeadOptions)
        assertEquals(listOf("1 分钟", "3 分钟", "5 分钟", "8 分钟"), state().leadTabs)

        assertEquals(0, state(leadMinutes = 1).leadIndex)
        assertEquals(2, state(leadMinutes = 5).leadIndex)
        assertEquals(3, state(leadMinutes = 8).leadIndex)

        val unknown = state(leadMinutes = 7)
        assertEquals(0, unknown.leadIndex)
        assertEquals(1, unknown.leadMinutes)
    }

    @Test
    fun `当前与下一节两行带正确的来源标识`() {
        val viewState = state()
        val current = viewState.sendRows[0]
        val next = viewState.sendRows[1]

        assertEquals("当前节次 · 第11节", current.title)
        assertEquals("10:00", current.details)
        assertEquals("quick_fixture_current_slot", current.source)
        assertTrue(current.enabled)

        assertEquals("下一节次 · 第12节", next.title)
        assertEquals("11:00", next.details)
        assertEquals("quick_fixture_next_slot", next.source)
    }

    @Test
    fun `方案名叫不出来时显示未选择并保留清除提示`() {
        val viewState = state(schemeName = null)

        assertEquals("未选择", viewState.activeSchemeName)
        assertEquals(
            "当前方案：未选择。测试完成后请先清除测试课表，再切换回原时间方案。",
            viewState.schemeDescription,
        )
    }

    @Test
    fun `三处提示文案的星期是数字`() {
        assertEquals(
            "已套用 默认方案 并添加 24 门测试课，星期3",
            LiveFixtureMessages.installed("默认方案", 24, 3),
        )
        assertEquals("已清除 24 门测试课", LiveFixtureMessages.cleared(24))
        assertEquals(
            "安装测试课表失败：sections_too_few",
            LiveFixtureMessages.installFailed("sections_too_few"),
        )
        assertEquals(
            "清除测试课表失败：boom",
            LiveFixtureMessages.clearFailed("boom"),
        )
    }

    @Test
    fun `页面标题与发送区提示照抄 Dart`() {
        val viewState = state()

        assertEquals("临时测试课程", viewState.pageTitle)
        assertEquals(
            "若当前日历周超过课程 endWeek、放假或未到课前窗口，会提示无课而不是硬弹出岛。",
            viewState.sendHint,
        )
        assertEquals(LiveFixtureStrings.pageTitle, viewState.pageTitle)
    }
}
