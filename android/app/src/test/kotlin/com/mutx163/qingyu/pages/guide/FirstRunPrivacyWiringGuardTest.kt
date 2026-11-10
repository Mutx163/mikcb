package com.mutx163.qingyu.pages.guide

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首启隐私门的**源码接线守卫**（B1，2026-11-10）。
 *
 * 为什么需要它：这类接线最容易「模型绿、界面没接」——`PrivacyConsentPreferences`
 * 单测全绿，但壳冷启动没调闸、或路由又把指南换回复看模式，用户照样第一次就能跳过
 * 隐私页。判据与 `DiagnosticsWiringGuardTest` 同一套：读源码文本，断真宿主/真调用在。
 *
 * 换宿主或换闸名时这条会先红——**那是故意的**，提醒改接线的人同步更新断言。
 */
class FirstRunPrivacyWiringGuardTest {

    @Test
    fun `冷启动必须先过首启门再挂壳`() {
        val source = source("android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt")

        assertTrue(
            "PagesShellActivity 里找不到 FirstRunPrivacyGate( —— 首启闸没接进冷启动路径",
            "FirstRunPrivacyGate(" in source,
        )
        assertTrue(
            "PagesShellActivity 里找不到 isFirstRunComplete() —— 冷启动没读两枚契约键",
            "isFirstRunComplete()" in source,
        )
        assertTrue(
            "PagesShellActivity 里找不到 if (firstRunDone) —— 壳没有按闸状态分流",
            "if (firstRunDone)" in source,
        )
    }

    @Test
    fun `通知权限申请必须排在首启门之后`() {
        val source = source("android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt")
        val gateAt = source.indexOf("LaunchedEffect(firstRunDone)")
        val permissionAt = source.indexOf("requestNotificationPermissionOnce()")

        assertTrue("找不到 LaunchedEffect(firstRunDone)", gateAt >= 0)
        assertTrue("找不到 requestNotificationPermissionOnce() 调用", permissionAt >= 0)
        assertTrue(
            "通知权限申请出现在首启门之前（隐私同意前就会弹系统权限框）",
            permissionAt > gateAt,
        )
    }

    @Test
    fun `复看路由也必须走抽出的宿主`() {
        val source = source("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")

        assertTrue(
            "ShellPageIndex 的 i.userGuide 分支没接 UserGuideHost（又退回直拼渲染层？）",
            "UserGuideHost(" in source,
        )
        val guideRoute = source.substringAfter("\"i.userGuide\"")
        assertTrue(
            "i.userGuide 分支里没有 UserGuideHost( —— 分支体被改回空实现或旧写法",
            guideRoute.substringBefore("\"i.more\"").contains("UserGuideHost("),
        )
    }

    @Test
    fun `友盟初始化必须查同意标记`() {
        val source = source("android/app/src/main/kotlin/com/mutx163/qingyu/UmengApplication.kt")

        assertTrue(
            "UmengApplication 里没有 initializeAnalyticsIfConsented —— 生产路径没有「已同意才 init」入口",
            "initializeAnalyticsIfConsented" in source,
        )
        assertTrue(
            "initializeAnalyticsIfConsented 里没有读 accepted_privacy_policy",
            "hasAcceptedPrivacyPolicy()" in source,
        )
    }

    @Test
    fun `指南页必须把勾选态回传宿主`() {
        val source = source(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/guide/UserGuidePage.kt",
        )

        assertTrue(
            "UserGuidePage 没有 onPrivacyConsentChanged 参数 —— 宿主拿不到真实勾选状态",
            "onPrivacyConsentChanged" in source,
        )
        assertTrue(
            "UserGuidePage 的勾选回调没有外抛（只更新了内部 privacyChecked）",
            "onPrivacyConsentChanged(it)" in source,
        )
    }

    /** 从工作目录向上找仓库根，与 `DiagnosticsWiringGuardTest` 同一套做法。 */
    private fun source(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
