package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「错误上报开关」的源码守卫（2026-11-15，用户批准的开关）。
 *
 * ## 口径
 *
 * 用户关掉「错误上报」后：**友盟 SDK 一个入口都不跑**（`preInit` 与 `init` 同受这一枚独立键
 * 门控），但**本地崩溃日志照留**（用户仍能在「应用日志」里自己导出）。所以开关只停上报，
 * 不停落盘；两件事必须分清，混在一起就会出现「关了开关连本地日志也没了」或「关了还在上报」。
 *
 * ## 五条判据（少一条就会被改坏而不自知）
 *
 * 1. `preInit` 在 `if (!analyticsOptedOut)` 里——`onCreate` 这一层没有隐私门，唯一门就是它；
 * 2. `init` 也在这枚键之后：`initializeAnalyticsIfNeeded` 里先查同意键、再查 opt-out，
 *    opt-out 分支 `return false` 早于 `UMConfigure.init(`；
 * 3. `CrashLogInstaller.install()` **只有一处**真实调用，且在那个局部函数
 *    `installCrashLogOnce()` 里——它必须待在开关分支之外（关上报时也要落盘），
 *    但也不能被塞进 `if (analyticsOptedOut)` 里当成「关掉才装」；
 * 4. 那句「关闭后…本地崩溃日志仍会记录」的**两句说明有生产渲染点**（摘要进 `subtitle`、
 *    整宽说明进 `text`），不是只写在 ARB / 测试里；
 * 5. `accepted_privacy_policy` **只写 `true`**：它是「同意过隐私」的钥匙，写 `false` 等于
 *    把同意状态抹掉；opt-out 用独立键，不许复用同意键。
 *
 * 档位：1–4 条判接线 / 结构，用中性化档；第 5 条判字面量与布尔值，用默认档（保留字符串）。
 */
class AnalyticsOptOutSwitchGuardTest {

    private val umeng = readKotlinSourceNoStrings(UMENG_APPLICATION)
    private val page = readKotlinSourceNoStrings(SELF_CHECK_PAGE)
    private val consent = readKotlinSourceNormalized(PRIVACY_CONSENT)
    private val optOut = readKotlinSourceNormalized(OPT_OUT_PREFS)

    @Test
    fun `preInit 与 init 同受一枚开关门控`() {
        assertEquals(
            "onCreate 里 UMConfigure.preInit 必须只有一处（多了就可能有一处漏门控）",
            1,
            countOf(umeng, "UMConfigure.preInit("),
        )
        assertSourceContains(
            windowBefore(umeng, "UMConfigure.preInit(", 400),
            "if (!analyticsOptedOut)",
            "$UMENG_APPLICATION 的 preInit 之前 400 字符",
        )

        assertEquals(
            "UMConfigure.init 必须只有一处（两处就说明有路径绕过了门控）",
            1,
            countOf(umeng, "UMConfigure.init("),
        )
        val beforeInit = windowBefore(umeng, "UMConfigure.init(", 600)
        assertSourceContains(beforeInit, "if (analyticsOptedOut)", "$UMENG_APPLICATION 的 init 之前 600 字符")
        assertSourceContains(beforeInit, "return false", "$UMENG_APPLICATION 的 init 之前 600 字符")
    }

    @Test
    fun `崩溃日志不在开关分支里 但仍只有一处调用`() {
        assertEquals(
            "CrashLogInstaller.install() 只许一处真实调用（FirstRunPrivacyWiringGuardTest 也钉这个数）",
            1,
            countOf(umeng, "CrashLogInstaller.install()"),
        )
        assertSourceContains(
            windowBefore(umeng, "CrashLogInstaller.install()", 300),
            "fun installCrashLogOnce()",
            "$UMENG_APPLICATION 的安装点之前 300 字符",
        )
        // 关闭上报的分支里调的是包装函数：说明「关了也落盘」这条是走同一条路径实现的。
        val optOutBranch = between(umeng, "if (analyticsOptedOut) {", "return false")
        assertSourceContains(optOutBranch, "installCrashLogOnce()", "$UMENG_APPLICATION 的 opt-out 分支")
    }

    @Test
    fun `开关的两句说明有生产渲染点`() {
        assertSourceContains(page, "subtitle = s.liveTestingAnalyticsOptOutSummary", SELF_CHECK_PAGE)
        assertSourceContains(page, "text = s.liveTestingAnalyticsOptOutDescription", SELF_CHECK_PAGE)
        assertSourceContains(page, "title = s.liveTestingAnalyticsOptOutTitle", SELF_CHECK_PAGE)
    }

    @Test
    fun `accepted_privacy_policy 只写 true 且与开关键分开`() {
        assertSourceContains(consent, "putBool(KEY_ACCEPTED_PRIVACY_POLICY, true)", PRIVACY_CONSENT)
        assertSourceLacks(consent, "putBool(KEY_ACCEPTED_PRIVACY_POLICY, false)", PRIVACY_CONSENT)
        assertSourceContains(consent, "const val KEY_ACCEPTED_PRIVACY_POLICY", PRIVACY_CONSENT)
        // 开关用独立键：复用同意键会把「关掉上报」变成「撤销隐私同意」。
        assertSourceContains(optOut, "const val KEY_ANALYTICS_OPT_OUT = \"analytics_opt_out\"", OPT_OUT_PREFS)
    }

    // ───────── 小工具（都在源码字符串上做，读不到就抛，不会静默通过） ─────────

    private fun countOf(source: String, needle: String): Int {
        var count = 0
        var index = source.indexOf(needle)
        while (index >= 0) {
            count++
            index = source.indexOf(needle, index + needle.length)
        }
        return count
    }

    private fun windowBefore(source: String, anchor: String, span: Int): String {
        val index = source.indexOf(anchor)
        check(index >= 0) { "找不到锚点：$anchor" }
        return source.substring(maxOf(0, index - span), index)
    }

    private fun between(source: String, start: String, end: String): String {
        val from = source.indexOf(start)
        check(from >= 0) { "找不到起点：$start" }
        val to = source.indexOf(end, from)
        check(to > from) { "找不到终点：$end" }
        return source.substring(from, to)
    }

    private companion object {
        const val UMENG_APPLICATION = "android/app/src/main/kotlin/com/mutx163/qingyu/UmengApplication.kt"
        const val PRIVACY_CONSENT =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/guide/PrivacyConsentPreferences.kt"
        const val OPT_OUT_PREFS =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/guide/AnalyticsOptOutPreferences.kt"
        const val SELF_CHECK_PAGE =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/settings/SettingsLiveSelfCheckPage.kt"
    }
}
