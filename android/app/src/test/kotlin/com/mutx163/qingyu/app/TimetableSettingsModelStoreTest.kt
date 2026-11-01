package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [TimetableSettingsModelStore.saveHomeViewMode] 的落盘口径。
 *
 * 底栏点一下「日 / 周 / 月」就走这条路径（`PagesShellActivity.selectRoot`），它必须：
 *
 * 1. **只改 `timetableHomeViewMode` 一个键**——不拿整份设置快照覆盖。旧写法
 *    `save(model)` 会把 `toJsonPatch()` 那 80+ 个键一起写下去，后台写只要比用户的
 *    下一次设置改动慢半拍，就会把刚改的那一项按旧值写回去；
 * 2. 两个落点（顶层 `timetable_settings` / active profile 内嵌 `settings`）都写，
 *    与 [TimetableSettingsModelStore.save] 和 Dart `persistHomeViewState` 同口径；
 * 3. 档案里别的东西（课程、底栏排列…）原样保留。
 *
 * 断言「键集合恰好等于原来那几项」是刻意的：只比单个值的话，旧实现（整份覆盖）
 * 照样能过 —— 咬合探针就是拿这条抓出来的。
 */
class TimetableSettingsModelStoreTest {

    private val settingsJson =
        """{"timetableHomeViewMode":"week","appLocaleTag":"zh","pageTransitionSpeed":1.2}"""

    private val profilesJson =
        """[{"id":"p1","name":"课表A","courses":[],""" +
            """"settings":{"timetableHomeViewMode":"week","glassDockActions":["day","week"]}}]"""

    private fun newStore(): Pair<InMemoryKeyValueStore, TimetableSettingsModelStore> {
        val raw = InMemoryKeyValueStore(
            mapOf(
                TimetableStore.KEY_SETTINGS to settingsJson,
                TimetableStore.KEY_PROFILES to profilesJson,
                TimetableStore.KEY_ACTIVE_PROFILE_ID to "p1",
            ),
        )
        return raw to TimetableSettingsModelStore(TimetableStore(raw))
    }

    /** 盘上某个键的 JSON 对象（测试断言用）。 */
    private fun InMemoryKeyValueStore.jsonObject(key: String): Map<*, *> =
        MiniJson.tryParse(getString(key)!!) as Map<*, *>

    @Test
    fun saveHomeViewMode_writesOnlyThatKeyInBothTargets() {
        val (raw, store) = newStore()

        store.saveHomeViewMode(TimetableHomeViewMode.DAY)

        // ── 顶层 settings：只多不少都不行，键集合必须原样 ──
        val settings = raw.jsonObject(TimetableStore.KEY_SETTINGS)
        assertEquals("day", settings["timetableHomeViewMode"])
        assertEquals(
            setOf("timetableHomeViewMode", "appLocaleTag", "pageTransitionSpeed"),
            settings.keys.filterIsInstance<String>().toSet(),
        )
        assertEquals("zh", settings["appLocaleTag"])
        assertEquals(1.2, (settings["pageTransitionSpeed"] as Number).toDouble(), 0.0)

        // ── active profile 内嵌 settings：同样只改一个键 ──
        val profiles = MiniJson.tryParse(raw.getString(TimetableStore.KEY_PROFILES)!!) as List<*>
        val profile = profiles.single() as Map<*, *>
        assertEquals("p1", profile["id"])
        assertEquals("课表A", profile["name"])
        assertTrue((profile["courses"] as List<*>).isEmpty())
        val embedded = profile["settings"] as Map<*, *>
        assertEquals("day", embedded["timetableHomeViewMode"])
        assertEquals(
            setOf("timetableHomeViewMode", "glassDockActions"),
            embedded.keys.filterIsInstance<String>().toSet(),
        )
        assertEquals(listOf("day", "week"), embedded["glassDockActions"])

        // ── 读侧能读到刚写的值 ──
        assertEquals(TimetableHomeViewMode.DAY, store.load().timetableHomeViewMode)
    }

    @Test
    fun saveHomeViewMode_keepsEveryOtherOwnedKeyUntouched() {
        val (raw, store) = newStore()
        val before = raw.jsonObject(TimetableStore.KEY_SETTINGS)

        store.saveHomeViewMode(TimetableHomeViewMode.MONTH)

        val after = raw.jsonObject(TimetableStore.KEY_SETTINGS)
        // 除视图档外逐键相同（顺序无关）
        val filtered = after.filterKeys { it != "timetableHomeViewMode" }
        assertEquals(before.filterKeys { it != "timetableHomeViewMode" }, filtered)
        assertEquals("month", after["timetableHomeViewMode"])
    }
}
