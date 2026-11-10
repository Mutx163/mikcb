package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.TimeScheme
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

    // ── 共享模板扩容（发布版 ensureSectionCapacityForImport 的 usageCount>1 分支） ──

    private fun twoSections() = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("08:55", "09:40"),
    )

    /** 第 N 次写 `timetable_profiles` 才失败（模拟写课那一步落盘失败）。 */
    private class FailingProfilesStore(
        private val delegate: KeyValueStore,
        private val failOnMatch: Int,
    ) : KeyValueStore by delegate {
        private var match = 0

        override fun putString(key: String, value: String) {
            if (key == TimetableStore.KEY_PROFILES) {
                match += 1
                if (match == failOnMatch) throw IllegalStateException("disk_full")
            }
            delegate.putString(key, value)
        }
    }

    /** 两张课表共用同一套模板 ts1——共享模板扩容必须复制副本，不能原地改。 */
    private fun sharedSchemeRepository(
        store: (InMemoryKeyValueStore) -> KeyValueStore = { it },
    ): TimetableRepository {
        val sections = twoSections()
        val scheme = TimeScheme(
            id = "ts1",
            name = "作息A",
            sections = sections,
            createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
        )
        val settings = TimetableSettings.defaults().copy(
            activeTimeSchemeId = "ts1",
            sections = sections,
        )
        val p1 = TimetableProfile(
            id = "p1",
            name = "我的课表",
            courses = emptyList(),
            settings = settings,
            currentWeek = 1,
            createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
            lastUsedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
        )
        val p2 = TimetableProfile(
            id = "p2",
            name = "另一张课表",
            courses = listOf(course("p2-course")),
            settings = settings,
            currentWeek = 1,
            createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
            lastUsedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
        )
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_PROFILES to MiniJson.encode(listOf(p1.toJson(), p2.toJson())),
                TimetableStore.KEY_TIME_SCHEMES to MiniJson.encode(listOf(scheme.toJson())),
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        return TimetableRepository(TimetableStore(store(raw)))
    }

    @Test
    fun `共享模板扩容复制副本 不串改其他课表`() {
        val repository = sharedSchemeRepository()

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(listOf(course("ai-1", endSection = 5))),
            expandSections = true,
        )

        assertTrue(result is AiImageImportApply.Result.Done)
        val schemes = repository.snapshot.timeSchemes
        assertEquals(
            "原模板必须原样保留（不能被原地改）",
            2,
            schemes.single { it.id == "ts1" }.sections.size,
        )
        val copy = schemes.single { it.id != "ts1" }
        assertEquals("作息A（导入补齐）", copy.name)
        assertEquals("副本要扩到课程需要的第 5 节", 5, copy.sections.size)

        val active = repository.snapshot.profiles.single { it.id == "p1" }
        assertEquals("当前课表改绑到副本", copy.id, active.settings.activeTimeSchemeId)
        val other = repository.snapshot.profiles.single { it.id == "p2" }
        assertEquals("别的课表不许被串改（模板引用）", "ts1", other.settings.activeTimeSchemeId)
        assertEquals("别的课表不许被串改（节次镜像）", 2, other.settings.sections.size)
    }

    @Test
    fun `共享模板扩容后写课失败 副本被删且其他课表不变`() {
        // updateTimeSchemeForImport 内部两次写 profiles（档案 + settings 镜像），
        // 第 3 次 profiles 写 = 写课程那一步，失败。
        val repository = sharedSchemeRepository { raw -> FailingProfilesStore(raw, failOnMatch = 3) }

        val result = AiImageImportApply.apply(
            repository = repository,
            request = request(listOf(course("ai-1", endSection = 5))),
            expandSections = true,
        )

        assertSame(AiImageImportApply.Result.Failed, result)
        assertEquals(
            "失败后不许留孤儿「（导入补齐）」模板",
            listOf("ts1"),
            repository.snapshot.timeSchemes.map { it.id },
        )
        assertEquals(2, repository.snapshot.timeSchemes.single().sections.size)
        val active = repository.snapshot.profiles.single { it.id == "p1" }
        assertEquals("当前课表要回到原模板", "ts1", active.settings.activeTimeSchemeId)
        assertTrue(repository.snapshot.courses.isEmpty())
    }
}
