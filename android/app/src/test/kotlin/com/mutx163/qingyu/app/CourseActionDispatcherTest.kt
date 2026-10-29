package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程操作弹层分派器单测（Phase 3.5 · 主派工大表 T1）。
 *
 * 期望值全部**手推**（照 Dart 出处一条条推），不从实现里抄：
 * - 删除整门课：`timetable_course_sheet_actions.dart:188-235`
 * - 删这一周：`timetable_provider.dart:2756-2827`
 * - 调课：`:2853-2927`（含「无变化不写」与「拆成两条」）
 * - 停课复课：`:2336-2360` 与 `suspendAllWeeks` / `unsuspendAllWeeks`
 */
class CourseActionDispatcherTest {

    // ================================================================
    // 1. 参数透传：带进去的必须是**同一门课**（老教训：只断言「页面打开了」抓不到丢参数）
    // ================================================================

    @Test
    fun `点编辑带进编辑页的是同一门课`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))
        val target = repo.snapshot.courses.single()

        val outcome = CourseActionDispatcher.dispatch(CourseAction.EDIT, target, week = 2, port = repo)

        val edit = outcome as CourseActionOutcome.OpenEdit
        assertSame("必须是同一个实例，不是「另一门同名的课」", target, edit.course)
        assertEquals("c1", edit.course.id)
    }

    @Test
    fun `点加作业带进作业页的也是同一门课`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))
        val target = repo.snapshot.courses.single()

        val outcome = CourseActionDispatcher.dispatch(CourseAction.ADD_TASK, target, week = 1, port = repo)

        assertSame(target, (outcome as CourseActionOutcome.OpenAddTask).course)
    }

    // ================================================================
    // 2. 删除：必须真的从仓储消失
    // ================================================================

    @Test
    fun `点删除整门课真的从仓储删掉 别的课不动`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3),
            course(id = "c2", name = "大学物理", startWeek = 1, endWeek = 3),
        )
        val target = repo.snapshot.courses.first { it.id == "c1" }

        val outcome = CourseActionDispatcher.dispatch(CourseAction.DELETE, target, week = 2, port = repo)

        assertEquals(CourseActionOutcome.DeletedCourse("c1"), outcome)
        assertFalse("c1 必须真的没了", repo.snapshot.courses.any { it.id == "c1" })
        assertTrue("别的课不许被连坐", repo.snapshot.courses.any { it.id == "c2" })
    }

    @Test
    fun `删这一周的课只摘那一周 课还在`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))
        val target = repo.snapshot.courses.single()

        val outcome = CourseActionDispatcher.dispatch(
            CourseAction.DELETE_OCCURRENCE,
            target,
            week = 2,
            port = repo,
        ) as CourseActionOutcome.DeletedOccurrence

        assertFalse(outcome.removedWholeCourse)
        val after = repo.snapshot.courses.single { it.id == "c1" }
        assertEquals("第 2 周应当被摘掉", listOf(1, 3), after.activeWeeks)
    }

    @Test
    fun `只剩这一周时删这一周等于删整门课`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 2, endWeek = 2))
        val target = repo.snapshot.courses.single()

        val outcome = CourseActionDispatcher.dispatch(
            CourseAction.DELETE_OCCURRENCE,
            target,
            week = 2,
            port = repo,
        ) as CourseActionOutcome.DeletedOccurrence

        assertTrue(outcome.removedWholeCourse)
        assertTrue(repo.snapshot.courses.isEmpty())
    }

    @Test
    fun `删一个不存在的课 或者删没课的那一周 都要抛错不静默`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 2))
        try {
            CourseActionDispatcher.deleteOccurrence(repo, courseId = "nope", sourceWeek = 1)
            error("应当抛 IllegalArgumentException")
        } catch (expected: IllegalArgumentException) {
            assertEquals("course_not_found_for_delete", expected.message)
        }
        try {
            CourseActionDispatcher.deleteOccurrence(repo, courseId = "c1", sourceWeek = 9)
            error("应当抛 IllegalArgumentException")
        } catch (expected: IllegalArgumentException) {
            assertTrue(expected.message!!.startsWith("course_not_scheduled_week"))
        }
    }

    // ================================================================
    // 3. 调课：把某一周挪到别的星期/节次
    // ================================================================

    @Test
    fun `调课把源周摘掉 并在目标周生成一条新条目`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3, dayOfWeek = 1, section = 1),
        )
        val target = repo.snapshot.courses.single()

        val outcome = CourseActionDispatcher.rescheduleOccurrence(
            port = repo,
            courseId = "c1",
            sourceWeek = 2,
            targetWeek = 4,
            targetDayOfWeek = 3,
            targetStartSection = 5,
            targetEndSection = 6,
            targetLocation = "三教-401",
        )

        assertTrue(outcome.changed)
        // 原课收缩到剩余周
        val original = repo.snapshot.courses.single { it.id == "c1" }
        assertEquals(listOf(1, 3), original.activeWeeks)
        // 目标位置出现一条同名新课（新 id、单周、目标星期与节次）
        val moved = repo.snapshot.courses.single { it.id != "c1" }
        assertNotEquals("c1", moved.id)
        assertEquals("高等数学", moved.name)
        assertEquals(3, moved.dayOfWeek)
        assertEquals(5, moved.startSection)
        assertEquals(6, moved.endSection)
        assertEquals(listOf(4), moved.activeWeeks)
        assertEquals("三教-401", moved.location)
    }

    @Test
    fun `调课无变化时不写库`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3, dayOfWeek = 1, section = 1),
        )
        val target = repo.snapshot.courses.single()

        val outcome = CourseActionDispatcher.rescheduleOccurrence(
            port = repo,
            courseId = "c1",
            sourceWeek = 2,
            targetWeek = 2,
            targetDayOfWeek = 1,
            targetStartSection = 1,
            targetEndSection = 1,
            targetLocation = target.location,
        )

        assertFalse("无变化必须报 changed=false", outcome.changed)
        assertEquals("课表不许被改写", 1, repo.snapshot.courses.size)
        assertEquals(listOf(1, 2, 3), repo.snapshot.courses.single().activeWeeks)
    }

    @Test
    fun `只剩这一周时调课是原地改 不新增条目`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 2, endWeek = 2, dayOfWeek = 1, section = 1),
        )

        CourseActionDispatcher.rescheduleOccurrence(
            port = repo,
            courseId = "c1",
            sourceWeek = 2,
            targetWeek = 2,
            targetDayOfWeek = 5,
            targetStartSection = 3,
            targetEndSection = 4,
        )

        val only = repo.snapshot.courses.single()
        assertEquals("c1", only.id)
        assertEquals(5, only.dayOfWeek)
        assertEquals(3, only.startSection)
        assertEquals(listOf(2), only.activeWeeks)
    }

    @Test
    fun `目标周超出学期范围要拒绝`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 2))
        try {
            CourseActionDispatcher.rescheduleOccurrence(
                port = repo,
                courseId = "c1",
                sourceWeek = 1,
                targetWeek = 999,
                targetDayOfWeek = 1,
                targetStartSection = 1,
                targetEndSection = 1,
            )
            error("应当抛 IllegalArgumentException")
        } catch (expected: IllegalArgumentException) {
            assertEquals("target_week_out_of_range", expected.message)
        }
    }

    // ================================================================
    // 4. 停课 / 复课
    // ================================================================

    @Test
    fun `本周停课写进 suspendedWeeks 再点一次复课清掉`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))

        val suspended = CourseActionDispatcher.dispatch(
            CourseAction.SUSPEND,
            repo.snapshot.courses.single(),
            week = 2,
            port = repo,
        ) as CourseActionOutcome.SuspensionChanged
        assertTrue(suspended.suspended)
        assertEquals(listOf(2), repo.snapshot.courses.single().suspendedWeeks)

        val resumed = CourseActionDispatcher.dispatch(
            CourseAction.SUSPEND,
            repo.snapshot.courses.single(),
            week = 2,
            port = repo,
        ) as CourseActionOutcome.SuspensionChanged
        assertFalse(resumed.suspended)
        assertEquals("空集合要写回 null（Dart :2356-2358）", null, repo.snapshot.courses.single().suspendedWeeks)
    }

    @Test
    fun `整门停课覆盖全部教学周 复课清空`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))

        CourseActionDispatcher.suspendAllWeeks(repo, "c1")
        assertEquals(listOf(1, 2, 3), repo.snapshot.courses.single().suspendedWeeks)

        CourseActionDispatcher.unsuspendAllWeeks(repo, "c1")
        assertEquals(null, repo.snapshot.courses.single().suspendedWeeks)
    }

    // ================================================================
    // 5. 明确缺口（不假实现）
    // ================================================================

    @Test
    fun `单节课提醒本批没有落点 要报缺口而不是假装成功`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))
        val outcome = CourseActionDispatcher.dispatch(
            CourseAction.SET_ALARM,
            repo.snapshot.courses.single(),
            week = 2,
            port = repo,
        ) as CourseActionOutcome.NotWired

        assertEquals(CourseAction.SET_ALARM, outcome.action)
        assertEquals("no_class_alarm_scheduler", outcome.reason)
        // 渲染层据此**不显示**这一行（显示一个点了没反应的入口就是假实现）
        assertFalse(CourseActionDispatcher.isClassAlarmAvailable())
    }

    @Test
    fun `那一周本来没课时 调课入口报缺口而不是打开空弹层`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 2))
        val target = repo.snapshot.courses.single()
        val outcome = CourseActionDispatcher.dispatch(
            CourseAction.RESCHEDULE,
            target,
            week = 9,
            port = repo,
        ) as CourseActionOutcome.NotWired

        assertEquals(CourseAction.RESCHEDULE, outcome.action)
        assertTrue(outcome.reason.startsWith("course_not_scheduled_week"))
        // 渲染层用的是同一个判据（Dart `course_action_sheet.dart:889` 把按钮置灰）
        assertFalse(CourseActionDispatcher.canReschedule(target, week = 9))
        assertTrue(CourseActionDispatcher.canReschedule(target, week = 2))
    }

    // ================================================================
    // 6. 备注弹层的写入口径（Dart `course_note_sheet.dart:149-197`）
    // ================================================================

    @Test
    fun `保存备注写共享简介并清掉 legacy note`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3)
                .copy(description = null, note = "旧备注"),
        )

        val saved = CourseActionDispatcher.saveCourseNotes(
            port = repo,
            courseId = "c1",
            week = 2,
            wholeNote = "  教材第 3 章  ",
            sessionNoteText = "  带计算器  ",
        )

        assertEquals("首尾空白要 trim 掉", "教材第 3 章", saved.description)
        // Dart `note: null`：两处都留着会出现「改了一处、另一处还是旧值」的漂移。
        assertEquals(null, saved.note)
        assertEquals("带计算器", saved.sessionNoteForWeek(2)?.text)
        assertEquals("只写这一周", 1, saved.normalizedSessionNotesMap?.size)
        // 落盘也要真的写进去（不是只改返回值）
        assertEquals("教材第 3 章", repo.snapshot.courses.single().description)
    }

    @Test
    fun `保存备注保留本周作业标记 只改文本`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3).copy(
                sessionNotes = mapOf(2 to CourseSessionNote(text = "旧文字", hasHomework = true)),
            ),
        )

        val saved = CourseActionDispatcher.saveCourseNotes(
            port = repo,
            courseId = "c1",
            week = 2,
            wholeNote = null,
            sessionNoteText = "新文字",
        )

        assertEquals("新文字", saved.sessionNoteForWeek(2)?.text)
        // 关键：用户只改一句备注，那门课本周的作业标记不能被悄悄清掉
        // （清掉之后 homeworkMark 作业下次重算会消失，Dart 注释 :160-164 专写这条）。
        assertTrue(saved.sessionNoteForWeek(2)?.hasHomework == true)
    }

    @Test
    fun `清空备注文本时保留作业标记 而不是整条删掉`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3).copy(
                sessionNotes = mapOf(2 to CourseSessionNote(text = "旧文字", hasHomework = true)),
            ),
        )

        val saved = CourseActionDispatcher.saveCourseNotes(
            port = repo,
            courseId = "c1",
            week = 2,
            wholeNote = null,
            sessionNoteText = "   ",
        )

        val note = saved.sessionNoteForWeek(2)
        assertTrue("有作业标记时不能写 null（normalizedOrNull 口径）", note != null)
        assertEquals("", note?.text)
        assertTrue(note?.hasHomework == true)
    }

    @Test
    fun `没有作业时清空文本只删这一周 别的周备注不动`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 4).copy(
                sessionNotes = mapOf(
                    2 to CourseSessionNote(text = "第二周", hasHomework = false),
                    4 to CourseSessionNote(text = "第四周", hasHomework = false),
                ),
            ),
        )

        val saved = CourseActionDispatcher.saveCourseNotes(
            port = repo,
            courseId = "c1",
            week = 2,
            wholeNote = null,
            sessionNoteText = "",
        )

        assertEquals(null, saved.sessionNoteForWeek(2))
        assertEquals("第四周", saved.sessionNoteForWeek(4)?.text)
    }

    @Test
    fun `简介写给同名课的其它课次`() {
        val repo = repositoryWith(
            course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3, dayOfWeek = 1),
            course(id = "c2", name = "高等数学", startWeek = 1, endWeek = 3, dayOfWeek = 3),
        )

        CourseActionDispatcher.saveCourseNotes(
            port = repo,
            courseId = "c1",
            week = 1,
            wholeNote = "同名课共享简介",
            sessionNoteText = null,
        )

        // Dart 注释：「Write shared description so all same-name schedule entries see it」。
        assertEquals(
            "同名课次必须跟着变（description 是课程级共享字段）",
            "同名课共享简介",
            repo.snapshot.courses.first { it.id == "c2" }.description,
        )
        // 另一条课次的单周备注不受影响（它是按条目 + 周次存的）。
        assertEquals(null, repo.snapshot.courses.first { it.id == "c2" }.normalizedSessionNotesMap)
    }

    @Test
    fun `课程不存在时抛错 不静默成功`() {
        val repo = repositoryWith(course(id = "c1", name = "高等数学", startWeek = 1, endWeek = 3))
        var threw = false
        try {
            CourseActionDispatcher.saveCourseNotes(repo, "missing", 1, "x", "y")
        } catch (e: IllegalArgumentException) {
            threw = true
        }
        assertTrue("找不到课必须抛，不能假装写成功", threw)
    }

    // ================================================================
    // 夹具
    // ================================================================

    private fun repositoryWith(vararg courses: Course): TimetableRepository {
        val repo = TimetableRepository(TimetableStore(InMemoryKeyValueStore()))
        courses.forEach { repo.addCourse(it) }
        return repo
    }

    private fun course(
        id: String,
        name: String,
        startWeek: Int,
        endWeek: Int,
        dayOfWeek: Int = 1,
        section: Int = 1,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "三教-101",
        dayOfWeek = dayOfWeek,
        startSection = section,
        endSection = section,
        startTime = "08:00",
        endTime = "08:45",
        startWeek = startWeek,
        endWeek = endWeek,
    )
}
