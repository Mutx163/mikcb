package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「设置落盘 → 原生岛快照同步」的契约测试（F-实时活动 P1）。
 *
 * 两条职责分开钉：
 * 1. [LiveDisplayStore] 落盘后**确实**通知了同步器，且带出的是**刚改的值**；
 * 2. [LiveSnapshotBuilder] 只换 `settings` 子树，课程等其余字段一个字节都不动。
 *
 * 这是「改设置 → 调用了 syncSnapshot 且参数用到新值」的可执行证明；真正的
 * `LiveUpdateScheduler.syncSnapshot` 由壳 Activity 挂上，本测试用 fake 接口替换。
 */
class LiveSnapshotSyncTest {

    private fun disk(initialJson: String? = null): InMemoryKeyValueStore =
        if (initialJson == null) {
            InMemoryKeyValueStore()
        } else {
            InMemoryKeyValueStore(mapOf("timetable_settings" to initialJson))
        }

    private fun store(raw: KeyValueStore): LiveDisplayStore = LiveDisplayStore(TimetableStore(raw))

    private fun rawJson(raw: KeyValueStore): Map<String, Any?> {
        val text = raw.getString("timetable_settings") ?: return emptyMap()
        @Suppress("UNCHECKED_CAST")
        return MiniJson.tryParse(text) as? Map<String, Any?> ?: emptyMap()
    }

    @After
    fun tearDown() {
        LiveSnapshotSyncRegistry.install(null)
    }

    // ==========================================================
    // 1. 落盘 → 同步器（参数用新值）
    // ==========================================================

    @Test
    fun `保存显示设置会调用同步器且带上新值`() {
        val raw = disk()
        var captured: Map<String, Any?>? = null
        LiveSnapshotSyncRegistry.install(LiveSnapshotSyncer { settingsJson -> captured = settingsJson })

        store(raw).saveDisplay(
            LiveDisplayState().copy(showCourseName = false, showLocation = false),
            forDuringEnd = false,
        )

        val synced = captured ?: error("没有通知同步器")
        assertEquals(false, synced[LiveDisplayCodec.KEY_SHOW_COURSE_NAME])
        assertEquals(false, synced[LiveDisplayCodec.KEY_SHOW_LOCATION])
        // 同步出去的是「合并后的整份设置」，不只是本页补丁。
        assertEquals(false, rawJson(raw)[LiveDisplayCodec.KEY_SHOW_COURSE_NAME])
    }

    @Test
    fun `保存提醒时段会调用同步器且带上新值`() {
        var captured: Map<String, Any?>? = null
        LiveSnapshotSyncRegistry.install(LiveSnapshotSyncer { settingsJson -> captured = settingsJson })

        store(disk()).saveReminderTiming(
            ReminderTimingState(
                liveEnableBeforeClass = false,
                liveEnableDuringClass = true,
                liveEnableBeforeEnd = true,
            ),
        )

        val synced = captured ?: error("没有通知同步器")
        assertEquals(false, synced[LiveDisplayCodec.KEY_ENABLE_BEFORE_CLASS])
        assertEquals(true, synced[LiveDisplayCodec.KEY_ENABLE_DURING_CLASS])
    }

    @Test
    fun `未挂同步器时落盘不崩（空操作）`() {
        // 不 install；只验证不抛。
        val raw = disk()
        store(raw).saveDisplay(LiveDisplayState().copy(showStageText = false), forDuringEnd = false)
        assertEquals(false, rawJson(raw)[LiveDisplayCodec.KEY_SHOW_STAGE_TEXT])
    }

    // ==========================================================
    // 2. 快照只换 settings，不动课程
    // ==========================================================

    @Test
    fun `合并设置时保留课程与既有 settings 里壳不拥有的键`() {
        val existing = """
            {
              "currentWeek": 3,
              "isHoliday": false,
              "courses": [{"name": "高等数学", "dayOfWeek": 1}],
              "settings": {
                "sections": [{"startTime": "08:00", "endTime": "08:45"}],
                "semesterWeekCount": 20,
                "liveShowCourseName": true
              }
            }
        """.trimIndent()

        val merged = LiveSnapshotBuilder.withSettings(
            existingSnapshotJson = existing,
            settingsJson = mapOf(
                LiveDisplayCodec.KEY_SHOW_COURSE_NAME to false,
                "appThemeMode" to "dark",
            ),
        ) ?: error("应能合并")

        @Suppress("UNCHECKED_CAST")
        val root = MiniJson.parse(merged) as Map<String, Any?>
        // 课程 / 当前周原样保留。（MiniJson 解析整数为 Long）
        assertEquals(3L, root["currentWeek"])
        val courses = root["courses"] as List<*>
        assertEquals(1, courses.size)

        @Suppress("UNCHECKED_CAST")
        val settings = root[LiveSnapshotBuilder.KEY_SETTINGS] as Map<String, Any?>
        // 用户新改的值生效。
        assertEquals(false, settings[LiveDisplayCodec.KEY_SHOW_COURSE_NAME])
        assertEquals("dark", settings["appThemeMode"])
        // 壳不拥有的键（节次 / 周数）保住了，否则岛的排课会失效。
        val sections = settings["sections"] as List<*>
        assertEquals(1, sections.size)
        assertEquals(20L, settings["semesterWeekCount"])
        // 版本号回填（Dart `buildLiveSnapshotSettingsJson` 同口径）。
        assertEquals(1L, settings[LiveSnapshotBuilder.KEY_EXPANDED_DETAIL_SCHEMA_VERSION])
    }

    @Test
    fun `没有既有快照时不造空课表快照`() {
        assertNull(LiveSnapshotBuilder.withSettings(null, mapOf("liveShowCourseName" to false)))
        assertNull(LiveSnapshotBuilder.withSettings("  ", mapOf("liveShowCourseName" to false)))
        assertNull(LiveSnapshotBuilder.withSettings("not json", mapOf("x" to 1)))
    }

    @Test
    fun `合并结果可被再次解析（编码往返）`() {
        val existing = """{"courses":[],"settings":{"sections":[]}}"""
        val merged = LiveSnapshotBuilder.withSettings(existing, mapOf("liveShowCountdown" to false))!!
        @Suppress("UNCHECKED_CAST")
        val settings = (MiniJson.parse(merged) as Map<String, Any?>)["settings"] as Map<String, Any?>
        assertEquals(false, settings["liveShowCountdown"])
        assertTrue(settings.containsKey(LiveSnapshotBuilder.KEY_EXPANDED_DETAIL_SCHEMA_VERSION))
        assertNull(settings[LiveDisplayCodec.KEY_ENABLE_BEFORE_CLASS])
    }
}
