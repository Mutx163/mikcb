package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.CourseTaskSource
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.course.TimetableCoursePort
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * [TaskListController] 的契约测试。
 *
 * 期望值全部**人推**（不是从实现里抄）：
 * - 三条任务里两条无课程、一条挂 c1；「无课程」筛选后应剩 2 条；
 * - 两条今天到期、一条无截止日；「今日」筛选后应剩 2 条（今天到期，无截止日不算）；
 * - 勾完成后仓储里那条 `isCompleted` 必须为 true 且触发通知；删除后仓储里必须不再有它。
 */
class TaskListControllerTest {

    private val fixedNow: LocalDateTime = LocalDateTime.of(2026, 3, 10, 12, 0)

    private class FakePort(
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
    ) : TimetableCoursePort {
        override var courses: List<Course> = ArrayList(courses)
        override var tasks: List<CourseTask> = ArrayList(tasks)
        override var exams: List<Exam> = ArrayList()
        override var profiles: List<TimetableProfile> = ArrayList()
        var notifyCalls = 0
        var persistCalls = 0
        override val semesterWeekCount: Int get() = 16
        override fun getCourseById(id: String): Course? = courses.firstOrNull { it.id == id }
        override fun dateForCourseOccurrence(course: Course, week: Int): LocalDateTime? = null
        override fun validateCourseTimeSchemeOverride(
            timeSchemeId: String?, startSection: Int, endSection: Int,
        ): String? = null
        override fun syncCourseWithEffectiveTimeScheme(course: Course): Course = course
        override fun isLiveTestingFixture(course: Course): Boolean = false
        override fun recordTeacher(teacher: String) {}
        override fun recordLocation(location: String) {}
        override fun persistActiveProfileState() { persistCalls++ }
        override fun clearCurrentLiveCourseId() {}
        override fun logEvent(name: String, parameters: Map<String, Any>) {}
        override fun syncExamReminders() {}
        override fun updateLiveActivity() {}
        override fun notifyStateChanged() { notifyCalls++ }
        override fun initialize() {}
    }

    private fun course(id: String, name: String): Course = Course(
        id = id, name = name, teacher = "", location = "",
        dayOfWeek = 1, startSection = 1, endSection = 2,
        startTime = "08:00", endTime = "09:45",
        startWeek = 1, endWeek = 16,
        shortName = null, description = null, note = null,
        timeSchemeIdOverride = null, sessionNotes = emptyMap<Int, CourseSessionNote>(),
    )

    private fun task(
        id: String,
        courseId: String? = null,
        completed: Boolean = false,
        dueDate: LocalDateTime? = null,
    ): CourseTask = CourseTask(
        id = id, title = "作业$id", courseId = courseId, sourceWeek = null,
        source = CourseTaskSource.MANUAL, isCompleted = completed, dueDate = dueDate,
        createdAt = fixedNow, updatedAt = fixedNow,
    )

    private fun visibleItemCount(state: TaskListViewState): Int = state.sections.sumOf { it.items.size }

    private fun newPort(): FakePort = FakePort(
        courses = listOf(course("c1", "数学")),
        tasks = listOf(
            task("t1", dueDate = LocalDateTime.of(2026, 3, 10, 0, 0)), // 今天到期、无课程
            task("t2"),                                                // 无截止日、无课程
            task("t3", courseId = "c1", dueDate = LocalDateTime.of(2026, 3, 10, 0, 0)), // 今天到期、挂 c1
        ),
    )

    @Test
    fun allFilterShowsEveryTask() {
        val controller = TaskListController(newPort(), clock = { fixedNow })
        val state = controller.viewState(now = fixedNow)
        assertEquals(3, state.totalTasksCount)
        assertEquals(3, visibleItemCount(state))
    }

    @Test
    fun noCourseFilterKeepsOnlyUnlinkedTasks() {
        val controller = TaskListController(newPort(), clock = { fixedNow })
        controller.setCourseFilter(TaskFilterLogic.NONE_COURSE_VALUE)
        val state = controller.viewState(now = fixedNow)
        assertEquals(2, visibleItemCount(state))
    }

    @Test
    fun todayFilterKeepsOnlyDueTodayOrOverdue() {
        val controller = TaskListController(newPort(), clock = { fixedNow })
        controller.setDateFilter(TaskDateFilter.TODAY)
        val state = controller.viewState(now = fixedNow)
        // t1 与 t3 今天到期；t2 无截止日 → 不计入「今日」
        assertEquals(2, visibleItemCount(state))
    }

    @Test
    fun courseOptionsHaveAllNonePlusDistinctCourseNames() {
        val controller = TaskListController(newPort(), clock = { fixedNow })
        val options = controller.courseOptions()
        // 全部 + 无课程 + 数学（1 个课程名） = 3
        assertEquals(3, options.size)
        assertTrue(options.first().isSelected) // 默认「全部课程」选中
    }

    @Test
    fun toggleTaskFlipsCompletedAndNotifies() {
        val port = newPort()
        val controller = TaskListController(port, clock = { fixedNow })
        val target = port.tasks.first { it.id == "t1" }
        controller.toggleTask(target)
        val after = port.tasks.first { it.id == "t1" }
        assertTrue("勾选后应完成", after.isCompleted)
        assertTrue("勾选后应触发仓储通知", port.notifyCalls > 0)
    }

    @Test
    fun deleteTaskRemovesItFromPort() {
        val port = newPort()
        val controller = TaskListController(port, clock = { fixedNow })
        val target = port.tasks.first { it.id == "t2" }
        controller.deleteTask(target)
        assertFalse("删除后仓储不应再有 t2", port.tasks.any { it.id == "t2" })
        assertEquals(2, port.tasks.size)
    }

    @Test
    fun setCourseFilterAllValueResetsToNull() {
        val controller = TaskListController(newPort(), clock = { fixedNow })
        controller.setCourseFilter("数学")
        assertEquals("数学", controller.courseFilter)
        controller.setCourseFilter(TaskFilterLogic.ALL_COURSES_VALUE)
        assertEquals(null, controller.courseFilter)
        assertNotNull(controller.viewState(now = fixedNow))
    }
}
