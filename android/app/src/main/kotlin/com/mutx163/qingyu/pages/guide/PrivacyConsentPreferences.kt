package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 首启隐私门的三枚标记（与 Dart `storage_service.dart:29-32` 逐字同一批键名）。
 *
 * 为什么单独一个类：`StartupFlowPreferences` 的注释已经写明
 * 「`has_seen_user_guide` / `accepted_privacy_policy` 属于用户指南页的职责」。
 * 把这两枚键放回那个类会混淆两段语义（开学日期引导 vs 隐私同意），
 * 也会让「谁写、什么时候写」在两处各说各话。这里集中定义，键名做对拍测试。
 *
 * 键名前缀由 [KeyValueStore] 实现统一加（`flutter.`），调用方不要自己拼。
 */
class PrivacyConsentPreferences(private val store: KeyValueStore) {

    /** Dart `hasAcceptedPrivacyPolicy()`。 */
    fun hasAcceptedPrivacyPolicy(): Boolean =
        store.getBool(KEY_ACCEPTED_PRIVACY_POLICY, false)

    /** Dart `hasSeenUserGuide()`。 */
    fun hasSeenUserGuide(): Boolean =
        store.getBool(KEY_SEEN_USER_GUIDE, false)

    fun markAcceptedPrivacyPolicy() {
        store.putBool(KEY_ACCEPTED_PRIVACY_POLICY, true)
    }

    fun markSeenUserGuide() {
        store.putBool(KEY_SEEN_USER_GUIDE, true)
    }

    /**
     * 回读校验：写完立刻读一遍，不一致返回 false。
     *
     * 与 [StartupFlowPreferences.markOnboardingCompletedAndVerify] 同口径：
     * 国产 ROM 的 `commit()` 有不可靠先例（Dart `storage_service.dart:888-891`
     * 自己就带这段防御），同意标记写丢了会让用户下次冷启再走一遍隐私门。
     */
    fun markAcceptedPrivacyPolicyAndVerify(): Boolean {
        markAcceptedPrivacyPolicy()
        return hasAcceptedPrivacyPolicy()
    }

    fun markSeenUserGuideAndVerify(): Boolean {
        markSeenUserGuide()
        return hasSeenUserGuide()
    }

    /**
     * 首启两键都齐了才算「不用再挡」——对齐 Dart `_handleStartupFlows`
     * 的快速路径判据（`v2.1.4.1:lib/main.dart:974-985`：`hasAcceptedPrivacy && hasSeenGuide`）。
     */
    fun isFirstRunComplete(): Boolean = hasAcceptedPrivacyPolicy() && hasSeenUserGuide()

    companion object {
        /** Dart `_acceptedPrivacyPolicyKey`。 */
        const val KEY_ACCEPTED_PRIVACY_POLICY = "accepted_privacy_policy"

        /** Dart `_hasSeenUserGuideKey`。 */
        const val KEY_SEEN_USER_GUIDE = "has_seen_user_guide"
    }
}

/** 首启指南退出时的三种结果。 */
enum class FirstRunPrivacyCompletion {
    /** 三枚标记都写入且回读一致，可以进首页。 */
    Completed,

    /** 必须勾选同意却没勾（用户取消勾选 / 直接退出），一个字节都不写。 */
    ConsentMissing,

    /** 写盘失败（磁盘满、国产 ROM 的 commit 不可靠等），停在隐私页并提示。 */
    SaveFailed,
}

/**
 * 首启门的**纯逻辑**（不依赖 Android / Compose），供 [FirstRunPrivacyGate] 与
 * JVM 单测共用。
 *
 * 行为对齐 `v2.1.4.1:lib/main.dart` 的 `_handleStartupFlows` + `_openGuide`：
 * - 快速路径：已同意 + 已看过指南 → 直接首页；
 * - 否则弹指南：未同意时 `requirePrivacyConsent = true`、初始勾选 = 已同意；
 * - 退出时：**勾了同意才写 `accepted_privacy_policy`**，并写 `has_seen_user_guide`，
 *   最后统一写 `has_completed_onboarding = true`；
 * - 必须勾选却没勾（或用户直接退出）→ 一条都不写、界面不放行；
 * - 写盘失败 → 停在隐私页提示「保存失败」，**不许崩**（2026-11-10 B1 复核补）。
 */
object FirstRunPrivacyFlow {

    /** 是否需要弹首启指南（快速路径取反）。 */
    fun needsGuide(acceptedPrivacy: Boolean, seenUserGuide: Boolean): Boolean =
        !(acceptedPrivacy && seenUserGuide)

    /** 本次是否强制要求勾选隐私同意（只有未同意过才强制）。 */
    fun requiresConsent(acceptedPrivacy: Boolean): Boolean = !acceptedPrivacy

    /**
     * 完成首启指南时落盘。
     *
     * 三处写入都走 `*AndVerify`（写完立刻回读）：国产 ROM 的 `commit()` 有不可靠
     * 先例，Dart 侧 `storage_service.dart:888-891` 自己就带这段防御。写盘异常
     *（如 `PrefsKeyValueStore.putBool` 在 `commit()` 失败时抛 `IOException`）一律
     * 收成 [FirstRunPrivacyCompletion.SaveFailed]，由界面给一句人话，绝不让崩溃
     * 发生在用户刚点「完成」的时候。
     *
     * @param consentChecked 退出时页面上的勾选状态（用户可以先勾后取消）
     * @param previouslyAccepted 进入指南前是否已同意
     */
    fun complete(
        privacy: PrivacyConsentPreferences,
        startup: StartupFlowPreferences,
        consentChecked: Boolean,
        previouslyAccepted: Boolean,
    ): FirstRunPrivacyCompletion {
        if (!previouslyAccepted && !consentChecked) {
            return FirstRunPrivacyCompletion.ConsentMissing
        }
        return try {
            if (consentChecked && !privacy.markAcceptedPrivacyPolicyAndVerify()) {
                return FirstRunPrivacyCompletion.SaveFailed
            }
            if (!privacy.markSeenUserGuideAndVerify()) {
                return FirstRunPrivacyCompletion.SaveFailed
            }
            if (!startup.markOnboardingCompletedAndVerify()) {
                return FirstRunPrivacyCompletion.SaveFailed
            }
            FirstRunPrivacyCompletion.Completed
        } catch (_: Throwable) {
            FirstRunPrivacyCompletion.SaveFailed
        }
    }
}
