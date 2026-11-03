package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「底栏根页不显示返回箭头」的壳层接线守卫（2026-11-03）。
 *
 * ## 它防的是哪一类事故
 *
 * 1. **判据回退成常显**：有人把骨架里的显隐判定删掉、`navigationIcon` 恢复成无条件
 *    画返回键 —— 根页箭头全站回归（用户报的就是这个）；
 * 2. **页面级旁路**：有人在 `QingyuPageScaffold` 签名上新增「是否显示返回」之类的参数，
 *    判定从一处收敛退化成逐页传参 —— 正是需求明确禁止的形态；
 * 3. **壳注入丢失**：entry 分支的根页标记被删，骨架读到 null 全站回到常显。
 *
 * ## 咬合探针
 *
 * 数值行为（根页/二级/更深）由 `ShellRootEntryRuleTest` 钉住，探针做过：
 * `shouldShowBackButton` 判反必红。本文件的文本探针在同一用例里喂改坏副本判假。
 */
class RootEntryBackGuardTest {

    @Test
    fun `骨架的返回键必须由根页判据守着`() {
        val scaffold = codeOnly(source(SCAFFOLD))
        assertTrue(
            "QingyuPageScaffold 没有经唯一取法 rememberShellShouldShowBackButton() 消费根页标记" +
                "——判定被删后箭头会全站回到常显",
            scaffoldGatesBackIcon(scaffold),
        )
        assertTrue(
            "骨架里返回键的构造点应只有 backIconOrNull 一处（三个顶栏分支都经它取槽内容），" +
                "出现多处直拼说明判定被绕过",
            scaffold.countBackIconConstructors() == 1,
        )
        // 反向探针：把判定改成常显，判据必须红。
        val broken = scaffold.replace(
            "val showBackButton = rememberShellShouldShowBackButton()",
            "val showBackButton = true",
        )
        assertFalse(
            "咬合探针失效：判据改成常显后守卫仍为真",
            scaffoldGatesBackIcon(broken),
        )
    }

    @Test
    fun `手拼顶栏的根页候选必须消费同一份判据`() {
        for ((label, path) in HAND_BUILT_PAGES) {
            val code = codeOnly(source(path))
            assertTrue(
                "$label 没有消费 rememberShellShouldShowBackButton( ——手拼顶栏的返回键显隐" +
                    "必须走与骨架同一份判据，不许自己另写一套",
                code.contains("if (rememberShellShouldShowBackButton())"),
            )
            assertFalse(
                "$label 直读了 LocalQingyuPageIsRootEntry ——取法只能有一处实现" +
                    "（components.rememberShellShouldShowBackButton），页面不得自己读 local 判定",
                code.contains("LocalQingyuPageIsRootEntry"),
            )
            assertFalse(
                "$label 出现了 isRoot/showBack 类参数——根页判定不许退化成逐页传参",
                code.contains("isRoot:") || code.contains("showBack:"),
            )
        }
        // 反向探针：把任务清单页的判定改成常显，判据必须红。
        val taskPath = HAND_BUILT_PAGES.first { it.first == "任务清单页" }.second
        val broken = codeOnly(source(taskPath)).replace(
            "if (rememberShellShouldShowBackButton()) {",
            "if (true) {",
        )
        assertFalse(
            "咬合探针失效：任务清单页判定改成常显后守卫仍为真",
            broken.contains("if (rememberShellShouldShowBackButton())"),
        )
    }

    @Test
    fun `骨架签名不许新增页面级显隐参数`() {
        val scaffold = codeOnly(source(SCAFFOLD))
        val signature = signatureOf(scaffold)
        assertTrue(
            "QingyuPageScaffold 签名解析出来太短（${signature.length} 字符），定位可能失效",
            signature.length > 60,
        )
        assertFalse(
            "骨架签名出现了 isRoot / showBack 类参数——根页判定必须由壳经 " +
                "LocalQingyuPageIsRootEntry 注入、骨架一处消费，不许退化成逐页传参",
            signature.contains("isRoot") || signature.contains("showBack"),
        )
    }

    @Test
    fun `壳必须在三个entry分支注入根页标记`() {
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "壳没有注入根页标记为 true（Dock 分支）——根页箭头不会隐藏",
            shellInjectsRootEntry(activity),
        )
        // 反向探针：Dock 注入改 false，判据必须红。
        val broken = activity.replace(
            "LocalQingyuPageIsRootEntry provides true",
            "LocalQingyuPageIsRootEntry provides false",
        )
        assertFalse(
            "咬合探针失效：Dock 注入改 false 后守卫仍为真",
            shellInjectsRootEntry(broken),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        val scaffold = codeOnly(source(SCAFFOLD))
        assertTrue(
            "QingyuPageScaffold.kt 读出来太短（${scaffold.length} 字符），解析可能坏了",
            scaffold.length > 1000,
        )
        val activity = codeOnly(source(ACTIVITY))
        assertTrue(
            "PagesShellActivity.kt 读出来太短（${activity.length} 字符），解析可能坏了",
            activity.length > 1000,
        )
    }

    // ------------------------------------------------------------------ 判据

    private fun scaffoldGatesBackIcon(text: String): Boolean =
        text.contains("val showBackButton = rememberShellShouldShowBackButton()") &&
            text.contains("backIconOrNull(") &&
            text.contains("fun rememberShellShouldShowBackButton(): Boolean") &&
            text.contains("ShellRootEntryRule.shouldShowBackButton(") &&
            text.contains("LocalQingyuPageIsRootEntry.current")

    private fun shellInjectsRootEntry(text: String): Boolean =
        text.contains("LocalQingyuPageIsRootEntry provides true") &&
            Regex("LocalQingyuPageIsRootEntry provides false").findAll(text).count() >= 2

    private fun String.countBackIconConstructors(): Int =
        Regex(Regex.escape("QingyuBackIconButton(onBack = onBack)")).findAll(this).count()

    /** 取 `fun QingyuPageScaffold(` 起到 `content:` 参数前的签名段（剥注释后）。 */
    private fun signatureOf(scaffold: String): String {
        val start = scaffold.indexOf("fun QingyuPageScaffold(")
        if (start < 0) return ""
        val end = scaffold.indexOf("content:", start)
        return if (end > start) scaffold.substring(start, end) else scaffold.substring(start)
    }

    // ------------------------------------------------------------------ 定位

    /** 只留代码：剥掉块注释与行注释，历史注释里的旧写法不参与判定。 */
    private fun codeOnly(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .lineSequence()
        .map { it.substringBefore("//") }
        .joinToString("\n")

    /** 从工作目录向上找仓库根，再读文件；与同目录守卫测试同一套做法。 */
    private fun source(relativePath: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relativePath)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relativePath（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val SCAFFOLD =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuPageScaffold.kt"

        const val ACTIVITY =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"

        /**
         * 手拼顶栏的根页候选（不走 QingyuPageScaffold，判据取法守卫到这里）。
         *
         * 2026-11-03 收口：月视图（`c2.month`，从「更多功能」推入时是二级页）与
         * 课表管理（`d1.profiles`）接上同一份判据，并入清单。
         */
        val HAND_BUILT_PAGES = listOf(
            "任务清单页" to "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/task/TaskListPage.kt",
            "日程列表页" to "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleListPage.kt",
            "课程总览页" to "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt",
            "局域网传输页" to "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditPage.kt",
            "月视图页" to "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewPage.kt",
            "课表管理页" to "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableProfilesPage.kt",
        )
    }
}
