package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入前「按 scope 的真差分」（F16）。
 *
 * 期望值全部按 Dart 手推，判据源：`lib/services/transfer_diff_service.dart`
 * （`compare` :150-203 / `_compareList` :313-367 / `_sameJson` :426-443 /
 * `reportRemovals` :159-161）+ `lib/services/transfer_package.dart:44-52`
 * （`overwriteUsesMergeSemantics` 只有 4 个 scope 为真）。
 *
 * 三类反例（清单点名要求）：同 id 内容变 / 新增 / 删除，各一条。
 *
 * 咬合探针：把 `DataTransferDiffLogic.compareEntities` 里的
 * `before.json != entity.json` 改成 `false`（即「同 id 一律判相同」），
 * `同 id 内容不同判更新` 与 `八类差分的顺序与增改删计数按 Dart 口径` 立刻红。
 */
class DataTransferDiffLogicTest {

    // ── 八类顺序与计数 ──────────────────────────────────────────────

    @Test
    fun `八类差分的顺序与增改删计数按 Dart 口径`() {
        val current = TransferDiffCurrent(
            courses = listOf(course("c1", "甲"), course("c2", "乙")),
            tasks = listOf(task("t1", "作业")),
            settings = TimetableSettings.defaults(),
        )
        val plan = plan(
            courses = listOf(course("c1", "甲改"), course("c3", "丙")),
            tasks = listOf(task("t1", "作业"), task("t2", "新作业")),
            settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
        )

        val diff = DataTransferDiffLogic.compare(
            current, plan, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.OVERWRITE,
        )

        assertEquals(
            listOf(
                "courses", "exams", "time_rules", "locations",
                "tasks", "schedule_items", "time_schemes", "settings",
            ),
            TransferDiffKind.entries.map { it.value },
        )
        assertEquals(
            listOf(
                Triple(1, 1, 1), // courses：c3 新增 / c1 改名 / c2 删除
                Triple(0, 0, 0), // exams
                Triple(0, 0, 0), // time_rules
                Triple(0, 0, 0), // locations（Kotlin 链路不解析也不落盘，恒零）
                Triple(1, 0, 0), // tasks：t2 新增
                Triple(0, 0, 0), // schedule_items
                Triple(0, 0, 0), // time_schemes
                Triple(0, 1, 0), // settings：两侧都能取到且不等
            ),
            diff.toSummaries().map { Triple(it.added, it.updated, it.removed) },
        )
    }

    @Test
    fun `喂给预览的八行摘要用 Dart 的 kind 字符串`() {
        val diff = DataTransferDiffLogic.compare(
            TransferDiffCurrent(),
            plan(courses = listOf(course("c1", "甲"))),
            TransferScope.CURRENT_TIMETABLE,
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(
            listOf(
                "courses", "exams", "time_rules", "locations",
                "tasks", "schedule_items", "time_schemes", "settings",
            ),
            diff.toSummaries().map { it.kind },
        )
    }

    // ── 三类反例：同 id 内容变 / 新增 / 删除 ─────────────────────────

    @Test
    fun `同 id 内容不同判更新`() {
        val diff = DataTransferDiffLogic.compare(
            current = TransferDiffCurrent(courses = listOf(course("c1", "高数"))),
            plan = plan(courses = listOf(course("c1", "高数(新)"))),
            scope = TransferScope.CURRENT_TIMETABLE,
            mode = TransferApplyMode.OVERWRITE,
        )

        val courses = diff.forKind(TransferDiffKind.COURSES)
        assertEquals(0, courses.addedCount)
        assertEquals(1, courses.updatedCount)
        assertEquals(0, courses.removedCount)
        val change = courses.changes.single()
        assertEquals(TransferChangeType.UPDATED, change.type)
        assertEquals("c1", change.id)
        assertEquals("标签要取课程名，不是 id", "高数(新)", change.label)
        assertEquals("updated: 高数(新) (c1)", change.description)
    }

    @Test
    fun `入包新 id 判新增`() {
        val diff = DataTransferDiffLogic.compare(
            current = TransferDiffCurrent(courses = listOf(course("c1", "高数"))),
            plan = plan(courses = listOf(course("c1", "高数"), course("c9", "体育"))),
            scope = TransferScope.CURRENT_TIMETABLE,
            mode = TransferApplyMode.OVERWRITE,
        )

        val courses = diff.forKind(TransferDiffKind.COURSES)
        assertEquals(1, courses.addedCount)
        assertEquals(0, courses.updatedCount)
        assertEquals(0, courses.removedCount)
        assertEquals(TransferChangeType.ADDED, courses.changes.single().type)
        assertEquals("c9", courses.changes.single().id)
    }

    @Test
    fun `本机独有且覆盖式导入判删除`() {
        val diff = DataTransferDiffLogic.compare(
            current = TransferDiffCurrent(
                courses = listOf(course("c1", "高数"), course("c2", "英语")),
            ),
            plan = plan(courses = listOf(course("c1", "高数"))),
            scope = TransferScope.CURRENT_TIMETABLE,
            mode = TransferApplyMode.OVERWRITE,
        )

        val courses = diff.forKind(TransferDiffKind.COURSES)
        assertEquals(0, courses.addedCount)
        assertEquals(0, courses.updatedCount)
        assertEquals(1, courses.removedCount)
        assertEquals("c2", courses.changes.single().id)
        assertEquals(TransferChangeType.REMOVED, courses.changes.single().type)
    }

    // ── mode × scope：删除只在「覆盖 + 非合并语义」时报 ──────────────

    @Test
    fun `合并模式永不报删除`() {
        val diff = DataTransferDiffLogic.compare(
            current = TransferDiffCurrent(courses = listOf(course("c1", "高数"), course("c2", "英语"))),
            plan = plan(courses = listOf(course("c1", "高数(新)"))),
            scope = TransferScope.CURRENT_TIMETABLE,
            mode = TransferApplyMode.MERGE,
        )
        assertFalse("合并预览不该出现删除计数", diff.hasRemovals())
        assertEquals("c1 改过了，所以有一条 updated", 1, diff.updatedCount)
        assertEquals(0, diff.addedCount)
        assertEquals("c2 本机独有，但合并不删", 0, diff.removedCount)
    }

    @Test
    fun `局部 scope 的覆盖也不报删除`() {
        val current = TransferDiffCurrent(courses = listOf(course("c1", "高数"), course("c2", "英语")))
        val plan = plan(courses = listOf(course("c1", "高数")))

        val scoped = DataTransferDiffLogic.compare(
            current, plan, TransferScope.WEEK_TIMETABLE, TransferApplyMode.OVERWRITE,
        )
        assertEquals("本周课表包覆盖时只更新包边界内实体", 0, scoped.removedCount)

        val whole = DataTransferDiffLogic.compare(
            current, plan, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.OVERWRITE,
        )
        assertEquals("整份课表包覆盖时本机多出来的课才是真删除", 1, whole.removedCount)
    }

    // ── 全量包：基线是整份档案表 ────────────────────────────────────

    @Test
    fun `全量包按整份档案表比 自己导出的包差异为零`() {
        val profile = profile(
            id = "p1",
            name = "大一上",
            courses = listOf(course("c1", "高数")),
            tasks = listOf(task("task-1", "作业")),
            exams = listOf(exam("exam-1", "c1")),
            scheduleItems = listOf(scheduleItem("item-1")),
        )
        val current = TransferDiffCurrent(profiles = listOf(profile), activeProfileId = "p1")
        val incoming = plan(profiles = listOf(profile), activeProfileId = "p1")

        val diff = DataTransferDiffLogic.compare(
            current, incoming, TransferScope.ALL_DATA, TransferApplyMode.OVERWRITE,
        )

        assertEquals("自己导自己不该有任何差异", 0, diff.totalCount)
        assertEquals(0, diff.forKind(TransferDiffKind.COURSES).addedCount)
        assertEquals(0, diff.forKind(TransferDiffKind.TASKS).removedCount)
        assertEquals(0, diff.forKind(TransferDiffKind.SCHEDULE_ITEMS).addedCount)
    }

    @Test
    fun `两张档案里的同 id 实体不算同一条`() {
        val current = TransferDiffCurrent(
            profiles = listOf(
                profile(id = "p1", name = "大一上", courses = listOf(course("c1", "高数"))),
                profile(id = "p2", name = "大一下", courses = listOf(course("c1", "英语"))),
            ),
            activeProfileId = "p1",
        )
        val incoming = plan(
            profiles = listOf(
                profile(id = "p1", name = "大一上", courses = listOf(course("c1", "高数"))),
                profile(id = "p2", name = "大一下", courses = listOf(course("c1", "英语(新)"))),
            ),
            activeProfileId = "p1",
        )

        val courses = DataTransferDiffLogic.compare(
            current, incoming, TransferScope.ALL_DATA, TransferApplyMode.OVERWRITE,
        ).forKind(TransferDiffKind.COURSES)

        assertEquals("两张档案各有一条 c1，但只有 p2 那条改了", 1, courses.updatedCount)
        assertEquals(0, courses.addedCount)
        assertEquals("p2", courses.changes.single().profileId)
        assertEquals("updated: 英语(新) (c1) [p2]", courses.changes.single().description)
    }

    // ── 设置行：只在 scope 会携带设置时比 ───────────────────────────

    @Test
    fun `局部 scope 的设置行恒零`() {
        val current = TransferDiffCurrent(
            courses = listOf(course("c1", "高数")),
            settings = TimetableSettings.defaults(),
        )
        val incoming = plan(
            courses = listOf(course("c1", "高数")),
            settings = TimetableSettings.defaults().copy(semesterWeekCount = 19),
        )

        val scoped = DataTransferDiffLogic.compare(
            current, incoming, TransferScope.SELECTED_COURSES, TransferApplyMode.MERGE,
        ).forKind(TransferDiffKind.SETTINGS)
        assertEquals("局部课程传输不携带设置，设置行必须全零", 0, scoped.updatedCount)

        val whole = DataTransferDiffLogic.compare(
            current, incoming, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.MERGE,
        ).forKind(TransferDiffKind.SETTINGS)
        assertEquals(1, whole.updatedCount)
    }

    @Test
    fun `单档案的全量包也能从那张档案里取到设置`() {
        val settings = TimetableSettings.defaults().copy(semesterWeekCount = 19)
        val current = TransferDiffCurrent(settings = TimetableSettings.defaults())
        // 只有一张档案、顶层没有 settings：Dart `_settingsFor` 会退到那张档案里的。
        val incoming = plan(
            profiles = listOf(profile(id = "p1", name = "大一上", settings = settings)),
        )

        val diff = DataTransferDiffLogic.compare(
            current, incoming, TransferScope.ALL_DATA, TransferApplyMode.OVERWRITE,
        ).forKind(TransferDiffKind.SETTINGS)

        assertEquals(1, diff.updatedCount)
    }

    // ── 其它类别 ────────────────────────────────────────────────────

    @Test
    fun `时间模板包只报模板差异`() {
        val diff = DataTransferDiffLogic.compare(
            current = TransferDiffCurrent(
                courses = listOf(course("c1", "高数")),
                timeSchemes = listOf(timeScheme("ts1", "默认作息")),
            ),
            // 时间模板包不带课程（`buildCurrentPackage(timeTemplate)` 的课程列表恒空）。
            plan = plan(timeSchemes = listOf(timeScheme("ts2", "冬季作息"))),
            scope = TransferScope.TIME_TEMPLATE,
            mode = TransferApplyMode.OVERWRITE,
        )

        assertEquals(0, diff.forKind(TransferDiffKind.COURSES).totalCount)
        assertEquals(1, diff.forKind(TransferDiffKind.TIME_SCHEMES).addedCount)
        assertEquals(0, diff.forKind(TransferDiffKind.TIME_SCHEMES).removedCount)
    }

    @Test
    fun `地点作息分组恒零`() {
        val diff = DataTransferDiffLogic.compare(
            current = TransferDiffCurrent(courses = listOf(course("c1", "高数"))),
            plan = plan(courses = listOf(course("c1", "高数"))),
            scope = TransferScope.ALL_DATA,
            mode = TransferApplyMode.OVERWRITE,
        )
        assertTrue(diff.forKind(TransferDiffKind.LOCATIONS).isEmpty)
    }

    // ── 夹具 ────────────────────────────────────────────────────────

    private fun TransferDiff.hasRemovals(): Boolean =
        TransferDiffKind.entries.any { forKind(it).removedCount > 0 }

    private fun plan(
        profiles: List<TimetableProfile> = emptyList(),
        activeProfileId: String? = null,
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        scheduleItems: List<ScheduleItem> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
        settings: TimetableSettings? = null,
        currentWeek: Int? = null,
    ) = TransferImportPlan(
        profiles = profiles,
        activeProfileId = activeProfileId ?: profiles.firstOrNull()?.id,
        courses = courses,
        settings = settings,
        currentWeek = currentWeek,
        timeSchemes = timeSchemes,
        tasks = tasks,
        exams = exams,
        scheduleItems = scheduleItems,
        scheduleDateRules = emptyList(),
    )

    private fun profile(
        id: String,
        name: String,
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        scheduleItems: List<ScheduleItem> = emptyList(),
        settings: TimetableSettings = TimetableSettings.defaults(),
    ) = TimetableProfile(
        id = id,
        name = name,
        courses = courses,
        tasks = tasks,
        exams = exams,
        scheduleItems = scheduleItems,
        settings = settings,
        currentWeek = 1L,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun course(id: String, name: String) = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun task(id: String, title: String) = CourseTask(
        id = id,
        title = title,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun exam(id: String, courseId: String) = Exam(
        id = id,
        courseId = courseId,
        name = "考试-$id",
        dateTime = LocalDateTime.of(2026, 6, 20, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun scheduleItem(id: String) = ScheduleItem(
        id = id,
        title = "日程-$id",
        startDate = LocalDateTime.of(2026, 9, 1, 0, 0),
        endDate = LocalDateTime.of(2026, 9, 1, 0, 0),
        startTime = "09:00",
        endTime = "10:00",
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun timeScheme(id: String, name: String) = TimeScheme(
        id = id,
        name = name,
        sections = listOf(com.mutx163.qingyu.core.SectionTime("08:00", "08:45")),
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )
}
