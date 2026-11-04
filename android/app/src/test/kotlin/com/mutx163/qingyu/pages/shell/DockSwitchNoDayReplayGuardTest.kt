package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 底栏/导航栏切回课表「不再重放日视图上下翻」守卫（2026-11-04）。
 *
 * ## 它钉的是什么
 *
 * 用户口径：只有「点星期栏（周几表头那行）的某一天进日视图」保留 `dayExpand` 的
 * 从上往下展开；**底栏 / 导航栏切换要正常左右滑、不能出现上下翻**。
 *
 * 2026-11-04 之前 `PagesShellActivity.selectRoot` 在「从别的底栏页切回课表、落在
 * 日视图」这条路径上登记了 `requestHomeViewMotion(TimetableHomeViewMode.WEEK)`：
 * 新宿主首帧会把 `dayExpand` 从 0 播到 1（`TimetableWeekPage` 的高度 reveal），
 * 叠在 `HorizontalPager` 的横滑上 = 用户报的「底栏切换上下翻」。
 *
 * 这里钉住「不要再把这个重放登记回来」，同时确认底栏切换仍走水平 Pager
 * （`HorizontalPager` + `springAnimateToPage`）——两者一起才是「纯左右滑」。
 *
 * 注意：本守卫只守壳层（`PagesShellActivity.kt`）。日视图 top-down 的几何本身由
 * `TimetableDayPanelGuardTest` 钉住（点某天进日视图保留，别处不动）。
 */
class DockSwitchNoDayReplayGuardTest {

    private val shell: String by lazy { readSource(ACTIVITY_PATH) }

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

    // 咬合探针（负例自测）：把重放加回来，第一条判据必须变红。
    @Test
    fun `负例自测_把重放加回会被判红`() {
        assertFalse("原文件应通过（未登记重放）", RE_REPLAY.containsMatchIn(shell))
        assertTrue(
            "探针失效：把 requestHomeViewMotion(WEEK) 加回后判据仍为真",
            RE_REPLAY.containsMatchIn(
                shell + "\n            wiring.requestHomeViewMotion(TimetableHomeViewMode.WEEK)\n",
            ),
        )
    }

    private fun readSource(rel: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, rel)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $rel —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val ACTIVITY_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"

        val RE_REPLAY = Regex("""requestHomeViewMotion\s*\(\s*TimetableHomeViewMode\.WEEK\s*\)""")
    }
}
