package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏「黑底黑字」修复的**接线守卫**（2026-11-04）。
 *
 * 三件事一起守，缺一条就复发「深/黑壁纸时坞字看不见」：
 * 1. 坞亮度不再只靠 `chrome.bands` 的一次性冷读：改为读缓存版本 + 回读 `cachedWallpaperInkBands(...)?.dock`，
 *    并把调用方可传入的 `wallpaperLuminance` 优先合并（`wallpaperLuminance ?: cachedDockLuminance`）；
 * 2. 缓存写入后 `wallpaperInkBandsCacheVersionState.value++`，让坞能重组回读到刚量出的真值；
 * 3. `GlassDockNavigationBar` 兜底：`overWallpaper && isBlurActive && wallpaperLuminance == null` 时
 *    保守取浅墨（`DockInkRule.resolve(0.0)`），绝不拿纯白 `surfaceContainer` 判深墨。
 *
 * 每一条都带负例自测（改坏→红）。
 */
class DockInkFallbackGuardTest {

    private val bar: String by lazy { codeOnly(read(BAR)) }
    private val dock: String by lazy { codeOnly(read(DOCK)) }
    private val backdrop: String by lazy { codeOnly(read(BACKDROP)) }

    @Test
    fun `面板亮度未知时坞取浅墨兜底`() {
        assertTrue(
            "GlassDockNavigationBar 缺「壁纸页且亮度未知→浅墨」兜底分支",
            fallbackPresent(bar),
        )
        // 负例：把兜底条件抹成 false，判据必须变红。
        assertFalse(
            "咬合探针失效：兜底条件抹掉后仍判为真",
            fallbackPresent(bar.replace("overWallpaper && isBlurActive && wallpaperLuminance == null", "false")),
        )
    }

    @Test
    fun `坞亮度响应式回读缓存并可被入参覆盖`() {
        assertTrue("HomeGlassDock 缺 cachedWallpaperInkBands 回读", dock.contains("cachedWallpaperInkBands("))
        assertTrue("HomeGlassDock 缺缓存版本订阅", dock.contains("wallpaperInkBandsCacheVersion()"))
        assertTrue("HomeGlassDock 缺「入参优先」合并", dock.contains("wallpaperLuminance ?: cachedDockLuminance"))
    }

    @Test
    fun `缓存写入后置位版本号`() {
        assertTrue(
            "HomeWallpaperBackdrop 写完缓存后没有 wallpaperInkBandsCacheVersionState.value++",
            backdrop.contains("wallpaperInkBandsCacheVersionState.value++"),
        )
        assertFalse(
            "咬合探针失效：删掉版本自增后仍判为真",
            backdrop.replace("wallpaperInkBandsCacheVersionState.value++", "").contains(
                "wallpaperInkBandsCacheVersionState.value++",
            ),
        )
    }

    @Test
    fun `负例自测_入参合并被删会被判红`() {
        assertTrue(reactiveMerge(dock))
        assertFalse(
            "把响应式合并改成仅入参后应判红",
            reactiveMerge(dock.replace("wallpaperLuminance ?: cachedDockLuminance", "wallpaperLuminance")),
        )
    }

    private fun fallbackPresent(text: String): Boolean =
        text.contains("overWallpaper && isBlurActive && wallpaperLuminance == null") &&
            text.contains("DockInkRule.resolve(0.0")

    private fun reactiveMerge(text: String): Boolean =
        text.contains("cachedWallpaperInkBands(") && text.contains("wallpaperLuminance ?: cachedDockLuminance")

    /** 只留代码：剥块注释 + 行注释，注释里的历史写法不参与判定。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    private fun read(relativePath: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relativePath)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        throw AssertionError("找不到 $relativePath —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val SHELL = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/shell"
        const val BAR = "$SHELL/GlassDockNavigationBar.kt"
        const val DOCK = "$SHELL/HomeGlassDock.kt"
        const val BACKDROP = "$SHELL/HomeWallpaperBackdrop.kt"
    }
}
