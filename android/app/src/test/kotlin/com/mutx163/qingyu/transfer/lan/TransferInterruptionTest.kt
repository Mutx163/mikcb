package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.calendar.ScheduleDateRule
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.LanEditSession
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 传输域「进程被杀在中途」硬化（导入 / 导出 / 局域网收发各两条）。
 *
 * 手法沿用 sync 域：用 [KilledMidway]（`Error` 子类）模拟 SIGKILL。
 * `LanTransferApplier` 的回滚是 `catch (_: Exception)`，`Error` 不在其中——
 * 正好还原真掉电语义：**没有补偿、已经落盘的半套数据留在盘上**。
 * 断言同时看仓储视图与盘上原始字节，避免「返回值对了但盘上残了」。
 */
class TransferInterruptionTest {

    private val now = 1_760_000_000_000L
    private val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 2, 9, 0)

    // -----------------------------------------------------------------------
    // 导入：写盘中途被杀
    // -----------------------------------------------------------------------

    @Test
    fun `导入写到设置时被杀 模板与课程留在盘上且不回滚`() {
        val backing = InMemoryKeyValueStore()
        val repository = repositoryOn(backing)
        val settings = KillingSettingsStore(failOnWrite = true)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore(), settingsStore = settings)

        assertThrows(KilledMidway::class.java) {
            host.applyTransferJson(
                packageJson(
                    courses = listOf(course("c9", "外来课程")),
                    timeSchemes = listOf(scheme("ts1", "外来新建模板", sectionsThree())),
                    settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
                    currentWeek = 5,
                    rules = listOf(rule("r9", "外来规则")),
                ),
                TransferApplyMode.MERGE,
            )
        }

        // 导入写序：模板 → 内容 → 设置 → 当前周 → 规则。
        // 掐在「设置」这一步：前两步已落盘，后面三步还没轮到。
        assertTrue(
            "模板先写，必须留在盘上",
            repository.snapshot.timeSchemes.any { it.name == "外来新建模板" },
        )
        assertTrue("课程随后写，必须留在盘上", repository.snapshot.courses.any { it.id == "c9" })
        assertEquals("设置已先落核心存储", 18, repository.snapshot.settings.semesterWeekCount)
        assertEquals("当前周还没轮到", 7, repository.snapshot.currentWeek)
        assertTrue("日期规则还没轮到", repository.snapshot.scheduleDateRules.isEmpty())
        assertFalse("设置镜像这一步被杀，不许留半条镜像", settings.backing.containsKey("semesterWeekCount"))
    }

    @Test
    fun `导入写到最后一步日期规则时被杀 前面全部生效但撤销点没建`() {
        val backing = InMemoryKeyValueStore()
        val store = TimetableStore(KillingStore(backing, TimetableStore.KEY_SCHEDULE_DATE_RULES))
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        assertThrows(KilledMidway::class.java) {
            host.applyTransferJson(
                packageJson(
                    courses = listOf(course("c9", "外来课程")),
                    timeSchemes = listOf(scheme("ts1", "默认作息", sectionsThree())),
                    settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
                    currentWeek = 5,
                    rules = listOf(rule("r9", "外来规则")),
                ),
                TransferApplyMode.MERGE,
            )
        }

        assertEquals("内容已落盘", listOf("c9"), repository.courses.map { it.id })
        assertEquals(18, repository.snapshot.settings.semesterWeekCount)
        assertEquals(5, repository.snapshot.currentWeek)
        assertTrue("规则这一步被掐断，仓储视图仍是旧值", repository.snapshot.scheduleDateRules.isEmpty())
        assertFalse("盘上不许留半条规则", backing.rawSnapshot().values.any { it.contains("外来规则") })
        // 撤销点在建完规则之后才建；这一步被杀 → 客户端拿不到 transferId，
        // 下次启动后也没有可用的撤销点（真掉电后的已知代价，不是可修的回滚缺失）。
        assertEquals(false, host.undoTransferJson("transfer-killed-mid-rules")["undo"])
    }

    // -----------------------------------------------------------------------
    // 导出：读盘中途被杀
    // -----------------------------------------------------------------------

    @Test
    fun `导出读到设置时被杀 不产出半截包也不动盘`() {
        val backing = InMemoryKeyValueStore()
        val repository = repositoryOn(backing)
        val host = LanEditRepositoryHost(
            repository,
            LanTransferUndoStore(),
            settingsStore = KillingSettingsStore(failOnRead = true),
        )
        val before = backing.rawSnapshot()

        assertThrows(KilledMidway::class.java) { host.exportProfileBackupJson() }

        assertEquals("导出是只读：被杀也一个字节都不许写", before, backing.rawSnapshot())
    }

    @Test
    fun `导出被杀后重启再导出仍是完整可用包`() {
        val backing = InMemoryKeyValueStore()
        val repository = repositoryOn(backing)
        val settings = KillingSettingsStore(failOnRead = true)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore(), settingsStore = settings)
        assertThrows(KilledMidway::class.java) { host.exportProfileBackupJson() }

        // 「重启」后同一份盘 + 健康读缝：导出不继承任何半截状态。
        settings.failOnRead = false
        val exported = host.exportProfileBackupJson()
        @Suppress("UNCHECKED_CAST")
        val parsed = MiniJson.tryParse(exported) as? Map<String, Any?>
        assertEquals("mikcb", parsed?.get("app"))
        assertEquals("transfer", parsed?.get("packageType"))
        assertTrue("导出必须带完整列表字段", parsed?.get("courses") is List<*>)
    }

    // -----------------------------------------------------------------------
    // 局域网收发：HTTP 路由层中途被杀
    // -----------------------------------------------------------------------

    @Test
    fun `局域网导入应用中途被杀 只回 500 不回 applied 且重试可成功`() {
        val backing = InMemoryKeyValueStore()
        val repository = repositoryOn(backing)
        val settings = KillingSettingsStore(failOnWrite = true)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore(), settingsStore = settings)
        val router = router(host)
        val content = packageJson(
            courses = listOf(course("c9", "外来课程")),
            settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
            currentWeek = 5,
        )

        val killed = router.route(
            postJson(
                "/api/v1/import/apply",
                MiniJson.encode(linkedMapOf("content" to content, "mode" to "merge")),
            ),
        )
        assertEquals(500, killed.status)
        @Suppress("UNCHECKED_CAST")
        val killedBody = MiniJson.tryParse(killed.body.toString(Charsets.UTF_8)) as? Map<String, Any?>
        assertEquals("internal_error", killedBody?.get("error"))
        assertFalse("不许回 applied:true", killedBody?.get("applied") == true)
        assertTrue("已写下去的内容仍留在盘上", repository.courses.any { it.id == "c9" })

        // 页面提示「重试」时不能因为上次半途而把数据写重：同 id 再导一次应成功且不新增。
        settings.failOnWrite = false
        val retried = router.route(
            postJson(
                "/api/v1/import/apply",
                MiniJson.encode(linkedMapOf("content" to content, "mode" to "merge")),
            ),
        )
        assertEquals(200, retried.status)
        assertEquals(18, repository.snapshot.settings.semesterWeekCount)
        assertEquals("重试不许产生第二门同 id 课程", 1, repository.courses.count { it.id == "c9" })
    }

    @Test
    fun `局域网导出中途被杀 只回 500 不吐半截包也不动盘`() {
        val backing = InMemoryKeyValueStore()
        val repository = repositoryOn(backing)
        val host = LanEditRepositoryHost(
            repository,
            LanTransferUndoStore(),
            settingsStore = KillingSettingsStore(failOnRead = true),
        )
        val before = backing.rawSnapshot()

        val response = router(host).route(get("/api/v1/profile/active"))

        assertEquals(500, response.status)
        @Suppress("UNCHECKED_CAST")
        val body = MiniJson.tryParse(response.body.toString(Charsets.UTF_8)) as? Map<String, Any?>
        assertEquals("internal_error", body?.get("error"))
        assertFalse("不许吐半截包", body?.containsKey("courses") == true)
        assertEquals("导出被杀不影响盘", before, backing.rawSnapshot())
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun repositoryOn(store: InMemoryKeyValueStore): TimetableRepository =
        repositoryOn(TimetableStore(store))

    private fun repositoryOn(timetableStore: TimetableStore): TimetableRepository {
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
        timetableStore.saveCurrentWeek(7)
        return TimetableRepository(timetableStore)
    }

    private fun router(host: LanEditRepositoryHost): LanEditApiRouter = LanEditApiRouter(
        host = host,
        session = LanEditSession.forTest(
            pin = "123456",
            token = "tok-abc",
            createdAtMillis = now,
            lastActivityAtMillis = now,
            boundProfileId = "p1",
            clockMillis = { now },
        ),
        clock = { now },
    )

    private fun get(target: String): LanEditHttpRequest = build(target, "GET", "")

    private fun postJson(target: String, body: String): LanEditHttpRequest =
        build(target, "POST", body)

    private fun build(target: String, method: String, body: String): LanEditHttpRequest {
        val (path, queryString) = LanEditHttpParse.splitTarget(target)
        val headers = LinkedHashMap<String, String>()
        if (body.isNotEmpty()) headers["content-type"] = "application/json"
        headers["authorization"] = "Bearer tok-abc"
        return LanEditHttpRequest(
            method = method,
            target = target,
            path = path,
            query = LanEditHttpParse.parseQuery(queryString),
            headers = headers,
            body = body,
            remoteAddress = "192.168.1.9",
        )
    }

    private fun packageJson(
        courses: List<Course> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
        settings: TimetableSettings? = TimetableSettings.defaults(),
        currentWeek: Int? = 7,
        rules: List<ScheduleDateRule> = emptyList(),
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-interrupt",
            scope = TransferScope.CURRENT_TIMETABLE,
            exportedAtIso = "2026-11-02T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = currentWeek,
            settingsJson = settings?.toJson(),
            coursesJson = courses.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
            scheduleDateRulesJson = rules.map { it.toJson() },
        ),
    )

    private fun course(id: String, name: String): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun scheme(id: String, name: String, sections: List<SectionTime>): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private fun sectionsThree(): List<SectionTime> = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("08:55", "09:40"),
        SectionTime("10:00", "10:45"),
    )

    private fun rule(id: String, name: String): ScheduleDateRule = ScheduleDateRule(
        id = id,
        name = name,
        timeSchemeId = "ts1",
        enabled = true,
        startDate = "2026-11-02",
        endDate = "2026-11-08",
    )
}

/** 模拟 SIGKILL：`Error` 不会被 `catch (_: Exception)` 接住。 */
internal class KilledMidway : Error("process killed midway")

/** 只在指定键主写盘时抛 [KilledMidway]，其余读写照常。 */
private class KillingStore(
    private val delegate: InMemoryKeyValueStore,
    private val killedKey: String,
) : KeyValueStore by delegate {

    override fun putString(key: String, value: String) {
        if (key == killedKey) throw KilledMidway()
        delegate.putString(key, value)
    }
}

/** 整份设置读写缝的可开关替身：读/写任一侧都能模拟「进程正好在这步被杀」。 */
internal class KillingSettingsStore(
    var failOnRead: Boolean = false,
    var failOnWrite: Boolean = false,
) : LanTransferSettingsStore {

    val backing: MutableMap<String, Any?> = LinkedHashMap()

    override fun readSettingsJson(): Map<String, Any?> {
        if (failOnRead) throw KilledMidway()
        return LinkedHashMap(backing)
    }

    override fun writeSettingsPatch(patch: Map<String, Any?>) {
        if (failOnWrite) throw KilledMidway()
        patch.forEach { (key, value) -> if (value == null) backing.remove(key) else backing[key] = value }
    }
}
