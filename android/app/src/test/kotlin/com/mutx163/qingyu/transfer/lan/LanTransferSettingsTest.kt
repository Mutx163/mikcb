package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 局域网导入的**整份设置**（Dart 250+ 键口径）L0：差异、落盘、撤销三处对齐。
 *
 * 旧实现只写 `TimetableSettings` 的核心四键，包里的显示/壁纸/更新类设置全被忽略，
 * 与 Dart `applyToProvider`（整份替换）不一致。
 */
class LanTransferSettingsTest {

    @Test
    fun `导入把整份设置写回并保留本机设备信任锚`() {
        val store = InMemoryKeyValueStore()
        val setup = setUpRepository(store)
        val host = LanEditRepositoryHost(setup.repository, settingsStore = setup.settingsStore)

        val result = host.applyTransferJson(
            packageWithSettings(
                linkedMapOf(
                    "semesterWeekCount" to 7,
                    "showWeekend" to false,
                    "wallpaperBlurSigma" to 12,
                    // 来源设备试图改写本机更新源：必须被本地值覆盖。
                    "appUpdateMirrorPreset" to "evil-mirror",
                    "appUpdateMirrorUrlPrefix" to "https://evil.example",
                ),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, result["applied"])

        val settings = setup.settingsStore.readSettingsJson()
        assertEquals(false, settings["showWeekend"])
        assertEquals(12, (settings["wallpaperBlurSigma"] as Number).toInt())
        assertEquals("local-mirror", settings["appUpdateMirrorPreset"])
        assertEquals("https://local.example", settings["appUpdateMirrorUrlPrefix"])
    }

    @Test
    fun `导入按整份替换语义清掉本地多余键`() {
        val store = InMemoryKeyValueStore()
        val setup = setUpRepository(store)
        val host = LanEditRepositoryHost(setup.repository, settingsStore = setup.settingsStore)

        val result = host.applyTransferJson(
            packageWithSettings(linkedMapOf("semesterWeekCount" to 7, "showWeekend" to false)),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, result["applied"])

        val settings = setup.settingsStore.readSettingsJson()
        assertNull("Dart 整份替换：外来缺的键回落默认（等价于删键）", settings["wallpaperBlurSigma"])
        assertFalse(settings.containsKey("wallpaperBlurSigma"))
    }

    @Test
    fun `撤销还原整份设置并删除导入新增的键`() {
        val store = InMemoryKeyValueStore()
        val setup = setUpRepository(store)
        val host = LanEditRepositoryHost(setup.repository, settingsStore = setup.settingsStore)

        val applied = host.applyTransferJson(
            packageWithSettings(
                linkedMapOf(
                    "semesterWeekCount" to 7,
                    "showWeekend" to false,
                    "importedOnlyKey" to "from-peer",
                ),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        val transferId = applied["transferId"] as String

        val undone = host.undoTransferJson(transferId)
        assertEquals(true, undone["undo"])

        val settings = setup.settingsStore.readSettingsJson()
        assertEquals(true, settings["showWeekend"])
        assertEquals("local-tag", settings["localOnlyKey"])
        assertFalse("导入新增的键必须被撤销删掉", settings.containsKey("importedOnlyKey"))
        assertNull(settings["importedOnlyKey"])
    }

    @Test
    fun `预览把非核心设置键的差异算进 settings 摘要`() {
        val store = InMemoryKeyValueStore()
        val setup = setUpRepository(store)
        val host = LanEditRepositoryHost(setup.repository, settingsStore = setup.settingsStore)

        val preview = host.previewTransferJson(
            packageWithSettings(linkedMapOf("semesterWeekCount" to 7, "showWeekend" to false)),
        )
        val diff = preview!!["overwriteDiff"] as Map<*, *>
        val settingsSummary = (diff["summaries"] as List<*>)
            .map { it as Map<*, *> }
            .first { it["kind"] == "settings" }
        assertTrue("只改非核心键也必须报设置变更", (settingsSummary["changes"] as List<*>).isNotEmpty())

        // 同一份整份设置再来一次：核心与非核心都没变 → 不算变更。
        val same = host.previewTransferJson(
            packageWithSettings(setup.settingsStore.readSettingsJson()),
        )!!
        val sameDiff = same["overwriteDiff"] as Map<*, *>
        val sameSummary = (sameDiff["summaries"] as List<*>)
            .map { it as Map<*, *> }
            .first { it["kind"] == "settings" }
        assertTrue((sameSummary["changes"] as List<*>).isEmpty())
    }

    // -----------------------------------------------------------------------

    private class Setup(
        val repository: TimetableRepository,
        val settingsStore: LanTransferSettingsStore,
    )

    /** 本地盘上先放一份「完整设置」：两个核心之外的本机键 + 设备信任锚。 */
    private fun setUpRepository(store: KeyValueStore): Setup {
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    currentWeek = 7L,
                    createdAt = stamp,
                    lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveSettingsPatch(
            linkedMapOf(
                "showWeekend" to true,
                "wallpaperBlurSigma" to 30,
                "localOnlyKey" to "local-tag",
                "appUpdateMirrorPreset" to "local-mirror",
                "appUpdateMirrorUrlPrefix" to "https://local.example",
            ),
        )
        timetableStore.saveCurrentWeek(7)
        return Setup(
            repository = TimetableRepository(timetableStore),
            settingsStore = TimetableStoreLanSettings(TimetableStore(store)),
        )
    }

    private fun packageWithSettings(settings: Map<String, Any?>): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-settings-1",
            scope = TransferScope.CURRENT_TIMETABLE,
            exportedAtIso = "2026-11-03T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = 7,
            settingsJson = settings,
            coursesJson = emptyList(),
        ),
    )

    private companion object {
        val stamp: LocalDateTime = LocalDateTime.of(2026, 1, 1, 0, 0)
    }
}
