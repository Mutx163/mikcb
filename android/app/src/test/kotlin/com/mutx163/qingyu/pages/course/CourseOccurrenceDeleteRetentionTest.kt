package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.app.CourseActionDispatcher
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.CourseTaskSource
import com.mutx163.qingyu.core.Exam
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 删单次课的存留语义（Dart `timetable_provider.dart:2756-2827`）。
 *
 * 关键真值：一周不剩时 Dart 只 `_courses.removeAt(index)`（`:2790-2791`），
 * **不碰 `_exams`**；作业重算只丢弃失去课程的派生作业，手写作业保留。
 *
 * 放在 `pages/course` 下是为了让 `scripts/test-kotlin-module.ps1 -Module course`
 * 统一入口能跑到（脚本只收本域 main/test 目录，`app/` 下的测试不在其 classpath 内）。
 */
class CourseOccurrenceDeleteRetentionTest {

    @Test
    fun `删中间一周不动考试与手写作业`() {
        val repo = repositoryWith(course(id = "c1", startWeek = 1, endWeek = 3))
        seedExamAndTasks(repo)

        CourseActionDispatcher.deleteOccurrence(repo, courseId = "c1", sourceWeek = 2)

        assertEquals(listOf(1, 3), repo.snapshot.courses.single().activeWeeks)
        assertEquals("考试不是删单次课该碰的数据", 1, repo.exams.size)
        assertTrue("手写作业必须保留", repo.tasks.any { it.id == "manual-1" })
    }

    @Test
    fun `删最后一周时课还在 考试与作业不动`() {
        val repo = repositoryWith(course(id = "c1", startWeek = 1, endWeek = 3))
        seedExamAndTasks(repo)

        CourseActionDispatcher.deleteOccurrence(repo, courseId = "c1", sourceWeek = 3)

        assertEquals(listOf(1, 2), repo.snapshot.courses.single().activeWeeks)
        assertEquals(1, repo.exams.size)
        assertTrue(repo.tasks.any { it.id == "manual-1" })
    }

    @Test
    fun `单周课删唯一一次 只移除课 考试与手写作业保留`() {
        val repo = repositoryWith(course(id = "c1", startWeek = 2, endWeek = 2))
        seedExamAndTasks(repo)

        val outcome = CourseActionDispatcher.deleteOccurrence(repo, courseId = "c1", sourceWeek = 2)

        assertTrue(outcome.removedWholeCourse)
        assertTrue(repo.snapshot.courses.isEmpty())
        // Dart `:2790-2791` 只 removeAt，不碰 `_exams`。
        assertEquals("整课没了考试也必须留着", 1, repo.exams.size)
        assertTrue("手写作业必须保留", repo.tasks.any { it.id == "manual-1" })
        // Dart 的作业重算只会丢掉已失去课程的派生作业。
        assertFalse("派生作业随课消失", repo.tasks.any { it.id == "derived-1" })
    }

    private fun repositoryWith(vararg courses: Course): TimetableRepository {
        val repo = TimetableRepository(TimetableStore(InMemoryKeyValueStore()))
        courses.forEach { repo.addCourse(it) }
        return repo
    }

    /** 一门课 + 一场考试 + 一条手写作业 + 一条备注派生作业。 */
    private fun seedExamAndTasks(repo: TimetableRepository) {
        val now = LocalDateTime.of(2026, 3, 1, 9, 0)
        repo.exams = listOf(
            Exam(
                id = "exam-1",
                courseId = "c1",
                name = "期中",
                dateTime = now,
                startTime = "09:00",
                endTime = "10:00",
                createdAt = now,
                updatedAt = now,
            ),
        )
        repo.tasks = listOf(
            CourseTask(
                id = "manual-1",
                title = "手写作业",
                courseId = "c1",
                createdAt = now,
                updatedAt = now,
            ),
            CourseTask(
                id = "derived-1",
                title = "备注作业",
                courseId = "c1",
                sourceWeek = 2L,
                source = CourseTaskSource.HOMEWORK_MARK,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }

    private fun course(
        id: String,
        startWeek: Int,
        endWeek: Int,
    ): Course = Course(
        id = id,
        name = "高等数学",
        teacher = "张老师",
        location = "三教-101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 1,
        startTime = "08:00",
        endTime = "08:45",
        startWeek = startWeek,
        endWeek = endWeek,
    )
}
