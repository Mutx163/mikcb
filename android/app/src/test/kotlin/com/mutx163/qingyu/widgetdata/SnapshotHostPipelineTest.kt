package com.mutx163.qingyu.widgetdata

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 快照宿主管线（buildHomeWidgetSnapshot / buildHomeWidgetSnapshotForProfile /
 * buildCoupleMergedHomeWidgetSnapshot）纯逻辑的端口测试。
 *
 * 期望值来源：按 lib/services/timetable_live_activity_service.dart 注释规则推演
 * （[Dart推演]）；周次与过滤口径与真机 TodayWidgetSupport.buildSnapshotFromFlutterState
 * 对齐（[Kotlin抄录]）。
 */
class SnapshotHostPipelineTest {

    private val monday: LocalDateTime = LocalDateTime.of(2026, 3, 2, 0, 0) // 周一

    private fun course(
        id: String,
        dayOfWeek: Int,
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:40",
    ) = com.mutx163.qingyu.core.Course(
        id = id, name = "课$id", teacher = "张老师", location = "A101",
        dayOfWeek = dayOfWeek, startSection = startSection, endSection = endSection,
        startTime = startTime, endTime = endTime,
    )

    @Test
    fun hostBuildUsesCalendarWeekFromHost() { // [Dart推演] active 路径周次由宿主给
        val port = FakeLiveHost(
            courses = listOf(course("c1", dayOfWeek = 1)),
        )
        port.calendarWeek = 6
        port.setActiveProfile(
            ProfileFace(
                id = "p1",
                name = "我的课表",
                courses = listOf(course("c1", dayOfWeek = 1)),
            ),
        )
        port.currentDayOfWeek = 1
        val snapshot = buildHomeWidgetSnapshot(port, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals(6, snapshot!!.currentWeek)
        assertEquals("p1", snapshot.profileId)
        assertEquals("我的课表", snapshot.profileName)
        assertEquals(1, snapshot.todayCourses.size)
    }

    @Test
    fun hostBuildReturnsNullWithoutProfile() { // [Dart抄录] activeProfile == null → null
        val port = FakeLiveHost()
        assertTrue(buildHomeWidgetSnapshot(port, now = monday) == null)
    }

    @Test
    fun holidayClearsTodayCourses() { // [Dart推演] isHoliday → 课程清空 + holiday 态
        val port = FakeLiveHost(
            holidayDates = setOf("2026-03-02"),
            courses = listOf(course("c1", dayOfWeek = 1)),
        )
        port.calendarWeek = 3
        port.setActiveProfile(ProfileFace(id = "p1", name = "n", courses = listOf(course("c1", dayOfWeek = 1))))
        port.currentDayOfWeek = 1
        val snapshot = buildHomeWidgetSnapshot(port, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals(HomeWidgetSnapshotState.HOLIDAY, snapshot!!.state)
        assertEquals(0, snapshot.totalTodayCourseCount)
        assertEquals("测试假", snapshot.holidayName)
    }

    @Test
    fun profileBuildUsesProfileOwnSettingsAndCourses() { // [Dart抄录/推演] 绑定卡按档案自身
        val port = FakeLiveHost()
        val profile = ProfileFace(
            id = "ta",
            name = "TA的课表",
            currentWeek = 9,
            courses = listOf(course("t1", dayOfWeek = 1)),
        ).let { ProfileFace.withSemesterStart(it.id, it.name, it.currentWeek, it.courses, it.exams, LocalDateTime.of(2026, 3, 2, 0, 0)) }
        // 第 1 周（2026-03-02 那周）
        val snapshot = buildHomeWidgetSnapshotForProfile(port, profile, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals("ta", snapshot!!.profileId)
        assertEquals(1, snapshot.currentWeek) // 3-02 当周 = 第 1 周
        assertEquals(1, snapshot.todayCourses.size)
        assertEquals(HomeWidgetSnapshotState.ONGOING, snapshot.state)
    }

    @Test
    fun profileBuildHonorsHolidayByResolver() { // [Dart推演] profile 路径走 HolidayResolver
        val port = FakeLiveHost(holidayDates = setOf("2026-03-02"))
        val profile = ProfileFace(
            id = "ta", name = "TA", currentWeek = 1,
            courses = listOf(course("t1", dayOfWeek = 1)),
        )
        val snapshot = buildHomeWidgetSnapshotForProfile(port, profile, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals(HomeWidgetSnapshotState.HOLIDAY, snapshot!!.state)
    }

    @Test
    fun profileBuildOverrideBeatsMarking() { // [Dart推演] 覆盖开关压过一切（非补班日）
        val port = FakeLiveHost()
        val profile = ProfileFace(
            id = "ta", name = "TA", currentWeek = 1,
            courses = listOf(course("t1", dayOfWeek = 1)),
        )
        // 用 profile 自己的设置开覆盖
        val overridden = profile.copy(
            settings = WidgetSettingsFace().copy(holidayOverrideEnabled = true),
        )
        val snapshot = buildHomeWidgetSnapshotForProfile(port, overridden, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals(HomeWidgetSnapshotState.HOLIDAY, snapshot!!.state)
    }

    @Test
    fun profileBuildPicksEarliestUpcomingExam() { // [Dart抄录] isExpired 过滤 + compareByStart
        val port = FakeLiveHost()
        val profile = ProfileFace(
            id = "ta", name = "TA", currentWeek = 1,
            exams = listOf(
                ExamFace(
                    id = "e-late",
                    name = "晚的考试",
                    dateTime = LocalDateTime.of(2026, 4, 10, 0, 0),
                    startTime = "09:00",
                    endTime = "11:00",
                ),
                ExamFace(
                    id = "e-early",
                    name = "早的考试",
                    dateTime = LocalDateTime.of(2026, 4, 2, 0, 0),
                    startTime = "14:00",
                    endTime = "16:00",
                ),
                ExamFace(
                    id = "e-past",
                    name = "过去的考试",
                    dateTime = LocalDateTime.of(2020, 1, 1, 0, 0),
                    startTime = "08:00",
                    endTime = "09:00",
                ),
            ),
        )
        val snapshot = buildHomeWidgetSnapshotForProfile(port, profile, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals("早的考试", snapshot!!.nextExamFace?.name)
        assertEquals("2026-04-02", snapshot.nextExamDate)
    }

    @Test
    fun coupleBuildRequiresBindingAndPartner() { // [Dart抄录] TA 解绑 → null
        val port = FakeLiveHost()
        port.setActiveProfile(ProfileFace(id = "p1", name = "n"))
        // 只有我的档案：未绑 TA → null
        assertTrue(buildCoupleMergedHomeWidgetSnapshot(port, now = monday) == null)

        port.setPartnerProfile(ProfileFace(id = "partner-imported", name = "TA"))
        port.partnerBinding = PartnerTimetableBinding.fromJson(
            mapOf("partnerProfileId" to "partner-imported"),
        )
        val snapshot = buildCoupleMergedHomeWidgetSnapshot(port, now = monday)
        assertTrue(snapshot != null)
        assertEquals(K_HOME_WIDGET_COUPLE_MERGED_BINDING_ID, snapshot!!.profileId)
        assertEquals("n", snapshot.profileName) // 名字锚定我方
    }

    @Test
    fun coupleBuildMergesAcrossDays() { // [Dart推演] 今天/明天按各自周合并
        // 假端口的「今天的课」读构造参数 courses（= Dart provider 内存态），
        // 档案列表只供绑定路径使用——两处都要给。
        val port = FakeLiveHost(courses = listOf(course("mine", dayOfWeek = 1)))
        port.calendarWeek = 1
        port.setActiveProfile(ProfileFace(id = "p1", name = "我", courses = listOf(course("mine", dayOfWeek = 1))))
        port.setPartnerProfile(
            ProfileFace(
                id = "partner-imported", name = "TA",
                courses = listOf(course("theirs", dayOfWeek = 2, startTime = "10:00", endTime = "11:40")),
            ),
        )
        port.partnerBinding = PartnerTimetableBinding.fromJson(
            mapOf("partnerProfileId" to "partner-imported"),
        )
        port.currentDayOfWeek = 1
        val snapshot = buildCoupleMergedHomeWidgetSnapshot(port, now = monday.plusHours(9))
        assertTrue(snapshot != null)
        assertEquals(K_HOME_WIDGET_COUPLE_MERGED_BINDING_ID, snapshot!!.profileId)
        // 今天=周一：我的课；明天=周二：TA 的课进明天列表
        // 展示名归一会加后缀，这里断数量与 id
        assertEquals(1, snapshot.todayCourses.size)
        assertEquals("mine", snapshot.todayCourses.single().id)
        assertEquals(listOf("theirs"), snapshot.tomorrowCourses.map { it.id })
    }

    @Test
    fun bindingTargetResolution() { // [Dart抄录] 绑定目标三态
        val follow = HomeWidgetInstanceData(1, null, null)
        val couple = HomeWidgetInstanceData(2, null, "couple-merged")
        val bound = HomeWidgetInstanceData(3, null, "profile-x")
        assertTrue(HomeWidgetBindingData.resolveBindingTarget(follow) is HomeWidgetBindingData.BindingTarget.FOLLOW_ACTIVE)
        assertTrue(HomeWidgetBindingData.resolveBindingTarget(couple) is HomeWidgetBindingData.BindingTarget.COUPLE_MERGED)
        val target = HomeWidgetBindingData.resolveBindingTarget(bound)
        assertTrue(target is HomeWidgetBindingData.BindingTarget.PROFILE && target.profileId == "profile-x")
    }

    @Test
    fun instanceParsingFiltersInvalidId() { // [Dart抄录] appWidgetId < 0 丢弃
        val ok = HomeWidgetInstanceData.fromChannel(
            mapOf("appWidgetId" to 11L, "widgetType" to "compact", "boundProfileId" to "p"),
        )
        assertTrue(ok != null && ok.appWidgetId == 11 && ok.widgetType == HomeWidgetTypeData.COMPACT)
        val invalid = HomeWidgetInstanceData.fromChannel(mapOf("appWidgetId" to -1L))
        assertTrue(invalid == null)
    }

    @Test
    fun refreshTriggersUnionAcrossHost() { // [Dart推演] buildRefreshTriggers 转发
        val port = FakeLiveHost()
        port.calendarWeek = 6
        val triggers = buildHostRefreshTriggers(
            port,
            todayCourses = listOf(course("c1", dayOfWeek = 1, startTime = "10:00", endTime = "11:00")),
            now = monday.plusHours(9),
            showCountdown = false,
            state = "ongoing",
            countdownLeadMinutes = 20,
        )
        assertTrue(triggers.contains(WidgetDataClock.toEpochMillis(monday.plusHours(10))))
        assertTrue(triggers.contains(WidgetDataClock.toEpochMillis(monday.plusHours(11))))
    }

    @Test
    fun holidayResolverOrdering() { // [Dart抄录] 调休上班 > 覆盖 > 标记
        val mondayKey = "2026-03-02"
        // 补班日：即使覆盖开着也照常上课
        assertEquals(
            false,
            resolveHoliday(
                monday, holidayDateKeys = setOf(mondayKey), adjustedWorkdayDateKeys = setOf(mondayKey),
                overrideEnabled = true, markingEnabled = true,
            ),
        )
        // 覆盖开着 → 一律假期
        assertEquals(
            true,
            resolveHoliday(monday, emptySet(), emptySet(), overrideEnabled = true, markingEnabled = false),
        )
        // 标记关 → 不隐藏
        assertEquals(
            false,
            resolveHoliday(monday, setOf(mondayKey), emptySet(), overrideEnabled = false, markingEnabled = false),
        )
        // 正常假期
        assertEquals(
            true,
            resolveHoliday(monday, setOf(mondayKey), emptySet(), overrideEnabled = false, markingEnabled = true),
        )
    }
}
