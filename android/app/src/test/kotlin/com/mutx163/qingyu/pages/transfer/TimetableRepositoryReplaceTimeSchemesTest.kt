package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `TimetableRepository.replaceTimeSchemes` 的**行为**单测（2026-11-06 三轮返工补强）。
 *
 * 之前这条只有宿主源码守卫（文本），证明不了真写盘、换内存、发通知。这里用与真实现同一套
 * 前缀/编码的 [InMemoryKeyValueStore] 做夹具，四件硬证据：
 *
 * 1. **落盘**：换一个 `TimetableStore` 读同一份盘，读到还原后的表；
 * 2. **内存**：`snapshot.timeSchemes` 当场就是还原后的表；
 * 3. **通知**：`observe` 订阅者收到恰好一次（撤销后界面重绘一次）；
 * 4. **不动档案**：恢复快照 ≠ 改模板——课程（含钟点）与档案内容一个字不改。
 *
 * 第三条用例钉住它**刻意绕过 `section_count_below_usage` 校验**的存在理由：
 * 构造一个「`updateTimeScheme` 会拒、`replaceTimeSchemes` 能收」的节次表，断言不抛。
 */
class TimetableRepositoryReplaceTimeSchemesTest {

    private val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 2, 9, 0)
    private val sectionsA = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40"))
    private val sectionsB = listOf(SectionTime("09:00", "09:45"), SectionTime("09:55", "10:40"))
    private val twelveSections = (1..12).map { i ->
        val start = 8 * 60 + (i - 1) * 60
        fun fmt(m: Int) = String.format(Locale.ROOT, "%02d:%02d", m / 60, m % 60)
        SectionTime(fmt(start), fmt(start + 45))
    }

    private fun scheme(id: String, name: String, sections: List<SectionTime>) = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private fun course(
        id: String,
        name: String,
        startSection: Int = 1,
        endSection: Int = 2,
        timeSchemeIdOverride: String? = null,
    ) = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        timeSchemeIdOverride = timeSchemeIdOverride,
    )

    /** 真仓储夹具：带一份档案，档案里至少有一门课（避免「空仓 → 档案未动」变成空断言）。 */
    private fun repositoryWithCourse(
        memory: InMemoryKeyValueStore,
        course: Course,
    ): TimetableRepository {
        val timetableStore = TimetableStore(memory)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    courses = listOf(course),
                    currentWeek = 1,
                    createdAt = stamp,
                    lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(1)
        return TimetableRepository(timetableStore)
    }

    @Test
    fun `整份写回模板表_落盘_内存_通知三件齐_且不动档案`() {
        val memory = InMemoryKeyValueStore()
        val repository = repositoryWithCourse(memory, course("c1", "高数"))
        val restored = listOf(scheme("ts-old", "我原来的作息", sectionsA))

        var notifications = 0
        val subscription = repository.observe { notifications++ }
        val coursesBefore = repository.snapshot.courses
        assertEquals("夹具必须真有一门课，否则「档案未动」是空断言", 1, coursesBefore.size)

        repository.replaceTimeSchemes(restored)
        subscription.close()

        // 1) 内存
        assertEquals(listOf("ts-old"), repository.snapshot.timeSchemes.map { it.id })
        assertEquals(sectionsA, repository.snapshot.timeSchemes.single().sections)
        // 2) 落盘（换一个 store 实例读同一份盘）
        assertEquals(
            "盘上必须是还原后的模板表（store.saveTimeSchemes 真写了）",
            listOf("ts-old"),
            TimetableStore(memory).loadTimeSchemes().schemes.map { it.id },
        )
        // 3) 通知
        assertEquals("必须通知恰好一次", 1, notifications)
        // 4) 反向约束：档案与课程（含钟点）一字未动
        assertEquals("恢复模板表不得改动课程与钟点", coursesBefore, repository.snapshot.courses)
    }

    @Test
    fun `整份写回会覆盖掉导入新建的多余模板`() {
        val memory = InMemoryKeyValueStore()
        val repository = repositoryWithCourse(memory, course("c1", "高数"))
        val localScheme = scheme("ts-local", "本机作息", sectionsA)
        repository.replaceTimeSchemes(listOf(localScheme, scheme("ts-imported", "导入新建的", sectionsB)))
        assertEquals(2, repository.snapshot.timeSchemes.size)

        repository.replaceTimeSchemes(listOf(scheme("ts-local", "本机作息", sectionsB)))

        assertEquals(listOf("ts-local"), repository.snapshot.timeSchemes.map { it.id })
        assertEquals(
            "盘上也不能留下导入新建的那套",
            listOf("ts-local"),
            TimetableStore(memory).loadTimeSchemes().schemes.map { it.id },
        )
        assertTrue("内存与盘一致", repository.snapshot.timeSchemes.single().sections == sectionsB)
    }

    @Test
    fun `恢复模板表能收下更新入口会拒的节次表`() {
        // 存在理由：恢复快照是「写回原样」，不是「改模板」——不该被
        // `section_count_below_usage` 这类编辑期校验挡住（那会把回滚卡成半还原）。
        val memory = InMemoryKeyValueStore()
        val initialSchemeId = "ts-12"
        val repository = repositoryWithCourse(
            memory,
            course("c1", "高数", startSection = 1, endSection = 10, timeSchemeIdOverride = initialSchemeId),
        )
        repository.replaceTimeSchemes(listOf(scheme(initialSchemeId, "12 节作息", twelveSections)))
        repository.updateSettings(
            repository.snapshot.settings.copy(
                activeTimeSchemeId = initialSchemeId,
                sections = twelveSections,
            ),
        )

        // 更新入口：课程用到第 10 节，缩到 4 节必被拒
        val rejected = repository.updateTimeScheme(initialSchemeId, "12 节作息", twelveSections.take(4))
        assertNotNull("updateTimeScheme 必须拒绝「节次低于已用最大节次」的收窄", rejected)

        // 恢复入口：同一份 4 节表照收（不校验、不重排）
        repository.replaceTimeSchemes(listOf(scheme(initialSchemeId, "12 节作息", twelveSections.take(4))))
        assertEquals(
            "恢复入口必须能收下更新入口拒绝的表",
            4,
            repository.snapshot.timeSchemes.single().sections.size,
        )
    }
}
