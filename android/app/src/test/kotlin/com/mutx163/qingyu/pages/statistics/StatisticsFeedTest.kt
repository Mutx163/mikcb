package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.ClassReminderEntry
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.CourseSessionPhase
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 统计族「真数据接线」测试（ST1）。
 *
 * ## 这些用例在钉什么
 *
 * 钉的不是算数（算数在 `core/` 与 `statistics/`，已有自己的测试），而是
 * **「页面拿到的到底是用户的课表，还是写死的演示值」**——这正是接线期最容易悄悄退化的地方：
 * 把 [StatisticsFeed.Input.fromSnapshot] 改回喂一组常量，页面照样渲染、什么都不崩，只有用户能用肉眼发现。
 *
 * 所有期望值都是**人从 Dart 源推出来的**，不是从实现里抄的：
 * - 课次展开与日期轴：`lib/domain/course_session_stats.dart` + `core/WeekCalculator`；
 * - 同名课程聚合：`lib/utils/course_group.dart:24-32`；
 * - 空态与文案：`lib/screens/statistics_session_screen.dart`、`course_statistics_screen.dart`（ARB）；
 * - 周次收敛：`lib/models/timetable_profile.dart:27-38`（`clampCurrentWeekToSettings`）。
 *
 * ## 时钟
 *
 * 一律用固定 [NOW]（2026-10-14 周三 12:00）+ 固定开学日（2026-09-07 周一），
 * **不出现 `LocalDateTime.now()`**：否则「已过 / 今天 / 未到」三档会随真实日期漂移，
 * 今天绿明天红（TEST-POLICY「日期老化」）。
 */
class StatisticsFeedTest {

    // ── 1. 空课表：只给空态，不许补假数据 ──

    @Test
    fun `空课表单节课明细页整页空态`() {
        val feed = feedOf(snapshot(courses = emptyList()))

        assertTrue("一门课都没有就算空", feed.isEmpty)
        assertEquals(0, feed.courseCount)

        val session = feed.session
        assertTrue("空课表必须走整页空态", session.isEmpty)
        assertTrue("课程选择行不该出现", session.courseNames.isEmpty())
        assertNull("没有可选课程时不给 stats", session.stats)
        assertNull("stats 为 null 时没有「没设开学日期」提示", session.noCalendarHint)
        assertTrue(session.summaryMetrics.isEmpty())
        assertTrue(session.coverageRows.isEmpty())
        assertTrue(session.sessionRows.isEmpty())
        assertEquals("暂无课程数据", session.emptyTitle)
        assertEquals("添加课程后即可查看统计", session.emptySubtitle)
    }

    @Test
    fun `空课表统计主页不给学期与周内容`() {
        val home = feedOf(snapshot(courses = emptyList())).home

        assertFalse(home.hasData)
        assertNull("无课就不该有学期内容", home.semester)
        assertNull("无课就不该有周内容", home.week)
        assertFalse("无课时顶栏不出现设置/分享", home.showHeaderActions)
        assertTrue("无课时深度分析入口整组不出现", home.analysisEntries.isEmpty())
        assertNull("无课不推小组件快照", home.widgetSnapshot)
        assertEquals("暂无课程数据", home.emptyTitle)
        assertEquals("添加课程后即可查看统计", home.emptyHint)
        assertEquals("统计标题来自 ARB", "课程统计", home.title)
    }

    @Test
    fun `空课表不会凭空冒出课程`() {
        // 咬合探针打的就是这条：把 fromSnapshot 改回写死演示课程，「0 门课」立刻变成 3 门。
        val session = feedOf(snapshot(courses = emptyList())).session
        assertTrue("空快照必须一门课都不报：${session.courseNames}", session.courseNames.isEmpty())

        // 但换成真的有一门课时，同一个入口必须报出这一门（不是被写死的那几门）。
        val one = feedOf(
            snapshot(courses = listOf(course(name = "线性代数"))),
        ).session
        assertEquals("只该出现快照里那一门", listOf("线性代数"), one.courseNames)
    }

    // ── 2. 只有 1 门课：数字要能对上 ──

    @Test
    fun `只有一门课时课次与已过课时按真实周次算`() {
        // 周三的课，第 1~16 周；NOW = 第 6 周周三 → 前 5 次已过、第 6 次就是今天、后 10 次未到。
        val feed = feedOf(
            snapshot(courses = listOf(course(name = "线性代数", dayOfWeek = 3, startWeek = 1, endWeek = 16))),
        )
        val session = feed.session

        assertEquals(listOf("线性代数"), session.courseNames)
        assertEquals("线性代数", session.selectedCourse)
        assertNotNull("有课就必须算得出课次", session.stats)
        val stats = session.stats!!

        assertEquals("16 个有效周 = 16 次课", 16, stats.sessions.size)
        assertEquals("已过 5 次", 5, stats.doneSessions)
        assertEquals("今天 1 次", 1, stats.todaySessions)
        assertEquals("未到 10 次", 10, stats.upcomingSessions)
        assertEquals("已过课时 = 5 次 × 2 节", 10, stats.doneSections)

        assertEquals("课次", session.summaryMetrics[0].label)
        assertEquals("16", session.summaryMetrics[0].value)
        assertEquals("5", session.summaryMetrics[1].value)
        assertEquals("10", session.summaryMetrics[2].value)
        assertEquals("0", session.summaryMetrics[3].value)
        assertTrue("首格（课次）强调", session.summaryMetrics[0].highlight)
    }

    @Test
    fun `只有一门课时统计主页总览就是那一门`() {
        val home = feedOf(snapshot(courses = listOf(course(name = "线性代数")))).home

        assertTrue(home.hasData)
        assertTrue("有课才出现设置/分享", home.showHeaderActions)
        assertNotNull(home.semester)
        val overview = home.semester!!.overview
        assertEquals("总览四格", 4, overview.size)
        assertEquals("门数 = 1（不是演示数据的 3~8 门）", "1", overview[0].value)
        assertEquals("门课程", overview[0].label)
        assertEquals("课时 = 1 门 × 2 节 × 6 个已到周 = 12", "12", overview[1].value)
    }

    // ── 3. 跨周：每次课落在哪一周、哪天 ──

    @Test
    fun `跨周课程按每个有效周展开且日期逐周推进`() {
        val session = feedOf(
            snapshot(courses = listOf(course(name = "高等数学", dayOfWeek = 3, startWeek = 1, endWeek = 16))),
        ).session
        val sessions = session.stats!!.sessions

        assertEquals("每周一次", 16, sessions.size)
        assertEquals("周次 1..16 各一次", (1..16).toList(), sessions.map { it.week })
        // 开学日 2026-09-07 是周一 → 第 1 周周三 = 9 月 9 日，第 16 周周三 = 12 月 23 日。
        assertEquals(LocalDateTime.of(2026, 9, 9, 0, 0), sessions.first().date)
        assertEquals(LocalDateTime.of(2026, 12, 23, 0, 0), sessions.last().date)
        // 相邻两次正好差 7 天（跨周不断档、不重复）。
        for (index in 1 until sessions.size) {
            val previous = sessions[index - 1].date!!
            val current = sessions[index].date!!
            assertEquals(
                "第 ${index + 1} 次应比上一次晚 7 天",
                7L,
                java.time.temporal.ChronoUnit.DAYS.between(previous, current),
            )
        }
        assertEquals("首行标题是 9月9日 · 周三", "9月9日 · 周三", session.sessionRows.first().title)
        assertEquals(
            "首行副标题是 第 1～2 节 · 08:00–09:40 · 教三 201",
            "第 1～2 节 · 08:00–09:40 · 教三 201",
            session.sessionRows.first().subtitle,
        )
    }

    @Test
    fun `同一门课两个时段合成一个选项且课次翻倍`() {
        // Dart `provider.courseGroups`：按课名聚合。拆成两项会让这门课出现两次、每项只有一半课次。
        val session = feedOf(
            snapshot(
                courses = listOf(
                    course(id = "c1", name = "高等数学", dayOfWeek = 3, startSection = 1, endSection = 2),
                    course(id = "c2", name = "高等数学", dayOfWeek = 5, startSection = 3, endSection = 4),
                ),
            ),
        ).session

        assertEquals("同一门课只出现一次", listOf("高等数学"), session.courseNames)
        assertEquals("两个时段 × 16 周", 32, session.stats!!.sessions.size)
        // 每周两次：周三(1-2) 在周五(3-4) 之前。
        val firstWeek = session.stats!!.sessions.take(2)
        assertEquals(listOf(3, 5), firstWeek.map { it.dayOfWeek })
        assertEquals(listOf(1, 3), firstWeek.map { it.startSection })
    }

    @Test
    fun `单双周课程只展开有效周`() {
        val odd = feedOf(
            snapshot(
                courses = listOf(course(name = "体育", startWeek = 1, endWeek = 16, isOddWeek = true)),
            ),
        ).session.stats!!
        assertEquals("单周 = 1,3,5,7,9,11,13,15 → 8 次", 8, odd.sessions.size)
        assertEquals((1..15 step 2).toList(), odd.sessions.map { it.week })

        val even = feedOf(
            snapshot(
                courses = listOf(course(name = "体育", startWeek = 1, endWeek = 16, isEvenWeek = true)),
            ),
        ).session.stats!!
        assertEquals("双周 = 2,4,6,8,10,12,14,16 → 8 次", 8, even.sessions.size)
        assertEquals((2..16 step 2).toList(), even.sessions.map { it.week })
    }

    @Test
    fun `停课周仍列在课次里但不算计划`() {
        val stats = feedOf(
            snapshot(
                courses = listOf(course(name = "大学物理", startWeek = 1, endWeek = 4, suspendedWeeks = listOf(3))),
            ),
        ).session.stats!!

        assertEquals("停课周照样列出", 4, stats.sessions.size)
        assertEquals(1, stats.suspendedSessions)
        assertEquals("停课周不计入计划", 3, stats.plannedSessions)
        assertEquals(listOf(1, 2, 4), stats.sessions.filter { it.isPlanned }.map { it.week })
    }

    // ── 4. 学期起始日未设置 ──

    @Test
    fun `学期未设起始日时按周次列出并明说`() {
        val feed = feedOf(
            snapshot(
                courses = listOf(course(name = "线性代数")),
                settingsStartDate = null,
                semesterStartEpochDay = null,
            ),
        )
        val session = feed.session
        val stats = session.stats!!

        assertFalse("没有日期轴", stats.hasCalendar)
        assertEquals("没设开学日期，只能按周次列出", session.noCalendarHint)
        assertEquals(16, stats.sessions.size)
        assertTrue(
            "没有日期轴时每次课都是 UNDATED：${stats.sessions.map { it.phase }}",
            stats.sessions.all { it.phase == CourseSessionPhase.UNDATED },
        )
        assertEquals("无日期 → 没有已过的课", 0, stats.doneSessions)
        assertEquals("无日期 → 课时为 0", 0, stats.doneSections)
        // 课次行没有日期时标题退回「第 N 周 · 周三」，副标题只写节次/钟点/教室。
        assertEquals("第 1 周 · 周三", session.sessionRows.first().title)
        assertEquals("第 1～2 节 · 08:00–09:40 · 教三 201", session.sessionRows.first().subtitle)

        // 统计主页走「按周估算」分支，且不印学期起止日。
        val progress = feed.home.semester!!.progress
        assertNull("没有开学日就没有起止日", progress.rangeLabel)
        assertEquals("按周估算", progress.factLabel)
        assertFalse("不是「还未开学」", progress.isBeforeStart)
    }

    @Test
    fun `学期起始日优先取天序而不是设置里的那份`() {
        // 两份表示分叉时以 semesterStartEpochDay 为准（天序跨时区不挪天）。
        // 设置里写 9 月 7 日、天序给 9 月 14 日 → 第 1 周周三应是 9 月 16 日。
        val session = feedOf(
            snapshot(
                courses = listOf(course(name = "线性代数", dayOfWeek = 3)),
                settingsStartDate = LocalDate.of(2026, 9, 7),
                semesterStartEpochDay = LocalDate.of(2026, 9, 14).toEpochDay(),
            ),
        ).session

        assertEquals("9月16日 · 周三", session.sessionRows.first().title)
        assertEquals("第 1～2 节 · 08:00–09:40 · 教三 201", session.sessionRows.first().subtitle)
    }

    // ── 5. currentWeek 越界 ──

    @Test
    fun `当前周超过学期周数时收敛到最后一周`() {
        val input = StatisticsFeed.Input.fromSnapshot(
            snapshot(courses = listOf(course(name = "线性代数")), currentWeek = 99, semesterWeekCount = 16),
        )
        assertEquals("99 → 16", 16, input.settledCurrentWeek)

        val home = StatisticsFeed.homeViewState(input, now = NOW)
        assertEquals(16, home.currentWeek)
        assertEquals("选中周跟随当前周", 16, home.selectedWeek)
        assertEquals(16, home.week!!.weekNumber)
    }

    @Test
    fun `当前周小于 1 时收敛到第 1 周`() {
        val zero = StatisticsFeed.homeViewState(
            StatisticsFeed.Input.fromSnapshot(
                snapshot(courses = listOf(course(name = "线性代数")), currentWeek = 0),
            ),
            now = NOW,
        )
        assertEquals(1, zero.currentWeek)

        val negative = StatisticsFeed.homeViewState(
            StatisticsFeed.Input.fromSnapshot(
                snapshot(courses = listOf(course(name = "线性代数")), currentWeek = -5),
            ),
            now = NOW,
        )
        assertEquals(1, negative.currentWeek)
    }

    @Test
    fun `学期周数非法时当前周收敛到 1`() {
        val input = StatisticsFeed.Input.fromSnapshot(
            snapshot(courses = listOf(course(name = "线性代数")), currentWeek = 7, semesterWeekCount = 0),
        )
        assertEquals("semesterWeekCount < 1 时上限按 1", 1, input.settledCurrentWeek)
    }

    @Test
    fun `选中周越界时回正到当前周`() {
        val input = StatisticsFeed.Input.fromSnapshot(
            snapshot(courses = listOf(course(name = "线性代数")), currentWeek = 6, semesterWeekCount = 16),
        )
        val tooBig = StatisticsFeed.homeViewState(input, now = NOW, selectedWeek = 99)
        assertEquals("99 越界 → 当前周 6", 6, tooBig.selectedWeek)
        assertEquals(6, tooBig.week!!.weekNumber)

        val tooSmall = StatisticsFeed.homeViewState(input, now = NOW, selectedWeek = 0)
        assertEquals(6, tooSmall.selectedWeek)
    }

    @Test
    fun `选中周合法时不被当前周顶掉`() {
        val input = StatisticsFeed.Input.fromSnapshot(
            snapshot(courses = listOf(course(name = "线性代数")), currentWeek = 6, semesterWeekCount = 16),
        )
        val home = StatisticsFeed.homeViewState(input, now = NOW, selectedWeek = 3, semesterView = false)
        assertEquals("用户翻到第 3 周就停在第 3 周", 3, home.selectedWeek)
        assertEquals("周视图 = 分段第 2 项", 1, home.selectedTabIndex)
        assertEquals("当前周仍是 6", 6, home.currentWeek)
    }

    // ── 6. 选中项收敛与分组 ──

    @Test
    fun `上次选中的课被删了回落到第一门`() {
        val session = StatisticsFeed.sessionViewState(
            StatisticsFeed.Input(
                courses = listOf(course(id = "c1", name = "高等数学"), course(id = "c2", name = "大学物理")),
            ),
            now = NOW,
            previousSelection = "线性代数",
        )
        assertEquals("高等数学", session.selectedCourse)

        val kept = StatisticsFeed.sessionViewState(
            StatisticsFeed.Input(
                courses = listOf(course(id = "c1", name = "高等数学"), course(id = "c2", name = "大学物理")),
            ),
            now = NOW,
            previousSelection = "大学物理",
        )
        assertEquals("上次选的还在就沿用", "大学物理", kept.selectedCourse)
    }

    @Test
    fun `分组保持课程在快照里的出现顺序`() {
        val groups = StatisticsFeed.groupByCourseName(
            listOf(
                course(id = "c1", name = "乙课"),
                course(id = "c2", name = "甲课"),
                course(id = "c3", name = "乙课"),
            ),
        )
        assertEquals(listOf("乙课", "甲课"), groups.map { it.name })
        assertEquals(listOf("c1", "c3"), groups[0].courses.map { it.id })
    }

    // ── 7. 参数透传：档案名 / 别的档案 / 作业 ──

    @Test
    fun `活动档案名透传到统计小组件快照`() {
        val profile = profileFixture(id = "p1", name = "大二上", courses = listOf(course(name = "线性代数")))
        val home = feedOf(
            snapshot(
                courses = listOf(course(name = "线性代数")),
                profiles = listOf(profile),
                activeProfileId = "p1",
            ),
        ).home

        assertNotNull("有课就必须有小组件快照", home.widgetSnapshot)
        val widget = home.widgetSnapshot!!
        assertEquals("大二上", widget.profileName)
    }

    @Test
    fun `首启没有档案时用仓储的默认档案名`() {
        val home = feedOf(
            snapshot(courses = listOf(course(name = "线性代数")), profiles = emptyList(), activeProfileId = null),
        ).home
        assertEquals("默认课表", home.widgetSnapshot!!.profileName)
    }

    @Test
    fun `只有一个档案时没有课表对比入口`() {
        val home = feedOf(
            snapshot(
                courses = listOf(course(name = "线性代数")),
                profiles = listOf(profileFixture(id = "p1", name = "课表 1", courses = listOf(course(name = "线性代数")))),
                activeProfileId = "p1",
            ),
        ).home
        assertFalse(home.analysisEntries.any { it.target == StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.COMPARE) })
        assertEquals("6 个入口（不含对比）", 6, home.analysisEntries.size)
    }

    @Test
    fun `有第二个档案时出现课表对比入口`() {
        val home = feedOf(
            snapshot(
                courses = listOf(course(name = "线性代数")),
                profiles = listOf(
                    profileFixture(id = "p1", name = "课表 1", courses = listOf(course(name = "线性代数"))),
                    profileFixture(id = "p2", name = "课表 2"),
                ),
                activeProfileId = "p1",
            ),
        ).home
        assertTrue(
            "有两个档案才出现对比",
            home.analysisEntries.any { it.target == StatisticsEntryTarget.Analysis(StatisticsAnalysisModule.COMPARE) },
        )
        assertEquals(7, home.analysisEntries.size)
    }

    @Test
    fun `活动档案的作业挂到对应课次上`() {
        val course = course(id = "c1", name = "线性代数")
        val task = CourseTask(
            id = "t1",
            title = "第三章习题",
            courseId = "c1",
            sourceWeek = 2L,
            createdAt = NOW,
            updatedAt = NOW,
        )
        val profile = profileFixture(
            id = "p1",
            name = "课表 1",
            courses = listOf(course),
            tasks = listOf(task),
        )
        val session = feedOf(
            snapshot(
                courses = listOf(course),
                profiles = listOf(profile),
                activeProfileId = "p1",
            ),
        ).session

        val withHomework = session.stats!!.sessions.filter { it.hasHomework }
        assertEquals("只有挂了作业的那一周算有作业", 1, withHomework.size)
        assertEquals("作业挂在第 2 周", 2, withHomework.first().week)
        assertEquals("1 / 16", session.coverageRows[1].valueText)
    }

    // ── 8. 时钟注入：今天/已过/未到跟着入参走 ──

    @Test
    fun `同一份课表换个时钟就换一批已过的课`() {
        val input = StatisticsFeed.Input.fromSnapshot(
            snapshot(courses = listOf(course(name = "线性代数", dayOfWeek = 3, startWeek = 1, endWeek = 16))),
        )
        val early = StatisticsFeed.sessionViewState(input, now = LocalDateTime.of(2026, 9, 10, 12, 0))
        val later = StatisticsFeed.sessionViewState(input, now = NOW)

        assertEquals("9 月 10 日：只有 9 月 9 日那次已过", 1, early.stats!!.doneSessions)
        assertEquals("10 月 14 日：已过 5 次", 5, later.stats!!.doneSessions)
        assertNotEquals(early.stats, later.stats)
    }

    // ── 9. 一次装配两份状态必须同源 ──

    @Test
    fun `一次装配的两份状态来自同一份课表`() {
        val feed = feedOf(
            snapshot(
                courses = listOf(
                    course(id = "c1", name = "高等数学", dayOfWeek = 3),
                    course(id = "c2", name = "大学物理", dayOfWeek = 5),
                ),
            ),
        )
        assertEquals("明细页可选 2 门", 2, feed.session.courseNames.size)
        assertEquals("主页总览也是 2 门", "2", feed.home.semester!!.overview[0].value)
        assertEquals(2, feed.courseCount)
        assertEquals(6, feed.currentWeek)
        assertEquals(16, feed.semesterWeekCount)
    }

    // ── 夹具 ──

    /** 固定「今天」：2026-10-14 周三 12:00，对开学日 2026-09-07 来说是第 6 周。 */
    private val NOW: LocalDateTime = LocalDateTime.of(2026, 10, 14, 12, 0)

    /** 固定开学日：2026-09-07（周一）。周次口径见 `core/WeekCalculator`。 */
    private val SEMESTER_START: LocalDate = LocalDate.of(2026, 9, 7)

    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "张老师",
        location: String = "教三 201",
        dayOfWeek: Int = 3,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        suspendedWeeks: List<Int>? = null,
        courseNature: CourseNature = CourseNature.REQUIRED,
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        suspendedWeeks = suspendedWeeks,
        courseNature = courseNature,
    )

    private fun profileFixture(
        id: String,
        name: String,
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
    ): TimetableProfile = TimetableProfile(
        id = id,
        name = name,
        courses = courses,
        tasks = tasks,
        currentWeek = 6,
        createdAt = NOW,
        lastUsedAt = NOW,
    )

    private fun snapshot(
        courses: List<Course> = emptyList(),
        currentWeek: Int = 6,
        semesterWeekCount: Int = 16,
        settingsStartDate: LocalDate? = SEMESTER_START,
        semesterStartEpochDay: Long? = SEMESTER_START.toEpochDay(),
        profiles: List<TimetableProfile> = emptyList(),
        activeProfileId: String? = null,
        classReminders: List<ClassReminderEntry> = emptyList(),
    ): TimetableSnapshot = TimetableSnapshot(
        profiles = profiles,
        activeProfileId = activeProfileId,
        courses = courses,
        settings = TimetableSettings(
            semesterWeekCount = semesterWeekCount,
            semesterStartDate = settingsStartDate?.atStartOfDay(),
            classReminders = classReminders,
        ),
        currentWeek = currentWeek,
        semesterStartEpochDay = semesterStartEpochDay,
    )

    private fun feedOf(
        snapshot: TimetableSnapshot,
        previousSelection: String? = null,
        selectedWeek: Int? = null,
    ) = StatisticsFeed.feed(
        input = StatisticsFeed.Input.fromSnapshot(snapshot),
        now = NOW,
        previousSelection = previousSelection,
        selectedWeek = selectedWeek,
    )

    // ── 9b. 提醒数据源（审核 misc-wiring P1-4 的收尾）──
    //
    // 数据源是 `core/TimetableSettings.classReminders`（随仓储快照进来）。
    // 之前 Kotlin 侧没有这个字段，覆盖行只能整行隐藏（宁缺勿假）；现在字段已补，
    // 「设过提醒」必须读真条目：空表 = 真的没设过（照画 0/N），有条目 = 真的计数。
    // 咬合探针打在这里：把 feed 的默认键集改回 `emptySet()`，下面第二条立刻红。

    @Test
    fun `覆盖卡的设过提醒读快照里的真实条目`() {
        val course = course(id = "c1", name = "线性代数")
        val snap = snapshot(
            courses = listOf(course),
            profiles = listOf(profileFixture(id = "p1", name = "课表 1", courses = listOf(course))),
            activeProfileId = "p1",
            // 2026-10-14（第 6 周周三）是这门课的一次真实课次。
            classReminders = listOf(
                ClassReminderEntry(courseId = "c1", date = "2026-10-14", minuteOfDay = 470),
            ),
        )
        val input = StatisticsFeed.Input.fromSnapshot(snap)

        assertEquals(
            "快照里的提醒键必须原样换装",
            setOf("c1|2026-10-14"),
            input.reminderKeys,
        )
        val session = StatisticsFeed.feed(input = input, now = NOW).session
        assertEquals("数据源已接，覆盖卡必须三行", 3, session.coverageRows.size)
        assertEquals("设过提醒", session.coverageRows[2].label)
        assertEquals(1, session.coverageRows[2].count)
    }

    @Test
    fun `没设过提醒时照画 0 而不是整行消失`() {
        val course = course(id = "c1", name = "线性代数")
        val snap = snapshot(
            courses = listOf(course),
            profiles = listOf(profileFixture(id = "p1", name = "课表 1", courses = listOf(course))),
            activeProfileId = "p1",
        )
        val session = StatisticsFeed.feed(
            input = StatisticsFeed.Input.fromSnapshot(snap),
            now = NOW,
        ).session

        assertEquals("空表是「真的没设过」，不是「拿不到」", 3, session.coverageRows.size)
        assertEquals("设过提醒", session.coverageRows[2].label)
        assertEquals(0, session.coverageRows[2].count)
    }

    @Test
    fun `调用方仍可显式换一份提醒键集`() {
        val course = course(id = "c1", name = "线性代数")
        val snap = snapshot(
            courses = listOf(course),
            profiles = listOf(profileFixture(id = "p1", name = "课表 1", courses = listOf(course))),
            activeProfileId = "p1",
        )
        val input = StatisticsFeed.Input.fromSnapshot(snap)

        val session = StatisticsFeed.feed(
            input = input,
            now = NOW,
            reminderKeys = setOf("c1|2026-10-14"),
        ).session

        assertEquals(3, session.coverageRows.size)
        assertEquals(1, session.coverageRows[2].count)
    }
}
