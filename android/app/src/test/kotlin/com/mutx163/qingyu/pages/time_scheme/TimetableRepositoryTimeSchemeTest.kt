package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 时间模板族的六个仓储写入口（`TimetableRepository.create/rename/duplicate/
 * update/apply/deleteTimeScheme`）的语义单测。
 *
 * 钉的是 Dart `TimetableTimeSchemeService` 里那些**用户能感知的后果**：
 * - 改节次不够课时 → 拒绝并指出是哪门课（否则课程取不到钟点、周视图画不出来）；
 * - 收窄/套用都必须重排课程钟点（否则「换了作息，课还是旧时间」）；
 * - 被引用时删除**一律拒绝**且不落盘、不通知（否则课表时间直接落空）；
 * - 失败路径不通知监听者（界面不会闪一下再退回）。
 *
 * 落盘用 [InMemoryKeyValueStore]（与真实现共用同一套前缀/编码规则），
 * 所以这里测出来的行为对 `SharedPreferences` 实现同样成立。
 */
class TimetableRepositoryTimeSchemeTest {

    // ───────────────────── create ─────────────────────

    @Test
    fun `新建模板默认沿用当前生效模板的节次并落盘`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)
        val created = repo.createTimeScheme("  夏季作息  ")

        assertEquals("夏季作息", created.name)
        assertEquals(SECTIONS_6, created.sections)
        assertTrue(created.id.isNotBlank())
        assertEquals(3, repo.snapshot.timeSchemes.size)
        assertEquals("夏季作息", store.loadTimeSchemes().schemes.last().name)
    }

    @Test
    fun `没有生效模板时新建沿用全局设置节次`() {
        val store = seedStore(activeSchemeId = null, schemes = emptyList())
        val repo = TimetableRepository(store)
        val created = repo.createTimeScheme("秋季")
        assertEquals(TimetableSettings.defaults().sections, created.sections)
    }

    @Test
    fun `新建并直接套到当前课表`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)
        val sections = listOf(SectionTime("09:00", "09:45"), SectionTime("09:55", "10:40"))
        val created = repo.createTimeScheme("新课表作息", sections = sections, applyToActiveProfile = true)

        assertEquals(created.id, repo.snapshot.activeTimeSchemeId)
        assertEquals(sections, repo.snapshot.settings.sections)
        assertEquals("09:00", repo.snapshot.courses.first().startTime)
        assertEquals("10:40", repo.snapshot.courses.first().endTime)
    }

    // ───────────────────── rename ─────────────────────

    @Test
    fun `改名成功落盘找不到返回 null`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)

        val renamed = repo.renameTimeScheme("s1", "  夏季新作息 ")
        assertEquals("夏季新作息", renamed!!.name)
        assertEquals("夏季新作息", store.loadTimeSchemes().schemes.first { it.id == "s1" }.name)

        val notifications = mutableListOf<Int>()
        repo.observe { notifications.add(1) }
        assertNull(repo.renameTimeScheme("nope", "随便"))
        assertEquals(0, notifications.size)
    }

    // ───────────────────── duplicate ─────────────────────

    @Test
    fun `复制默认名用 Dart 的副本后缀`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)

        val duplicated = repo.duplicateTimeScheme("s1")!!
        assertEquals("夏季作息 副本", duplicated.name)
        assertEquals(SECTIONS_6, duplicated.sections)
        assertNotEquals("s1", duplicated.id)
        assertEquals(3, store.loadTimeSchemes().schemes.size)

        val named = repo.duplicateTimeScheme("s1", "自定义副本")!!
        assertEquals("自定义副本", named.name)

        assertNull(repo.duplicateTimeScheme("nope"))
    }

    // ───────────────────── update ─────────────────────

    @Test
    fun `改节次同时更新设置与课程钟点`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)

        val newSections = listOf(
            SectionTime("08:10", "08:55"),
            SectionTime("09:05", "09:50"),
            SectionTime("10:00", "10:45"),
        )
        assertNull(repo.updateTimeScheme("s1", "夏季作息", newSections))

        val updated = repo.snapshot.timeSchemes.first { it.id == "s1" }
        assertEquals(newSections, updated.sections)
        assertEquals(newSections, repo.snapshot.settings.sections)
        assertEquals("08:10", repo.snapshot.courses.first().startTime)
        assertEquals("09:50", repo.snapshot.courses.first().endTime)
        assertEquals(newSections, store.loadTimeSchemes().schemes.first { it.id == "s1" }.sections)
    }

    @Test
    fun `非法节次表被拒且什么都不改`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)
        val notifications = mutableListOf<Int>()
        repo.observe { notifications.add(1) }

        val code = repo.updateTimeScheme("s1", "夏季作息", listOf(SectionTime("10:00", "09:00")))
        assertEquals("section_end_must_after_start|sectionNumber=1", code)
        assertEquals(SECTIONS_6, repo.snapshot.timeSchemes.first { it.id == "s1" }.sections)
        assertEquals(0, notifications.size)

        assertEquals("at_least_one_section_required", repo.updateTimeScheme("s1", "夏季作息", emptyList()))
    }

    @Test
    fun `收窄到不够课时时拒绝并指出占用课程`() {
        val store = seedStore(activeSchemeId = "s1", courseEndSection = 5)
        val repo = TimetableRepository(store)

        val code = repo.updateTimeScheme("s1", "夏季作息", SECTIONS_6.take(3))!!
        assertTrue("实际返回：$code", code.startsWith("section_count_below_usage_detail|"))
        assertTrue(code.contains("requiredMaxSection=5"))
        assertTrue(code.contains("courseName=高数"))
        assertTrue(code.contains("profileName=三年级"))
        assertTrue(code.contains("usageType=usage_type_profile"))
        // 被拒时盘上仍是原来那 6 节。
        assertEquals(SECTIONS_6, store.loadTimeSchemes().schemes.first { it.id == "s1" }.sections)
    }

    @Test
    fun `改不存在的模板返回 not found`() {
        val repo = TimetableRepository(seedStore(activeSchemeId = "s1"))
        assertEquals("time_scheme_not_found", repo.updateTimeScheme("nope", "X", SECTIONS_6))
    }

    // ───────────────────── apply ─────────────────────

    @Test
    fun `套用模板改设置与课程钟点`() {
        val store = seedStore(activeSchemeId = null, courseEndSection = 2)
        val repo = TimetableRepository(store)

        assertNull(repo.applyTimeScheme("s1"))
        assertEquals("s1", repo.snapshot.activeTimeSchemeId)
        assertEquals(SECTIONS_6, repo.snapshot.settings.sections)
        assertEquals("08:00", repo.snapshot.courses.first().startTime)
        assertEquals("09:40", repo.snapshot.courses.first().endTime)
        assertEquals(SECTIONS_6, store.loadSettings().sections)
    }

    @Test
    fun `套用节次不足的模板被拒`() {
        val store = seedStore(activeSchemeId = null, courseEndSection = 8)
        val repo = TimetableRepository(store)
        val code = repo.applyTimeScheme("s1")!!
        assertTrue("实际返回：$code", code.startsWith("section_count_below_usage|"))
        assertTrue(code.contains("requiredMaxSection=8"))
        assertNull(repo.snapshot.activeTimeSchemeId)
    }

    @Test
    fun `套用不存在的模板返回 not found`() {
        val repo = TimetableRepository(seedStore(activeSchemeId = "s1"))
        assertEquals("time_scheme_not_found", repo.applyTimeScheme("nope"))
    }

    // ───────────────────── delete ─────────────────────

    @Test
    fun `被课表引用时拒绝删除且不落盘不通知`() {
        val store = seedStore(activeSchemeId = "s1")
        val repo = TimetableRepository(store)
        val notifications = mutableListOf<Int>()
        repo.observe { notifications.add(1) }

        assertFalse(repo.deleteTimeScheme("s1"))
        assertEquals(0, notifications.size)
        assertEquals(2, store.loadTimeSchemes().schemes.size)
        assertTrue(repo.snapshot.timeSchemes.any { it.id == "s1" })
    }

    @Test
    fun `被地点分组绑定时也拒绝删除`() {
        val store = seedStore(activeSchemeId = null, schemes = listOf(scheme("s1"), scheme("s2")))
        store.saveLocationTimeGroups(
            listOf(
                LocationTimeGroup(
                    id = "g1",
                    name = "教学楼",
                    timeSchemeId = "s1",
                    enabled = false,
                    keywords = listOf(LocationKeyword("教学楼")),
                ),
            ),
        )
        val repo = TimetableRepository(store)
        assertFalse(repo.deleteTimeScheme("s1"))
        // 没有绑定的那套可以删。
        assertTrue(repo.deleteTimeScheme("s2"))
        assertEquals(listOf("s1"), store.loadTimeSchemes().schemes.map { it.id })
    }

    @Test
    fun `被日期规则绑定时拒绝删除`() {
        val store = seedStore(activeSchemeId = null)
        store.saveScheduleDateRules(
            listOf(
                ScheduleDateRule(
                    id = "d1",
                    name = "期中周",
                    timeSchemeId = "s1",
                    startDate = "2026-10-01",
                    endDate = "2026-10-31",
                ),
            ),
        )
        val repo = TimetableRepository(store)
        assertFalse(repo.deleteTimeScheme("s1"))
    }

    @Test
    fun `没人用时删除成功并落盘`() {
        val store = seedStore(activeSchemeId = null)
        val repo = TimetableRepository(store)
        assertTrue(repo.deleteTimeScheme("s1"))
        assertTrue(repo.snapshot.timeSchemes.none { it.id == "s1" })
        assertEquals(listOf("s2"), store.loadTimeSchemes().schemes.map { it.id })
        // 不存在的再删一次返回 false（不是抛错）。
        assertFalse(repo.deleteTimeScheme("s1"))
    }

    // ───────────────────── 地点分组存储 ─────────────────────

    @Test
    fun `地点分组能存能读并进快照`() {
        val store = seedStore(activeSchemeId = "s1")
        val group = LocationTimeGroup(
            id = "g1",
            name = "教学楼",
            timeSchemeId = "s1",
            keywords = listOf(LocationKeyword("教学楼")),
        )
        store.saveLocationTimeGroups(listOf(group))
        assertEquals("location_time_groups", TimetableStore.KEY_LOCATION_TIME_GROUPS)

        // 存储层自己也能读回来（键名与 Dart `storage_service.dart:25` 同名）。
        assertEquals(listOf(group), store.loadLocationTimeGroups())

        val repo = TimetableRepository(store)
        assertEquals(listOf(group), repo.snapshot.locationTimeGroups)
    }

    @Test
    fun `损坏的地点分组留档且不炸整份`() {
        val kv = InMemoryKeyValueStore()
        kv.putString(TimetableStore.KEY_LOCATION_TIME_GROUPS, "not-json")
        val store = TimetableStore(kv) { 1_700_000_000_000_000L }
        assertTrue(store.loadLocationTimeGroups().isEmpty())
        assertTrue(
            kv.keys().any { it.startsWith("${TimetableStore.KEY_LOCATION_TIME_GROUPS}_corrupt_backup_") },
        )
        assertFalse(kv.contains(TimetableStore.KEY_LOCATION_TIME_GROUPS))
    }

    // ───────────────────── 测试夹具 ─────────────────────

    private fun seedStore(
        activeSchemeId: String?,
        schemes: List<TimeScheme> = listOf(scheme("s1"), scheme("s2")),
        courseEndSection: Int = 2,
    ): TimetableStore {
        val store = TimetableStore(InMemoryKeyValueStore())
        val settings = TimetableSettings.defaults().copy(activeTimeSchemeId = activeSchemeId)
        val profile = TimetableProfile(
            id = "p1",
            name = "三年级",
            courses = listOf(
                Course(
                    id = "c1",
                    name = "高数",
                    teacher = "",
                    location = "",
                    dayOfWeek = 1,
                    startSection = 1,
                    endSection = courseEndSection,
                    startTime = "00:00",
                    endTime = "00:00",
                ),
            ),
            settings = settings,
            currentWeek = 1,
            createdAt = LocalDateTime.of(2026, 10, 26, 8, 0),
            lastUsedAt = LocalDateTime.of(2026, 10, 26, 8, 0),
        )
        store.saveProfiles(listOf(profile))
        store.saveActiveProfileId("p1")
        store.saveSettings(settings)
        store.saveTimeSchemes(schemes)
        return store
    }

    private fun scheme(id: String, sections: List<SectionTime> = SECTIONS_6): TimeScheme {
        val now = LocalDateTime.of(2026, 10, 26, 8, 0)
        return TimeScheme(id = id, name = if (id == "s1") "夏季作息" else "冬季作息", sections = sections, createdAt = now, updatedAt = now)
    }

    private companion object {
        /** 六节，够覆盖 `courseEndSection = 5` 那条边界测试。 */
        val SECTIONS_6 = listOf(
            SectionTime("08:00", "08:45"),
            SectionTime("08:55", "09:40"),
            SectionTime("10:00", "10:45"),
            SectionTime("10:55", "11:40"),
            SectionTime("14:00", "14:45"),
            SectionTime("14:55", "15:40"),
        )
    }
}
