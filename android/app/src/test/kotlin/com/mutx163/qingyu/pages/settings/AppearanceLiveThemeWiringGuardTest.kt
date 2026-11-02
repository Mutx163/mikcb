package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 外观与配色页「改了设置当场生效」的接线守卫（2026-11-02 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 外观页的六个写入控件（主题模式 / 字体 / 字重 / 字号 / 预设主题 / 恢复默认）一直
 * 都在往设置模型里写，但主题桥（`QingyuPageTheme`）在壳 Activity 那一层，设置存储
 * 又没有变更通道 —— 用户在外观页选「深色」、拖字号滑杆、换主题色，屏上**一点变化
 * 都没有**，要退出到主屏才换肤。看起来就是「这些设置没接上」。
 *
 * 还有一层更隐蔽：页面骨架与十几个独立页面都会自己再包一层无参
 * `QingyuPageTheme { }`，而那一层的默认参数原本是「种子色 null / 字重 400 /
 * 字族 null / 字号 1.0」——把壳里选好的外观**静默覆盖回默认值**。所以只把模型
 * 回推给壳还不够，主题桥本身必须默认继承外层档位。
 *
 * ## 本守卫钉住四件事
 *
 * 1. `QingyuPageTheme` 的四个外观形参默认取 `LocalQingyuPageAppearance`（继承）；
 * 2. 字号缩放用「缩放前基准 density」，嵌套包裹不会把 fontScale 平方；
 * 3. `SettingsHost` 有 `onModelChanged` 回推，并在滑杆拖动 / 落盘校验 / 写盘失败
 *    回滚三条路径上都发；
 * 4. 壳把外观 / 主题管理 / 恢复默认三页接到 `onSettingsChanged`，Activity 再接到
 *    顶层的 `settingsModel` 状态（`onReloadSettings`）。
 *
 * ## 为什么读源码文本
 *
 * 「某个 composable 有没有读某个 state / 某个参数有没有接上」在编译产物与反射里
 * 都看不到（Compose 强跳过下更看不出来）。与 `HomeSettingsRefreshGuardTest`
 * 同一套做法：判据是「出现 / 出现几次」，不依赖缩进与折行；找不到文件**判失败
 * 而不是跳过**。
 */
class AppearanceLiveThemeWiringGuardTest {

    @Test
    fun `主题桥默认继承外层外观档位`() {
        val source = readSource("$COMPOSE/components/QingyuPageTheme.kt")
        val required = listOf(
            "seedColor: String? = LocalQingyuPageAppearance.current.seedColor",
            "userFontWeight: Int = LocalQingyuPageAppearance.current.userFontWeight",
            "fontFamily: FontFamily? = LocalQingyuPageAppearance.current.fontFamily",
            "textScale: Float = LocalQingyuPageAppearance.current.textScale",
        )
        val missing = required.filter { it !in source }
        assertEquals(
            "QingyuPageTheme 的这些形参不再默认继承外层外观档位，页面里再包一层时会把" +
                "用户选的主题色 / 字重 / 字体覆盖回默认值：",
            emptyList<String>(),
            missing,
        )
        assertTrue(
            "QingyuPageTheme 必须提供 LocalQingyuPageAppearance（否则「继承」读到的是空实现）",
            "LocalQingyuPageAppearance provides" in source,
        )
    }

    @Test
    fun `字号缩放使用缩放前基准避免嵌套平方放大`() {
        val source = readSource("$COMPOSE/components/QingyuPageTheme.kt")
        assertTrue(
            "字号缩放必须先读 LocalQingyuBaseDensity（缩放前基准）；直接用 LocalDensity.current " +
                "会让嵌套的页面主题把 fontScale 乘两次（1.2 变 1.44）。",
            "LocalQingyuBaseDensity.current ?: LocalDensity.current" in source,
        )
        assertTrue(
            "基准 density 必须继续往下传，否则更内层的包裹又拿不到基准",
            "LocalQingyuBaseDensity provides baseDensity" in source,
        )
    }

    @Test
    fun `设置宿主提供模型变更回推`() {
        val source = readSource("$COMPOSE/app/SettingsHost.kt")
        assertTrue(
            "SettingsHost 没有 `onModelChanged` 形参：外观页改完设置只能等回主屏才生效。",
            "onModelChanged: (TimetableSettingsModel) -> Unit = {}" in source,
        )
        assertTrue(
            "非滑杆写入（下拉 / 开关 / 恢复默认）没有回推",
            "onModelChanged(model)" in source,
        )
        assertTrue(
            "滑杆拖动中没有回推：字重 / 字号 / 材质预览不会跟手",
            "onModelChanged(result.model)" in source,
        )
        assertTrue(
            "防抖落盘失败回滚后没有回推：界面会停在没存下的档位",
            "latestOnModelChanged(model)" in source,
        )
    }

    @Test
    fun `外观与主题页把回推接到壳`() {
        val index = readSource("$MAIN/pages/ShellPageIndex.kt")
        assertTrue(
            "ShellPageContent 没有 `onSettingsChanged` 形参",
            "onSettingsChanged: (TimetableSettingsModel) -> Unit = {}" in index,
        )
        val wired = Regex("""onModelChanged = onSettingsChanged""").findAll(index).count()
        assertEquals(
            "外观 / 主题管理 / 恢复默认三页里接上即时回推的只有 $wired 处，应当恰好 3 处" +
                "（少哪页，哪页改完设置就不换肤）。",
            3,
            wired,
        )

        val shell = readSource("$MAIN/pages/PagesShellActivity.kt")
        val forwarded = Regex("""onSettingsChanged = onReloadSettings""").findAll(shell).count()
        assertTrue(
            "PagesShellActivity 里把 `onSettingsChanged` 接到 `onReloadSettings` 的只有 " +
                "$forwarded 处（主屏 / 普通页 / 缩放页三条 ShellPageContent 都要接）。",
            forwarded >= 3,
        )
    }

    // ------------------------------------------------------------------ 解析

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
        const val COMPOSE = "android/app/src/composeP1/kotlin/com/mutx163/qingyu"
    }
}
