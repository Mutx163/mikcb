package com.mutx163.qingyu.pages.import.warehouse

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壳桥「进程级单例 + 代数信号」接线守卫（2026-11-10 第二波；2026-11-10 J14 收紧）。
 *
 * ## 防的是哪一类回归
 *
 * 桥原先建在 `ShellPageContent` 里（`remember { ImportShellBridge() }`），而
 * `ShellPageContent` 由 `entry<ShellRoute.Page>` **每个路由条目各组合一次** ⇒ 目标页拿到
 * 的是另一份空桥。症状三条：二维码发送页出不了码、扫码收齐后点导入没反应、任一导入
 * 成功后入口页不自关。本守卫钉住「单例 + 代数」接线，防它被写回每路由一份/布尔标记。
 *
 * ## J14 收紧（评审六复核）
 *
 * 1. **判据先剥注释**：旧版直接在原文上 `contains`/`Regex.containsMatchIn`，把接线整行
 *    注释掉仍会命中（假绿：自关功能静默失效，守卫还绿）。照同域先例
 *    `WarehouseWebLoginHostWiringGuardTest.kt:21` 的 `stripKotlinComments` 做法。
 * 2. **正断言加行锚**：`^…$` 锚在代码行上，注释里的同样字串不算。
 * 3. **负断言同样在剥注释后的文本上做**：否则 KDoc 里提到 `completedImport`
 *    会把守卫判成红（J11 翻正 KDoc 时就踩过）。
 *
 * ## J11 语义（2026-11-10 评审一方案二）
 *
 * 入口页只在 **RESUMED** 时消费「导入成功」代数：外部「打开方式」推来的导入页压在
 * 入口页之上时，导入页自己 `onBack()` 就够，入口页再弹一下就是多弹一层（用户被送回首页）。
 *
 * 纯逻辑语义由 [ShellBridgeSignalsTest] 行为测试覆盖；这里只管**接线**（Compose 宿主
 * 进不了 JVM 单测，只能读源码）。
 */
class ShellBridgeSingletonWiringGuardTest {

    private val shellSource: String by lazy {
        strip(relativeSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"))
    }
    private val importHostsSource: String by lazy {
        strip(
            relativeSource(
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/ImportHosts.kt",
            ),
        )
    }
    private val dataTransferSource: String by lazy {
        strip(
            relativeSource(
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt",
            ),
        )
    }
    private val aiImageHostSource: String by lazy {
        strip(
            relativeSource(
                "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/" +
                    "AiImageCourseImportHost.kt",
            ),
        )
    }
    /** 三态判据本体（纯函数）：Wait 不推进基线这条口径钉在它身上。 */
    private val signalLogicSource: String by lazy {
        strip(
            relativeSource(
                "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/ImportEntrySignalLogic.kt",
            ),
        )
    }

    // ── 0. 判据本身不能假绿 ─────────────────────────────────────────────

    @Test
    fun `判据必须剥掉注释 注释掉的接线不算接线`() {
        val fake = "fun f() {\n" +
            "    // val decision = ImportEntrySignalLogic.decide(\n" +
            "    // ImportShellBridge.markImported()\n" +
            "}"
        val stripped = stripText(fake)
        assertFalse(
            "注释掉的 decide 调用点仍被命中（假绿：判据拆了守卫还绿）。",
            DECIDE_CALL.containsMatchIn(stripped),
        )
        assertFalse(
            "注释掉的 markImported 仍被命中。",
            stripped.contains("bridge.markImported()"),
        )
        // 字符串字面量里的 // 不能被当注释吃掉（源码里有 URL）
        assertTrue(
            "字符串字面量里的 // 被误当注释剥掉了。",
            stripText("val u = \"a//b\"").contains("a//b"),
        )
    }

    // ── 1. 单例 ─────────────────────────────────────────────────────────

    @Test
    fun `两个桥都必须是进程级 object 不许再每路由 remember 一份`() {
        assertTrue(
            "ImportShellBridge 必须改成 object（每路由一份 = 入口页读不到成功信号）",
            Regex("""(?m)^object ImportShellBridge \{""").containsMatchIn(importHostsSource),
        )
        assertTrue(
            "TransferShellBridge 必须改成 object（每路由一份 = 发送页/扫码页拿到空桥）",
            Regex("""(?m)^object TransferShellBridge \{""").containsMatchIn(dataTransferSource),
        )

        assertTrue(
            "壳里必须直接用单例（`val transferBridge = TransferShellBridge`）。",
            Regex("""(?m)^\s*val transferBridge = TransferShellBridge\s*$""")
                .containsMatchIn(shellSource),
        )
        // 2026-11-10 J12：导入宿主改成直接调 object 后，壳里那条 `val importBridge = …`
        // 已是没人读的别名，删掉；这里钉「壳不许再给导入宿主传桥，也不许自己再造一份」。
        assertFalse(
            "壳里不该再有 `val importBridge = ImportShellBridge` 这种没人读的别名（J12 已删）。",
            Regex("""(?m)^\s*val importBridge = ImportShellBridge\s*$""")
                .containsMatchIn(shellSource),
        )
        assertFalse(
            "桥不许再在路由条目里 new 一份（`remember { TransferShellBridge() }` 就是事故原样）。",
            Regex("""val\s+transferBridge\s*=\s*remember\s*\{\s*TransferShellBridge\(\)\s*\}""")
                .containsMatchIn(shellSource),
        )
        assertFalse(
            "桥不许再在路由条目里 new 一份（`remember { ImportShellBridge() }` 就是事故原样）。",
            Regex("""val\s+importBridge\s*=\s*remember\s*\{\s*ImportShellBridge\(\)\s*\}""")
                .containsMatchIn(shellSource),
        )
    }

    @Test
    fun `宿主不许再收 bridge 形参 object 化后只剩唯一合法实参`() {
        // 2026-11-10 J12：桥是 object 之后，形参只可能收到同一个实参，纯噪音；
        // 留着还会让「谁的桥」看起来可注入，掩盖单例语义。
        assertFalse(
            "ImportHosts 里还留着 `bridge: ImportShellBridge` 形参。",
            Regex("""(?m)^\s*bridge: ImportShellBridge,\s*$""").containsMatchIn(importHostsSource),
        )
        assertFalse(
            "AiImageCourseImportHost 里还留着 `bridge: ImportShellBridge` 形参。",
            Regex("""(?m)^\s*bridge: ImportShellBridge,\s*$""").containsMatchIn(aiImageHostSource),
        )
        assertFalse(
            "DataTransferHost 里还留着 `bridge: TransferShellBridge` 形参。",
            Regex("""(?m)^\s*bridge: TransferShellBridge,\s*$""").containsMatchIn(dataTransferSource),
        )
        assertFalse(
            "壳里还在给宿主传 `bridge = …`（形参已删）。",
            Regex("""(?m)^\s*bridge = (importBridge|transferBridge),\s*$""")
                .containsMatchIn(shellSource),
        )
    }

    // ── 2. 发送路径：载荷 + 标题 ────────────────────────────────────────

    @Test
    fun `发送页必须从进程级桥读载荷与标题`() {
        val sendBranch = branch(shellSource, "\"g3.qrSend\" ->", "\"g3.qrScan\" ->")
        assertTrue(
            "发送页没有从桥里取传输包（session 恒 null、出不了码）。",
            Regex("""(?m)^\s*val payload = transferBridge\.outboundPayload""")
                .containsMatchIn(sendBranch),
        )
        assertTrue(
            "发送页标题没接 outboundTitle：两种发送范围（当前课表/全部数据）看起来一模一样。",
            Regex("""(?m)^\s*title = transferBridge\.outboundTitle\s*,""")
                .containsMatchIn(sendBranch),
        )
        assertTrue(
            "数据备份页必须把字节与标题一起写进桥（publishOutbound）。",
            Regex("""(?m)^\s*TransferShellBridge\.publishOutbound\(result\.bytes, result\.title\)""")
                .containsMatchIn(dataTransferSource),
        )
    }

    // ── 3. 扫码路径：回填 + snapshotFlow 消费 ──────────────────────────

    @Test
    fun `扫码回填进进程级桥 且消费仍用 snapshotFlow`() {
        // 终点用**代码行**锚（J14①：整份源码先剥注释，注释锚会失效）
        val scanBranch = branch(shellSource, "\"g3.qrScan\" ->", "\"g3.icsExport\" ->")
        assertTrue(
            "扫码收齐的字节没有写回桥（回本页后没有任何事发生）。",
            Regex("""(?m)^\s*transferBridge\.inboundBytes = raw\s*$""")
                .containsMatchIn(scanBranch),
        )
        assertTrue(
            "扫码字节的消费必须走 snapshotFlow（hy模型 3 的写法，2026-11-10 已定）。",
            Regex("""(?m)^\s*snapshotFlow \{ TransferShellBridge\.inboundBytes \}""")
                .containsMatchIn(dataTransferSource),
        )
        assertFalse(
            "不许改回以 inboundBytes 为 key 的 LaunchedEffect：清空会把正在解码的协程自己取消。",
            "LaunchedEffect(TransferShellBridge.inboundBytes)" in dataTransferSource,
        )
    }

    // ── 4. 导入成功 → 入口页自关（三态决策：Consume / Wait / Ignore）──────

    @Test
    fun `入口页自关由成功代数驱动 三个写入点都走 markImported`() {
        assertTrue(
            "J11：`awaitingMyChild` 状态位必须由入口页的导航分支置位（找不到 `awaitingMyChild = true`）：" +
                "外部「打开方式」推来的子页不经过那里，三态判据靠它区分「谁推的子页」。",
            Regex("""(?m)^\s*awaitingMyChild = true\s*$""").containsMatchIn(importHostsSource),
        )
        assertTrue(
            "J11/J8：消费判据必须走纯函数三态决策（`ImportEntrySignalLogic.decide(...)`），" +
                "判据语义由 `ImportEntrySignalLogicTest` 直接断言；这里钉「宿主真的调了它」。",
            DECIDE_CALL.containsMatchIn(importHostsSource),
        )
        assertTrue(
            "判据结果必须作用到导航（找不到 `if (decision == ImportEntrySignalLogic.Decision.Consume) onBack()`）：" +
                "算了不用 = 自关失效。",
            CONSUME_ACTION.containsMatchIn(importHostsSource),
        )
        assertTrue(
            "基线推进必须走纯函数 `baselineAfter(...)`（Wait 不推进、其余推进这条口径要可单测）。",
            BASELINE_CALL.containsMatchIn(importHostsSource),
        )
        assertTrue(
            "Wait 分支不许顺手清掉 awaitingMyChild（清了就等于把这次增长作废，正常流程自关丢失）。",
            WAIT_KEEPS_AWAITING.containsMatchIn(importHostsSource),
        )
        assertTrue(
            "入口页必须在组合里读代数 + 页面 RESUMED 状态（否则被盖住时收不到状态变化）。",
            Regex("""(?m)^\s*LaunchedEffect\(ImportShellBridge\.importGeneration, pageResumed\)\s*\{""")
                .containsMatchIn(importHostsSource),
        )
        assertTrue(
            "RESUMED 状态必须来自导航条目级 LocalLifecycleOwner（Activity 级永远是 RESUMED，" +
                "先例 AppearanceEditorHost.kt:762）。",
            Regex("""(?m)^\s*val entryLifecycle = LocalLifecycleOwner\.current\s*$""")
                .containsMatchIn(importHostsSource),
        )
        // 评审六加固：只留 `val entryLifecycle = …`、把观察者整块删掉时，`pageResumed` 恒等于
        // 挂载值，上面全部断言仍绿 —— 所以必须钉住「状态真的会被重算」这条接线。
        assertTrue(
            "生命周期观察者必须挂上（找不到 `entryLifecycle.lifecycle.addObserver(observer)`）：" +
                "删掉后 pageResumed 恒等于挂载值，三态里的 RESUMED 判据形同虚设。",
            Regex("""(?m)^\s*entryLifecycle\.lifecycle\.addObserver\(observer\)\s*$""")
                .containsMatchIn(importHostsSource),
        )
        assertTrue(
            "观察者里必须按当前状态重算 pageResumed（找不到 `pageResumed = entryLifecycle.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)`）。",
            Regex(
                """(?m)^\s*pageResumed = entryLifecycle\.lifecycle\.currentState\.isAtLeast\(Lifecycle\.State\.RESUMED\)\s*$""",
            ).containsMatchIn(importHostsSource),
        )
        assertTrue(
            "Wait 分支必须**不推进基线**（纯函数里 `Decision.Wait -> importGenerationAtMount`）：" +
                "推进了 = 这次增长被作废，正常流程自关丢失（评审六指出的那个缺口）。",
            Regex("""(?m)^\s*Decision\.Wait -> importGenerationAtMount\s*$""")
                .containsMatchIn(signalLogicSource),
        )
        assertTrue(
            "「自己的子页被盖住」必须判 Wait（`awaitingMyChild && !pageResumed -> Decision.Wait`）：" +
                "判成 Ignore 会顺手推进基线，等于把正常流程的自关丢掉。",
            Regex("""(?m)^\s*awaitingMyChild && !pageResumed -> Decision\.Wait\s*$""")
                .containsMatchIn(signalLogicSource),
        )
        assertTrue(
            "桥必须提供 markImported()。",
            Regex("""(?m)^\s*fun markImported\(\)""").containsMatchIn(importHostsSource),
        )
        assertFalse(
            "旧的布尔标记 completedImport 不许回来（陈旧信号会把下一次进入的入口页秒关）。",
            "completedImport" in importHostsSource,
        )
        assertEquals(
            "ICS / 表格两条成功路径都必须通知入口页。",
            2,
            Regex("""(?m)^\s*ImportShellBridge\.markImported\(\)\s*$""")
                .findAll(importHostsSource)
                .count(),
        )
        assertTrue(
            "识图导入成功也必须通知入口页（它同样从导入方式页进来）。",
            Regex("""(?m)^\s*ImportShellBridge\.markImported\(\)\s*$""")
                .containsMatchIn(aiImageHostSource),
        )
        assertFalse(
            "识图宿主里不许残留旧的布尔写入。",
            "completedImport" in aiImageHostSource,
        )
    }

    // ── 工具 ────────────────────────────────────────────────────────────

    private fun strip(file: File): String = stripText(file.readText(Charsets.UTF_8))

    /**
     * 剥掉 Kotlin 行注释与（可嵌套）块注释，保留字符串/字符字面量原文。
     *
     * 照同域先例 `WarehouseWebLoginHostWiringGuardTest.stripKotlinComments`（2026-11-03 那边
     * 被「注释掉判据仍命中」咬过一次）：逐字符扫描，没有正则回溯问题。
     */
    private fun stripText(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }

    /** 取 [from]（含）到 [to]（不含）之间的源码段。 */
    private fun branch(source: String, from: String, to: String): String {
        val start = source.indexOf(from)
        assertTrue("找不到分支起点 $from（守卫自身失效）", start >= 0)
        val end = source.indexOf(to, start)
        assertTrue("找不到分支终点 $to（守卫自身失效）", end > start)
        return source.substring(start, end)
    }

    private fun relativeSource(relative: String): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate
            dir = dir?.parentFile
        }
        throw AssertionError("找不到源文件：$relative（工作目录=${File("").absolutePath}）")
    }

    private companion object {
        /**
         * J8/J11 三态消费判据的**调用点**：行锚钉住「宿主真的调了 pure function」。
         * 判据语义本身由 `ImportEntrySignalLogicTest` 直接断言（三态三组边缘）。
         */
        val DECIDE_CALL = Regex(
            """(?m)^\s*val decision = ImportEntrySignalLogic\.decide\($""",
        )
        val BASELINE_CALL = Regex(
            """(?m)^\s*importGenerationAtMount = ImportEntrySignalLogic\.baselineAfter\($""",
        )
        val CONSUME_ACTION = Regex(
            """(?m)^\s*if \(decision == ImportEntrySignalLogic\.Decision\.Consume\) onBack\(\)\s*$""",
        )
        val WAIT_KEEPS_AWAITING = Regex(
            """(?m)^\s*if \(decision != ImportEntrySignalLogic\.Decision\.Wait\) awaitingMyChild = false\s*$""",
        )
    }
}
