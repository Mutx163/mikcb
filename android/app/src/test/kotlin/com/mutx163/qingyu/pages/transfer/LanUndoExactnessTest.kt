package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson
import com.mutx163.qingyu.transfer.lan.LanEditRepositoryHost
import com.mutx163.qingyu.transfer.lan.LanTransferUndoStore
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 局域网撤销 / 补偿的**精确原态**与**全档对称**（2026-11-06 第五轮返工）。
 *
 * 三个此前会被门禁逐字节 diff 抓到的洞：
 * 1. 「导入前不存在的集合 key」被还原成 `[]`（多出键）——现在按存在性：不存在就删 key；
 * 2. 还原路径改写 `lastUsedAt`（`setCurrentWeek` → `persistActiveProfileState` 会 touch）——
 *    现在走 `restoreCurrentWeek`，回滚不是「使用」；
 * 3. `resync=true` 改**所有档**钟点、快照只抓活动档 ⇒ 非活动档半还原——现在按需扩到
 *    所有档案的课程（`LanTransferState.profileCourses`），撤销对称还原。
 *
 * 放在 `pages/transfer`（L0 够得到：`transfer` / `app` / `sync` 都是共享模型层），
 * 用真仓储 + `LanEditRepositoryHost` 走真实 apply/undo；LAN 域那两个测试文件仍留在 L2。
 */
class LanUndoExactnessTest {

    private val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 2, 9, 0)
    private val sectionsA = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40"))
    private val sectionsC = listOf(SectionTime("10:00", "10:45"), SectionTime("10:55", "11:40"))

    private fun scheme(id: String, name: String, sections: List<SectionTime>) = TimeScheme(
        id = id, name = name, sections = sections, createdAt = stamp, updatedAt = stamp,
    )

    private fun course(
        id: String,
        name: String,
        startTime: String = "00:00",
        endTime: String = "00:45",
    ) = Course(
        id = id, name = name, teacher = "", location = "",
        dayOfWeek = 1, startSection = 1, endSection = 2,
        startTime = startTime, endTime = endTime,
    )

    private fun packageJson(
        courses: List<Course> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
        rules: List<ScheduleDateRule> = emptyList(),
        groups: List<LocationTimeGroup> = emptyList(),
        currentWeek: Int = 1,
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-test-exact",
            scope = TransferScope.CURRENT_TIMETABLE,
            exportedAtIso = "2026-11-02T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = currentWeek,
            settingsJson = TimetableSettings.defaults().toJson(),
            coursesJson = courses.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
            scheduleDateRulesJson = rules.map { it.toJson() },
            locationTimeGroupsJson = groups.map { it.toJsonMap() },
        ),
    )

    /** 单档夹具（不含 schemes / rules / groups 三个可选 key）。 */
    private fun repositoryOn(store: InMemoryKeyValueStore): TimetableRepository {
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1", name = "默认课表", currentWeek = 1,
                    createdAt = stamp, lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(1)
        return TimetableRepository(timetableStore)
    }

    @Test
    fun `撤销后导入前不存在的集合键仍然不存在_且不改lastUsedAt`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        assertFalse("前提：导入前三块集合 key 都不存在", store.rawSnapshot().containsKey("flutter.location_time_groups"))
        assertFalse(
            "前提：导入前 schedule_date_rules key 也不存在",
            store.rawSnapshot().containsKey("flutter.schedule_date_rules"),
        )
        val lastUsedBefore = repository.snapshot.profiles.single().lastUsedAt
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(scheme("s9", "全新模板", sectionsC)),
                // 三块可选集合都要真的被导入写出来，否则「撤销后不存在」是空断言
                //（hy3 点名的 schedule_date_rules 缺口，2026-11-07 补）。
                rules = listOf(
                    ScheduleDateRule(
                        id = "r1",
                        name = "换课",
                        timeSchemeId = "s9",
                        startDate = "2026-11-03",
                        endDate = "2026-11-09",
                    ),
                ),
                groups = listOf(LocationTimeGroup(id = "g1", name = "新组", timeSchemeId = "s9")),
                // 包里当前周与导入前不同，好让撤销真的走 restoreCurrentWeek 那条路
                currentWeek = 7,
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals("应用必须成功：$applied", true, applied["applied"])
        assertTrue(
            "前提：导入确实写进了地点分组 key",
            store.rawSnapshot().containsKey("flutter.location_time_groups"),
        )
        assertTrue(
            "前提：导入确实写进了日程规则 key",
            store.rawSnapshot().containsKey("flutter.schedule_date_rules"),
        )
        // 应用本身会按包里的当前周调用 setCurrentWeek（那是合法「使用」，会刷新 lastUsedAt）；
        // 要钉的是**撤销路径**不额外改写它。
        val lastUsedAfterApply = repository.snapshot.profiles.single { it.id == "p1" }.lastUsedAt

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals("撤销必须成功：$undone", true, undone["undo"])

        assertFalse(
            "导入前不存在的地点分组 key，撤销后必须**删除**（不是写成 []）",
            store.rawSnapshot().containsKey("flutter.location_time_groups"),
        )
        assertFalse(
            "导入前不存在的日程规则 key，撤销后必须删除（不是写成 []）",
            store.rawSnapshot().containsKey("flutter.schedule_date_rules"),
        )
        assertFalse(
            "导入前不存在的时间模板 key，撤销后必须删除",
            store.rawSnapshot().containsKey("flutter.time_schemes"),
        )
        assertEquals("撤销要把当前周也还原", 1, repository.snapshot.currentWeek)
        assertEquals(
            "撤销不是「使用」：不许把 lastUsedAt 再改成撤销时刻",
            lastUsedAfterApply,
            repository.snapshot.profiles.single { it.id == "p1" }.lastUsedAt,
        )
        assertTrue("（对照）应用前的 lastUsedAt 是夹具时间", lastUsedBefore < lastUsedAfterApply || lastUsedBefore == lastUsedAfterApply)
    }

    @Test
    fun `撤销恢复非活动档被resync改掉的课程钟点`() {
        // 两档：p1 活动、p2 非活动；两档课程初始钟点都是占位值。
        val store = InMemoryKeyValueStore()
        val timetableStore = TimetableStore(store)
        val schemeA = scheme("s1", "本机作息", sectionsA)
        timetableStore.saveTimeSchemes(listOf(schemeA))
        val settings = TimetableSettings.defaults()
            .copy(activeTimeSchemeId = "s1", sections = sectionsA)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1", name = "活动档",
                    courses = listOf(course("c1", "活动档的课")),
                    settings = settings, currentWeek = 1, createdAt = stamp, lastUsedAt = stamp,
                ),
                TimetableProfile(
                    id = "p2", name = "非活动档",
                    courses = listOf(course("c2", "非活动档的课")),
                    settings = settings, currentWeek = 1, createdAt = stamp, lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(settings)
        timetableStore.saveCurrentWeek(1)
        val repository = TimetableRepository(timetableStore)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(scheme("s9", "新模板", sectionsC)),
                groups = listOf(LocationTimeGroup(id = "g1", name = "新组", timeSchemeId = "s9")),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])

        // 前提：resync 真的把**非活动档**的钟点也按本机作息重排了
        val p2After = repository.snapshot.profiles.single { it.id == "p2" }
        assertEquals(
            "resync 会把非活动档钟点也改掉（这是需要对称还原的原因）",
            sectionsA[0].startTime,
            p2After.courses.single().startTime,
        )

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals(true, undone["undo"])
        val p2Restored = repository.snapshot.profiles.single { it.id == "p2" }
        assertEquals(
            "撤销必须把非活动档的钟点还原成导入前",
            "00:00",
            p2Restored.courses.single().startTime,
        )
        assertEquals("00:45", p2Restored.courses.single().endTime)
    }

    @Test
    fun `撤销少撤一套时计数与skipped如实上报`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(scheme("s9", "全新模板", sectionsC)),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        val created = repository.snapshot.timeSchemes.single { it.name == "全新模板" }
        // 导入后用户加一门课绑到这套模板 → 撤销时它仍被引用、不能删
        repository.addCourse(course("c_user", "用户后加的课").copy(timeSchemeIdOverride = created.id))

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals(true, undone["undo"])
        assertTrue(
            "仍被引用的模板必须在 skipped 里如实出现",
            (undone["skipped"] as List<*>).any { it.toString().startsWith("time_scheme_delete_refused:") },
        )
        assertEquals(
            "skippedCount 要与 skipped 条数一致（网页端据此提示「其中 N 条未撤」）",
            (undone["skipped"] as List<*>).size,
            undone["skippedCount"],
        )
        val restored = undone["restored"] as Map<*, *>
        assertTrue(
            "少撤的模板不能算进 restored.time_schemes（否则 undone=true 却少数一套还不报）",
            (restored["time_schemes"] as? Int ?: 0) == 0,
        )
        assertNotNull("模板本身要还在", repository.snapshot.timeSchemes.firstOrNull { it.id == created.id })
    }

    @Test
    fun `可删模板全被拦下时跳过整表写回_不多写一次`() {
        // 第五轮返工·第 4 件：plan 里有「该删的模板」但全被引用校验拦下（deletable 为空）、
        // 又没有要写回的模板时，撤销不该顺手整份写一次模板表——那是还原路径里唯一一处
        // 纯多余的落盘（多一次全表替换 + 多一次监听通知），且内容一字不变。
        val backing = InMemoryKeyValueStore()
        val counting = CountingKeyValueStore(backing)
        val timetableStore = TimetableStore(counting)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1", name = "默认课表", currentWeek = 1,
                    createdAt = stamp, lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(1)
        val repository = TimetableRepository(timetableStore)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(scheme("s9", "全新模板", sectionsC)),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        val created = repository.snapshot.timeSchemes.single { it.name == "全新模板" }
        // 导入后用户把一门课绑到这套模板 ⇒ 撤销时删除被拒（deletable 为空）
        repository.addCourse(course("c_user", "用户后加的课").copy(timeSchemeIdOverride = created.id))

        val schemesBefore = repository.snapshot.timeSchemes
        counting.reset()
        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals("撤销必须成功：$undone", true, undone["undo"])

        assertEquals(
            "没有可删、也没有要写回的模板时，不许整表写回模板表（多写一次就是多余的落盘+通知）",
            0,
            counting.putCounts[TimetableStore.KEY_TIME_SCHEMES] ?: 0,
        )
        assertEquals(
            "同理不许删表",
            0,
            counting.removeCounts[TimetableStore.KEY_TIME_SCHEMES] ?: 0,
        )
        assertEquals("模板表内容也不许变", schemesBefore, repository.snapshot.timeSchemes)
    }

    /** 计数存储：只数「某个 key 被写 / 被删了几次」，用来钉「不多写一次」。 */
    private class CountingKeyValueStore(
        private val delegate: KeyValueStore,
    ) : KeyValueStore by delegate {
        val putCounts: MutableMap<String, Int> = mutableMapOf()
        val removeCounts: MutableMap<String, Int> = mutableMapOf()

        fun reset() {
            putCounts.clear()
            removeCounts.clear()
        }

        override fun putString(key: String, value: String) {
            putCounts[key] = (putCounts[key] ?: 0) + 1
            delegate.putString(key, value)
        }

        override fun remove(key: String) {
            removeCounts[key] = (removeCounts[key] ?: 0) + 1
            delegate.remove(key)
        }
    }
}
