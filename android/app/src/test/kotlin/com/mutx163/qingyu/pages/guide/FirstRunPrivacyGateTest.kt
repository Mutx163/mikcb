package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首启隐私门的模型层测试（B1，2026-11-10）。
 *
 * 测的是「进门判定 + 退出落盘」这层纯逻辑；Compose 渲染与系统返回键不在这里
 * （真机清单里另验）。键名是跨端契约：Dart 发布版读的就是
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
        val allowed = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = false,
            previouslyAccepted = false,
        )

        assertFalse(allowed)
        val raw = store.rawSnapshot()
        assertFalse(raw.containsKey("flutter.accepted_privacy_policy"))
        assertFalse(raw.containsKey("flutter.has_seen_user_guide"))
        assertFalse(raw.containsKey("flutter.has_completed_onboarding"))
    }

    @Test
    fun `勾选同意后完成_三键落盘且与Dart键名逐字一致`() {
        val store = InMemoryKeyValueStore()
        val allowed = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = true,
            previouslyAccepted = false,
        )

        assertTrue(allowed)
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
        val allowed = FirstRunPrivacyFlow.complete(
            privacy = PrivacyConsentPreferences(store),
            startup = StartupFlowPreferences(store),
            consentChecked = false,
            previouslyAccepted = true,
        )

        assertTrue(allowed)
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
}
