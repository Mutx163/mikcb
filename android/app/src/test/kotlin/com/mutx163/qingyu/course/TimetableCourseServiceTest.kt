package com.mutx163.qingyu.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.CourseTaskSource
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDateTime

/**
 * TimetableCourseService 端口测试（族3课表CRUD · 纯逻辑）。
 *
 * Dart 源：lib/services/timetable_course_service.dart（978 行）；
 * 抄录用例：test/services/timetable_course_service_test.dart（851 行，假端口口径）。
 *
 * 期望值来源：
 * - [Dart抄录]：Dart 测试的输入输出原样翻成 Kotlin；
 * - [Dart推演]：对照服务实现逐行推演；
 * - [人推]：独立推的边界值（空/极值/非法/回滚）。
 *
 * 假端口说明：内存状态 + 钩子计数；方案补齐走"原样返回"，
 * 钉的是服务自己的校验、归一、广播与回滚逻辑（与 Dart _FakePort 同构）。
 */
class TimetableCourseServiceTest {

    private class FakePort(
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        profiles: List<TimetableProfile> = emptyList(),
    ) : TimetableCoursePort {
        override var courses: List<Course> = ArrayList(courses)
        override var tasks: List<CourseTask> = ArrayList(tasks)
        override var exams: List<Exam> = ArrayList(exams)
        override var profiles: List<TimetableProfile> = ArrayList(profiles)

        var initializeCalls = 0
        var persistCalls = 0
        var notifyCalls = 0
        var clearLiveCalls = 0
        var syncReminderCalls = 0
        var updateLiveCalls = 0
        var recordTeacherCalls = 0
        var recordLocationCalls = 0
        val loggedEvents = mutableListOf<String>()
        var failPersist = false
        var validationMessage: String? = null

        override val semesterWeekCount: Int get() = 16

        override fun getCourseById(id: String): Course? = courses.firstOrNull { it.id == id }

        override fun dateForCourseOccurrence(course: Course, week: Int): LocalDateTime? {
            if (week < 1) return null
            val base = DartTime.dateTime(2026, 3, 2)
            return base.plusDays(((week - 1) * 7 + course.dayOfWeek - 1).toLong())
        }

        override fun validateCourseTimeSchemeOverride(
            timeSchemeId: String?,
            startSection: Int,
            endSection: Int,
        ): String? = validationMessage

        override fun syncCourseWithEffectiveTimeScheme(course: Course): Course = course

        override fun isLiveTestingFixture(course: Course): Boolean = course.id.startsWith("live_test_")

        override fun recordTeacher(teacher: String) { recordTeacherCalls++ }

        override fun recordLocation(location: String) { recordLocationCalls++ }

        override fun persistActiveProfileState() {
            persistCalls++
            if (failPersist) throw IllegalStateException("disk down")
        }

        override fun initialize() { initializeCalls++ }

        override fun clearCurrentLiveCourseId() { clearLiveCalls++ }

        override fun notifyStateChanged() { notifyCalls++ }

        override fun logEvent(name: String, parameters: Map<String, Any>) { loggedEvents.add(name) }

        override fun syncExamReminders() { syncReminderCalls++ }

        override fun updateLiveActivity() { updateLiveCalls++ }
    }

    private fun course(
        id: String,
        name: String = "数学",
        teacher: String = "",
        location: String = "",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        shortName: String? = null,
        description: String? = null,
        note: String? = null,
        timeSchemeIdOverride: String? = null,
        sessionNotes: Map<Int, CourseSessionNote>? = null,
    ): Course = Course(
        id = id, name = name, teacher = teacher, location = location,
        dayOfWeek = dayOfWeek, startSection = startSection, endSection = endSection,
        startTime = "08:00", endTime = "09:45",
        startWeek = startWeek, endWeek = endWeek,
        shortName = shortName, description = description, note = note,
        timeSchemeIdOverride = timeSchemeIdOverride, sessionNotes = sessionNotes,
    )

    private fun task(
        id: String,
        title: String = "作业",
        courseId: String? = null,
        sourceWeek: Long? = null,
        completed: Boolean = false,
        source: CourseTaskSource = CourseTaskSource.MANUAL,
        dueDate: LocalDateTime? = null,
    ): CourseTask = CourseTask(
        id = id, title = title, courseId = courseId, sourceWeek = sourceWeek,
        source = source, isCompleted = completed, dueDate = dueDate,
        createdAt = DartTime.dateTime(2026, 3, 1), updatedAt = DartTime.dateTime(2026, 3, 1),
    )

    private fun exam(id: String, courseId: String): Exam = Exam(
        id = id, courseId = courseId, name = "期末考试",
        dateTime = DartTime.dateTime(2026, 6, 1),
        startTime = "09:00", endTime = "11:00",
        createdAt = DartTime.dateTime(2026, 3, 1), updatedAt = DartTime.dateTime(2026, 3, 1),
    )

    private fun profile(id: String): TimetableProfile = TimetableProfile(
        id = id, name = "课表$id", courses = emptyList(),
        settings = TimetableSettings.defaults(), currentWeek = 1,
        createdAt = DartTime.dateTime(2026, 3, 1), lastUsedAt = DartTime.dateTime(2026, 3, 1),
    )

    // ---------------- normalize / validateUnboundSections ----------------

    @Test
    fun normalize_trimsAndPromotesNoteAndClampsWeeks() { // [Dart抄录 service_test:572-590]
        val normalized = TimetableCourseService.normalize(
            course("c1", name = "  数学  ", teacher = " 张老师 ", startWeek = 0, endWeek = 99, note = "  旧备注  "),
            semesterWeekCount = 16,
        )
        assertEquals("数学", normalized.name)
        assertEquals("张老师", normalized.teacher)
        assertEquals("旧备注", normalized.description)
        assertEquals(1, normalized.startWeek)
        assertEquals(16, normalized.endWeek)
    }

    @Test
    fun normalize_emptyShortNameBecomesNull_descriptionPrefersExplicit() { // [人推：空/极值]
        val c = TimetableCourseService.normalize(
            course("c1", shortName = "   ", description = " 共享 ", note = " 旧 "),
            semesterWeekCount = 16,
        )
        assertNull(c.shortName)
        assertEquals("共享", c.description)
        // description 为空时回落 note：
        val fallback = TimetableCourseService.normalize(
            course("c1", description = "  ", note = " 旧备注 "),
            semesterWeekCount = 16,
        )
        assertEquals("旧备注", fallback.description)
        // 两者皆空 → null：
        val none = TimetableCourseService.normalize(course("c1"), semesterWeekCount = 16)
        assertNull(none.description)
        assertNull(none.note)
    }

    @Test
    fun validateUnboundSections_rejectsOutOfRange() { // [Dart抄录 service_test:592-621]
        assertEquals("course_sections_invalid", TimetableCourseService.validateUnboundSections(0, 2))
        assertEquals("course_sections_invalid", TimetableCourseService.validateUnboundSections(3, 2))
        assertEquals("course_sections_invalid", TimetableCourseService.validateUnboundSections(1, 31))
        assertNull(TimetableCourseService.validateUnboundSections(1, 30))
        assertNull(TimetableCourseService.validateUnboundSections(5, 6))
    }

    // ---------------- update ----------------

    @Test
    fun update_broadcastsSharedFieldsToSameGroupOnly() { // [Dart抄录 service_test:199-224]
        val port = FakePort(courses = listOf(course("c1", teacher = "张老师"), course("c2", dayOfWeek = 3), course("c3", name = "英语")))
        TimetableCourseService.update(port, course("c1", teacher = "张老师", shortName = "数"), previousSharedName = "数学")
        assertEquals("数", port.getCourseById("c1")!!.shortName)
        assertEquals("数", port.getCourseById("c2")!!.shortName)
        assertNull(port.getCourseById("c3")!!.shortName)
        assertEquals(1, port.persistCalls)
        assertEquals(1, port.notifyCalls)
        assertEquals(1, port.clearLiveCalls)
        assertTrue(port.loggedEvents.contains("course_updated"))
    }

    @Test
    fun update_missingCourse_isNoopWithoutPersist() { // [Dart抄录 service_test:251-258]
        val port = FakePort(courses = listOf(course("c1")))
        TimetableCourseService.update(port, course("missing"))
        assertEquals(0, port.persistCalls)
        assertEquals(0, port.notifyCalls)
    }

    @Test
    fun update_boundSchemeValidationError_throwsAndSkipsPersist() { // [Dart抄录 service_test:260-280]
        val port = FakePort(courses = listOf(course("c1", timeSchemeIdOverride = "s1")))
        port.validationMessage = "course_sections_invalid"
        try {
            TimetableCourseService.update(port, course("c1", timeSchemeIdOverride = "s1"))
            fail("expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("course_sections_invalid", e.message)
        }
        assertEquals(0, port.persistCalls)
    }

    @Test
    fun update_unboundOverflow_throws() { // [Dart抄录 service_test:282-300]
        val port = FakePort(courses = listOf(course("c1")))
        try {
            TimetableCourseService.update(port, course("c1", endSection = 40))
            fail("expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("course_sections_invalid", e.message)
        }
    }

    @Test
    fun update_persistFailure_rollsBackCoursesTasksProfiles() { // [Dart抄录 service_test:226-249]
        val port = FakePort(
            courses = listOf(course("c1"), course("c2")),
            tasks = listOf(task("t1", courseId = "c1")),
            profiles = listOf(profile("p1")),
        )
        port.failPersist = true
        try {
            TimetableCourseService.update(port, course("c1", shortName = "数"), previousSharedName = "数学")
            fail("expected persist failure")
        } catch (_: IllegalStateException) { }
        assertNull(port.getCourseById("c1")!!.shortName)
        assertNull(port.getCourseById("c2")!!.shortName)
        assertEquals(1, port.tasks.size)
        assertEquals(1, port.profiles.size)
        assertEquals(0, port.notifyCalls)
        assertEquals(0, port.clearLiveCalls)
    }

    // ---------------- delete / deleteGroup / clear ----------------

    @Test
    fun delete_removesCourseExamsTasksButKeepsOthers() { // [Dart抄录 service_test:304-322]
        val port = FakePort(
            courses = listOf(course("c1"), course("c2")),
            exams = listOf(exam("e1", "c1"), exam("e2", "c2")),
            tasks = listOf(task("t1", courseId = "c1"), task("t2", courseId = "c2"), task("t3")),
        )
        TimetableCourseService.delete(port, "c1")
        assertEquals(listOf("c2"), port.courses.map { it.id })
        assertEquals(listOf("e2"), port.exams.map { it.id })
        assertEquals(listOf("t2", "t3"), port.tasks.map { it.id })
        assertEquals(1, port.persistCalls)
        assertTrue(port.loggedEvents.contains("course_deleted"))
    }

    @Test
    fun delete_persistFailure_restoresAllFourLists() { // [Dart抄录 service_test:324-343]
        val port = FakePort(
            courses = listOf(course("c1")), exams = listOf(exam("e1", "c1")),
            tasks = listOf(task("t1", courseId = "c1")), profiles = listOf(profile("p1")),
        )
        port.failPersist = true
        try {
            TimetableCourseService.delete(port, "c1")
            fail("expected persist failure")
        } catch (_: IllegalStateException) { }
        assertEquals(1, port.courses.size)
        assertEquals(1, port.exams.size)
        assertEquals(1, port.tasks.size)
        assertEquals(1, port.profiles.size)
        assertEquals(0, port.notifyCalls)
    }

    @Test
    fun clearEmpty_returnsFalseWithoutPersist() { // [Dart抄录 service_test:347-356]
        val port = FakePort()
        assertFalse(TimetableCourseService.clearActiveProfileCourses(port))
        assertEquals(1, port.initializeCalls)
        assertEquals(0, port.persistCalls)
    }

    @Test
    fun clear_removesCoursesAndLinkedTasksKeepsExams() { // [Dart抄录 service_test:358-377]
        val port = FakePort(
            courses = listOf(course("c1")),
            tasks = listOf(task("t1", courseId = "c1"), task("t2")),
            exams = listOf(exam("e1", "c1")),
        )
        assertTrue(TimetableCourseService.clearActiveProfileCourses(port))
        assertTrue(port.courses.isEmpty())
        assertEquals(listOf("t2"), port.tasks.map { it.id })
        assertEquals(1, port.exams.size)
        assertEquals(1, port.persistCalls)
        assertTrue(port.loggedEvents.contains("courses_cleared"))
    }

    @Test
    fun clear_persistFailure_restoresSnapshot() { // [Dart抄录 service_test:379-394]
        val port = FakePort(
            courses = listOf(course("c1")), tasks = listOf(task("t1", courseId = "c1")),
            profiles = listOf(profile("p1")),
        )
        port.failPersist = true
        try {
            TimetableCourseService.clearActiveProfileCourses(port)
            fail("expected persist failure")
        } catch (_: IllegalStateException) { }
        assertEquals(1, port.courses.size)
        assertEquals(1, port.tasks.size)
        assertEquals(1, port.profiles.size)
    }

    // ---------------- add / addGroup / updateGroup ----------------

    @Test
    fun add_trimsAndRecordsTeacherLocation() { // [Dart抄录 service_test:625-640]
        val port = FakePort()
        TimetableCourseService.add(port, course("c1", name = " 物理 ", teacher = "李老师", location = "A101"))
        assertEquals("物理", port.courses.single().name)
        assertEquals(1, port.recordTeacherCalls)
        assertEquals(1, port.recordLocationCalls)
        assertEquals(1, port.persistCalls)
        assertEquals(1, port.notifyCalls)
        assertTrue(port.loggedEvents.contains("course_created"))
    }

    @Test
    fun add_inheritsSharedFieldsFromExistingGroup() { // [Dart抄录 service_test:642-650]
        val port = FakePort(courses = listOf(course("c1", shortName = "数")))
        TimetableCourseService.add(port, course("c2"))
        assertEquals("数", port.getCourseById("c2")!!.shortName)
    }

    @Test
    fun add_liveFixtureSkipsSchemeSync() { // [Dart抄录 service_test:652-658]
        val port = FakePort()
        TimetableCourseService.add(port, course("live_test_1"))
        assertEquals("live_test_1", port.courses.single().id)
    }

    @Test
    fun addGroup_dedupesTeacherLocationAndPersistsOnce() { // [Dart抄录 service_test:760-773]
        val port = FakePort()
        TimetableCourseService.addGroup(
            port, listOf(
                course("c1", name = "物理", teacher = "李老师", location = "A101"),
                course("c2", name = "物理", teacher = "李老师", dayOfWeek = 4),
            ),
        )
        assertEquals(2, port.courses.size)
        assertEquals(1, port.recordTeacherCalls)
        assertEquals(1, port.recordLocationCalls)
        assertEquals(1, port.persistCalls)
        assertTrue(port.loggedEvents.contains("course_group_created"))
    }

    @Test
    fun addGroup_oneInvalidCourse_addsNothing() { // [Dart抄录 service_test:775-787]
        val port = FakePort()
        try {
            TimetableCourseService.addGroup(
                port, listOf(course("c1", name = "物理"), course("c2", name = "物理", endSection = 40)),
            )
            fail("expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("course_sections_invalid", e.message)
        }
        assertTrue(port.courses.isEmpty())
        assertEquals(0, port.persistCalls)
    }

    @Test
    fun deleteGroup_removesWholeGroupWithExamsTasks() { // [Dart抄录 service_test:662-683]
        val port = FakePort(
            courses = listOf(course("c1"), course("c2", dayOfWeek = 3), course("c3", name = "英语")),
            exams = listOf(exam("e1", "c1"), exam("e2", "c3")),
            tasks = listOf(task("t1", courseId = "c2"), task("t2", courseId = "c3")),
        )
        TimetableCourseService.deleteGroup(port, " 数学 ")
        assertEquals(listOf("c3"), port.courses.map { it.id })
        assertEquals(listOf("e2"), port.exams.map { it.id })
        assertEquals(listOf("t2"), port.tasks.map { it.id })
        assertEquals(1, port.persistCalls)
        assertTrue(port.loggedEvents.contains("course_group_deleted"))
    }

    @Test
    fun updateGroup_replacesSetAndPrunesOrphanTasks() { // [Dart抄录 service_test:705-732]
        val port = FakePort(
            courses = listOf(course("c1"), course("c2", dayOfWeek = 3)),
            tasks = listOf(task("t1", courseId = "c1"), task("t2", courseId = "c2"), task("t3", title = "手写作业")),
        )
        TimetableCourseService.updateGroup(
            port, "数学", listOf(course("c1", shortName = "数"), course("c3", dayOfWeek = 5)),
        )
        assertEquals(listOf("c1", "c3"), port.courses.map { it.id })
        assertEquals("数", port.getCourseById("c3")!!.shortName)
        assertEquals(listOf("t1", "t3"), port.tasks.map { it.id })
        assertEquals(1, port.persistCalls)
        assertTrue(port.loggedEvents.contains("course_group_updated"))
    }

    @Test
    fun updateGroup_emptyList_isNoop() { // [Dart抄录 service_test:734-741]
        val port = FakePort(courses = listOf(course("c1")))
        TimetableCourseService.updateGroup(port, "数学", emptyList())
        assertEquals(1, port.courses.size)
        assertEquals(0, port.persistCalls)
    }

    // ---------------- tasks ----------------

    @Test
    fun addTask_trimsSortsPersistsAndNotifies() { // [Dart抄录 service_test:398-416]
        val port = FakePort(
            courses = listOf(course("c1")),
            tasks = listOf(task("t1", dueDate = DartTime.dateTime(2026, 4, 1))),
        )
        TimetableCourseService.addTask(
            port, task("t2", title = "  写实验报告  ", courseId = "c1", dueDate = DartTime.dateTime(2026, 3, 20)),
        )
        assertEquals(listOf("t2", "t1"), port.tasks.map { it.id })
        assertEquals("写实验报告", port.tasks.first().title)
        assertEquals(1, port.persistCalls)
        assertEquals(1, port.notifyCalls)
        assertTrue(port.loggedEvents.contains("task_created"))
    }

    @Test
    fun addTask_blankTitle_rejectsWithoutPersist() { // [Dart抄录 service_test:418-432]
        val port = FakePort()
        try {
            TimetableCourseService.addTask(port, task("t1", title = "   "))
            fail("expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("task_title_required", e.message)
        }
        assertEquals(0, port.persistCalls)
    }

    @Test
    fun addTask_unknownCourse_rejects() { // [Dart抄录 service_test:434-447]
        val port = FakePort()
        try {
            TimetableCourseService.addTask(port, task("t1", courseId = "missing"))
            fail("expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("task_course_not_found", e.message)
        }
    }

    @Test
    fun updateTask_keepsCreatedAt_unknownIdIsNoop() { // [Dart抄录 service_test:449-465]
        val port = FakePort(tasks = listOf(task("t1", title = "旧标题")))
        val createdAt = port.tasks.single().createdAt
        TimetableCourseService.updateTask(port, task("t1", title = "新标题", dueDate = DartTime.dateTime(2026, 5, 1)))
        val updated = port.tasks.single()
        assertEquals("新标题", updated.title)
        assertEquals(createdAt, updated.createdAt)
        assertEquals(1, port.persistCalls)
        TimetableCourseService.updateTask(port, task("missing"))
        assertEquals(1, port.persistCalls)
    }

    @Test
    fun toggleTaskCompleted_flipsAndPersists() { // [Dart抄录 service_test:467-475]
        val port = FakePort(tasks = listOf(task("t1")))
        TimetableCourseService.toggleTaskCompleted(port, "t1")
        assertTrue(port.tasks.single().isCompleted)
        assertEquals(1, port.persistCalls)
        assertEquals(1, port.notifyCalls)
    }

    @Test
    fun toggleTaskCompleted_unknownId_isNoop() { // [人推：非法 id]
        val port = FakePort(tasks = listOf(task("t1")))
        TimetableCourseService.toggleTaskCompleted(port, "missing")
        assertEquals(0, port.persistCalls)
        assertFalse(port.tasks.single().isCompleted)
    }

    @Test
    fun deleteTask_clearsHomeworkMark() { // [Dart抄录 service_test:477-497]
        val port = FakePort(
            courses = listOf(course("c1", sessionNotes = mapOf(3 to CourseSessionNote(text = "第三章", hasHomework = true)))),
            tasks = listOf(task("t1", courseId = "c1", sourceWeek = 3L, source = CourseTaskSource.HOMEWORK_MARK)),
        )
        TimetableCourseService.deleteTask(port, "t1")
        assertTrue(port.tasks.isEmpty())
        assertFalse(port.getCourseById("c1")!!.sessionNoteForWeek(3)!!.hasHomework)
        assertTrue(port.loggedEvents.contains("task_deleted"))
    }

    @Test
    fun sortTasks_ordersByDueDateCompletedTitleId() { // [人推：排序口径独立推导]
        val t1 = task("b", title = "b", dueDate = DartTime.dateTime(2026, 4, 1))
        val t2 = task("a", title = "a", dueDate = DartTime.dateTime(2026, 4, 1))
        val t3 = task("c", title = "c", dueDate = null)
        val sorted = TimetableCourseService.sortTasks(mutableListOf(t1, t2, t3))
        assertEquals(listOf("a", "b", "c"), sorted.map { it.id })
    }

    // ---------------- syncHomework / occurrence / queries ----------------

    @Test
    fun syncHomework_marksCreateTasksWithOccurrenceDueDate() { // [Dart抄录 service_test:527-553]
        val port = FakePort(
            courses = listOf(course("c1", dayOfWeek = 2, sessionNotes = mapOf(2 to CourseSessionNote(text = "习题 1", hasHomework = true)))),
        )
        val changed = TimetableCourseService.syncHomeworkTasksWithCourses(port)
        assertTrue(changed)
        val generated = port.tasks.single()
        assertEquals("习题 1", generated.title)
        assertEquals("c1", generated.courseId)
        assertEquals(2L, generated.sourceWeek)
        assertEquals(CourseTaskSource.HOMEWORK_MARK, generated.source)
        // 学期首周周一=2026-03-02，第2周周二=03-10（Dart 用例注释原样）。
        assertEquals(DartTime.dateTime(2026, 3, 10), generated.dueDate)
    }

    @Test
    fun tasksForCourse_filtersByCourseAndWeekAndSorts() { // [Dart抄录 service_test:791-825]
        val port = FakePort(
            courses = listOf(course("c1")),
            tasks = listOf(
                task("t1", courseId = "c1", sourceWeek = 2L, dueDate = DartTime.dateTime(2026, 4, 1)),
                task("t2", courseId = "c1", sourceWeek = 3L, dueDate = DartTime.dateTime(2026, 3, 1)),
                task("t3", courseId = "c2"),
            ),
        )
        assertEquals("t2", TimetableCourseService.taskById(port, "t2")!!.id)
        assertNull(TimetableCourseService.taskById(port, "missing"))
        assertEquals(listOf("t2", "t1"), TimetableCourseService.tasksForCourse(port, "c1").map { it.id })
        assertEquals("t1", TimetableCourseService.tasksForCourse(port, "c1", sourceWeek = 2L).single().id)
        assertNull(TimetableCourseService.courseForTask(port, port.tasks.last()))
        assertEquals("c1", TimetableCourseService.courseForTask(port, port.tasks.first())!!.id)
    }

    @Test
    fun courseOccurrenceDate_countsFromSemesterMonday() { // [Dart抄录 service_test:827-849]
        assertEquals(
            DartTime.dateTime(2026, 3, 3),
            TimetableCourseService.courseOccurrenceDate(DartTime.dateTime(2026, 3, 2), course("c1", dayOfWeek = 2), 1),
        )
        assertEquals(
            DartTime.dateTime(2026, 3, 17),
            TimetableCourseService.courseOccurrenceDate(DartTime.dateTime(2026, 3, 2), course("c1", dayOfWeek = 2), 3),
        )
        assertNull(TimetableCourseService.courseOccurrenceDate(null, course("c1"), 1))
        assertNull(TimetableCourseService.courseOccurrenceDate(DartTime.dateTime(2026, 3, 2), course("c1"), 0))
    }
}
