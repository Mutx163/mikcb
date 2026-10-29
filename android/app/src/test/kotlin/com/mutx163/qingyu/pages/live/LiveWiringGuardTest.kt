package com.mutx163.qingyu.pages.live

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「超级岛四页必须接真宿主」守卫（2026-10-29 F01 交付时建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 本批修掉的事故长这样：`ShellPageIndex.kt` 里三条分支写的是
 *
 * ```kotlin
 * "j.live" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
 * ```
 *
 * 这个写法**合法、能编译、模型层单测全绿**——因为 `initialState` 有默认值
 * （`LiveDisplayState()`），三个平台回调也有默认值（`= {}`）。但真机上它是死页：
 * 进去永远是默认值，改了不落盘，退出去就没了；免打扰权限与试弹按钮点了没反应。
 * 同一类病全仓已经发生过两次（诊断族的空快照、任务页的「路由能用底栏是死的」），
 * 两次都是靠**读源码文本**的守卫才钉住的，因为「喂默认值」在类型系统里完全合法。
 *
 * ## 判据（都读源码文本，注释先剥掉）
 *
 * 1. 四条 `j.*` 路由分支必须调用各自的真宿主（`LiveDisplayHost(` / `LiveReminderTimingHost(`），
 *    且**不许**再出现没有宿主的状态化重载（`DisplaySettingsPage(` / `LiveReminderTimingPage(`）；
 * 2. 宿主必须**先读真快照**（`loadDisplay(` / `loadReminderTiming(`）**再写回**
 *    （`store.saveDisplay(` / `store.saveReminderTiming(`）——只读不写是「改了不落盘」，
 *    只写不读是「回显缺失」，两条都算没接线；
 * 3. 宿主那三个曾经是空实现的回调必须各有真落点：
 *    勿扰权限要真跳系统页（`ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`）、
 *    试弹起停要真给一句实话（`TRIGGER_REFRESH_MISSING`）、选图要真拉起系统选图
 *    （`pickLauncher.launch(`）。
 *
 * ## 为什么「有牙齿」用合成文本证明，而不是临时改壳文件
 *
 * 壳是**多会话共享件**（改动要先拿 `_SHARED-WRITER.md` 锁）。为了证明守卫会红而临时把
 * 别人的在途分支改坏，风险远大于收益。所以判据抽成 [violations] 纯函数，
 * 用「旧写法」的合成源码直接喂进去，证明它确实会报出违规（见
 * `旧写法会被这条守卫抓住`）。真实文件那一侧由 `守卫解析到的分支确实非空` 防空转。
 */
class LiveWiringGuardTest {

    // ────────────────────────── 判据 ──────────────────────────

    /**
     * 返回违规清单（空 = 通过）。纯函数，喂合成文本也能跑，因此可被反向验证。
     *
     * @param shellIndex `ShellPageIndex.kt` 的源码文本（内部会剥掉 `//` 行注释）
     * @param host `LiveDisplayHost.kt` 的源码文本（同样剥注释）
     */
    fun violations(shellIndex: String, host: String): List<String> {
        val out = ArrayList<String>()
        val shell = stripLineComments(shellIndex)
        val hostCode = stripLineComments(host)

        // ① 四条路由 → 各自的真宿主，且不许退回无宿主重载
        val displayMarkers = listOf(""""j.live" ->""", """"j.displayBefore" ->""", """"j.displayDuring" ->""")
        for (marker in displayMarkers) {
            val branch = branchOf(shell, marker)
            if (!branch.contains("LiveDisplayHost(")) {
                out += "$marker 分支没有调用 LiveDisplayHost( ——没有宿主的页面读不到真快照、也写不回落盘"
            }
            if (branch.contains("DisplaySettingsPage(")) {
                out += "$marker 分支又出现了没有宿主的状态化重载 DisplaySettingsPage( ——那就是本轮修掉的死页写法"
            }
        }
        val reminderBranch = branchOf(shell, REMINDER_MARKER)
        if (!reminderBranch.contains("LiveReminderTimingHost(")) {
            out += "$REMINDER_MARKER 分支没有调用 LiveReminderTimingHost( ——提醒时机改了不落盘"
        }
        if (reminderBranch.contains("LiveReminderTimingPage(")) {
            out += "$REMINDER_MARKER 分支又出现了没有宿主的 LiveReminderTimingPage( ——onPersist 默认空实现"
        }

        // ② 宿主必须读真快照 + 写回（回路闭合）
        for ((needle, why) in listOf(
            "loadDisplay(" to "宿主没有从真快照读显示设置——进页面只会是默认值",
            "saveDisplay(" to "宿主没有把显示设置写回——改了不落盘",
            "loadReminderTiming(" to "宿主没有从真快照读提醒时段",
            "saveReminderTiming(" to "宿主没有把提醒时段写回——改了不落盘",
        )) {
            if (!hostCode.contains(needle)) out += why
        }

        // ③ 三个曾经是空实现的回调必须各有真落点
        if (!hostCode.contains("ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS")) {
            out += "宿主没有真跳系统勿扰权限页（找不到 ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS）"
        }
        if (!hostCode.contains("TRIGGER_REFRESH_MISSING")) {
            out += "试弹起停没有给实话（找不到 TRIGGER_REFRESH_MISSING）——不许用空 lambda 假装能跑"
        }
        if (!hostCode.contains("pickLauncher.launch(")) {
            out += "选图没有真拉起系统选图（找不到 pickLauncher.launch(）"
        }

        // ④ 空 lambda 一律不许（本仓红线：不许拿 `= {}` 当交付）
        for (empty in listOf("= {}", "= { }")) {
            if (hostCode.contains(empty)) out += "宿主里仍有空 lambda「$empty」——不许拿空回调当交付"
        }
        return out
    }

    // ────────────────────────── 用例 ──────────────────────────

    @Test
    fun `四条 j 路由都接真宿主且宿主回路闭合`() {
        val found = violations(source(SHELL_INDEX), source(HOST))
        assertTrue("接线守卫抓到 ${found.size} 条违规：\n" + found.joinToString("\n"), found.isEmpty())
    }

    /**
     * 反向验证：把**本批修掉的旧写法**（无宿主重载 + 空回调）喂给同一套判据，
     * 必须报出违规。否则上面那条「零违规」只是说明守卫在空转。
     */
    @Test
    fun `旧写法会被这条守卫抓住`() {
        val oldShell = """
            "j.live" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
            "j.displayBefore" -> DisplaySettingsPage(forDuringEnd = false, onBack = onBack)
            "j.displayDuring" -> DisplaySettingsPage(forDuringEnd = true, onBack = onBack)
            "j.reminderTiming" -> LiveReminderTimingPage(onBack = onBack)
        """.trimIndent()
        val oldHost = """
            fun LiveDisplayHost(forDuringEnd: Boolean, onBack: () -> Unit) {
                DisplaySettingsPage(
                    initialState = LiveDisplayState(),
                    onBack = onBack,
                    onOpenDoNotDisturbAccess = {},
                    onStagePreviewStart = {},
                    onStagePreviewStop = {},
                )
            }
        """.trimIndent()

        val found = violations(oldShell, oldHost)

        assertTrue("守卫没认出旧写法（${found.size} 条）——它已经变成永远绿的摆设", found.size >= 8)
        assertTrue(found.any { it.contains("LiveDisplayHost(") })
        assertTrue(found.any { it.contains("LiveReminderTimingHost(") })
        assertTrue(found.any { it.contains("空 lambda") })
    }

    /**
     * 防空转：文本定位一旦因格式化失效，「零违规」会全部变绿——那比没有守卫更糟。
     * 这里钉住「确实解析到了东西」。
     */
    @Test
    fun `守卫解析到的分支确实非空`() {
        val shell = stripLineComments(source(SHELL_INDEX))
        for (marker in listOf(""""j.live" ->""", """"j.displayDuring" ->""", """"j.reminderTiming" ->""")) {
            val branch = branchOf(shell, marker)
            assertTrue("分支 $marker 解析出来只有 ${branch.length} 字符，文本定位可能失效", branch.length >= 20)
            assertTrue("分支 $marker 里没有宿主调用，文本可能截错范围", branch.contains("Host("))
        }
    }

    // ────────────────────────── 源码定位 ──────────────────────────

    private fun source(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    /** 去掉 `//` 行注释（保留换行）。注释里会写「原先是个空实现」，不剥会把解释当成复发。 */
    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { it.substringBefore("//") }

    /** 截取一个分支：从标记起，到下一个同级 `j.*` 路由标记或 [MAX_BRANCH_CHARS] 为止。 */
    private fun branchOf(shell: String, marker: String): String {
        val start = shell.indexOf(marker)
        if (start < 0) return ""
        val rest = shell.substring(start + marker.length)
        val siblings = listOf(
            """"j.live" ->""",
            """"j.displayBefore" ->""",
            """"j.displayDuring" ->""",
            """"j.reminderTiming" ->""",
            """"j.keepAlive" ->""",
        ).filter { it != marker }
        val cut = siblings.mapNotNull { rest.indexOf(it).takeIf { index -> index > 0 } }
            .minOrNull() ?: rest.length
        return rest.take(minOf(cut, MAX_BRANCH_CHARS))
    }

    private companion object {
        const val MAX_BRANCH_CHARS = 2000

        /** 壳里的分支标记（原文就是这样，含引号）。 */
        val REMINDER_MARKER = """"j.reminderTiming" ->"""

        const val SHELL_INDEX =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
        const val HOST = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/LiveDisplayHost.kt"
    }
}