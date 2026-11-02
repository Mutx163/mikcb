package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「从设置页返回首页，首页必须重读设置」的接线守卫（2026-11-02 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 用户实报：外观编辑页改完材质，点「完成」回首页，材质还是**旧**的；左右滑一下
 * （翻页 → 仓储状态变化 → 逼出一次重组）才突然变成新样式。
 *
 * 根因是设置存储**没有变更通道**（`TimetableSettingsModelStore` 只有 `load` / `save`），
 * 而首页各视图在组合期裸调 `settingsModel.load()` 读盘 —— 这既不是可观察状态，也不会
 * 让 Compose 建立依赖。从页面层退回主屏时，首页条目一直被 NavDisplay 保持组合、参数
 * 又都没变（Compose 强跳过会把捕获值相等的 lambda 记住），整棵页面内容被跳过 ⇒
 * `load()` 不会重跑。以前「靠 `onBack` / `onOpenPage` 两个不稳定 lambda 补一次重读」
 * 的写法在强跳过下已经不成立。
 *
 * 修法：壳持有可观察的 `ShellWiring.settingsRevision`，回到主屏时自增；首页各视图把它
 * 读进 `remember` 键里，自增即重读。本守卫钉住三件事：
 *
 * 1. 序号存在且是可观察状态；
 * 2. 三个首页视图（周 / 日 / 月）都**订阅**了它（只增不读 = 没有效果）；
 * 3. 回到主屏的那一处真的自增（漏了 = 返回时不刷新）。
 *
 * ## 为什么读源码文本
 *
 * 「某个 composable 有没有读某个 state」在编译产物里看不出来（强跳过下更看不出来），
 * 反射也不保留。与同目录 `DayViewWiringGuardTest` / `DiagnosticsWiringGuardTest`
 * 同一套做法：判据是「出现/不出现某些字样」，不依赖缩进与折行。
 */
class HomeSettingsRefreshGuardTest {

    @Test
    fun `壳必须提供可观察的设置变更序号`() {
        val wiring = readSource("${MAIN}/pages/ShellWiring.kt")
        assertTrue(
            "`ShellWiring` 里没有 `var settingsRevision: Int by mutableIntStateOf(0)`：" +
                "页面内容就没有「返回主屏时重读设置」的信号，材质会停在旧值上。",
            "var settingsRevision: Int by mutableIntStateOf(0)" in wiring,
        )
    }

    @Test
    fun `周视图必须订阅设置变更序号`() {
        val wiring = readSource("${MAIN}/pages/ShellWiring.kt")
        assertTrue(
            "`TimetableWithCourseActions`（c1.week 的宿主）没有读 " +
                "`wiring.settingsRevision`：返回首页时不会重组合，材质 / 壁纸不刷新。",
            "val settingsRevision = wiring.settingsRevision" in wiring,
        )
        assertTrue(
            "周视图的设置读取没有用 `remember(settingsRevision)` 当键：每帧解析 JSON 或" +
                "返回主屏不重读，二者必居其一。",
            "remember(settingsRevision) { wiring.settingsModel.load() }" in wiring,
        )
    }

    @Test
    fun `日视图与月视图必须订阅设置变更序号`() {
        val index = readSource("${MAIN}/pages/ShellPageIndex.kt")
        val subscriptions = Regex("""remember\(wiring\.settingsRevision\)""")
            .findAll(index)
            .count()
        assertTrue(
            "`ShellPageIndex.kt` 里订阅 `wiring.settingsRevision` 的分支只有 $subscriptions 处，" +
                "应当至少两处（`c2.month` 与 `c3.day`）：少哪个分支，哪个视图返回后不刷新材质。",
            subscriptions >= 2,
        )
    }

    @Test
    fun `回到主屏必须自增设置变更序号`() {
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        val effect = atRootEffectBody(shell)
        assertTrue(
            "`LaunchedEffect(atRoot)` 里没有 `onReloadSettings(`：主题 / 底栏不会随设置更新。",
            "onReloadSettings(" in effect,
        )
        assertTrue(
            "`LaunchedEffect(atRoot)` 里没有 `wiring.settingsRevision++`：返回主屏时首页内容" +
                "不会重读设置（用户 2026-11-02 实报的「返回后材质还是旧的」）。",
            "wiring.settingsRevision++" in effect,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：解析器坏了会让上面几条全部变绿 —— 那比没有守卫更糟。
        val shell = readSource("${MAIN}/pages/PagesShellActivity.kt")
        assertTrue(
            "`LaunchedEffect(atRoot)` 解析出来太短（${atRootEffectBody(shell).length} 字符），" +
                "解析可能坏了",
            atRootEffectBody(shell).length > 50,
        )
    }

    // ------------------------------------------------------------------ 解析

    /** 取出 `LaunchedEffect(atRoot) { ... }` 的函数体文本（按大括号配对，不含外层调用）。 */
    private fun atRootEffectBody(source: String): String {
        val marker = "LaunchedEffect(atRoot)"
        val start = source.indexOf(marker)
        if (start < 0) return ""
        val open = source.indexOf('{', start + marker.length)
        if (open < 0) return ""
        var depth = 0
        var i = open
        while (i < source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(open + 1, i)
                }
            }
            i++
        }
        return ""
    }

    /**
     * 从工作目录向上找仓库根再定位文件：L0 脚本与 Gradle 的工作目录不同，
     * 所以按「向上找标志文件」而不是写死相对路径；**找不到仍判失败**。
     */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val MAIN = "android/app/src/main/kotlin/com/mutx163/qingyu"
    }
}
