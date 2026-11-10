package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.app.IMPORT_TIME_SCHEME_SUPPLEMENT_SUFFIX
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimeSchemeImportUpdate
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 教务导入扩节的契约：**不能串改其他课表共用的时间模板**。
 *
 * 放在 `pages/time_scheme` 而不是导入域：被测对象是仓储的模板写入口，
 * 与 [TimetableRepositoryTimeSchemeTest] 同域；导入域那边同模块还有别的泳道在改
 * 守卫测试，混跑会把别人的半成品红算到这条契约头上。
 *
 * 期望不是从实现里读出来的，而是发布版语义（人对读 `v2.1.4.1` 得出）：
 * - `import_export_service.dart:268-331`：模板被引用超过 1 次时，复制一份
 *   `<原名>（导入补齐）`、只把当前课表改绑到副本，其他课表连节次带课程钟点都不动；
 * - `time_scheme_repository.dart:206-221`：手工改模板才把节次镜像给所有引用者
 *   （所以本文件同时钉「只有当前课表在用 ⇒ 原地改」，防止把通用语义也改了）；
 * - `import_time_scheme_restore_point.dart:100-123`：导入失败时删掉带后缀的副本，
 *   靠的是「先恢复设置、副本无引用后再删」的顺序（本文件第三条钉这个回滚配方）。
 */
class TimetableRepositoryImportTimeSchemeTest {

    private val twoSections = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("08:55", "09:40"),
    )
    private val threeSections = twoSections + SectionTime("10:00", "10:45")

    @Test
    fun `共享模板被导入扩节时 只改当前课表 其他课表原样`() {
        val raw = InMemoryKeyValueStore()
        seedTwoProfilesSharing(raw)

        val repository = TimetableRepository(TimetableStore(raw))
        val otherBefore = repository.snapshot.profiles.first { it.id == "p2" }

        val update = repository.updateTimeSchemeForImport("ts-1", "两节作息", threeSections)

        assertTrue("共享模板必须走复制分支", update is TimeSchemeImportUpdate.Applied)
        val createdId = (update as TimeSchemeImportUpdate.Applied).createdSchemeId
        assertNotNull("共享模板必须复制副本，而不是原地改", createdId)

        val snap = repository.snapshot
        // 当前课表：改绑副本、节次变 3 节（课程钟点按新模板重算）。
        val active = snap.profiles.first { it.id == "p1" }
        assertEquals(createdId, active.settings.activeTimeSchemeId)
        assertEquals(threeSections, active.settings.sections)
        // 其他课表：模板引用、节次、课程钟点一字不动。
        val other = snap.profiles.first { it.id == "p2" }
        assertEquals("ts-1", other.settings.activeTimeSchemeId)
        assertEquals(twoSections, other.settings.sections)
        assertEquals(otherBefore.settings, other.settings)
        assertEquals(otherBefore.courses, other.courses)
        // 原模板不动；副本带「（导入补齐）」后缀、节次 = 本次扩节结果。
        assertEquals(twoSections, snap.timeSchemes.first { it.id == "ts-1" }.sections)
        val created = snap.timeSchemes.single { it.id == createdId }
        assertTrue(
            "副本名字必须带发布版同款后缀，恢复点/清理判据认它",
            created.name.endsWith(IMPORT_TIME_SCHEME_SUPPLEMENT_SUFFIX),
        )
        assertEquals(threeSections, created.sections)
        assertEquals(2, snap.timeSchemes.size)

        // 真落盘：杀进程重开（同一份盘、新实例）结论不变。
        val reopened = TimetableRepository(TimetableStore(raw))
        val reopenedSnap = reopened.snapshot
        assertEquals(2, reopenedSnap.timeSchemes.size)
        assertEquals(twoSections, reopenedSnap.timeSchemes.first { it.id == "ts-1" }.sections)
        assertEquals(
            createdId,
            reopenedSnap.profiles.first { it.id == "p1" }.settings.activeTimeSchemeId,
        )
        val reopenedOther = reopenedSnap.profiles.first { it.id == "p2" }
        assertEquals("ts-1", reopenedOther.settings.activeTimeSchemeId)
        assertEquals(twoSections, reopenedOther.settings.sections)
        assertEquals(otherBefore.courses, reopenedOther.courses)
    }

    @Test
    fun `模板只有当前课表使用时 导入扩节原地改 不复制`() {
        val raw = InMemoryKeyValueStore()
        val store = TimetableStore(raw)
        val settings = TimetableSettings(
            sections = twoSections,
            activeTimeSchemeId = "ts-1",
        )
        store.saveTimeSchemes(listOf(scheme("ts-1", "两节作息", twoSections)))
        store.saveProfiles(
            listOf(
                profile("p1", "课表一", settings, listOf(course("c1", "数学"))),
                // p2 不使用任何模板：它不该被这条导入路径碰到。
                profile(
                    "p2",
                    "课表二",
                    TimetableSettings(sections = twoSections),
                    listOf(course("c2", "体育")),
                ),
            ),
        )
        store.saveActiveProfileId("p1")
        store.saveSettings(settings)
        val repository = TimetableRepository(TimetableStore(raw))
        val otherBefore = repository.snapshot.profiles.first { it.id == "p2" }

        val update = repository.updateTimeSchemeForImport("ts-1", "两节作息", threeSections)

        assertTrue(update is TimeSchemeImportUpdate.Applied)
        assertNull(
            "只有当前课表在用 ⇒ 与手工改模板同径，不复制",
            (update as TimeSchemeImportUpdate.Applied).createdSchemeId,
        )
        val snap = repository.snapshot
        assertEquals(1, snap.timeSchemes.size)
        val sole = snap.timeSchemes.single()
        assertEquals("ts-1", sole.id)
        assertEquals("两节作息", sole.name)
        assertEquals(threeSections, sole.sections)
        assertEquals(threeSections, snap.profiles.first { it.id == "p1" }.settings.sections)
        assertEquals("其他课表不许被碰", otherBefore, snap.profiles.first { it.id == "p2" })
    }

    @Test
    fun `导入失败回滚配方 先恢复设置再删副本 回到导入前`() {
        val raw = InMemoryKeyValueStore()
        seedTwoProfilesSharing(raw)
        val repository = TimetableRepository(TimetableStore(raw))
        val before = repository.snapshot

        val update = repository.updateTimeSchemeForImport("ts-1", "两节作息", threeSections)
        val createdId = (update as TimeSchemeImportUpdate.Applied).createdSchemeId
        assertNotNull(createdId)

        // 与 WarehouseCoursesImportApply 的 catch 同序：先恢复设置（活动档改回原模板），
        // 副本此时已无引用，deleteTimeScheme 的 in-use 守卫才会放行。
        repository.updateSettings(before.settings)
        assertTrue("副本已无引用，必须可删", repository.deleteTimeScheme(createdId!!))

        val snap = repository.snapshot
        assertEquals(1, snap.timeSchemes.size)
        assertEquals(twoSections, snap.timeSchemes.single().sections)
        val active = snap.profiles.first { it.id == "p1" }
        assertEquals("ts-1", active.settings.activeTimeSchemeId)
        assertEquals(twoSections, active.settings.sections)
        // 盘上也干净：重开不会冒出孤儿副本。
        assertEquals(1, TimetableRepository(TimetableStore(raw)).snapshot.timeSchemes.size)
    }

    @Test
    fun `不存在的模板返回拒绝码而不是抛错`() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        val update = repository.updateTimeSchemeForImport("nope", "任意", threeSections)

        assertTrue(update is TimeSchemeImportUpdate.Rejected)
        assertEquals("time_scheme_not_found", (update as TimeSchemeImportUpdate.Rejected).serviceMessage)
    }

    // ---------- 夹具 ----------

    /** 两个课表共用 ts-1：p1 是当前档，p2 是「别的课表」。 */
    private fun seedTwoProfilesSharing(raw: InMemoryKeyValueStore) {
        val settings = TimetableSettings(
            sections = twoSections,
            activeTimeSchemeId = "ts-1",
        )
        val store = TimetableStore(raw)
        store.saveTimeSchemes(listOf(scheme("ts-1", "两节作息", twoSections)))
        store.saveProfiles(
            listOf(
                profile("p1", "课表一", settings, listOf(course("c1", "数学"))),
                profile("p2", "课表二", settings, listOf(course("c2", "体育"))),
            ),
        )
        store.saveActiveProfileId("p1")
        // saveSettings 会同时镜像进活动档内嵌 settings（TimetableStore.saveSettingsPatch），
        // 所以必须在 saveActiveProfileId 之后调用。
        store.saveSettings(settings)
    }

    private fun scheme(id: String, name: String, sections: List<SectionTime>) = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun profile(
        id: String,
        name: String,
        settings: TimetableSettings,
        courses: List<Course>,
    ) = TimetableProfile(
        id = id,
        name = name,
        courses = courses,
        settings = settings,
        currentWeek = 3L,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        lastUsedAt = LocalDateTime.of(2026, 9, 2, 8, 0),
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
}
