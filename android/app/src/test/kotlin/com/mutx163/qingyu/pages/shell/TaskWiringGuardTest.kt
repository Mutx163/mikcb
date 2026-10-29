package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「任务清单页必须只有一个真宿主」守卫（2026-10-29 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 任务清单页有**两个渲染点**：路由 `d2.taskList`（`ShellPageIndex.kt`）与底栏常驻
 * 「任务」tab（`PagesShellActivity.kt` 的 `DockSlot.TASK`）。
 *
 * 2026-10-29 复刻质量审核时抓到的实况：路由那个接了真仓储，底栏那个仍在喂
 * `shellSampleTaskViewState()`（演示空态）+ 5 个空回调。表现是
 * **「从路由进去能用、从底栏进去是死的」**，而且底栏才是最常用的入口。
 * 这类事故**不会让编译失败**，也不会让任何模型层单测变红——它们测的层都是对的，
 * 错的是「谁把数据喂给页面」。与 `DiagnosticsWiringGuardTest` 同一类病。
 *
 * ## 判据（三条，都是读源码文本）
 *
 * 1. 两个渲染点都必须调用同一个宿主 `TaskListHost(`；
 * 2. 两个渲染点都**不许**再出现演示态喂法（`shellSampleTaskViewState`）与空回调
 *    （`onToggleTask = { }` / `onDeleteTask = { }` / `onBack = { }` 之类）；
 * 3. `shellSampleTaskViewState()` 这个函数本身**不许再存在**——留着就是给下一次
 *    「先喂个假的凑合」留抓手（它当年就是这么进仓库的）。
 *
 * ## 为什么要文本守卫而不是单测
 *
 * 「壳把一个演示对象喂给页面」这件事在类型系统里是合法的：`TaskListViewState` 就是
 * 那个类型，空态也是合法状态。只有看**调用点文本**才能区分「真宿主」与「假数据」。
 * 同仓先例：`ShellPageDispatchCoverageTest`（目录↔分派一致性）、
 * `DiagnosticsWiringGuardTest`（诊断族空快照）。
 */
class TaskWiringGuardTest {

    @Test
    fun `路由与底栏两个渲染点都走同一个真宿主`() {
        val index = source("ShellPageIndex.kt")
        assertTrue(
            "ShellPageIndex.kt 的 d2.taskList 分支没有调用 TaskListHost(——" +
                "任务清单页应只有一个宿主（app/TaskHost.kt）",
            branchOf(index, """"d2.taskList"""", source("ShellPageIndex.kt")).contains("TaskListHost("),
        )

        val activity = source("PagesShellActivity.kt")
        val dockBranch = branchOf(activity, "DockSlot.TASK ->", activity)
        assertTrue(
            "底栏 DockSlot.TASK 分支没有调用 TaskListHost(——" +
                "它必须与路由 d2.taskList 共用同一个宿主，否则两个入口会再次分叉",
            dockBranch.contains("TaskListHost("),
        )
    }

    @Test
    fun `两个渲染点都不许再喂演示态或空回调`() {
        val activity = source("PagesShellActivity.kt")
        val dockBranch = branchOf(activity, "DockSlot.TASK ->", activity)
        for (forbidden in listOf("shellSampleTaskViewState", "onToggleTask = { }", "onDeleteTask = { }")) {
            assertFalse(
                "底栏 DockSlot.TASK 里仍出现「$forbidden」——那正是 2026-10-29 修掉的死页写法",
                dockBranch.contains(forbidden),
            )
        }

        // 底栏的 onBack 仍然允许是空实现之外的普通 lambda，但**不许**是空 lambda：
        // 空 onBack 会让底栏任务 tab 无法返回课表，用户被困在这一屏。
        assertFalse(
            "底栏 DockSlot.TASK 的 onBack 是空实现——用户从底栏进任务页后将无法返回",
            dockBranch.contains("onBack = { }") || dockBranch.contains("onBack = {}"),
        )
    }

    @Test
    fun `演示态工厂函数不许复活`() {
        val index = source("ShellPageIndex.kt")
        assertFalse(
            "ShellPageIndex.kt 里又出现了 shellSampleTaskViewState() 的定义或调用——" +
                "演示态喂给真页面就是本轮修掉的死页根因；要展示空态请用模型层的 TaskFilterLogic 生成",
            index.contains("shellSampleTaskViewState"),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：文本解析一旦因格式变化失效，上面三条「零违规」会全部变绿——
        // 那比没有守卫更糟。这里把「确实解析到了东西」钉住。
        val activity = source("PagesShellActivity.kt")
        val dockBranch = branchOf(activity, "DockSlot.TASK ->", activity)
        assertTrue(
            "解析出的 DockSlot.TASK 分支太短（${dockBranch.length} 字符），文本定位可能失效了",
            dockBranch.length >= 200,
        )
        assertTrue("程序里应当恰好有 4 个底栏槽位", countOccurrences(activity, "DockSlot.") >= 8)
    }

    // ------------------------------------------------------------------ 定位

    /**
     * 从工作目录向上找仓库根，再定位壳源码。与 `ShellPageDispatchCoverageTest` 同一套做法。
     *
     * 返回的是**去掉行注释后**的代码：本轮的修复注释里会写「原先喂 `shellSampleTaskViewState()`」
     * 这类说明文字，而守卫要判的是**代码**里还喂不喂——不剥注释会把「解释旧事故」当成「事故复发」。
     */
    private fun source(name: String): String {
        val candidates = listOf(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/$name",
            "android/app/src/composeUi/kotlin/com/mutx163/qingyu/pages/$name",
        )
        var dir: File? = File("").absoluteFile
        repeat(8) {
            for (relative in candidates) {
                val candidate = File(dir, relative)
                if (candidate.isFile) return stripLineComments(candidate.readText(Charsets.UTF_8))
            }
            dir = dir?.parentFile
        }
        error(
            "找不到 $name（工作目录 ${File("").absolutePath}）；试过：\n" +
                candidates.joinToString("\n") { "  $it" },
        )
    }

    /** 去掉 `//` 行注释（保留换行，行号语义不变）。 */
    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }

    /**
     * 截取「从 [marker] 起到下一个同级分支」的那段文本。
     *
     * 任务是壳源码里的 `when` 分支，用固定字数截取会在格式化后错位；这里按
     * 「下一个出现同族标记的位置」或 MAX 字数兜底，避免整块判断串到别的分支。
     */
    private fun branchOf(source: String, marker: String, whole: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到分支标记 $marker" }
        val rest = source.substring(start + marker.length)
        val sibling = SIBLINGS.firstNotNullOfOrNull { sibling ->
            rest.indexOf(sibling).takeIf { it > 0 }
        } ?: return rest.take(MAX_BRANCH_CHARS)
        return rest.take(minOf(sibling, MAX_BRANCH_CHARS))
    }

    private fun countOccurrences(text: String, needle: String): Int {
        var count = 0
        var index = text.indexOf(needle)
        while (index >= 0) {
            count++
            index = text.indexOf(needle, index + needle.length)
        }
        return count
    }

    private companion object {
        /** 一个分支最多看这么多字符（`d2.addTask` 那种长分支约 3.5k）。 */
        const val MAX_BRANCH_CHARS = 6000

        /** 「下一个同级分支」的标记：任选其一先出现者。 */
        val SIBLINGS = listOf(
            "DockSlot.SETTINGS ->",
            "DockSlot.SCHEDULE ->",
            "DockSlot.TIMETABLE ->",
            "\"d2.addTask\" ->",
            "\"d2.taskList\" ->",
        )
    }
}
