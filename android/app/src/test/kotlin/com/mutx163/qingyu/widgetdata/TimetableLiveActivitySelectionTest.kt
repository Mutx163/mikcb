package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 超级岛选课管线纯逻辑的端口测试（移植 lib/services/timetable_live_activity_service.dart）。
 *
 * 期望值来源：test/services/timetable_live_activity_service_test.dart
 * 与 test/services/live_testing_fixture_service_test.dart 既有用例（[Dart抄录]），
 * 少数边界按实现注释推演（[Dart推演]）。假端口移植自 Dart 测试的 _FakePort。
 */
class TimetableLiveActivitySelectionTest {

    private val day: LocalDateTime = LocalDateTime.of(2026, 3, 2, 0, 0) // 周一

    private fun at(h: Int, m: Int): LocalDateTime = day.plusHours(h.toLong()).plusMinutes(m.toLong())

    private fun course(
        id: String = "course-1",
        name: String = "高等数学",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:40",
        startWeek: Int = 1,
        endWeek: Int = 16,
    ): Course = Course(
        id = id, name = name, teacher = "张老师", location = "A101",
        dayOfWeek = dayOfWeek, startSection = startSection, endSection = endSection,
        startTime = startTime, endTime = endTime, startWeek = startWeek, endWeek = endWeek,
    )

    private fun fixtureCourse(
        id: String = "live_test_1",
        dayOfWeek: Int = 1,
        startTime: String = "08:00",
        endTime: String = "09:40",
    ): Course = course(id = id, name = "自检课", dayOfWeek = dayOfWeek, startTime = startTime, endTime = endTime)

    // —— resolveRealTime ——

    @Test
    fun fixtureUsesFreeClockIgnoringScheme() { // [Dart抄录] 自检预设课用自身自由时钟
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("10:00", "10:45")),
        )
        val fixture = fixtureCourse(startTime = "07:15", endTime = "08:05")
        assertEquals("07:15", TimetableLiveActivityData.resolveRealTime(port, fixture, isStart = true))
        assertEquals("08:05", TimetableLiveActivityData.resolveRealTime(port, fixture, isStart = false))
    }

    @Test
    fun realCourseResolvesThroughSections() { // [Dart抄录] 真实课按节次解析
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("08:00", "08:45"), SectionTimeData("08:50", "09:35")),
        )
        val c = course(startTime = "00:00", endTime = "00:00")
        assertEquals("08:00", TimetableLiveActivityData.resolveRealTime(port, c, isStart = true))
        assertEquals("09:35", TimetableLiveActivityData.resolveRealTime(port, c, isStart = false))
    }

    @Test
    fun outOfRangeSectionFallsBackToCourseClock() { // [Dart推演] 节次越界回落自身钟点
        val port = FakeLiveHost(sections = listOf(SectionTimeData("08:00", "08:45")))
        val c = course(startSection = 5, endSection = 6, startTime = "09:00", endTime = "10:00")
        assertEquals("09:00", TimetableLiveActivityData.resolveRealTime(port, c, isStart = true))
        assertEquals("10:00", TimetableLiveActivityData.resolveRealTime(port, c, isStart = false))
    }

    // —— buildCorrectedCourseDateTime ——

    @Test
    fun correctionShiftsBySeconds() { // [Dart抄录] +90s → 08:01:30
        val port = FakeLiveHost(timeCorrectionSeconds = 90)
        assertEquals(
            LocalDateTime.of(2026, 3, 2, 8, 1, 30),
            TimetableLiveActivityData.buildCorrectedCourseDateTime(port, day, "08:00"),
        )
    }

    @Test
    fun malformedClockReturnsNull() { // [Dart抄录] 25:00 不静默挪一天
        assertNull(TimetableLiveActivityData.buildCorrectedCourseDateTime(FakeLiveHost(), day, "25:00"))
    }

    // —— getActivityCourseSelection ——

    @Test
    fun holidayShortCircuitsSelection() { // [Dart抄录] 节假日直接不选课
        val now = at(9, 0)
        val port = FakeLiveHost(
            courses = listOf(course(dayOfWeek = now.dayOfWeek.value)),
            holidayDates = setOf("2026-03-02"),
        )
        assertNull(TimetableLiveActivityData.getActivityCourseSelection(port, now = now))
    }

    @Test
    fun duringClassReturnsNormalizedDisplayName() { // [Dart抄录] 展示名归一 + 阶段
        val now = at(9, 0)
        val port = FakeLiveHost(courses = listOf(course(dayOfWeek = now.dayOfWeek.value)))
        val selection = TimetableLiveActivityData.getActivityCourseSelection(port, now = now)
        assertTrue(selection != null)
        assertEquals("高等数学(归一名)", selection!!.currentCourse.name)
        assertEquals(LiveActivityStage.DURING_CLASS, selection.stage)
        assertTrue(port.resolveDisplayNameCalls > 0)
    }

    @Test
    fun noCoursesTodayReturnsNull() { // [Dart抄录]
        val now = at(9, 0)
        val otherDay = if (now.dayOfWeek.value == 1) 2 else 1
        val port = FakeLiveHost(courses = listOf(course(dayOfWeek = otherDay)))
        assertNull(TimetableLiveActivityData.getActivityCourseSelection(port, now = now))
    }

    @Test
    fun fixtureCompetesByResolvedStartTime() { // [Dart抄录] 预设课 07:00 vs 真实课 10:00
        val now = at(7, 30)
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("10:00", "11:40")),
            showBeforeClassMinutes = 40,
            courses = listOf(course(id = "real", dayOfWeek = now.dayOfWeek.value)),
        )
        port.liveRuntime.fixtureOverlayCourses = listOf(
            fixtureCourse(id = "live_test_a", dayOfWeek = now.dayOfWeek.value, startTime = "07:00", endTime = "07:45"),
        )
        val selection = TimetableLiveActivityData.getActivityCourseSelection(port, now = now)
        assertTrue(selection != null)
        assertEquals("live_test_a", selection!!.currentCourse.id)
        assertEquals("real", selection.nextCourse?.id)
    }

    @Test
    fun upcomingFallbackRequiresEnableBeforeClass() { // [Dart抄录]
        val now = at(9, 0)
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("10:00", "11:40")),
            liveEnableBeforeClass = false,
            courses = listOf(course(dayOfWeek = now.dayOfWeek.value)),
        )
        assertNull(TimetableLiveActivityData.getActivityCourseSelection(port, now = now, allowUpcomingFallback = true))
    }

    @Test
    fun upcomingFallbackYieldsBeforeClass() { // [Dart抄录] 09:55 进 10:00 课前窗
        val now = at(9, 55)
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("10:00", "11:40")),
            courses = listOf(course(dayOfWeek = now.dayOfWeek.value)),
        )
        val selection = TimetableLiveActivityData.getActivityCourseSelection(port, now = now, allowUpcomingFallback = true)
        assertTrue(selection != null)
        assertEquals(LiveActivityStage.BEFORE_CLASS, selection!!.stage)
    }

    @Test
    fun beforeClassWindowStartsAtLeadMinutes() { // [Dart推演] 默认提前 20 分钟
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("10:00", "11:40")),
            courses = listOf(course(dayOfWeek = 1, startSection = 1, endSection = 1)),
        )
        // 09:40 整 = 恰好提前 20 分钟：isBefore(aheadTime) 为 false → 选中
        val atEdge = TimetableLiveActivityData.getActivityCourseSelection(port, now = at(9, 40))
        assertTrue(atEdge != null)
        assertEquals(LiveActivityStage.BEFORE_CLASS, atEdge!!.stage)
        // 09:39 → 还没进窗
        assertNull(TimetableLiveActivityData.getActivityCourseSelection(port, now = at(9, 39)))
    }

    @Test
    fun beforeClassBlockedByPreviousCourse() { // [Dart推演] blockedUntil 推迟 aheadTime
        // 场景：第一节 08:00-09:40 还挂着但其阶段全关（无选中资格），
        // 第二节 10:00-11:40 的课前窗 30 分钟（=09:30 起）被第一节的结束时刻
        // (blockedUntil=09:40) 推迟 → 09:35 时还没进窗（原口径会提前选中）。
        val port = FakeLiveHost(
            showBeforeClassMinutes = 30,
            courses = listOf(
                course(id = "c1", startTime = "08:00", endTime = "09:40"),
                course(id = "c2", startSection = 3, endSection = 4, startTime = "10:00", endTime = "11:40"),
            ),
        )
        // 09:35：第一节无阶段（课上/课末关），第二节的课前窗被 blockedUntil(09:40) 压住
        port.settings = port.settings.copy(liveEnableDuringClass = false, liveEnableBeforeEnd = false)
        assertNull(TimetableLiveActivityData.getActivityCourseSelection(port, now = at(9, 35)))
        // 09:41：blockedUntil 已过 → beforeClass 选中第二节
        val selection = TimetableLiveActivityData.getActivityCourseSelection(port, now = at(9, 41))
        assertTrue(selection != null)
        assertEquals("c2", selection!!.currentCourse.id)
        assertEquals(LiveActivityStage.BEFORE_CLASS, selection.stage)
    }

    @Test
    fun ongoingCourseStillWinsDuringEndReminder() { // [Dart推演] 第一节课上着就先命中它的阶段
        // 09:30 恰好是第一节的课末 10 分钟窗起点（end 09:40 - 10min）→ BEFORE_END
        val port = FakeLiveHost(
            courses = listOf(
                course(id = "c1", startTime = "08:00", endTime = "09:40"),
                course(id = "c2", startSection = 3, endSection = 4, startTime = "10:00", endTime = "11:40"),
            ),
        )
        val selection = TimetableLiveActivityData.getActivityCourseSelection(port, now = at(9, 30))
        assertTrue(selection != null)
        assertEquals("c1", selection!!.currentCourse.id)
        assertEquals(LiveActivityStage.BEFORE_END, selection.stage)
    }

    // —— getCoursesInProgress / getTodayCourses / getCurrentCourse ——

    @Test
    fun inProgressFiltersByResolvedClock() { // [Dart抄录] 只挑实时时钟落在起止之间的课
        val now = at(9, 10)
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("08:00", "08:45"), SectionTimeData("08:50", "09:35")),
            courses = listOf(
                course(id = "c1", dayOfWeek = now.dayOfWeek.value),
                course(id = "c2", name = "大学物理", dayOfWeek = now.dayOfWeek.value, startSection = 3, endSection = 4, startTime = "10:00", endTime = "11:40"),
            ),
        )
        val inProgress = TimetableLiveActivityData.getCoursesInProgress(port, dayOfWeek = now.dayOfWeek.value, now = now)
        assertEquals(listOf("c1"), inProgress.map { it.id })
        assertEquals("高等数学(归一名)", inProgress.single().name)
    }

    @Test
    fun inProgressHonorsExplicitWeek() { // [Dart抄录] 显式周次过滤
        val now = at(9, 10)
        val port = FakeLiveHost(courses = listOf(course(dayOfWeek = now.dayOfWeek.value, endWeek = 4)))
        assertTrue(
            TimetableLiveActivityData.getCoursesInProgress(port, dayOfWeek = now.dayOfWeek.value, week = 8, now = now).isEmpty(),
        )
    }

    @Test
    fun todayCoursesUseCurrentDateWeekWithoutSemesterStart() { // [Dart抄录]
        val port = FakeLiveHost(courses = listOf(course(id = "today", endWeek = 3)))
        assertEquals(listOf("today"), TimetableLiveActivityData.getTodayCourses(port).map { it.id })
        port.currentDateWeek = 5
        assertTrue(TimetableLiveActivityData.getTodayCourses(port).isEmpty())
    }

    @Test
    fun todayCoursesUseCalendarWeekWithSemesterStart() { // [Dart抄录] 结课后不复活旧课
        val port = FakeLiveHost(
            semesterStartDate = LocalDateTime.of(2026, 3, 2, 0, 0),
            courses = listOf(course(id = "cal", startWeek = 3, endWeek = 3)),
        )
        port.calendarWeek = 3
        port.currentDateWeek = 1
        assertEquals(listOf("cal"), TimetableLiveActivityData.getTodayCourses(port).map { it.id })
    }

    @Test
    fun currentCourseComparesByMinuteOrder() { // [Dart抄录] 全天课钟面判「正在上」
        val port = FakeLiveHost(courses = listOf(course(id = "all-day", startTime = "00:00", endTime = "23:59")))
        assertEquals("all-day", TimetableLiveActivityData.getCurrentCourse(port)?.id)
    }

    @Test
    fun unnormalizedClockStillComparesByMinutes() { // [Dart推演] 9:00 不补零也正确
        val port = FakeLiveHost(courses = listOf(course(id = "loose", startTime = "9:00", endTime = "10:00")))
        val current = TimetableLiveActivityData.getCurrentCourseAt(port, at(9, 30))
        assertEquals("loose", current?.id)
        assertNull(TimetableLiveActivityData.getCurrentCourseAt(port, at(10, 0))) // 恰好结束 → 不算正在上
        val next = TimetableLiveActivityData.getNextCourseAt(port, at(8, 0))
        assertEquals("loose", next?.id)
    }

    // —— 自检预设课覆盖层 ——

    @Test
    fun armAndDisarmFixtureOverlay() { // [Dart抄录]
        val port = FakeLiveHost()
        TimetableLiveActivityData.armFixtureCourses(port, listOf(fixtureCourse()))
        assertEquals(1, port.liveRuntime.fixtureOverlayCourses.size)
        TimetableLiveActivityData.disarmFixtureCourses(port)
        assertTrue(port.liveRuntime.fixtureOverlayCourses.isEmpty())
    }

    @Test
    fun disarmIfFinishedWaitsForAllPresets() { // [Dart抄录] 09:39 未结束 / 09:41 摘除
        val port = FakeLiveHost()
        port.liveRuntime.fixtureOverlayCourses = listOf(fixtureCourse())
        assertEquals(false, TimetableLiveActivityData.disarmFixtureCoursesIfFinished(port, at(9, 39)))
        assertEquals(1, port.liveRuntime.fixtureOverlayCourses.size)
        assertEquals(true, TimetableLiveActivityData.disarmFixtureCoursesIfFinished(port, at(9, 41)))
        assertTrue(port.liveRuntime.fixtureOverlayCourses.isEmpty())
    }

    @Test
    fun disarmIfFinishedNoOpOnEmpty() { // [Dart抄录]
        val port = FakeLiveHost()
        TimetableLiveActivityData.disarmFixtureCourses(port)
        assertTrue(port.liveRuntime.fixtureOverlayCourses.isEmpty())
        assertEquals(false, TimetableLiveActivityData.disarmFixtureCoursesIfFinished(port, at(9, 41)))
    }

    @Test
    fun armEmptyOverlayIsNoOp() { // [Dart抄录] arm([]) 不清空既有覆盖层
        val port = FakeLiveHost()
        port.liveRuntime.fixtureOverlayCourses = listOf(fixtureCourse())
        TimetableLiveActivityData.armFixtureCourses(port, emptyList())
        assertEquals(1, port.liveRuntime.fixtureOverlayCourses.size)
    }

    // —— 挂起窗口 ——

    @Test
    fun suspendWindowRoundTrip() { // [Dart抄录]
        val port = FakeLiveHost()
        val before = LocalDateTime.now()
        TimetableLiveActivityData.suspendSyncFor(port, 300L)
        assertTrue(port.liveRuntime.suspendedUntil != null)
        assertTrue(port.liveRuntime.suspendedUntil!!.isAfter(before))
        TimetableLiveActivityData.clearSyncSuspend(port)
        assertNull(port.liveRuntime.suspendedUntil)
    }

    // —— getTestActivityCourseSelection（跨周兜底）——

    @Test
    fun testSelectionFallsBackToNextFutureCourseThisWeek() { // [Dart推演]
        val now = at(12, 0) // 第一节课已结束
        val port = FakeLiveHost(
            sections = listOf(SectionTimeData("10:00", "11:40")),
            courses = listOf(course(id = "c1", startTime = "10:00", endTime = "11:40")),
        )
        val selection = TimetableLiveActivityData.getTestActivityCourseSelection(port, now = now)
        assertTrue(selection != null)
        assertEquals("c1", selection!!.currentCourse.id)
    }

    @Test
    fun testSelectionScansNextWeek() { // [Dart推演] 周日已过 → 跨周扫到下周一同一门课
        val sunday = LocalDateTime.of(2026, 3, 8, 0, 0)
        val now = sunday.plusHours(12)
        val port = FakeLiveHost(
            courses = listOf(course(id = "c1", dayOfWeek = 1, startTime = "10:00", endTime = "11:40")),
        )
        val selection = TimetableLiveActivityData.getTestActivityCourseSelection(port, now = now)
        assertTrue(selection != null)
        assertEquals("c1", selection!!.currentCourse.id)
    }

    @Test
    fun testSelectionReturnsNullWhenAllWeeksExpired() { // [Dart推演] 课表周次全部过期 → null
        val sunday = LocalDateTime.of(2026, 3, 8, 0, 0)
        val now = sunday.plusHours(12)
        val port = FakeLiveHost(
            courses = listOf(course(id = "c1", dayOfWeek = 1, startTime = "10:00", endTime = "11:40", endWeek = 1)),
        )
        port.calendarWeek = 2 // 已出课表周次范围
        assertNull(TimetableLiveActivityData.getTestActivityCourseSelection(port, now = now))
    }

    // —— 情侣合并（buildCoupleMergedDayCourses 的纯内核）——

    @Test
    fun coupleMergeDedupsTogetherAndColorsByKind() { // [Dart抄录] 同行程按我的去重 + 三色
        val mine = course(id = "m1", name = "英语", startTime = "08:00", endTime = "09:40")
        val partner = course(id = "p1", name = "英语", startTime = "08:00", endTime = "09:40")
        val partnerOther = course(id = "p2", name = "音乐", startSection = 3, endSection = 4, startTime = "10:00", endTime = "11:40")
        val merged = coupleMergedDayCourses(
            mineCourses = listOf(mine),
            partnerCourses = listOf(partner, partnerOther),
            week = 1,
            partnerWeekOffset = 0,
            mineColorHex = "#111111",
            partnerColorHex = "#222222",
            togetherColorHex = "#333333",
        )
        assertEquals(2, merged.size)
        assertEquals("m1", merged[0].id)
        assertEquals("#333333", merged[0].color) // 同行程 → together 色
        assertEquals("p2", merged[1].id)
        assertEquals("#222222", merged[1].color) // 未消费 → partner 色
    }

    @Test
    fun coupleMergeRespectsWeekValidity() { // [Dart推演] 我方停课周不配对（纯内核不做我方过滤）
        val mine = course(id = "m1", name = "英语", startTime = "08:00", endTime = "09:40", endWeek = 2)
        val partner = course(id = "p1", name = "英语", startTime = "08:00", endTime = "09:40", endWeek = 16)
        // week=3：我的课停了 → 不参与同行程配对；纯合并内核照单收下
        //（宿主入口 coupleMergedDayCoursesForDay 才按 isActiveInWeek 过滤我方课）。
        val merged = coupleMergedDayCourses(
            mineCourses = listOf(mine),
            partnerCourses = listOf(partner),
            week = 3,
            partnerWeekOffset = 0,
        )
        assertEquals(listOf("m1", "p1"), merged.map { it.id })
        assertEquals("#2196F3", merged[0].color) // 未配对 → mine 默认色
        assertEquals("#E91E63", merged[1].color) // 未被消费 → partner 默认色
    }

    @Test
    fun coupleMergeHostFiltersMyInactiveCourses() { // [Dart推演] 宿主入口按周过滤我方停课
        val port = FakeLiveHost()
        port.calendarWeek = 3
        port.setActiveProfile(
            ProfileFace(
                id = "p1", name = "我",
                courses = listOf(course(id = "m1", name = "英语", endWeek = 2)),
            ),
        )
        port.setPartnerProfile(
            ProfileFace(
                id = "partner-imported", name = "TA",
                courses = listOf(course(id = "p1", name = "英语", dayOfWeek = 1, endWeek = 16)),
            ),
        )
        port.partnerBinding = PartnerTimetableBinding.fromJson(mapOf("partnerProfileId" to "x"))
        val merged = coupleMergedDayCoursesForDay(
            host = port,
            dayOfWeek = 1,
            myWeek = 3,
            myProfile = port.activeProfileFace!!,
            partnerProfile = port.partnerProfileFace!!,
            binding = port.partnerBinding!!,
        )
        assertEquals(listOf("p1"), merged.map { it.id })
        assertEquals("#E91E63", merged[0].color)
    }

    @Test
    fun coupleMergeSortsBySectionThenClockMinutes() { // [Dart推演] 同节次按分钟数比
        val early = course(id = "p-early", name = "早课", startSection = 3, endSection = 3, startTime = "9:00", endTime = "9:45")
        val late = course(id = "p-late", name = "晚课", startSection = 3, endSection = 3, startTime = "10:00", endTime = "10:45")
        val merged = coupleMergedDayCourses(
            mineCourses = emptyList(),
            partnerCourses = listOf(late, early), // 故意乱序 + 未补零钟点
            week = 1,
            partnerWeekOffset = 0,
        )
        assertEquals(listOf("p-early", "p-late"), merged.map { it.id })
    }
}
