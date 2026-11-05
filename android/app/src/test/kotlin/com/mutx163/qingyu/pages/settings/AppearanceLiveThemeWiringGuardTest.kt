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
 * 3. `SettingsHost` 有 `onModelChanged` 回推，并在落盘校验 / 写盘失败回滚两条路径上发；
 *    **滑杆例外（2026-11-05 改契约）**：拖动中不广播、只走页面草稿（外观页样例句吃草稿
 *    字号 / 字重），松手才补广播（`finishSliderEdit`）。旧契约「每 tick 广播」正是用户报的
 *    「拖字号拉到一半就断、得松手重按」的成因：每帧换一次 `LocalDensity` ⇒ 整棵页面树重排，
 *    滑杆自己的拖动会话跟着断。发布版同口径（拖动只改页面草稿、全局字号走防抖后的 provider）；
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
    fun `滑杆拖动中只走页面草稿松手才回推全局换肤`() {
        val host = readSource("$COMPOSE/app/SettingsHost.kt")
        val renderers = readSource("$COMPOSE/pages/settings/SettingsPageRenderers.kt")

        // ── ① 滑杆分支**不得**再「拖动中每 tick 广播全局换肤」。这是 2026-11-05 用户报的
        //     「外观页拖字号，拉到一半就断、得松手重按」的成因：本页的 onModelChanged 是壳的
        //     onSettingsChanged，它把 appTextScale 变成 QingyuPageTheme 里的一层新
        //     LocalDensity（只缩 fontScale），每帧换一次 = 整棵页面树逐帧重排，而滑杆的
        //     拖动会话就挂在被重排的那棵树上。
        assertTrue(
            "滑杆分支又变回「拖动中每 tick 广播 onModelChanged」：外观页拖字号会在拖动途中" +
                "断掉手势（每帧换一次 LocalDensity ⇒ 整页重排）。拖动中要跟手请走页面草稿" +
                "（下面 ② 那几处），松手再广播（③ finishSliderEdit）。",
            "onModelChanged(result.model)" !in host,
        )
        assertTrue(
            "滑杆分支不再是「先记拖动闸门、再走 250ms 防抖落盘」的形态：拖动中会每帧同步落盘",
            Regex("""sliderDragActive = true\s+writer\.schedule\(result\.model\)""")
                .containsMatchIn(host),
        )

        // ── ② 拖动中「跟手」只能靠**页面草稿**（三种预览各一条）。
        //    字号：外观页样例句按草稿 appTextScale 就地缩放（发布版 `fontSize: 16 * _draft...`）。
        val appearance = readSource("$MAIN/pages/settings/SettingsAppearancePage.kt")
        assertTrue(
            "外观页样例句不再吃草稿字号（appearance.fontPreview.textScaleFactor）：拖字号时" +
                "屏上除了行尾数字没有任何反馈",
            "textScaleFactor = state.appTextScale" in appearance,
        )
        //    字重：同一句样张按草稿 appFontWeight 平移（发布版 `FontWeight(_draft.appFontWeight)`）。
        assertTrue(
            "外观页样例句不再吃草稿字重（appearance.fontPreview.textWeight）：拖字重时样张" +
                "不跟着变粗变细",
            "textWeight = state.appFontWeight" in appearance,
        )
        assertTrue(
            "样例句没有把草稿字号倍率用起来（SettingsInline.textScaleFactor → 字号）",
            "node.textScaleFactor.toFloat()" in renderers,
        )
        assertTrue(
            "样例句没有把草稿字重按**相对增量**平移（shiftWeight(weightDelta)）；" +
                "写死 fontWeight 既丢跟手又违反 R7",
            "scaledStyle.shiftWeight(weightDelta)" in renderers,
        )
        //    材质预览：外观编辑页的缩尺首页吃本页草稿 model（材质滑杆的落点），与设置宿主无关。
        val editor = readSource("$COMPOSE/app/AppearanceEditorHost.kt")
        assertTrue(
            "外观编辑页（材质面板）的预览不再读页面草稿：材质滑杆拖动中预览不跟手",
            "draft = model," in editor,
        )

        // ── ③ 松手后必须**补广播**，否则字号 / 字重要等离开页面才生效。
        //
        // ⚠️ 这里按「函数体」判，不用一条跨全文件的正则：`sliderDragActive = false` 与
        // `latestOnModelChanged(model)` 在**写盘失败回滚**那个回调里也各出现过一次，跨文件
        // 正则会被那一对命中（2026-11-05 咬合探针实测：删掉本函数里的广播守卫仍然绿）。
        val finishStart = host.indexOf("fun finishSliderEdit(")
        assertTrue(
            "SettingsHost 里没有 `finishSliderEdit`：滑杆松手没有补广播的落点（字号 / 字重" +
                "改完整页要等离开页面才生效）",
            finishStart >= 0,
        )
        val finishEnd = if (finishStart >= 0) host.indexOf("\n    }", finishStart) else -1
        val finishBody = if (finishEnd > finishStart) host.substring(finishStart, finishEnd) else ""
        assertTrue(
            "`finishSliderEdit` 里没有清拖动闸门（sliderDragActive = false）",
            "sliderDragActive = false" in finishBody,
        )
        assertTrue(
            "`finishSliderEdit` 里没有「松手补广播」（latestOnModelChanged(model)）：" +
                "拖动结束后整页字号 / 字重不生效",
            "latestOnModelChanged(model)" in finishBody,
        )
        assertTrue(
            "`finishSliderEdit` 里没有把防抖欠档补写掉（writer.flush()）",
            "writer.flush()" in finishBody,
        )
        assertTrue(
            "`finishSliderEdit` 没有接到 SettingsPageScreen 的松手回调：渲染层报的 " +
                "onValueChangeFinished 白报，滑杆改完不回推",
            "onSliderEditFinished = { rowId -> finishSliderEdit(rowId) }" in host,
        )
        assertTrue(
            "渲染层没有把滑杆的「松手」报出来（onValueChangeFinished）",
            "onValueChangeFinished = { onEditFinished(row.id) }" in renderers,
        )

        // 非滑杆写入（下拉 / 开关 / 恢复默认）仍是「一次动作一次回推」，别被拖动闸门拖下水。
        assertTrue(
            "SettingsHost 没有 `onModelChanged` 形参：外观页改完设置只能等回主屏才生效。",
            "onModelChanged: (TimetableSettingsModel) -> Unit = {}" in host,
        )
        assertTrue(
            "非滑杆写入（下拉 / 开关 / 恢复默认）没有回推：这些控件改完不换肤",
            "onModelChanged(model)" in host,
        )
        assertTrue(
            "防抖落盘失败回滚后没有回推：界面会停在没存下的档位",
            "latestOnModelChanged(model)" in host,
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
