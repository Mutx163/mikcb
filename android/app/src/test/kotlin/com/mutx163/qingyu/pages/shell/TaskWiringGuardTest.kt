package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「任务清单页必须只有一个真宿主」守卫（2026-10-29 建立，2026-10-31 随底栏改造重写）。
 *
 * ## 它防的是哪一类事故
 *
 * 2026-10-29 复刻质量审核抓到的实况：任务清单页有**两个渲染点** —— 路由 `d2.taskList`
 * （`ShellPageIndex.kt`）接了真仓储，而底栏「任务」tab（`PagesShellActivity.kt` 的
 * `DockSlot.TASK`）仍在喂 `shellSampleTaskViewState()`（演示空态）+ 5 个空回调。
 * 表现是「从路由进去能用、从底栏进去是死的」，而底栏才是最常用的入口。
 * 这类事故**不会让编译失败**，模型层单测也全绿 —— 错的是「谁把数据喂给页面」。
 *
 * ## 2026-10-31 底栏改造后，判据为什么变了
 *
 * 底栏不再自带一套槽位渲染：条目 id 经 `rootPageIdFor` 映射成**壳页面 id**，
 * 再由同一个 `ShellPageContent` 渲染（`PagesShellActivity.kt` 的 `entry<ShellRoute.Dock>`）。
 * 也就是说「两个渲染点」这个前提被**结构上消灭**了：任务页只剩 `d2.taskList` 一处。
 *
 * 所以本守卫改成钉「结构上必须继续只有一个渲染点」，而不是钉某个枚举分支：
 *
 * 1. `ShellPageIndex.kt` 的 `d2.taskList` 分支必须调用 `TaskListHost(`；
 * 2. `PagesShellActivity.kt` **不许**再直接构造任何页面宿主（含 `TaskListHost(`）——
 *    主屏必须走 `ShellPageContent(pageId = rootPageIdFor(...))` 这一条路；
 * 3. 主屏那条分支必须真的把条目 id 交给 `rootPageIdFor(`（防止有人再写死一套槽位）；
 * 4. 演示态工厂 `shellSampleTaskViewState` 不许复活。
 *
 * ## 为什么要文本守卫而不是单测
 *
 * 「壳把一个演示对象喂给页面」在类型系统里完全合法（空态也是合法状态），
 * 只有看**调用点文本**才能区分「真宿主」与「假数据」。同仓先例：
 * `ShellPageDispatchCoverageTest`、`DiagnosticsWiringGuardTest`、`DayViewWiringGuardTest`。
 *
 * ## 咬合探针（2026-10-31 重写后做过）
 *
 * 在 `PagesShellActivity.kt` 的主屏分支里临时加一行 `TaskListHost(` → 第 2 条立即红；
 * 把 `pageId = rootPageIdFor(pageItemId)` 改成写死 `"d2.taskList"` → 第 3 条立即红；
 * 两处都还原后复跑全绿。
 */
class TaskWiringGuardTest {

    @Test
    fun `任务页在分派层走真宿主`() {
        val index = source("ShellPageIndex.kt")
        assertTrue(
            "ShellPageIndex.kt 的 d2.taskList 分支没有调用 TaskListHost(——" +
                "任务清单页应只有一个宿主（app/TaskHost.kt）",
            // 定位串必须带 `->`：只写 `"d2.taskList"` 会先命中前面的
            // `onOpenPage("d2.taskList")` 调用点，再靠 6000 字上限兜底截取——
            // 2026-11-01 新增代码后两者距离超过上限，守卫误判成「分支里没有 TaskListHost」。
            branchOf(index, """"d2.taskList" ->""", index).contains("TaskListHost("),
        )
    }

    @Test
    fun `主屏分支不许自己构造页面宿主`() {
        val activity = source("PagesShellActivity.kt")
        val rootBranch = branchOf(activity, "entry<ShellRoute.Dock>", activity)
        // 主屏只能把「条目 id」翻译成「壳页面 id」，渲染交给 ShellPageContent。
        // 一旦这里又出现某个具体宿主，第二个渲染点就回来了（且必然慢慢长第二套数据来路）。
        for (host in listOf("TaskListHost(", "ScheduleListHost(", "TimetableHost(", "TimetableWeekPage(")) {
            assertFalse(
                "PagesShellActivity 的主屏分支直接构造了 `$host`——" +
                    "主屏必须走 ShellPageContent，否则同一个页面会有第二个渲染点/第二套数据来路",
                rootBranch.contains(host),
            )
        }
        assertTrue(
            "主屏分支没有调用 ShellPageContent(——它应当只负责「条目 id → 壳页面 id」",
            rootBranch.contains("ShellPageContent("),
        )
    }

    @Test
    fun `主屏分支必须把条目 id 交给页面映射表`() {
        val activity = source("PagesShellActivity.kt")
        val rootBranch = branchOf(activity, "entry<ShellRoute.Dock>", activity)
        assertTrue(
            "主屏分支没有调用 rootPageIdFor(——底栏条目必须经 `shellTimetableMenuPageId` " +
                "那张唯一的映射表取页面，不许在分支里写死页面 id",
            rootBranch.contains("rootPageIdFor("),
        )
        // 写死的页面 id 形如 `pageId = "d2.taskList"`（带引号）。主屏必须走映射表，
        // 所以这条分支里不该出现「pageId = 」后面紧跟引号的写法。
        val hardcodedPageId = rootBranch.contains("pageId = \"") || rootBranch.contains("pageId=\"")
        assertFalse(
            "主屏分支里出现了写死的页面 id——底栏条目是用户可编排的，" +
                "写死就等于又回到「四个槽位」的老结构",
            hardcodedPageId,
        )
    }

    @Test
    fun `演示态工厂函数不许复活`() {
        val index = source("ShellPageIndex.kt")
        assertFalse(
            "ShellPageIndex.kt 里又出现了 shellSampleTaskViewState() 的定义或调用——" +
                "演示态喂给真页面就是 2026-10-29 修掉的死页根因；要展示空态请用模型层的 TaskFilterLogic 生成",
            index.contains("shellSampleTaskViewState"),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：文本解析一旦因格式变化失效，上面几条「零违规」会全部变绿——
        // 那比没有守卫更糟。这里把「确实解析到了东西」钉住。
        val activity = source("PagesShellActivity.kt")
        val rootBranch = branchOf(activity, "entry<ShellRoute.Dock>", activity)
        assertTrue(
            "解析出的主屏分支太短（${rootBranch.length} 字符），文本定位可能失效了",
            rootBranch.length >= 200,
        )
        assertTrue(
            "底栏条目来源必须由 HomeDockNavModel 解析（读用户存档），找不到解析调用" +
                "（2026-11-03 起三处共用 resolveDockIds 合一入口：坞 / Rail / 壳 Pager 页列表）",
            source("shell/HomeGlassDock.kt").contains("HomeDockNavModel.resolveDockIds("),
        )
    }

    // ------------------------------------------------------------------ 定位

    /**
     * 从工作目录向上找仓库根，再定位壳源码。与 `ShellPageDispatchCoverageTest` 同一套做法。
     *
     * 返回的是**去掉行注释后**的代码：修复注释里会写「原先喂 `shellSampleTaskViewState()`」
     * 这类说明，而守卫要判的是**代码**里还喂不喂 —— 不剥注释会把「解释旧事故」当成「事故复发」。
     */
    private fun source(name: String): String {
        val candidates = listOf(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/$name",
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/$name",
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
     * 用固定字数截取会在格式化后错位；这里按「下一个出现同族标记的位置」或
     * MAX 字数兜底，避免整块判断串到别的分支。
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

    private companion object {
        /** 一个分支最多看这么多字符（`d2.addTask` 那种长分支约 3.5k）。 */
        const val MAX_BRANCH_CHARS = 6000

        /**
         * 「下一个同级分支」的标记：任选其一先出现者。
         *
         * 2026-10-31 起底栏主屏分支的兄弟是 `entry<ShellRoute.Page>`；
         * 分派层的兄弟是 `when` 里的下一页分支标记。
         */
        val SIBLINGS = listOf(
            "entry<ShellRoute.Page>",
            "// ── P3-",
            "\"d2.addTask\"",
        )
    }
}
