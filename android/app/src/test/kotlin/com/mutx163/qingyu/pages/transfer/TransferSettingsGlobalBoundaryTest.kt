package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.AppGlobalSettingsStore
import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 传输包的「整机级设置边界」（2026-11-08 审核 P0 回归）。
 *
 * ## 钉住的缺陷
 *
 * 1. 导出把 `readRawSettings()` 整份塞进单课表包，里面含 44 个整机级键；接收端
 *    `updateSettingsPatch` 一路走到 `globalSettings.save()`，于是**别人的主题/语言/材质
 *    会覆盖你的设备**。撤销只写回活动档案内嵌，全局那份回不来。
 * 2. 全量备份恢复只把完整设置铺进档案内嵌；读侧 `globalSettings.overlay(...)` 让本机
 *    已有的全局值整组盖掉内嵌值，所以同机/换机恢复后外观、语言仍是本机的。
 *
 * 这里用真实仓储 + 内存盘验证两条边界：**单课表补丁永不改全局**、**全量恢复显式写回全局**。
 */
class TransferSettingsGlobalBoundaryTest {

    private val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 8, 9, 0)

    private fun profile(id: String): TimetableProfile = TimetableProfile(
        id = id,
        name = "课表$id",
        currentWeek = 1,
        createdAt = stamp,
        lastUsedAt = stamp,
    )

    private fun repository(memory: InMemoryKeyValueStore): TimetableRepository {
        val store = TimetableStore(memory)
        store.saveProfiles(listOf(profile("p1")))
        store.saveActiveProfileId("p1")
        store.saveSettings(TimetableSettings.defaults())
        store.saveCurrentWeek(1)
        return TimetableRepository(store)
    }

    @Test
    fun `导入单课表不改整机级设置_撤销也不依赖它`() {
        val memory = InMemoryKeyValueStore()
        val repository = repository(memory)
        repository.updateSettingsPatch(
            mapOf(
                "appLocaleTag" to "zh-Hans",
                "enableHaptics" to true,
                "courseCardDensity" to "compact",
            ),
        )
        val globalBefore = memory.getString(AppGlobalSettingsStore.KEY)
        assertNotNull("夹具必须先落下全局真源，否则下面的不变断言是空跑", globalBefore)

        // 对方设备导出的单课表包：整机偏好 + 随课表走的偏好混在一起。
        val incoming = mapOf(
            "appLocaleTag" to "en",
            "enableHaptics" to false,
            "courseCardDensity" to "cozy",
        )
        repository.updateSettingsPatch(AppGlobalSettingsStore.stripGlobalKeys(incoming))

        assertEquals(
            "整机级设置一个字都不该变（主题/语言/触感是设备级真源）",
            globalBefore,
            memory.getString(AppGlobalSettingsStore.KEY),
        )
        assertEquals("zh-Hans", repository.readRawSettings()["appLocaleTag"])
        assertEquals(true, repository.readRawSettings()["enableHaptics"])
        assertEquals("cozy", repository.readRawSettings()["courseCardDensity"])
    }

    @Test
    fun `全量恢复把档案内嵌的整机偏好写回全局`() {
        val memory = InMemoryKeyValueStore()
        val repository = repository(memory)
        repository.updateSettingsPatch(
            mapOf("appLocaleTag" to "zh-Hans", "enableHaptics" to true),
        )

        val backupEmbedded = mapOf(
            "appLocaleTag" to "en",
            "enableHaptics" to false,
            "courseCardDensity" to "cozy",
        )
        repository.replaceAllProfiles(
            profiles = listOf(profile("p2")),
            activeProfileId = "p2",
            preferredEmbeddedSettings = mapOf("p2" to backupEmbedded),
        )

        // 缺陷现场：包里的 en 铺进了档案，但读侧被本机全局 zh-Hans 盖掉。
        assertEquals("zh-Hans", repository.readRawSettings()["appLocaleTag"])

        val restored = AppGlobalSettingsStore.globalKeysOnly(
            repository.activeProfileSettingsJson().orEmpty(),
        )
        assertEquals(
            "只把整机级键写回全局，随课表走的偏好留在档案里",
            setOf("appLocaleTag", "enableHaptics"),
            restored.keys,
        )
        assertTrue("写回全局必须成功", repository.writeRawSettingsPatch(restored))

        assertEquals("en", repository.readRawSettings()["appLocaleTag"])
        assertEquals(false, repository.readRawSettings()["enableHaptics"])
        assertFalse(
            "非整机级键不得被提升为设备级偏好",
            restored.containsKey("courseCardDensity"),
        )
    }
}
