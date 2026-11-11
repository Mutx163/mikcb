package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException
import java.time.LocalDateTime

/**
 * **设置合并写的单次事务 + 双侧补偿**（P1-14，2026-11-11）。
 *
 * ## 它防的是哪一类事故
 *
 * 旧实现是「`store.saveSettingsPatch(patch)` 再 `saveSettingsPatchToActiveProfile(patch)`」：
 * 而前者**内部已经**把补丁镜像进活动档案 ⇒ 同一份档案写两遍；第二笔失败时补偿只回滚
 * 顶层，档案内嵌那份留着新值——用户看到「设置页改了、桌面卡片没变」（或反过来）。
 *
 * 现在：只调一次；失败时把顶层与活动档案**两侧**都按调用前的快照差量补回。
 *
 * 落盘用 [InMemoryKeyValueStore] 套一层可控故障的壳，与真实现共用同一套键/编码规则。
 */
class TimetableRepositorySettingsPatchTest {

    @Test
    fun `成功路径只写一次活动档案（不再是两笔）`() {
        val keyValue = CountingStore(InMemoryKeyValueStore())
        val store = seedStore(keyValue)
        val repo = TimetableRepository(store)

        keyValue.putsByKey.clear()
        repo.updateSettingsPatch(mapOf("semesterWeekCount" to 18))

        assertEquals(
            "活动档案本次只该被写一次（旧实现是两笔：saveSettingsPatch 内部一次 + 外层再调一次）",
            1,
            keyValue.putsByKey[TimetableStore.KEY_PROFILES] ?: 0,
        )
        assertEquals(18, repo.snapshot.settings.semesterWeekCount)
        assertEquals(18, (store.loadSettingsJson()["semesterWeekCount"] as Number).toInt())
        assertEquals(18, (store.embeddedSettingsById()["p1"]?.get("semesterWeekCount") as Number).toInt())
    }

    @Test
    fun `顶层镜像写失败时顶层与活动档案两侧都回到调用前`() {
        // 故障注在**最后一笔物理写**（顶层镜像 `timetable_settings`）：档案内嵌那笔已经落盘
        // 新值、顶层镜像还没写，这才是「部分落盘」的真实现场。旧实现只把顶层补回去，
        // 档案内嵌那份会留新值；若把故障注在第一笔（KEY_PROFILES）上，盘上根本没变，
        // 测不到补偿——那是下面另一条用例。
        val keyValue = FailingStore(InMemoryKeyValueStore(), failKey = TimetableStore.KEY_SETTINGS)
        val store = seedStore(keyValue)
        val repo = TimetableRepository(store)
        val beforeTop = store.loadSettingsJson()
        val beforeRawTop = keyValue.getString(TimetableStore.KEY_SETTINGS)
        val beforeEmbedded = store.embeddedSettingsById()["p1"]
        val beforeMemory = repo.snapshot.settings.semesterWeekCount

        keyValue.armed = true
        try {
            repo.updateSettingsPatch(mapOf("semesterWeekCount" to 7))
            fail("顶层镜像写失败时 updateSettingsPatch 必须把异常抛出去")
        } catch (_: IOException) {
            // 预期
        }

        assertEquals(
            "顶层镜像文档要回到调用前",
            beforeRawTop,
            keyValue.getString(TimetableStore.KEY_SETTINGS),
        )
        assertEquals(
            "读出来的合并视图也要回到调用前",
            beforeTop["semesterWeekCount"],
            store.loadSettingsJson()["semesterWeekCount"],
        )
        assertEquals(
            "活动档案内嵌 settings 也要回到调用前（旧实现只补偿顶层，这一份会留新值）",
            beforeEmbedded?.get("semesterWeekCount"),
            store.embeddedSettingsById()["p1"]?.get("semesterWeekCount"),
        )
        assertEquals("内存只在成功后更新", beforeMemory, repo.snapshot.settings.semesterWeekCount)
    }

    @Test
    fun `档案写失败时盘上不留半成品`() {
        // 第一笔物理写就失败：盘上本来就没变（无需补偿），但异常必须上抛、内存不能动。
        val keyValue = FailingStore(InMemoryKeyValueStore(), failKey = TimetableStore.KEY_PROFILES)
        val store = seedStore(keyValue)
        val repo = TimetableRepository(store)
        val beforeTop = store.loadSettingsJson()
        val beforeEmbedded = store.embeddedSettingsById()["p1"]
        val beforeMemory = repo.snapshot.settings.semesterWeekCount

        keyValue.armed = true
        try {
            repo.updateSettingsPatch(mapOf("semesterWeekCount" to 7))
            fail("档案写失败时 updateSettingsPatch 必须把异常抛出去")
        } catch (_: IOException) {
            // 预期
        }

        assertEquals("顶层文档不该被改动", beforeTop["semesterWeekCount"], store.loadSettingsJson()["semesterWeekCount"])
        assertEquals(
            "活动档案内嵌 settings 不该被改动",
            beforeEmbedded?.get("semesterWeekCount"),
            store.embeddedSettingsById()["p1"]?.get("semesterWeekCount"),
        )
        assertEquals("内存只在成功后更新", beforeMemory, repo.snapshot.settings.semesterWeekCount)
    }

    @Test
    fun `补丁不再重复写时内存与两处文档保持一致`() {
        val keyValue = CountingStore(InMemoryKeyValueStore())
        val store = seedStore(keyValue)
        val repo = TimetableRepository(store)

        repo.updateSettingsPatch(mapOf("semesterWeekCount" to 12, "appFontWeight" to 600))

        assertEquals(12, repo.snapshot.settings.semesterWeekCount)
        assertEquals(12, (store.loadSettingsJson()["semesterWeekCount"] as Number).toInt())
        assertEquals(12, (store.embeddedSettingsById()["p1"]?.get("semesterWeekCount") as Number).toInt())
        assertTrue(
            "盘上不该留下「顶层与档案不一致」的组合",
            store.loadSettingsJson()["semesterWeekCount"] == store.embeddedSettingsById()["p1"]?.get("semesterWeekCount"),
        )
    }

    // ------------------------------------------------------------------ 夹具

    private fun seedStore(keyValue: KeyValueStore): TimetableStore {
        val store = TimetableStore(keyValue)
        val settings = TimetableSettings.defaults()
        val profile = TimetableProfile(
            id = "p1",
            name = "三年级",
            courses = emptyList(),
            tasks = emptyList(),
            scheduleItems = emptyList(),
            exams = emptyList(),
            settings = settings,
            currentWeek = 1,
            createdAt = LocalDateTime.of(2026, 10, 26, 8, 0),
            lastUsedAt = LocalDateTime.of(2026, 10, 26, 8, 0),
        )
        store.saveProfiles(listOf(profile))
        store.saveActiveProfileId("p1")
        store.saveSettings(settings)
        return store
    }

    /** 记账壳：统计每个键被 `putString` 的次数（别的写方法原样转发）。 */
    private class CountingStore(private val delegate: KeyValueStore) : KeyValueStore by delegate {
        val putsByKey = mutableMapOf<String, Int>()
        override fun putString(key: String, value: String) {
            putsByKey[key] = (putsByKey[key] ?: 0) + 1
            delegate.putString(key, value)
        }
    }

    /**
     * 故障壳：`armed` 为真且写到 [failKey] 时抛一次 [IOException]，随即自动解除
     * （补偿那几笔必须能写进去，否则测的就不是补偿而是「全挂」）。
     */
    private class FailingStore(
        private val delegate: KeyValueStore,
        private val failKey: String,
    ) : KeyValueStore by delegate {
        var armed = false
        override fun putString(key: String, value: String) {
            if (armed && key == failKey) {
                armed = false
                throw IOException("simulated write failure on $key")
            }
            delegate.putString(key, value)
        }
    }
}
