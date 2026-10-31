package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SettingsActionDispatcher
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置族**动作通道**接线守卫（一轮审核 P0 的回归网）。
 *
 * ## 它守的是什么（2026-10-29 的真实缺陷）
 *
 * `SettingsHost.onIntent` 的默认值是空实现、壳一处都没传，于是分派器把动作翻成
 * `ClipboardExport` / `ShowDialog` / `ShowSheet` / `ShowRecolorSheet` 之后
 * **全仓 0 消费者** —— 主题管理页四处 + 课卡「重新配色」点了完全没反应，
 * 而编译能过、模型层单测全绿、真机上才看得见。
 *
 * 所以这里钉三件事：
 * 1. 默认值**不许**再是 `= {}`（一旦回到空实现，任何人都可能再漏一次）；
 * 2. 五种界面意图在宿主里**必须**各有分支（`handleIntent` 的 `when`）；
 * 3. 分派器必须提供主题配置/已存主题/落盘校验那批纯逻辑（行为由
 *    `SettingsThemeConfigTest` 钉）。
 *
 * ## 为什么读源码文本
 *
 * 「默认值写了什么」「when 里有哪些分支」写在 Compose/Kotlin 的源码里，
 * 编译产物与反射都拿不到（`src/test` 只挂 `main` 源集，`composeP1` 里的
 * `SettingsHost` 根本编不进来）。与 `SettingsRouteWiringGuardTest` 同一套做法；
 * 找不到文件**判失败而不是跳过**。
 */
class SettingsHostIntentWiringGuardTest {

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

    private fun settingsHostSource(): String {
        val host = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt",
        )
        assertTrue("SettingsHost.kt 不存在：${host.path}", host.isFile)
        return host.readText()
    }

    @Test
    fun `onIntent 的默认值不许是空实现`() {
        val source = settingsHostSource()
        assertTrue(
            "SettingsHost 的 onIntent 形参必须存在（改签名时记得同步本守卫）",
            "onIntent: ((SettingsDispatch) -> Unit)? = null" in source,
        )
        assertTrue(
            "onIntent 的默认值不许回到 `= {}`：那正是「意图被丢弃」的写法",
            "onIntent: (SettingsDispatch) -> Unit = {}" !in source,
        )
    }

    @Test
    fun `五种界面意图在宿主里都有分支`() {
        val source = settingsHostSource()
        val required = listOf(
            "is SettingsDispatch.ClipboardExport ->" to "导出主题（剪贴板）",
            "is SettingsDispatch.ClipboardImport ->" to "导入主题（剪贴板）",
            "is SettingsDispatch.ShowDialog ->" to "弹对话框（保存当前主题）",
            "is SettingsDispatch.ShowSheet ->" to "弹底部表（已存主题动作表）",
            "is SettingsDispatch.ShowRecolorSheet ->" to "课表重新配色",
        )
        val missing = required.filter { (needle, _) -> needle !in source }.map { it.second }
        assertEquals(
            "这些界面意图在 SettingsHost.handleIntent 里没有分支（点了会没反应）：",
            emptyList<String>(),
            missing,
        )
    }

    @Test
    fun `宿主不再把意图直接丢给空实现`() {
        val source = settingsHostSource()
        assertTrue(
            "`else -> onIntent(` 这个写法等于「壳不接就静默丢弃」，必须走 deliverIntent",
            "else -> onIntent(" !in source,
        )
        assertTrue(
            "必须有 deliverIntent 这个统一出口（壳传了走壳、没传走内置）",
            "fun deliverIntent(" in source,
        )
    }

    @Test
    fun `分派器提供主题配置与已存主题的纯逻辑`() {
        val dispatcher = File(
            androidSrc(),
            "main/kotlin/com/mutx163/qingyu/app/SettingsActionDispatcher.kt",
        )
        assertTrue("SettingsActionDispatcher.kt 不存在", dispatcher.isFile)
        val source = dispatcher.readText()
        val required = listOf(
            "fun themeConfigOf(",
            "fun themeConfigIsUsable(",
            "fun applyThemeConfig(",
            "fun saveTheme(",
            "fun applySavedTheme(",
            "fun renameSavedTheme(",
            "fun duplicateSavedTheme(",
            "fun deleteSavedTheme(",
            "fun savedThemeIdOf(",
            "fun persistLanded(",
        )
        val missing = required.filter { it !in source }
        assertEquals("分派器缺少这些主题相关入口：", emptyList<String>(), missing)
        // 导出必须带版本号（Dart 导入侧靠 v==2 校验必填色）。
        assertEquals(2, SettingsActionDispatcher.THEME_CONFIG_VERSION)
        assertEquals("theme.saved.", SettingsActionDispatcher.ROW_SAVED_THEME_PREFIX)
    }
}
