package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
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
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * R12「局域网两个残余」的**契约测试**（2026-11-03 随修复合入；2026-11-11 补回）。
 *
 * 缺口①：设置原先只写回 Kotlin 已移植的时间/周次五键，包里其余 200+ 个字段被
 * 静默丢掉。现在按**原始文档**合并写回（含活动档案镜像），并保留设备级信任锚。
 * 断言直接落在盘上的 JSON 与仓储视图，不看「页面能不能渲染」。
 *
 * 缺口②：地点分组变化后不重算课程钟点。Dart 侧 `replaceLocationTimeGroups(resync: true)`
 * 的重算结果必须原样出现，且覆盖 / 合并两条应用路径都要走。
 *
 * ## 为什么这份文件 2026-11-11 又出现一次
 *
 * 737a69909 随修复一起加过同名文件，但 11-03→11-08 之间被一次合并整份吞掉
 * （HEAD 树里没有它，也没有一条「删除」提交可追）——缺口② 的**合并分支**与
 * **未命中分组**两条用例就此失去覆盖，只剩 `LanUndoExactnessTest` 里那条
 * 「撤销前 precondition」。这里按当前构造器（`settingsStore` 改为显式注入，
 * 见 ac515c15b）重新落一份，断言口径与原来逐条一致。
 */
class LanTransferResidualsTest {

    // -----------------------------------------------------------------------
    // 缺口①：设置整份文档
    // -----------------------------------------------------------------------

    @Test
    fun `设置未知键真的落到盘上 活动档案镜像也写到了`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(
            store,
            settingsPatch = mapOf(
                "localOnlyKey" to "keep-me",
                "appUpdateMirrorPreset" to "official",
                "appUpdateMirrorUrlPrefix" to "https://local.example/",
            ),
        )
        val host = hostOn(repository)
        val incomingSettings = settingsDocument(
            "semesterWeekCount" to 18,
            "localOnlyKey" to "incoming",
            "dartOnlyKey" to true,
            "appUpdateMirrorPreset" to "attacker",
            "appUpdateMirrorUrlPrefix" to "https://evil.example/",
        )

        val applied = host.applyTransferJson(
            packageJson(settingsDocument = incomingSettings),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])

        val top = settingsOnDisk(store)
        assertEquals("未移植字段也要写回", true, top["dartOnlyKey"])
        assertEquals("普通设置键按外来值覆盖", "incoming", top["localOnlyKey"])
        assertEquals("周次按外来值覆盖", 18L, (top["semesterWeekCount"] as Number).toLong())
        assertEquals("更新镜像保留本机值", "official", top["appUpdateMirrorPreset"])
        assertEquals(
            "更新镜像主机保留本机值",
            "https://local.example/",
            top["appUpdateMirrorUrlPrefix"],
        )
        assertEquals("仓储视图的已移植子集也要更新", 18, repository.snapshot.settings.semesterWeekCount)

        val profileSettings = activeProfileSettingsOnDisk(store)
        assertEquals("桌面小组件读的档案镜像也要带上未移植字段", true, profileSettings["dartOnlyKey"])
        assertEquals("档案镜像同样保留本机更新镜像", "official", profileSettings["appUpdateMirrorPreset"])
    }

    @Test
    fun `设置差异按原始文档比 未移植字段变化也报出来`() {
        val current = LanTransferDiffSource(
            settings = TimetableSettings.defaults(),
            settingsJson = settingsDocument("dartOnlyKey" to "a"),
        )
        val changed = LanTransferDiffSource(
            settings = TimetableSettings.defaults(),
            settingsJson = settingsDocument("dartOnlyKey" to "b"),
        )
        val same = LanTransferDiffSource(
            settings = TimetableSettings.defaults(),
            settingsJson = settingsDocument("dartOnlyKey" to "a"),
        )

        val diff = LanTransferLogic.compare(
            current,
            changed,
            TransferScope.CURRENT_TIMETABLE,
            TransferApplyMode.MERGE,
        )
        assertEquals(1, diff.forKind(LanTransferKind.SETTINGS).updatedCount)

        val noChange = LanTransferLogic.compare(
            current,
            same,
            TransferScope.CURRENT_TIMETABLE,
            TransferApplyMode.MERGE,
        )
        assertEquals(0, noChange.forKind(LanTransferKind.SETTINGS).totalCount)
    }

    @Test
    fun `信任锚的差异不报变更 因为应用时会保留本机值`() {
        val current = LanTransferDiffSource(
            settings = TimetableSettings.defaults(),
            settingsJson = settingsDocument("appUpdateMirrorPreset" to "official"),
        )
        val incoming = LanTransferDiffSource(
            settings = TimetableSettings.defaults(),
            settingsJson = settingsDocument("appUpdateMirrorPreset" to "attacker"),
        )

        val diff = LanTransferLogic.compare(
            current,
            incoming,
            TransferScope.CURRENT_TIMETABLE,
            TransferApplyMode.MERGE,
        )
        assertEquals(
            "预览不许承诺一个应用时会被拒绝的变更",
            0,
            diff.forKind(LanTransferKind.SETTINGS).totalCount,
        )
    }

    @Test
    fun `撤销把整份设置文档原样退回 未移植字段一起消失`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val beforeSettings = settingsOnDisk(store)
        val host = hostOn(repository)

        val applied = host.applyTransferJson(
            packageJson(
                settingsDocument = settingsDocument(
                    "semesterWeekCount" to 18,
                    "dartOnlyKey" to "imported",
                ),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        assertEquals("imported", settingsOnDisk(store)["dartOnlyKey"])

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals(true, undone["undo"])

        assertEquals("顶层设置文档要回到导入前一模一样", beforeSettings, settingsOnDisk(store))
        assertNull("导入写进去的未移植键必须被删掉", settingsOnDisk(store)["dartOnlyKey"])
        assertFalse(
            "档案镜像里也不许留下导入写进去的键",
            activeProfileSettingsOnDisk(store).containsKey("dartOnlyKey"),
        )
    }

    @Test
    fun `后续步骤写盘失败时 设置文档也整份补偿回去`() {
        val backing = InMemoryKeyValueStore()
        val failing = FailingKeyValueStore(backing, failOnKeyContaining = "location_time_groups")
        val repository = repositoryOn(failing)
        // 本地已有同签名模板：导入走「复用」不写 time_schemes，补偿要断言的
        // 就只剩设置（整份快照还会被 lastUsedAt 这种时间戳干扰）。
        repository.createTimeScheme("A楼作息", sectionsB)
        val beforeTop = settingsOnDisk(backing)
        val beforeProfile = activeProfileSettingsOnDisk(backing)
        val host = hostOn(repository)

        failing.enabled = true
        val applied = host.applyTransferJson(
            packageJson(
                settingsDocument = settingsDocument("dartOnlyKey" to "imported"),
                groups = listOf(group("g1", "A楼", "s_remote", "A楼")),
                timeSchemes = listOf(scheme("s_remote", "A楼作息", sectionsB)),
            ),
            TransferApplyMode.MERGE,
        )
        failing.enabled = false

        assertEquals(false, applied["applied"])
        assertEquals("transfer_import_failed", applied["error"])
        assertEquals("顶层设置文档必须整份回到导入前", beforeTop, settingsOnDisk(backing))
        assertEquals(
            "活动档案镜像也必须整份回到导入前",
            beforeProfile,
            activeProfileSettingsOnDisk(backing),
        )
        assertNull(
            "回滚后内存里也不该留着导入写的未移植键（合并写删键 = 写 null）",
            repository.settingsJson()["dartOnlyKey"],
        )
    }

    // -----------------------------------------------------------------------
    // 缺口②：地点分组变化后重算钟点
    // -----------------------------------------------------------------------

    @Test
    fun `合并导入换地点分组后 课程钟点按新分组重算`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(
            course("c1", "高等数学", location = "A楼101", start = "08:00", end = "09:40"),
        )
        val host = hostOn(repository)

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(
                    course("c1", "高等数学", location = "A楼101", start = "08:00", end = "09:40"),
                ),
                timeSchemes = listOf(scheme("s_b", "A楼作息", sectionsB)),
                groups = listOf(group("g1", "A楼", "s_b", "A楼")),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])

        val course = repository.getCourseById("c1")
        assertNotNull(course)
        assertEquals("1~2 节要按 A楼作息重算开始时间", "09:00", course!!.startTime)
        assertEquals("1~2 节要按 A楼作息重算结束时间", "10:40", course.endTime)

        val raw = store.rawSnapshot().values.joinToString("\n")
        assertTrue("盘上的课程也要是新钟点", raw.contains("\"startTime\":\"09:00\""))
        assertTrue("盘上的课程也要是新钟点", raw.contains("\"endTime\":\"10:40\""))
    }

    @Test
    fun `覆盖导入换地点分组后同样重算钟点`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = hostOn(repository)

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(
                    course("c9", "外来课", location = "B楼201", start = "08:00", end = "09:40"),
                ),
                timeSchemes = listOf(scheme("s_c", "B楼作息", sectionsB)),
                groups = listOf(group("g2", "B楼", "s_c", "B楼")),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])

        val course = repository.getCourseById("c9")
        assertNotNull(course)
        assertEquals("09:00", course!!.startTime)
        assertEquals("10:40", course.endTime)
    }

    @Test
    fun `课程没有命中地点分组时 钟点保持原样`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(
            course("c1", "高等数学", location = "C楼301", start = "08:00", end = "09:40"),
        )
        val host = hostOn(repository)

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(
                    course("c1", "高等数学", location = "C楼301", start = "08:00", end = "09:40"),
                ),
                timeSchemes = listOf(scheme("s_b", "A楼作息", sectionsB)),
                groups = listOf(group("g1", "A楼", "s_b", "A楼")),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        assertEquals("08:00", repository.getCourseById("c1")!!.startTime)
        assertEquals("09:40", repository.getCourseById("c1")!!.endTime)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    /** 局域网宿主：设置读写缝显式注入（生产同款，见 `pages/transfer/LanEditHost.start`）。 */
    private fun hostOn(repository: TimetableRepository): LanEditRepositoryHost =
        LanEditRepositoryHost(
            repository,
            settingsStore = TimetableStoreLanSettings(repository),
        )

    private class FailingKeyValueStore(
        private val delegate: KeyValueStore,
        private val failOnKeyContaining: String,
    ) : KeyValueStore by delegate {

        var enabled: Boolean = false

        override fun putString(key: String, value: String) {
            if (enabled && key.contains(failOnKeyContaining)) {
                throw IllegalStateException("store_write_failed:$key")
            }
            delegate.putString(key, value)
        }
    }

    private fun repositoryOn(
        store: KeyValueStore,
        settingsPatch: Map<String, Any?> = emptyMap(),
    ): TimetableRepository {
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    currentWeek = 7,
                    createdAt = stamp,
                    lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveSettingsPatch(settingsPatch)
        timetableStore.saveSettingsPatchToActiveProfile(settingsPatch)
        timetableStore.saveCurrentWeek(7)
        return TimetableRepository(timetableStore)
    }

    private fun packageJson(
        courses: List<Course> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
        groups: List<LocationTimeGroup> = emptyList(),
        settingsDocument: Map<String, Any?>? = TimetableSettings.defaults().toJson(),
        currentWeek: Int? = 7,
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-r12",
            scope = TransferScope.CURRENT_TIMETABLE,
            exportedAtIso = "2026-11-03T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = currentWeek,
            settingsJson = settingsDocument,
            coursesJson = courses.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
            locationTimeGroupsJson = groups.map { it.toJsonMap() },
        ),
    )

    /** 一份带未移植字段的设置文档（五键先铺默认值，再叠加场景键）。 */
    private fun settingsDocument(vararg entries: Pair<String, Any?>): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>(TimetableSettings.defaults().toJson())
        for ((key, value) in entries) out[key] = value
        return out
    }

    /**
     * 盘上设置文档按 Dart `toJson` 口径读：**null 值键 = 缺键**（合并写为了能删键
     * 会把旧键写成显式 null；Dart 侧 toJson 对 null 是省略，两者读侧等价）。
     */
    @Suppress("UNCHECKED_CAST")
    private fun settingsOnDisk(store: InMemoryKeyValueStore): Map<String, Any?> {
        val raw = store.rawSnapshot()["flutter.${TimetableStore.KEY_SETTINGS}"]
        assertNotNull("盘上必须有 timetable_settings", raw)
        return withoutNulls(MiniJson.tryParse(raw!!) as Map<String, Any?>)
    }

    @Suppress("UNCHECKED_CAST")
    private fun activeProfileSettingsOnDisk(store: InMemoryKeyValueStore): Map<String, Any?> {
        val raw = store.rawSnapshot()["flutter.${TimetableStore.KEY_PROFILES}"]
        assertNotNull("盘上必须有 timetable_profiles", raw)
        val profiles = MiniJson.tryParse(raw!!) as List<*>
        val active = profiles.first { (it as Map<*, *>)["id"] == "p1" } as Map<*, *>
        return withoutNulls(active["settings"] as Map<String, Any?>)
    }

    private fun withoutNulls(map: Map<String, Any?>): Map<String, Any?> =
        map.filterValues { it != null }

    private fun course(
        id: String,
        name: String,
        location: String,
        start: String,
        end: String,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = start,
        endTime = end,
    )

    private fun group(id: String, name: String, schemeId: String, keyword: String): LocationTimeGroup =
        LocationTimeGroup(
            id = id,
            name = name,
            timeSchemeId = schemeId,
            keywords = listOf(LocationKeyword(keyword)),
        )

    private fun scheme(id: String, name: String, sections: List<SectionTime>): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private companion object {
        val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 3, 9, 0)

        val sectionsB: List<SectionTime> = listOf(
            SectionTime("09:00", "09:45"),
            SectionTime("09:55", "10:40"),
            SectionTime("10:50", "11:35"),
            SectionTime("11:45", "12:30"),
        )
    }
}
