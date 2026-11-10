package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首启隐私门的模型层测试（B1，2026-11-10；同批复核补写盘失败路径）。
 *
 * 测的是「进门判定 + 退出落盘 + 写盘失败不崩」这层纯逻辑；Compose 渲染与系统返回键
 * 不在这里（真机清单里另验）。键名是跨端契约：Dart 发布版读的就是
 * `flutter.accepted_privacy_policy` / `flutter.has_seen_user_guide`，写错等于没写。
 */
class FirstRunPrivacyGateTest {

    // ---------------------------------------------------------------- 进门判定

    @Test
    fun `新装两键都缺_需要弹指南且强制勾选`() {
        val store = InMemoryKeyValueStore()
        val privacy = PrivacyConsentPreferences(store)

        assertFalse(privacy.hasAcceptedPrivacyPolicy())
        assertFalse(privacy.hasSeenUserGuide())
        assertFalse(privacy.isFirstRunComplete())
        assertTrue(FirstRunPrivacyFlow.needsGuide(acceptedPrivacy = false, seenUserGuide = false))
        assertTrue(FirstRunPrivacyFlow.requiresConsent(acceptedPrivacy = false))
    }

    @Test
    fun `已同意已看过_走快速路径直接进首页`() {
        val store = InMemoryKeyValueStore(
            mapOf(
                PrivacyConsentPreferences.KEY_ACCEPTED_PRIVACY_POLICY to "true",
                PrivacyConsentPreferences.KEY_SEEN_USER_GUIDE to "true",
            ),
        )
        val privacy = PrivacyConsentPreferences(store)

        assertTrue(privacy.isFirstRunComplete())
        assertFalse(FirstRunPrivacyFlow.needsGuide(acceptedPrivacy = true, seenUserGuide = true))
    }

    @Test
    fun `只同意没看过_仍要看指南但不再强制勾选`() {
        assertTrue(FirstRunPrivacyFlow.needsGuide(acceptedPrivacy = true, seenUserGuide = false))
        assertFalse(FirstRunPrivacyFlow.requiresConsent(acceptedPrivacy = true))
    }

    // ---------------------------------------------------------------- 退出落盘

    @Test
    fun `未勾选且此前未同意_不放行且一个键都不写`() {
        val store = InMemoryKeyValueStore()
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = false,
            previouslyAccepted = false,
        )

        assertEquals(FirstRunPrivacyCompletion.ConsentMissing, result)
        val raw = store.rawSnapshot()
        assertFalse(raw.containsKey("flutter.accepted_privacy_policy"))
        assertFalse(raw.containsKey("flutter.has_seen_user_guide"))
        assertFalse(raw.containsKey("flutter.has_completed_onboarding"))
    }

    @Test
    fun `勾选同意后完成_三键落盘且与Dart键名逐字一致`() {
        val store = InMemoryKeyValueStore()
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = true,
            previouslyAccepted = false,
        )

        assertEquals(FirstRunPrivacyCompletion.Completed, result)
        val raw = store.rawSnapshot()
        assertEquals("true", raw["flutter.accepted_privacy_policy"])
        assertEquals("true", raw["flutter.has_seen_user_guide"])
        assertEquals("true", raw["flutter.has_completed_onboarding"])

        // 回读：下次冷启必须直接走快速路径。
        assertTrue(PrivacyConsentPreferences(store).isFirstRunComplete())
        assertTrue(StartupFlowPreferences(store).isOnboardingCompleted())
    }

    @Test
    fun `已同意但没看过指南_只补看过的两键也放行`() {
        val store = InMemoryKeyValueStore(
            mapOf(PrivacyConsentPreferences.KEY_ACCEPTED_PRIVACY_POLICY to "true"),
        )
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = false,
            previouslyAccepted = true,
        )

        assertEquals(FirstRunPrivacyCompletion.Completed, result)
        val raw = store.rawSnapshot()
        assertEquals("true", raw["flutter.accepted_privacy_policy"])
        assertEquals("true", raw["flutter.has_seen_user_guide"])
        assertEquals("true", raw["flutter.has_completed_onboarding"])
    }

    @Test
    fun `写完回读校验_防国产ROM提交不可靠`() {
        val store = InMemoryKeyValueStore()
        val privacy = PrivacyConsentPreferences(store)

        assertTrue(privacy.markAcceptedPrivacyPolicyAndVerify())
        assertTrue(privacy.markSeenUserGuideAndVerify())
        assertTrue(privacy.isFirstRunComplete())
    }

    // ---------------------------------------------------------------- 写盘失败（B1 复核补）

    @Test
    fun `同意写入抛异常_返回SaveFailed而不是崩`() {
        val store = FailingKeyValueStore(
            failOn = setOf(PrivacyConsentPreferences.KEY_ACCEPTED_PRIVACY_POLICY),
        )
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = true,
            previouslyAccepted = false,
        )

        assertEquals(FirstRunPrivacyCompletion.SaveFailed, result)
        assertFalse(PrivacyConsentPreferences(store).hasAcceptedPrivacyPolicy())
    }

    @Test
    fun `已看过写入抛异常_返回SaveFailed`() {
        val store = FailingKeyValueStore(
            failOn = setOf(PrivacyConsentPreferences.KEY_SEEN_USER_GUIDE),
        )
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = true,
            previouslyAccepted = false,
        )

        assertEquals(FirstRunPrivacyCompletion.SaveFailed, result)
    }

    @Test
    fun `引导完成标记写入抛异常_返回SaveFailed`() {
        val store = FailingKeyValueStore(
            failOn = setOf(StartupFlowPreferences.KEY_COMPLETED_ONBOARDING),
        )
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = true,
            previouslyAccepted = false,
        )

        assertEquals(FirstRunPrivacyCompletion.SaveFailed, result)
    }

    @Test
    fun `写进去但回读不一致_也判SaveFailed`() {
        // 模拟国产 ROM：putBool 不抛异常，但值没真正落盘（回读仍是 false）。
        val store = SilentlyDroppingKeyValueStore(
            dropKeys = setOf(PrivacyConsentPreferences.KEY_SEEN_USER_GUIDE),
        )
        val result = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = true,
            previouslyAccepted = false,
        )

        assertEquals(FirstRunPrivacyCompletion.SaveFailed, result)
        assertFalse(PrivacyConsentPreferences(store).hasSeenUserGuide())
    }

    // ---------------------------------------------------------------- 测试替身

    /** 指定键的 `putBool` 直接抛 IOException（模拟磁盘满 / commit 失败）。 */
    private class FailingKeyValueStore(
        private val delegate: InMemoryKeyValueStore = InMemoryKeyValueStore(),
        private val failOn: Set<String>,
    ) : KeyValueStore by delegate {
        override fun putBool(key: String, value: Boolean) {
            if (key in failOn) throw IOException("simulated write failure")
            delegate.putBool(key, value)
        }
    }

    /** `putBool` 静默丢弃指定键（模拟「写成功但回读不一致」）。 */
    private class SilentlyDroppingKeyValueStore(
        private val delegate: InMemoryKeyValueStore = InMemoryKeyValueStore(),
        private val dropKeys: Set<String>,
    ) : KeyValueStore by delegate {
        override fun putBool(key: String, value: Boolean) {
            if (key in dropKeys) return
            delegate.putBool(key, value)
        }
    }
}
