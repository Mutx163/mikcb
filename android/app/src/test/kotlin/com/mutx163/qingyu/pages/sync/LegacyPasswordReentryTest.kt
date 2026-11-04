package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 升级后「请重输网盘密码」一次性提示的纯判据与取数（JVM，无 Android）。
 *
 * 页面接入层（`CloudSyncControllerPage.kt` / `CoupleTimetableSettingsHost.kt`）把
 * 探测、读标记、写标记都以函数注入，所以这里能用计数假实现断言「只探测一次」。
 */
class LegacyPasswordReentryTest {

    private val cloudSuffix = CloudSyncLogic.LEGACY_KEY_SUFFIX_CLOUD
    private val cloudMark = CloudSyncLogic.LEGACY_REPROMPT_MARK_CLOUD

    @Test
    fun promptsOnlyWhenAllThreeConditionsHold() {
        assertTrue(
            CloudSyncLogic.shouldPromptLegacyPasswordReentry(
                hasStoredPassword = false,
                hasLegacyDartCredential = true,
                alreadyPrompted = false,
            ),
        )
    }

    @Test
    fun doesNotPromptWhenAnyConditionFails() {
        // 新版已存密码
        assertFalse(
            CloudSyncLogic.shouldPromptLegacyPasswordReentry(
                hasStoredPassword = true,
                hasLegacyDartCredential = true,
                alreadyPrompted = false,
            ),
        )
        // 旧键不存在
        assertFalse(
            CloudSyncLogic.shouldPromptLegacyPasswordReentry(
                hasStoredPassword = false,
                hasLegacyDartCredential = false,
                alreadyPrompted = false,
            ),
        )
        // 已经提示过
        assertFalse(
            CloudSyncLogic.shouldPromptLegacyPasswordReentry(
                hasStoredPassword = false,
                hasLegacyDartCredential = true,
                alreadyPrompted = true,
            ),
        )
    }

    @Test
    fun marksOnceSoSecondVisitDoesNotPromptAgain() {
        val store = InMemoryKeyValueStore()
        var probeCalls = 0
        fun prompt(): Boolean = CloudSyncLogic.takeLegacyPasswordReentryPrompt(
            hasStoredPassword = false,
            legacyKeySuffix = cloudSuffix,
            alreadyPrompted = { store.getBool(cloudMark, false) },
            hasLegacyDartCredential = { suffix ->
                probeCalls++
                suffix == cloudSuffix
            },
            markPrompted = { store.putBool(cloudMark, true) },
        )

        assertTrue("首访应提示", prompt())
        assertTrue("标记应已落盘", store.getBool(cloudMark, false))
        assertFalse("第二次不应再提示", prompt())
        assertEquals("标记存在时不应再探测旧键", 1, probeCalls)
    }

    @Test
    fun doesNotPromptWhenLegacyKeyIsAbsent() {
        val store = InMemoryKeyValueStore()
        val should = CloudSyncLogic.takeLegacyPasswordReentryPrompt(
            hasStoredPassword = false,
            legacyKeySuffix = cloudSuffix,
            alreadyPrompted = { store.getBool(cloudMark, false) },
            hasLegacyDartCredential = { false },
            markPrompted = { store.putBool(cloudMark, true) },
        )

        assertFalse("旧键不存在不应提示", should)
        assertFalse("未提示不应写标记", store.getBool(cloudMark, false))
    }

    @Test
    fun neverProbesWhenPasswordAlreadyStored() {
        var probeCalls = 0
        val should = CloudSyncLogic.takeLegacyPasswordReentryPrompt(
            hasStoredPassword = true,
            legacyKeySuffix = cloudSuffix,
            alreadyPrompted = { false },
            hasLegacyDartCredential = {
                probeCalls++
                true
            },
            markPrompted = {},
        )

        assertFalse(should)
        assertEquals("新版已有密码时不应探测旧键", 0, probeCalls)
    }

    @Test
    fun markWriteFailureStillShowsPrompt() {
        val should = CloudSyncLogic.takeLegacyPasswordReentryPrompt(
            hasStoredPassword = false,
            legacyKeySuffix = cloudSuffix,
            alreadyPrompted = { false },
            hasLegacyDartCredential = { true },
            markPrompted = { throw IOException("prefs 写失败") },
        )

        assertTrue("写标记失败也必须显示提示", should)
    }
}
