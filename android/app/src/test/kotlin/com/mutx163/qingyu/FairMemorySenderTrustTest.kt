package com.mutx163.qingyu

import android.os.Process
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 公平内存广播发送方校验（2026-10-19 审计 #23）。
 *
 * exported 动态接收器任何应用都能发广播过来；这里钉住白名单口径：
 * 系统 uid / 本应用 / 系统应用包放行，第三方应用一律拒绝。
 */
class FairMemorySenderTrustTest {
    private val isSystemPackage: (String) -> Boolean = { pkg ->
        pkg == "com.miui.securitycenter" || pkg == "com.oplus.safecenter"
    }

    @Test
    fun systemUidSendersAreTrusted() {
        // system_server（uid 1000）：ITGSA 官方路径的发送方。
        assertTrue(
            isFairMemorySenderTrusted(
                sdkInt = 34,
                myUid = 10200,
                sentFromUid = Process.SYSTEM_UID,
                sentFromPackage = "android",
                isSystemPackage = isSystemPackage,
            ),
        )
        // root（uid 0）与系统 uid 段上限内（9999 < FIRST_APPLICATION_UID=10000）。
        assertTrue(
            isFairMemorySenderTrusted(34, 10200, 0, null, isSystemPackage),
        )
        assertTrue(
            isFairMemorySenderTrusted(34, 10200, 9999, "com.android.system", isSystemPackage),
        )
    }

    @Test
    fun ownUidIsTrusted() {
        assertTrue(
            isFairMemorySenderTrusted(34, 10200, 10200, "com.mutx163.qingyu", isSystemPackage),
        )
    }

    @Test
    fun thirdPartyAppUidIsRejected() {
        // 普通 uid（≠ 本应用 uid），包不在系统应用白名单：拒绝。
        assertFalse(
            isFairMemorySenderTrusted(34, 10200, 10233, "com.evil.app", isSystemPackage),
        )
        // uid 段可疑但读不到发送方包名：拒绝（fail-closed）。
        assertFalse(
            isFairMemorySenderTrusted(34, 10200, 10233, null, isSystemPackage),
        )
    }

    @Test
    fun systemAppWithDedicatedAppUidIsTrusted() {
        // 个别 OEM 服务持应用段独占 uid，但包是系统应用：放行。
        assertTrue(
            isFairMemorySenderTrusted(34, 10200, 10255, "com.miui.securitycenter", isSystemPackage),
        )
    }

    @Test
    fun preApi34KeepsLegacyAllowAllBehavior() {
        // Android < 14 没有公开 API 读发送方身份，保持既有放行行为。
        assertTrue(
            isFairMemorySenderTrusted(33, 10200, 10200, "com.evil.app", isSystemPackage),
        )
        assertTrue(
            isFairMemorySenderTrusted(28, 10200, 10200, null, isSystemPackage),
        )
    }
}
