package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏墨色的**接线守卫**（2026-11-03）。判据一律先剥注释再判。
 *
 * 防的是四类编译期看不出来的静默回退：
 *
 * 1. 墨色又回到固定主题色（`onBackground` / `tabContentColor`）——壁纸一亮一暗就翻车；
 * 2. 标签与图标各吃一套颜色（图标读 `LocalContentColor`、文字走别的 provider），
 *   真机上就会「图标还行、字发灰」；
 * 3. 壳没有把「这一页底下是不是壁纸」告诉坞，内嵌实色页被按壁纸亮度判；
 * 4. 壁纸亮度取错带（用正文带 0.22~0.72 代替坞自己压住的 0.78~0.96）。
 */
class DockInkGuardTest {

    @Test
    fun `坞的墨色必须走唯一判据且标签图标共用`() {
        val bar = codeOnly(source(BAR))
        assertTrue(
            "GlassDockNavigationBar 没有接 DockInkRule（effectiveLuminance + resolve）：" +
                "墨色回到固定主题色时，暗壁纸上的底栏字会看不见",
            sharedInkResolution(bar),
        )
        // 反向探针 1：判据被摘掉，必须红。
        assertFalse(
            "咬合探针失效：摘掉 DockInkRule.resolve 后判据仍为真",
            sharedInkResolution(bar.replace("DockInkRule.resolve(", "X(")),
        )
        // 反向探针 2：文字绕过共用判定（改回整条统一色），必须红。
        assertFalse(
            "咬合探针失效：把 itemInk 换回统一色后判据仍为真",
            sharedInkResolution(bar.replace("provides itemInk", "provides unselectedInk")),
        )
    }

    @Test
    fun `壳必须告诉坞这一页底下是不是壁纸`() {
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "壳没有传 overWallpaper = DockPagerMotion.showsWallpaper(currentRootId)：任务 / 设置" +
                "这类不透明页会被按壁纸亮度判，浅色主题 + 暗壁纸会给浅底配白字",
            shellFlagsOverWallpaper(activity),
        )
        val broken = activity.replace(
            "overWallpaper = DockPagerMotion.showsWallpaper(currentRootId)",
            "overWallpaper = true",
        )
        assertFalse("咬合探针失效：overWallpaper 写死后判据仍为真", shellFlagsOverWallpaper(broken))
    }

    @Test
    fun `壁纸亮度必须取坞压住的那条带`() {
        val dock = codeOnly(source(DOCK))
        assertTrue(
            "HomeGlassDock 没有把坞那条壁纸带（bands.dock）传下去：用正文带会在" +
                "「正文亮、照片下半部暗」时判错（用户截图即此构图）",
            dockUsesDockBand(dock),
        )
        assertFalse(
            "咬合探针失效：把 dock 带换成 body 带后判据仍为真",
            dockUsesDockBand(dock.replace("?.dock", "?.body")),
        )
    }

    @Test
    fun `判据阈值与旧版一致且不写死色值`() {
        val rule = source(RULE)
        assertTrue(
            "DockInkRule 的翻面阈值不是 0.45（Dart timetable_glass_dock.dart:165 同口径）",
            rule.contains("INK_FLIP_LUMINANCE = 0.45"),
        )
        assertTrue(
            "DockInkRule 里出现了写死色值（Color(0x…)）；墨色本体必须由主题令牌提供",
            !Regex("""Color\(0x""").containsMatchIn(rule),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        assertTrue("GlassDockNavigationBar.kt 读出来太短，解析可能坏了", source(BAR).length > 5000)
        assertTrue("HomeGlassDock.kt 读出来太短，解析可能坏了", source(DOCK).length > 2000)
        assertTrue("DockInkRule.kt 读出来太短，解析可能坏了", source(RULE).length > 1000)
    }

    // ------------------------------------------------------------------ 判据

    private fun sharedInkResolution(text: String): Boolean {
        if (!text.contains("DockInkRule.effectiveLuminance(")) return false
        if (!text.contains("DockInkRule.resolve(")) return false
        if (!text.contains("CompositionLocalProvider(LocalContentColor provides itemInk)")) return false
        if (text.contains("onBackground") || text.contains("tabContentColor")) return false
        // 图标与文字必须都在同一个 provider 里面（两者都继承 LocalContentColor）。
        val providerIndex = text.indexOf("CompositionLocalProvider(LocalContentColor provides itemInk)")
        val block = text.substring(providerIndex)
        return block.contains("Icon(") && block.contains("Text(")
    }

    private fun shellFlagsOverWallpaper(text: String): Boolean =
        text.contains("overWallpaper = DockPagerMotion.showsWallpaper(currentRootId)")

    // 2026-11-04：坞改为「响应式回读 cachedWallpaperInkBands(...)?.dock」+ 可传入参，
    // 不再直接读一次性的 chrome.bands.dock。判据改成「取 dock 带 + 响应式合并」。
    private fun dockUsesDockBand(text: String): Boolean =
        text.contains("cachedWallpaperInkBands(") &&
            text.contains("?.dock") &&
            text.contains("wallpaperLuminance ?: cachedDockLuminance")

    // ------------------------------------------------------------------ 定位

    /** 只留代码：剥掉块注释与行注释，历史注释里的旧写法不参与判定。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

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
        const val SHELL_DIR_COMPOSE = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/shell"
        const val SHELL_DIR_MAIN = "android/app/src/main/kotlin/com/mutx163/qingyu/pages/shell"

        const val BAR = "$SHELL_DIR_COMPOSE/GlassDockNavigationBar.kt"
        const val DOCK = "$SHELL_DIR_COMPOSE/HomeGlassDock.kt"
        const val RULE = "$SHELL_DIR_MAIN/DockInkRule.kt"
        const val ACTIVITY = "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
    }
}
