package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 语言切换必须**原地刷新**，不许把壳整棵重建。
 *
 * 背景（2026-11-07 用户实报）：切语言后界面没变，修好回推链后又出现「切完被弹回首页」——
 * 原因是壳用 `key(AppLocaleRuntime.tag)` 把整棵 `PagesShell` 重建了，返回栈随之清空。
 *
 * 正确形态：`ArbText.text` 每次取值读一下 `AppLocaleRuntime.revisionReader()`；
 * UI 桥把它接到 Compose snapshot state，语言变化时自增 revision，正在显示的文案自动重组，
 * 导航栈、滚动位置、表单草稿全部保留。
 */
class LanguageSwitchLiveUpdateGuardTest {

    @Test
    fun `壳不重建 只靠重组刷新文案`() {
        val shell = read("android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt")
        assertTrue(
            "PagesShellActivity 没有安装 AppLocaleUiBridge：语言变化不会被 Compose 观察到",
            "AppLocaleUiBridge.install()" in shell,
        )
        assertFalse(
            "又用 `key(AppLocaleRuntime.tag)` 重建整棵壳了：切语言会丢返回栈、弹回首页。",
            "key(AppLocaleRuntime.tag)" in shell,
        )
    }

    @Test
    fun `text 读订阅点 语言变化能被 Composition 观察`() {
        val arb = read("android/app/src/main/kotlin/com/mutx163/qingyu/app/ArbText.kt")
        assertTrue(
            "`ArbText.text` 没有读 `revisionReader()`：Composable 不会订阅语言变化",
            "revisionReader()" in arb,
        )
        val bridge = read(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppLocaleUiBridge.kt",
        )
        assertTrue(
            "UI 桥没有把 revisionReader 接到 snapshot state",
            "revisionReader = { revision }" in bridge,
        )
        assertTrue(
            "UI 桥没有在语言变化时自增 revision",
            "onLocaleChanged = { revision++ }" in bridge,
        )
    }

    private fun read(relative: String): String {
        val file = File(repoRoot(), relative)
        assertTrue("找不到源文件：${file.absolutePath}", file.isFile)
        return file.readText(Charsets.UTF_8)
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "lib/l10n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（lib/l10n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}
