package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * R09 壳接线咬合守卫（A + B）。落地路径即本文件所在处。
 *
 * ## A 防的是哪类退化
 * R09 曾「假绿」：只断言 onCreate/onNewIntent 里出现过 `postLaunchPage(intent)`。
 * 但真正要保证的是——**投递必须落在 `if (savedInstanceState == null)` 块内**；
 * 一旦有人把调用挪到 if 外（无条件投递，进程恢复场景会把已关页面重新推出来），
 * 只 contains 的断言仍然绿。故 A 用花括号配平取出该 if 块，断言调用在其内部。
 *
 * ## 为什么守卫是 savedInstanceState == null（不是「旋转重建」）
 * `PagesShellActivity` 在 manifest 里 configChanges 已含 `orientation|screenSize`，
 * 旋转 / 分屏**不会**重建 Activity。非空 savedInstanceState 只在「进程被系统回收后
 * 按原任务恢复」时出现——那才是要跳过重投的场景（避免把用户已关的页面推回来）。
 *
 * ## B 防的是哪类退化
 * 落点页 id 是契约常量（d3.examList / g3.lanEdit）。壳分派表 ShellPageIndex 一旦改名
 * 而通知契约没跟，点通知会推到空白页。B 把两侧字面量绑死。
 */
class NotificationLaunchShellWiringGuardTest {

    @Test
    fun `A 壳 onCreate 的投递必须落在 savedInstanceState==null 块内，且 onNewIntent 也投递`() {
        val text = File(resolveSourceRoot(), "pages/PagesShellActivity.kt").readText()

        // (1) 必须覆写 onNewIntent：singleTop 复用（通知都带 SINGLE_TOP/NEW_TASK）走这条路。
        assertTrue(
            "PagesShellActivity 必须覆写 onNewIntent，否则后台点通知不会落页",
            text.contains("override fun onNewIntent("),
        )

        // (2) onCreate 的投递必须**落在 if (savedInstanceState == null) { ... } 内部**。
        //     不是「文件里出现过就算」——用花括号配平把该 if 块切出来再判。
        val onCreateBody = methodBody(text, "override fun onCreate(")
        val guardBlock = guardedBlock(onCreateBody, "if (savedInstanceState == null)")
        assertTrue(
            "onCreate 里的 NotificationLaunchTarget.postLaunchPage(intent) 必须写在 " +
                "if (savedInstanceState == null) { ... } 块内部；写在块外属退化" +
                "（进程恢复时会把已关页面重新推出来）。实际取到的守卫块：\n$guardBlock",
            guardBlock.contains("NotificationLaunchTarget.postLaunchPage(intent)"),
        )

        // (3) onNewIntent 也必须投递（后台 singleTop 复用路径）。
        val onNewIntentBody = methodBody(text, "override fun onNewIntent(")
        assertTrue(
            "onNewIntent 必须调用 NotificationLaunchTarget.postLaunchPage(intent)",
            onNewIntentBody.contains("NotificationLaunchTarget.postLaunchPage(intent)"),
        )
    }

    @Test
    fun `B 通知落点页 id 必须存在于壳分派表`() {
        val shell = File(resolveSourceRoot(), "pages/ShellPageIndex.kt").readText()
        assertTrue(
            "PAGE_EXAMS=\"${NotificationLaunchTarget.PAGE_EXAMS}\" 未出现在 ShellPageIndex 分派表，点通知会推空白页",
            shell.contains("\"${NotificationLaunchTarget.PAGE_EXAMS}\" ->"),
        )
        assertTrue(
            "PAGE_LAN_EDIT=\"${NotificationLaunchTarget.PAGE_LAN_EDIT}\" 未出现在 ShellPageIndex 分派表，点通知会推空白页",
            shell.contains("\"${NotificationLaunchTarget.PAGE_LAN_EDIT}\" ->"),
        )
        assertEquals("d3.examList", NotificationLaunchTarget.PAGE_EXAMS)
        assertEquals("g3.lanEdit", NotificationLaunchTarget.PAGE_LAN_EDIT)
    }

    /** 取签名所在方法源码（从签名后第一个 `{` 起，花括号配平到闭合）。 */
    private fun methodBody(text: String, signature: String): String {
        val start = text.indexOf(signature)
        check(start >= 0) { "找不到签名：$signature" }
        val body = guardedBlock(text.substring(start), "{")
        check(body.length > 2) { "方法体为空：$signature" }
        return body
    }

    /**
     * 从 [marker] 之后第一个 `{` 起，花括号配平取出完整块（含两端花括号）。
     * marker 找不到、或其后无 `{`、或括号不配平，都判失败（不让守卫空转）。
     */
    private fun guardedBlock(text: String, marker: String): String {
        val m = text.indexOf(marker)
        check(m >= 0) { "找不到守卫标记：$marker" }
        val open = text.indexOf('{', m)
        check(open >= 0) { "守卫标记后没有块起点 '{'：$marker" }
        var depth = 0
        var i = open
        while (i < text.length) {
            when (text[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return text.substring(open, i + 1)
                }
            }
            i++
        }
        error("块未闭合：$marker")
    }

    /** 与 NotificationLaunchTargetGuardTest 同款路径解析（工作目录可能是仓库根或 android/）。 */
    private fun resolveSourceRoot(): File {
        val candidates = listOf(
            File("android/app/src/main/kotlin/com/mutx163/qingyu"),
            File("app/src/main/kotlin/com/mutx163/qingyu"),
            File("../android/app/src/main/kotlin/com/mutx163/qingyu"),
            File("../../android/app/src/main/kotlin/com/mutx163/qingyu"),
        )
        return candidates.firstOrNull { it.isDirectory }
            ?: error("找不到 Kotlin 源根目录，工作目录=${File(".").absolutePath}")
    }
}
