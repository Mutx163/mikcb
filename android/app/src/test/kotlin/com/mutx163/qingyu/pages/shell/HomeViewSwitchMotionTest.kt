package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.TimetableHomeViewMode
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「底栏日↔月直达、不路过周视图」守卫（2026-11-11 用户真机反馈）。
 *
 * ## 用户口径
 *
 * 底栏在「月视图」和「日视图」之间切换时，画面明显在**周视图**停了一下，应该直接切换。
 *
 * ## 为什么会路过
 *
 * 三档是并排坐标 `日 | 周 | 月`（日 / 月各自读自己的进度做 `translateX`，周内容的位置由
 * 「谁在过渡」决定）。`日 ↔ 月` 不是相邻档，两个进度同时播时，中间那一截露出来的就是
 * 淡出中的周网格 ⇒ 读作「在周视图停了一下」。
 *
 * ## 基准
 *
 * 发布版 `v2.1.4.1`（2026-10-19）**没有月视图**，可比的是去 Flutter 前最后一版 Dart：
 * 月视图是首页内整屏内嵌页，「点底栏闪现直切，无滑动转场」
 *（`timetable_home_dock_shell.dart` 原注释）⇒ 基准就是直达。
 *
 * 本守卫咬两件事：
 * 1. 判据本身只认 `日 ↔ 月`（相邻档与同档都不许被判成直达，否则周↔日/周↔月的横滑会被吞掉）；
 * 2. `ShellWiring.switchHomeViewMode` 里那一行**必须**经判据收口（不许退回 `animate = animate`）。
 */
class HomeViewSwitchMotionTest {

    @Test
    fun `日与月互切判为跨周直达`() {
        assertTrue(
            "月→日没有被判成直达：底栏从月切日会再次播出周网格。",
            HomeViewSwitchMotion.directAcrossWeek(
                from = TimetableHomeViewMode.MONTH,
                to = TimetableHomeViewMode.DAY,
            ),
        )
        assertTrue(
            "日→月没有被判成直达：底栏从日切月会再次播出周网格。",
            HomeViewSwitchMotion.directAcrossWeek(
                from = TimetableHomeViewMode.DAY,
                to = TimetableHomeViewMode.MONTH,
            ),
        )
    }

    @Test
    fun `相邻档与同档都不许判成直达`() {
        // 相邻档：周↔日、周↔月的横滑是既有口径（2026-11-04 用户拍板），不能被这条判据吞掉。
        val mustKeepSliding = listOf(
            TimetableHomeViewMode.WEEK to TimetableHomeViewMode.DAY,
            TimetableHomeViewMode.DAY to TimetableHomeViewMode.WEEK,
            TimetableHomeViewMode.WEEK to TimetableHomeViewMode.MONTH,
            TimetableHomeViewMode.MONTH to TimetableHomeViewMode.WEEK,
        )
        for ((from, to) in mustKeepSliding) {
            assertFalse(
                "$from→$to 被判成了直达：相邻档的横滑会被收成硬切（用户 2026-11-04 口径是横滑）。",
                HomeViewSwitchMotion.directAcrossWeek(from, to),
            )
        }
        // 同档（重复点）：不换档，不算跨周直达。
        for (mode in TimetableHomeViewMode.entries) {
            assertFalse(
                "同档 $mode 被判成直达：重复点的语义不该被这条判据改写。",
                HomeViewSwitchMotion.directAcrossWeek(mode, mode),
            )
        }
    }

    @Test
    fun `switchHomeViewMode 必须经判据收口`() {
        val wiring = read(WIRING_PATH)
        assertTrue(
            "ShellWiring.switchHomeViewMode 没有把 animate 收进 HomeViewSwitchMotion.directAcrossWeek：" +
                "日↔月会再次播出周网格（用户报「在周视图停一下」）。",
            wiring.contains(UNDER_GATE),
        )
        assertTrue(
            "收口行把 horizontal 也一并改了：底栏两格互点的横滑判据会跟着失效。",
            wiring.contains("homeViewSwitchHorizontal = horizontal"),
        )
    }

    // 咬合探针：把收口行退回 `animate = animate`，判据必须变红。
    @Test
    fun `负例自测_退回 animate 直传会被判红`() {
        val wiring = read(WIRING_PATH)
        assertTrue("原文件应通过（收口行在）", wiring.contains(UNDER_GATE))
        val mutated = wiring.replace(UNDER_GATE, "homeViewSwitchAnimate = animate")
        assertFalse(
            "探针失效：把收口行退回 animate 直传后，判据仍为真。",
            mutated.contains(UNDER_GATE),
        )
    }

    private fun read(rel: String): String {
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
        const val WIRING_PATH = "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"

        const val UNDER_GATE =
            "homeViewSwitchAnimate = animate && !HomeViewSwitchMotion.directAcrossWeek(homeViewMode, mode)"
    }
}
