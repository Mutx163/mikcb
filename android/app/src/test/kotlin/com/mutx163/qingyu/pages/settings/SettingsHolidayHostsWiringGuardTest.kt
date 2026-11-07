package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 节假日两页**宿主层**的接线回归网（2026-11-05 修的两处「界面看起来有、实际不通」）。
 *
 * ## 修的是什么
 *
 * 1. **「检查更新」的结果提示就是按钮名本身**：修前成功也弹
 *    `SettingsStringsExt3.holidayCheckUpdate`（= 按钮文案「检查更新」），失败分支根本不弹。
 *    动作本身从不抛（provider 内部兜内置资产），所以「runCatching 成功」不代表数据更新了——
 *    得看 `HolidaySnapshot.remoteFetchSucceeded`。
 * 2. **首屏把「加载中」显示成「近期没有节假日」**：`initialize()` 在 IO 上跑、远端超时 8 秒，
 *    这段时间用户分不清「还没有数据」和「真的没有」。
 *
 * ## 为什么读源码文本
 *
 * 与 `TimetableHolidayWiringGuardTest` 同一套做法：`src/test` 只挂 `main` 源集，
 * composeP1 的 Compose 源码编不进来。找不到文件**判失败而不是跳过**。
 *
 * 咬合探针（已实测）：
 * - 把 `SettingsHolidayHost.kt` 的 `loading = initializing && snapshot.data == null`
 *   改回 `loading = false`（或不传）→ 第 1 条红；
 * - 把高级页的结果文案改回 `SettingsStringsExt3.holidayCheckUpdate.zh` → 第 3、4 条红。
 */
class SettingsHolidayHostsWiringGuardTest {

    @Test
    fun `首屏加载态真的接到页面上 而不是恒 false`() {
        val host = hostSource("SettingsHolidayHost.kt")
        assertTrue(
            "宿主必须把「首次 initialize 未完成且还没有数据」这个判据传给页面",
            "loading = initializing && snapshot.data == null" in host,
        )
        assertFalse(
            "loading 不许写死 false（页面永远出不了加载态）",
            "loading = false" in host,
        )
    }

    @Test
    fun `initialize 抛异常也要退出加载态`() {
        val host = hostSource("SettingsHolidayHost.kt")
        assertTrue(
            "initialize 必须包 runCatching：抛了就不会往下走，initializing 会永远停在 true（永久加载中）",
            "runCatching { withContext(Dispatchers.IO) { provider.initialize() } }" in host,
        )
        assertTrue(
            "不管成功失败都要落 loading=false",
            "initializing = false" in host,
        )
    }

    @Test
    fun `检查更新的提示按结果分流 而不是弹按钮名`() {
        val host = hostSource("SettingsHolidayAdvancedHost.kt")
        assertTrue(
            "结果要看 remoteFetchSucceeded（动作成功 ≠ 数据更新了）",
            "remoteFetchSucceeded" in host,
        )
        assertTrue(
            "成功要给结果句",
            "holidayDataUpdated" in host,
        )
        assertTrue(
            "失败要给失败句（原来失败分支完全不提示）",
            "holidayDataUpdateFailed" in host,
        )
        assertFalse(
            "提示不许再用按钮名 holidayCheckUpdate（用户看到的是「检查更新」飘过，等于没说结果）",
            "SettingsStringsExt3.holidayCheckUpdate.zh" in host,
        )
    }

    @Test
    fun `失败分支不再被 runCatching 的 isSuccess 吞掉`() {
        val host = hostSource("SettingsHolidayAdvancedHost.kt")
        // 修前写法：`val ok = runCatching { … }.isSuccess` —— provider 从不抛，恒 true，
        // 于是「失败了」永远走成功分支。现在必须 fold 出三态（true / false / null）。
        assertFalse(
            "不许再只看 runCatching().isSuccess 判断结果",
            ".isSuccess" in host,
        )
        assertTrue("失败要落到 false（fold 的 onFailure 分支）", "onFailure = { false }" in host)
    }

    // ------------------------------------------------------------ 工具

    private fun hostSource(name: String): String {
        val file = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/app/$name")
        assertTrue("${file.path} 不存在", file.isFile)
        // Windows 上是 CRLF；断言里有跨行片段时 CR 会让匹配失败，这里统一成 LF。
        return file.readText().replace("\r\n", "\n")
    }

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }
}
