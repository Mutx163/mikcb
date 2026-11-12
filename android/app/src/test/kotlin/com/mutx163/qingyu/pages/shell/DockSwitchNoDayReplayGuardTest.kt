package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 底栏/导航栏切页「日↔周按来源选几何」守卫（2026-11-04）。
 *
 * ## 用户口径（三档，来源区分）
 *
 * - 底栏 / 导航栏「周/日」两格互点 → **横滑 translateX**（周内容右出、日内容左入），
 *   即 `switchHomeViewMode(..., animate = true, horizontal = true)`；
 * - 从别的底栏页切回课表 → **只让 Pager 横滑**，页面 `snapTo`（`animate = false`）；
 * - 点星期栏某天 / 页内关闭（BackHandler）→ **heightFactor 从上往下**（`horizontal = false`，默认）；
 * - 系统「减少动画」仍优先 `snapTo`。
 *
 * 同一个 `dayExpand` 进度驱动两套几何：页面里 `daySwitchHorizontal` 决定走 translateX 还是
 * heightFactor；`daySwitchAnimate=false` 决定直接 snapTo。
 *
 * 历史病灶（本守卫一并防回潮）：曾用 `requestHomeViewMotion(WEEK)` 在重建宿主时把
 * `dayExpand` 从 0 播到 1（底栏切回上下翻），已删。
 */
class DockSwitchNoDayReplayGuardTest {

    private val shell: String by lazy { read(ACTIVITY_PATH) }
    private val wiring: String by lazy { read(WIRING_PATH) }
    private val host: String by lazy { read(HOST_PATH) }
    private val weekPage: String by lazy { read(WEEK_PAGE_PATH) }

    @Test
    fun `底栏切回课表不再登记日视图展开重放`() {
        assertFalse(
            "PagesShellActivity 又从「底栏切回课表」的路径登记了 requestHomeViewMotion(WEEK)：" +
                "新宿主会把 dayExpand 从 0 播到 1，底栏切换会再次出现从上往下的重放。",
            RE_REPLAY.containsMatchIn(shell),
        )
    }

    @Test
    fun `底栏切换仍走水平 Pager`() {
        assertTrue("主屏内容区不是 HorizontalPager，左右滑转场丢了", shell.contains("HorizontalPager("))
        assertTrue("底栏切换不再走 springAnimateToPage，水平滑动丢了", shell.contains("springAnimateToPage("))
    }

    @Test
    fun `底栏两格互点走横滑_跨页切回走 snap`() {
        // ① 两格互点：animate=true + horizontal=true（translateX 横滑）。
        assertTrue(
            "底栏周/日两格互点没有传 animate=true, horizontal=true（会退化成上下翻或闪切）。",
            twoCellHorizontal(shell),
        )
        // ② 跨页切回课表：animate=false（snap，只让 Pager 横滑）。
        assertTrue(
            "跨页切回课表没有传 animate=false（会在 Pager 横滑上再叠一层 dayExpand）。",
            shell.contains("switchHomeViewMode(mode, animate = false)"),
        )
        // ③ 透传链：ShellWiring 有 horizontal 参数与状态、并传给 TimetableHost。
        assertTrue(
            "ShellWiring.switchHomeViewMode 缺 horizontal 参数 / homeViewSwitchHorizontal 状态 / 透传。",
            wiring.contains("fun switchHomeViewMode(") &&
                wiring.contains("horizontal: Boolean = false") &&
                wiring.contains("homeViewSwitchHorizontal = horizontal") &&
                wiring.contains("daySwitchHorizontal = wiring.homeViewSwitchHorizontal"),
        )
        assertTrue(
            "TimetableHost 缺 daySwitchHorizontal 参数或没透传给 TimetableWeekPage。",
            host.contains("daySwitchHorizontal: Boolean = false") &&
                host.contains("daySwitchHorizontal = daySwitchHorizontal,"),
        )
    }

    @Test
    fun `页面按来源分两套几何_横滑用 translateX_上下翻保留`() {
        // 横滑几何：周内容 -p*W、日内容 (1-p)*W（都读同一个 dayExpand 缓动进度）。
        assertTrue(
            "TimetableWeekPage 缺横滑的周内容 translationX（+dayExpandEasing.transform(...)*size.width）。",
            weekPage.contains("dayExpandEasing.transform(dayExpand.value) * size.width.toFloat()"),
        )
        assertTrue(
            "TimetableWeekPage 缺横滑的日内容 translationX（-(1f - dayExpandEasing.transform(...))*size.width）。",
            weekPage.contains("-(1f - dayExpandEasing.transform(dayExpand.value)) * size.width.toFloat()"),
        )
        assertTrue("TimetableWeekPage 缺 daySwitchHorizontal 分支参数。", weekPage.contains("daySwitchHorizontal: Boolean = false"))
        // 上下翻几何仍在（点星期栏用），且默认 animate=true 时仍 animateTo。
        assertTrue("TimetableWeekPage 丢了 dayExpand.animateTo（会变成纯 snap）。", weekPage.contains("dayExpand.animateTo("))
        // 2026-11-09：高度公式挪进 `dayPanelHeightPx`（日页下穿带高），这里钉调用；
        // 公式本体由 TimetableBandUnderlapTest 的纯函数用例覆盖。
        assertTrue("TimetableWeekPage 的 top-down 几何（dayPanelHeightPx）不见了", weekPage.contains("dayPanelHeightPx("))
        assertTrue("TimetableWeekPage 的 top-down 几何（Alignment.TopCenter）不见了", weekPage.contains("Alignment.TopCenter"))
    }

    @Test
    fun `点星期栏某天仍保留 animateTo 上下翻`() {
        // 点星期栏/页内关闭：不传 horizontal（默认 false = 上下翻），也不传 animate=false。
        assertTrue(
            "onSelectDay / onCloseDay 被误改：点某天进日视图的上下翻会丢。",
            wiring.contains("wiring.switchHomeViewMode(TimetableHomeViewMode.DAY)") &&
                wiring.contains("onCloseDay = { wiring.switchHomeViewMode(TimetableHomeViewMode.WEEK) }"),
        )
    }

    // 咬合探针 1：把两格的 horizontal=true 去掉，横滑判据必须变红。
    @Test
    fun `负例自测_两格不传 horizontal 会被判红`() {
        assertTrue("原文件应通过（两格都 horizontal=true）", twoCellHorizontal(shell))
        val mutated = shell.replace(", horizontal = true", "")
        assertFalse("探针失效：去掉 horizontal=true 后判据仍为真", twoCellHorizontal(mutated))
    }

    // 咬合探针 2：把周内容的 translationX 去掉，几何判据必须变红。
    @Test
    fun `负例自测_去掉 translateX 会被判红`() {
        val week = "dayExpandEasing.transform(dayExpand.value) * size.width.toFloat()"
        assertTrue("原文件应通过（有周内容 translateX）", weekPage.contains(week))
        val mutated = weekPage.replace(week, "0f")
        assertFalse("探针失效：去掉 translationX 后判据仍为真", mutated.contains(week))
    }

    private fun twoCellHorizontal(src: String): Boolean =
        src.contains("switchHomeViewMode(TimetableHomeViewMode.DAY, animate = true, horizontal = true)") &&
            src.contains("switchHomeViewMode(TimetableHomeViewMode.WEEK, animate = true, horizontal = true)")

    /**
     * 读生产源码，走**中性化字符串档**（`readKotlinSourceNoStrings`：剥注释 + 字符串内容换空格）。
     *
     * ## 为什么这一档（2026-11-12 B1 批）
     *
     * 本文件判的全是**调用与实参**：`HorizontalPager(`、`springAnimateToPage(`、
     * `switchHomeViewMode(mode, animate = false)`、`dayExpandEasing.transform(dayExpand.value) * size.width.toFloat()`、
     * `daySwitchHorizontal: Boolean = false`、`onCloseDay = { … }`。这些是代码骨架，
     * 判据要的是「这行代码在不在」，不是「这句话有没有被谁写进字符串」。
     *
     * 选中性化档的两个理由：
     * 1. 生产代码里任何一句含同样片段的日志 / 提示语，都能让 `contains` 假绿；
     * 2. 两条负例自测（`负例自测_*`）先断言「原文件通过」再 `replace` 造负例——若字符串内容
     *    留着，负例的 `replace` 可能把字符串里的同名字样也替掉，探针结论就不可信。
     *
     * 本文件**没有**判「某字面量许不许出现」的判据，所以不需要默认档。
     * 剥注释那一半是必须的：**注释掉的接线不算接线**——此前 `readText()` 读原文时，
     * 把目标行注释掉守卫照样绿（B1 批实测的绕过面）。
     */
    private fun read(rel: String): String = readKotlinSourceNoStrings(rel)

    private companion object {
        const val ACTIVITY_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
        const val WIRING_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"
        const val HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt"
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"

        val RE_REPLAY = Regex("""requestHomeViewMotion\s*\(\s*TimetableHomeViewMode\.WEEK\s*\)""")
    }
}
