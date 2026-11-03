package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏左右滑转场的**壳层接线守卫**（2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * 底栏切换从「替换 miuix-nav 栈底路由（瞬时直切）」改成官方 demo 的 Pager 形态后，
 * 有两类静默回退编译期看不出来：
 *
 * 1. **自研转场回潮**：有人在壳/导航层抄一段 `AnimatedContent` / `slideIn…` / `fadeIn…`
 *    自己滑 —— MIUIX-FIRST 规定页面动效只能用官方能力（miuix-nav 的 NavDisplay 预设、
 *    官方 demo 的 Pager + `springAnimateToPage`），自研几何是禁区；
 * 2. **栈底替换复活**：把换底栏条目改回 `backStack[0] = Dock(...)` —— miuix-nav 对
 *    Replace 官方就是瞬时卸载旧条目，「闪现」立刻回来。
 *
 * ## 咬合探针
 *
 * 每条判据写成「文本 → 布尔」函数，并在同一用例里喂一份**故意改坏**的副本：改坏后
 * 必须为假（与 `ShellRailWiringGuardTest` 同一套路）。纯函数行为（方向 / 降级）的
 * 数值咬合探针在 `DockPagerMotionTest` 的 KDoc 里记录。
 */
class DockPagerWiringGuardTest {

    // ---------------------------------------------------------------- 壳层接线

    @Test
    fun `底栏切换必须走官方Pager形态`() {
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "壳层没有完整的 Pager 切换链（HorizontalPager + 手势关闭 + springAnimateToPage " +
                "+ 降级判据 + 方向判据）：底栏切页必须滑过去，不许闪现。",
            shellHasPagerMotion(activity),
        )
        // 反向探针：动画引擎被摘掉，判据必须红。
        assertFalse(
            "咬合探针失效：摘掉 springAnimateToPage 后判据仍为真",
            shellHasPagerMotion(activity.replace("springAnimateToPage(", "X(")),
        )
    }

    @Test
    fun `壳与导航层不许出现自研转场`() {
        val activity = codeOnly(source(ACTIVITY))
        val route = codeOnly(source(ROUTE))
        assertTrue(
            "壳层出现了自研转场 API（${FORBIDDEN.joinToString()}）——页面动效只能用 " +
                "miuix 官方能力（NavDisplay 预设 / 官方 demo 的 Pager + springAnimateToPage）",
            shellHasNoSelfMadeTransition(activity),
        )
        assertTrue(
            "ShellRoute.kt 出现了自研转场 API —— 路由文件不该有任何动画代码",
            shellHasNoSelfMadeTransition(route),
        )
        // 反向探针：注入违规 API，判据必须红。
        assertFalse(
            "咬合探针失效：注入 AnimatedContent 后判据仍为真",
            shellHasNoSelfMadeTransition(activity + "\nval x = AnimatedContent(a) { it }\n"),
        )
    }

    @Test
    fun `栈底替换不许复活`() {
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "壳层又出现了栈底替换（instantOnReplace / backStack[0] = ...）：" +
                "miuix-nav 对 Replace 官方就是瞬时直切，换底栏条目只能改 currentRootId 走 Pager 滑动",
            shellHasNoStackBottomReplace(activity),
        )
        val route = codeOnly(source(ROUTE))
        assertTrue(
            "ShellRoute.Dock 必须保持无参 data object：带 itemId 的 Dock 会让切底栏变成栈底替换",
            route.contains("data object Dock : ShellRoute"),
        )
        // 反向探针：把 Dock 改回带参 data class，判据必须红。
        val broken = route.replace("data object Dock", "data class Dock")
        assertFalse(
            "咬合探针失效：Dock 改回 data class 后判据仍为真",
            broken.contains("data object Dock : ShellRoute"),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：文本解析一旦因格式变化失效，上面几条「零违规」会全部变绿。
        val activity = source(ACTIVITY)
        assertTrue(
            "PagesShellActivity.kt 读出来太短（${activity.length} 字符），解析可能坏了",
            activity.length > 1000,
        )
        val pagerBranch = branchOf(codeOnly(activity), "entry<ShellRoute.Dock>")
        assertTrue(
            "entry<ShellRoute.Dock> 分支解析出来太短（${pagerBranch.length} 字符），定位可能失效",
            pagerBranch.length >= 200,
        )
        assertTrue(
            "主屏分支里没有 HorizontalPager —— Pager 形态不在这个分支里，接线被挪走了？",
            pagerBranch.contains("HorizontalPager("),
        )
    }

    // ------------------------------------------------------------------ 判据

    private fun shellHasPagerMotion(text: String): Boolean =
        text.contains("HorizontalPager(") &&
            text.contains("userScrollEnabled = false") &&
            text.contains("springAnimateToPage(") &&
            text.contains("pagerState.scrollToPage(") &&
            text.contains("DockPagerMotion.reducedMotion(") &&
            text.contains("ANIMATOR_DURATION_SCALE") &&
            text.contains("DockPagerMotion.slideStep(")

    private fun shellHasNoSelfMadeTransition(text: String): Boolean =
        FORBIDDEN.none { text.contains(it) }

    private fun shellHasNoStackBottomReplace(text: String): Boolean =
        !text.contains("instantOnReplace") && !text.contains("backStack[0]")

    // ------------------------------------------------------------------ 定位

    /** 只留代码：剥掉块注释与行注释，历史注释里的旧写法不参与判定。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    /** 截取从 marker 起到下一个同级 entry 分支（或 6000 字上限）的那段文本。 */
    private fun branchOf(source: String, marker: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到分支标记 $marker" }
        val rest = source.substring(start + marker.length)
        val sibling = rest.indexOf("entry<ShellRoute.")
        return rest.take(if (sibling > 0) sibling else 6000)
    }

    /** 从工作目录向上找仓库根，再读文件；与同目录守卫测试同一套做法。 */
    private fun source(relativePath: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relativePath)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relativePath（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val ACTIVITY =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"

        const val ROUTE =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellRoute.kt"

        /**
         * 自研转场的标志性 API（MIUIX-FIRST 禁区）。判据只认代码文本（注释已剥），
         * 所以历史注释里提到这些词不误伤。
         */
        val FORBIDDEN = listOf(
            "AnimatedContent(",
            "slideInHorizontally(",
            "slideInVertically(",
            "fadeIn(",
            "fadeOut(",
            "PageRouteBuilder(",
        )
    }
}
