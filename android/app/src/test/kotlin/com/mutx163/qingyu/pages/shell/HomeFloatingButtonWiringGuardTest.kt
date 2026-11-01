package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 首页两颗浮钮的**接线守卫**（2026-11-01，来自用户「按钮在导航栏底下」）。
 *
 * ## 防的是哪一类事故
 *
 * 「回本周」与「回今日」原先各写了一个魔法数（`72dp` / `20dp`），都不认识玻璃坞
 * 药丸的真实占用（手势导航下 86dp），于是一颗落在药丸里、一颗贴着屏幕底。修法是把
 * 避让量交给 `HomeFloatingMetrics`，由宿主算好、页面照用。
 *
 * 这条链上有三处可以**静默断掉**，编译器全都不会拦：
 *
 * 1. 宿主忘了传 `floatingButtonBottomInset = ...`：参数有默认值（`null`），页面退回旧口径；
 * 2. 页面收了参数却没用：编译通过，钮还在老位置；
 * 3. 壳的 `c3.day` 没走 `rememberHomeFloatingInsets`：自己瞎算一份，与周视图漂开。
 *
 * 所以这里读源码文本逐条钉住（与同目录 `DayViewWiringGuardTest` 同一套做法）。
 */
class HomeFloatingButtonWiringGuardTest {

    @Test
    fun `周视图宿主必须把浮钮避让传下去`() {
        val source = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt",
        )
        assertTrue(
            "`TimetableHost` 没有把 `floatingButtonBottomInset` 传给 `TimetableWeekPage`：" +
                "「回本周」会退回写死的 72dp，手势导航下又被药丸盖住。",
            "floatingButtonBottomInset = floatingInsets.buttonBottom" in source,
        )
        assertTrue(
            "`TimetableHost` 没有调 `rememberHomeFloatingInsets(`：避让量的算法必须在那一份里。",
            "rememberHomeFloatingInsets(" in source,
        )
    }

    @Test
    fun `壳的日视图必须传浮钮与内容避让`() {
        val source = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        val branch = branchBody(source, "c3.day")
        for (expected in listOf(
            "floatingButtonBottomInset = floatingInsets.buttonBottom",
            "contentBottomInset = floatingInsets.contentBottom",
            "rememberHomeFloatingInsets(",
        )) {
            assertTrue(
                "`c3.day` 分支里没有 `$expected`：「回今日」与列表底部会退回旧口径，" +
                    "按钮再次落进玻璃坞里。",
                expected in branch,
            )
        }
        assertTrue("`c3.day` 分支解析出来太短，解析可能坏了", branch.length > 200)
    }

    @Test
    fun `两颗按钮都必须真的用上避让量`() {
        val week = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt",
        )
        val day = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt",
        )
        // 参数声明 + 使用 = 至少两处；只出现一次说明收了参数没用（编译仍然通过）。
        assertTrue(
            "`TimetableWeekPage` 声明了 `floatingButtonBottomInset` 却没有用上",
            countOccurrences(week, "floatingButtonBottomInset") >= 2,
        )
        assertTrue(
            "`DayViewPage` 声明了 `floatingButtonBottomInset` 却没有用上",
            countOccurrences(day, "floatingButtonBottomInset") >= 2,
        )
        assertTrue(
            "`DayViewPage` 没有把 `contentBottomInset` 用进列表避让",
            countOccurrences(day, "contentBottomInset") >= 2,
        )
    }

    private fun countOccurrences(source: String, needle: String): Int =
        source.split(needle).size - 1

    /** 取 `ShellPageIndex` 里某个分派分支的源码文本（与 `DayViewWiringGuardTest` 同口径）。 */
    private fun branchBody(source: String, id: String): String {
        val matches = BRANCH.findAll(source).toList()
        val index = matches.indexOfFirst { it.groupValues[1] == id }
        assertTrue("ShellPageIndex.kt 里找不到分支 `$id`", index >= 0)
        val start = matches[index].range.last + 1
        val end = matches.getOrNull(index + 1)?.range?.first ?: source.length
        return source.substring(start, end)
    }

    /** 从工作目录向上找仓库根再定位文件；找不到判失败（不许静默跳过）。 */
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
        val BRANCH = Regex("""^[ \t]*"([A-Za-z0-9._-]+)"[ \t]*->""", RegexOption.MULTILINE)
    }
}
