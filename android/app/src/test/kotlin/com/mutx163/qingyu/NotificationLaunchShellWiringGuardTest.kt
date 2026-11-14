package com.mutx163.qingyu

import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.readSourceNormalized
import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * R09 壳接线咬合守卫（A + B）。落地路径即本文件所在处。
 *
 * ## A 防的是哪类退化
 *
 * R09 曾「假绿」：只断言 onCreate/onNewIntent 里出现过 `postLaunchPage(intent)`。
 * 2026-11-14 判据收紧（`ShellLaunchLanding.shouldPostLaunchPage`）：旧的
 * `if (savedInstanceState == null)` 一刀切会把「进程被回收后按原任务恢复、同时点了**新**通知」
 * 整条路径吞掉。现在判的是「本次 Intent 的落点」与「上次启动已投递的落点」是否相同。
 *
 * 所以 A 钉四件事：① onCreate 解析落点；② `postLaunchPage(intent)` 必须落在
 * `shouldPostLaunchPage(...)` 的 if 块**内部**（配平取块，不是 contains 全文）；
 * ③ onCreate 里**不许**再出现旧的 `savedInstanceState == null` 判据（反向钉，防回退）；
 * ④ `onSaveInstanceState` 必须把本次落点写进 `STATE_POSTED_LAUNCH_PAGE`，否则进程恢复时
 * 无从判断「是不是同一份启动」。onNewIntent 的投递照旧必须存在。
 *
 * ## B 防的是哪类退化
 * 落点页 id 是契约常量（d3.examList / g3.lanEdit）。壳分派表 ShellPageIndex 一旦改名
 * 而通知契约没跟，点通知会推到空白页。B 把两侧字面量绑死。
 */
class NotificationLaunchShellWiringGuardTest {

    @Test
    fun `A 壳 onCreate 的投递必须由落点判据门控，且 onNewIntent 也投递`() {
        // ── 选档：**中性化字符串档**（`neutralizeStrings = true`）──
        // A 判的是「某个调用在不在这块里」以及「某个旧判据还在不在」，属接线型。
        // 字符串内容必须抹掉，否则一句日志 / 提示语里出现同样的调用字样就能把 contains 喂饱。
        //
        // ── 顺序：**先切片、再对切片剥离** ──
        // 块定位靠花括号配平，剥离会改变文本长度。所以：原件切块 → 切出来那段再剥离。
        val activity = readSourceNormalized(ACTIVITY_PATH)

        // (1) 必须覆写 onNewIntent：singleTop 复用（通知都带 SINGLE_TOP/NEW_TASK）走这条路。
        assertTrue(
            "PagesShellActivity 必须覆写 onNewIntent，否则后台点通知不会落页",
            stripKotlinComments(activity, neutralizeStrings = true)
                .contains("override fun onNewIntent("),
        )
        val onNewIntentBody = stripKotlinComments(
            methodBody(activity, "override fun onNewIntent("),
            neutralizeStrings = true,
        )
        assertTrue(
            "onNewIntent 必须调用 NotificationLaunchTarget.postLaunchPage(intent)",
            onNewIntentBody.contains("NotificationLaunchTarget.postLaunchPage(intent)"),
        )

        // (2) onCreate 必须解析本次落点，并把「恢复的落点」交给判据。
        val onCreateBody = methodBody(activity, "override fun onCreate(")
        val onCreateCode = stripKotlinComments(onCreateBody, neutralizeStrings = true)
        assertTrue(
            "onCreate 必须解析本次通知落点：缺少 NotificationLaunchTarget.pageIdForIntent(intent)",
            onCreateCode.contains("NotificationLaunchTarget.pageIdForIntent(intent)"),
        )
        assertTrue(
            "onCreate 必须把「上次已投递的落点」交给判据：" +
                "缺少 restoredPageId = savedInstanceState?.getString(STATE_POSTED_LAUNCH_PAGE)",
            onCreateCode.contains(
                "restoredPageId = savedInstanceState?.getString(STATE_POSTED_LAUNCH_PAGE)",
            ),
        )

        // (3) 投递必须落在 shouldPostLaunchPage(...) 的 if 块**内部**（配平取块，不是全文 contains）。
        val gateBlock = stripKotlinComments(
            guardedBlock(onCreateBody, "ShellLaunchLanding.shouldPostLaunchPage("),
            neutralizeStrings = true,
        )
        assertTrue(
            "onCreate 里的 NotificationLaunchTarget.postLaunchPage(intent) 必须写在 " +
                "ShellLaunchLanding.shouldPostLaunchPage(...) 的 if 块内部；写在块外属退化" +
                "（进程恢复 / 无落点时会无条件投递）。实际取到的守卫块：\n$gateBlock",
            gateBlock.contains("NotificationLaunchTarget.postLaunchPage(intent)"),
        )
        assertTrue(
            "守卫块里必须把本次落点记为已投递（postedLaunchPageId = launchPageId），" +
                "否则进程恢复时判不出「同一份启动」。实际：\n$gateBlock",
            gateBlock.contains("postedLaunchPageId = launchPageId"),
        )

        // (4) 反向钉：旧的 savedInstanceState == null 一刀切不许回来（那会吞掉「恢复 + 新通知」）。
        assertTrue(
            "onCreate 里又出现了旧的 savedInstanceState == null 判据：它会把" +
                "「进程恢复 + 点了新通知」的落页吞掉；判据应只走 ShellLaunchLanding.shouldPostLaunchPage",
            !onCreateCode.contains("savedInstanceState == null"),
        )

        // (5) 恢复时要知道「上次投递的是哪一页」：必须写进 onSaveInstanceState。
        val saveBody = stripKotlinComments(
            methodBody(activity, "override fun onSaveInstanceState("),
            neutralizeStrings = true,
        )
        assertTrue(
            "onSaveInstanceState 必须把本次落点写进 STATE_POSTED_LAUNCH_PAGE，否则恢复时判断不了同一份启动",
            saveBody.contains("STATE_POSTED_LAUNCH_PAGE"),
        )
        assertTrue(
            "STATE_POSTED_LAUNCH_PAGE 的键值必须钉死为 qingyu.postedLaunchPage（改动即等于换契约）",
            readKotlinSourceNormalized(ACTIVITY_PATH)
                .contains("const val STATE_POSTED_LAUNCH_PAGE = \"qingyu.postedLaunchPage\""),
        )
    }

    @Test
    fun `B 通知落点页 id 必须存在于壳分派表`() {
        // ── 选档：**默认档**（保留字符串内容，`readKotlinSourceNormalized`）──
        // B 判的正是「某个**字面量**在不在分派表」：`"d3.examList" ->` / `"g3.lanEdit" ->`。
        // 这一档不能换成中性化档——那会把被判的字面量自己擦成空格，判据从此既抓不到真回归、
        // 也认不出正确实现（等于把守卫变成摆设）。注释照样剥：**注释掉的接线不算接线**。
        val shell = readKotlinSourceNormalized(SHELL_INDEX_PATH)
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

    /**
     * 取签名所在方法源码（从签名后第一个 `{` 起，花括号配平到闭合）。
     *
     * ⚠️ 入参必须是**剥注释之前**的源码：本函数与 [guardedBlock] 都按花括号配平定位，
     * 剥离会改变长度。调用方拿到切片后再 `stripKotlinComments(…)`（先切片、再剥离）。
     */
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

    /**
     * 仓库相对路径（走 `readSourceNormalized` 的向上找根：工作目录是仓库根或 `android/` 都行）。
     *
     * 2026-11-12 之前这里是 `File(resolveSourceRoot(), …).readText()` 直接读原文——那样
     * 「把目标行注释掉」守卫照样绿（B1 批实测的绕过面）。现在读法统一走 testutil。
     */
    private companion object {
        const val ACTIVITY_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
        const val SHELL_INDEX_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
    }
}
