package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `TimetableStore.runRestoreTransaction` 的**落盘级**咬合测试（2026-11-05 数据安全修复）。
 *
 * 云恢复此前七笔逐 key 直写，中途一笔抛错会把磁盘留在半新半旧。守卫钉三件事：
 * 1. 第一笔成功、后续笔抛错 ⇒ **七个键全部回到快照原值**（含「原本不存在的键回到不存在」，
 *    不许变成空串或残留新值）——断言的是 `store` 落盘内容，不是返回值；
 * 2. 事务内没写过的键原样不动（快照不越权）；
 * 3. 对照组：全部成功时新值全部落盘、且不多写不少写。
 *
 * 咬合探针（2026-11-05 实测）：去掉 `runRestoreTransaction` 的回滚调用 → 本类
 * `第一笔成功后续笔抛错_七键全部回到快照原值` 变红（`current_week` 残留 9、
 * rules 残留新值）→ 还原后全绿。
 */
class TimetableStoreRestoreTransactionTest {

    /** 按键名注入写失败的假存储：命中 [failOnKey] 的写入直接抛，其余透传。 */
    private class FlakyKeyValueStore(
        private val delegate: KeyValueStore,
    ) : KeyValueStore by delegate {
        @Volatile
        var failOnKey: String? = null

        override fun putString(key: String, value: String) {
            if (key == failOnKey) throw IllegalStateException("injected write failure: $key")
            delegate.putString(key, value)
        }

        override fun putInt(key: String, value: Int) {
            if (key == failOnKey) throw IllegalStateException("injected write failure: $key")
            delegate.putInt(key, value)
        }
    }

    private val oldProfiles =
        """[{"id":"p1","name":"旧档案","settings":{"semesterWeekCount":16}}]"""
    private val newProfiles =
        """[{"id":"p2","name":"新档案","settings":{"semesterWeekCount":30}}]"""
    private val oldSchemes =
        """[{"id":"s1","name":"旧模板","sections":[{"startTime":"08:00","endTime":"08:45"}],"createdAt":"2026-01-01T08:00:00.000","updatedAt":"2026-01-01T08:00:00.000"}]"""
    private val oldGroups = """[{"id":"g1","name":"旧分组"}]"""

    /** 七键组种子：schemas 章=2（非 1，保证回滚断言不是默认值）、rules **不种**（考「回到不存在」）。 */
    private fun seeded(flaky: FlakyKeyValueStore): TimetableStore {
        val store = TimetableStore(flaky)
        flaky.putString(TimetableStore.KEY_PROFILES, oldProfiles)
        flaky.putString(TimetableStore.KEY_TIME_SCHEMES, oldSchemes)
        flaky.putString(TimetableStore.KEY_LOCATION_TIME_GROUPS, oldGroups)
        flaky.putInt(TimetableStore.KEY_PROFILES_SCHEMA_VERSION, 2)
        flaky.putString(TimetableStore.KEY_ACTIVE_PROFILE_ID, "p1")
        flaky.putInt(TimetableStore.KEY_CURRENT_WEEK, 3)
        // 事务里的写走 saveRawProfiles（会盖 schema 章），先把章拨到 2 之外的位置无意义，
        // 这里种在 saveRawProfiles 之前会立刻被盖回 1 —— 所以章的种子放在 saveRawProfiles
        // 之后由各用例自行处理（见 rollback 用例）。
        return store
    }

    /** 恢复七键组的全部写入（与云恢复 restoreFromCloudSnapshotLocked 的落盘同构）。 */
    private fun restoreWrites(store: TimetableStore, flaky: FlakyKeyValueStore) {
        store.saveRawProfiles(newProfiles)
        store.saveActiveProfileId("p2")
        store.saveSettingsPatch(mapOf("semesterWeekCount" to 30))
        store.saveTimeSchemes(
            listOf(
                TimeScheme(
                    id = "s2",
                    name = "新模板",
                    sections = listOf(SectionTime("09:00", "09:45")),
                    createdAt = LocalDateTime.of(2026, 3, 1, 8, 0),
                    updatedAt = LocalDateTime.of(2026, 3, 1, 8, 0),
                ),
            ),
        )
        flaky.putString(TimetableStore.KEY_SCHEDULE_DATE_RULES, """[{"id":"r1"}]""")
        store.saveCurrentWeek(9)
    }

    @Test
    fun `第一笔成功后续笔抛错_七键全部回到快照原值`() {
        val delegate = InMemoryKeyValueStore()
        val flaky = FlakyKeyValueStore(delegate)
        val store = seeded(flaky)
        store.saveRawProfiles(oldProfiles) // 盖章：schema → 1
        flaky.putInt(TimetableStore.KEY_PROFILES_SCHEMA_VERSION, 2) // 拨回非默认值，回滚必须还原它
        val settingsViewBefore = store.loadSettingsJson()

        // 注入点选 current_week（restoreWrites 最后一笔 = 回滚序第 5 步）：前四笔
        // （profiles / schema 章 / active id / settings）与 schemes、rules 五笔脏键落盘后，
        // current_week 这笔注入抛。回滚在第 5 步（week 恢复）处注入失败，但
        // **第 6-8 步（schemes / rules / groups）必须继续执行**——KDoc「能救多少救多少」：
        // 首错后不许跳过其余键（2026-11-05 修过首错即中止的缺陷，本用例就是它的探针）。
        // 注入的 current_week 写本身没落盘（抛在 delegate 写之前）、回滚也在同一步失败，
        // 所以它应保持种子值 3。
        flaky.failOnKey = TimetableStore.KEY_CURRENT_WEEK
        val error = runCatching {
            store.runRestoreTransaction { restoreWrites(store, flaky) }
        }.exceptionOrNull()

        assertTrue("注入的写失败必须原样上抛（不能被事务吞掉）", error is IllegalStateException)
        // —— 落盘断言：七键全部回到快照原值 ——
        assertEquals("profiles 原始串必须还原", oldProfiles, delegate.getString(TimetableStore.KEY_PROFILES))
        assertEquals(
            "schema 章必须还原成快照值 2（不是默认 1，也不是新写的值）",
            2,
            delegate.getInt(TimetableStore.KEY_PROFILES_SCHEMA_VERSION, 0),
        )
        assertEquals("active id 必须还原", "p1", delegate.getString(TimetableStore.KEY_ACTIVE_PROFILE_ID))
        assertEquals("settings 视图必须整份还原", settingsViewBefore, store.loadSettingsJson())
        assertEquals("current_week 必须还原", 3, delegate.getInt(TimetableStore.KEY_CURRENT_WEEK, 0))
        // —— 注入点**之后**的回滚步骤也必须执行（首错不许中止）——
        assertEquals(
            "注入点之后的 schemes 也必须被回滚（首错中止 = 本断言红）",
            oldSchemes,
            delegate.getString(TimetableStore.KEY_TIME_SCHEMES),
        )
        // 原本**不存在**的键必须回到不存在：不能是空串、不能残留新值
        assertFalse("rules 键必须回到不存在（注入点之后的步骤）", delegate.contains(TimetableStore.KEY_SCHEDULE_DATE_RULES))
        assertNull("rules 键回滚后读值必须是 null", delegate.getString(TimetableStore.KEY_SCHEDULE_DATE_RULES))
        assertEquals(
            "注入点之后的 groups 也必须被处理（未被写 → 原样）",
            oldGroups,
            delegate.getString(TimetableStore.KEY_LOCATION_TIME_GROUPS),
        )
    }

    @Test
    fun `全部成功的对照组_新值全部落盘且未触碰的键不动`() {
        val delegate = InMemoryKeyValueStore()
        val flaky = FlakyKeyValueStore(delegate)
        val store = seeded(flaky)

        store.runRestoreTransaction { restoreWrites(store, flaky) }

        assertEquals("对照组：profiles 落新值", newProfiles, delegate.getString(TimetableStore.KEY_PROFILES))
        assertEquals("对照组：schema 章被 saveRawProfiles 盖成 1", 1, delegate.getInt(TimetableStore.KEY_PROFILES_SCHEMA_VERSION, 0))
        assertEquals("对照组：active id 落新值", "p2", delegate.getString(TimetableStore.KEY_ACTIVE_PROFILE_ID))
        assertEquals("对照组：settings 视图含新 core 键", 30L, (store.loadSettingsJson()["semesterWeekCount"] as Number).toLong())
        assertEquals("对照组：rules 落新值", """[{"id":"r1"}]""", delegate.getString(TimetableStore.KEY_SCHEDULE_DATE_RULES))
        assertEquals("对照组：current_week 落新值", 9, delegate.getInt(TimetableStore.KEY_CURRENT_WEEK, 0))
        // time_schemes 断结构不认原始串：saveTimeSchemes 走 MiniJson.encode，字段序
        // 由模型 toJson 决定，手写字面量会假红。
        val controlSchemes = store.loadTimeSchemes().schemes
        assertEquals("对照组：time_schemes 落新模板（结构）", "s2", controlSchemes.single().id)
        assertEquals("对照组：新模板节次", listOf(SectionTime("09:00", "09:45")), controlSchemes.single().sections)
        assertEquals("对照组：事务没写 groups，必须原样", oldGroups, delegate.getString(TimetableStore.KEY_LOCATION_TIME_GROUPS))
    }
}
