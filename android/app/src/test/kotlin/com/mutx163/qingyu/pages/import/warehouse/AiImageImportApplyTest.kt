package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * AI 导入落盘（[AiImageImportApply]）单测。
 *
 * 钉住四件事：
 * 1. 覆盖导入真的走 `replaceActiveProfileContent`，开学日一并写入；
 * 2. 更新导入保留本地课，只报告新增/更新条数；
 * 3. 节次不够且用户同意时先扩节再写课；
 * 4. **空课程列表绝不覆盖**（否则等于一键清空课表），写盘失败要回滚设置。
 */
class AiImageImportApplyTest {

    private fun repository(): TimetableRepository =
        TimetableRepository(TimetableStore(InMemoryKeyValueStore()))

    private fun course(
        id: String,
        name: String = "数学",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
    ) = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun request(
        courses: List<Course>,
        semesterStartDate: LocalDateTime? = null,
        replaceExisting: Boolean = true,
        preserveLocalColors: Boolean = true,
    ) = AiImageImportApply.Request(
        courses = courses,
        semesterStartDate = semesterStartDate,
        replaceExisting = replaceExisting,
        preserveLocalColors = preserveLocalColors,
    )

    @Test
    fun `覆盖导入写入课程与开学日`() {
        val repository = repository()
        val start = LocalDateTime.of(2026, 9, 7, 0, 0)

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(listOf(course("ai-1")), semesterStartDate = start),
            expandSections = false,
        )

        assertTrue(result is AiImageImportApply.Result.Done)
        val done = result as AiImageImportApply.Result.Done
        assertEquals(1, done.importedCount)
        assertEquals(listOf("ai-1"), repository.snapshot.courses.map { it.id })
        assertEquals(start, repository.snapshot.settings.semesterStartDate)
    }

    @Test
    fun `更新导入保留本地课并只计新增与更新`() {
        val repository = repository()
        repository.addCourse(course("local-1", name = "数学"))

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(listOf(course("ai-1", name = "英语", dayOfWeek = 2)), replaceExisting = false),
            expandSections = false,
        )

        val done = result as AiImageImportApply.Result.Done
        assertEquals(1, done.importedCount)
        assertEquals(setOf("local-1", "ai-1"), repository.snapshot.courses.map { it.id }.toSet())
    }

    @Test
    fun `节次不够且用户同意时先扩节再写课`() {
        val repository = repository()
        val required = 12

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(listOf(course("ai-1", endSection = required))),
            expandSections = true,
        )

        assertTrue(result is AiImageImportApply.Result.Done)
        assertEquals(required, repository.snapshot.courses.single().endSection)
        assertTrue(repository.snapshot.settings.sections.size >= required)
    }

    @Test
    fun `空课程列表不覆盖课表`() {
        val repository = repository()
        repository.addCourse(course("local-1"))

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(emptyList(), semesterStartDate = LocalDateTime.of(2026, 9, 7, 0, 0)),
            expandSections = false,
        )

        val done = result as AiImageImportApply.Result.Done
        assertEquals(0, done.importedCount)
        assertEquals(listOf("local-1"), repository.snapshot.courses.map { it.id })
        assertNull(repository.snapshot.settings.semesterStartDate)
    }

    @Test
    fun `写课失败时回滚开学日并返回失败`() {
        val delegate = InMemoryKeyValueStore()
        val failingStore = object : KeyValueStore by delegate {
            override fun putString(key: String, value: String) {
                if (key == TimetableStore.KEY_PROFILES) {
                    throw IllegalStateException("disk full")
                }
                delegate.putString(key, value)
            }
        }
        val repository = TimetableRepository(TimetableStore(failingStore))

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(
                listOf(course("ai-1")),
                semesterStartDate = LocalDateTime.of(2026, 9, 7, 0, 0),
            ),
            expandSections = false,
        )

        assertSame(AiImageImportApply.Result.Failed, result)
        assertTrue(repository.snapshot.courses.isEmpty())
        assertNull(repository.snapshot.settings.semesterStartDate)
    }
}
