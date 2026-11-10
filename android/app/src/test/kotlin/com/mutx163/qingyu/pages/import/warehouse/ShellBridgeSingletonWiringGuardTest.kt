package com.mutx163.qingyu.pages.import.warehouse

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壳桥「进程级单例 + 代数信号」接线守卫（2026-11-10 第二波）。
 *
 * ## 防的是哪一类回归
 *
 * 桥原先建在 `ShellPageContent` 里（`remember { ImportShellBridge() }`），而
 * `ShellPageContent` 由 `entry<ShellRoute.Page>` **每个路由条目各组合一次** ⇒ 目标页拿到
 * 的是另一份空桥。症状三条：二维码发送页出不了码、扫码收齐后点导入没反应、任一导入
 * 成功后入口页不自关。本守卫钉住「单例 + 代数」接线，防它被写回每路由一份/布尔标记。
 *
 * 纯逻辑语义由 [ShellBridgeSignalsTest] 行为测试覆盖；这里只管**接线**（Compose 宿主
 * 进不了 JVM 单测，只能读源码）。断言串都带足够的代码上下文，注释里出现同类字样不算。
 */
class ShellBridgeSingletonWiringGuardTest {

    private val shellSource: String by lazy {
        read("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
    }
    private val importHostsSource: String by lazy {
        read(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/ImportHosts.kt",
        )
    }
    private val dataTransferSource: String by lazy {
        read(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt",
        )
    }
    private val aiImageHostSource: String by lazy {
        read(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/" +
                "AiImageCourseImportHost.kt",
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
        assertTrue(
            "壳里必须直接用单例（`val importBridge = ImportShellBridge`）。",
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
            Regex("""(?m)^\s*bridge\.publishOutbound\(result\.bytes, result\.title\)""")
                .containsMatchIn(dataTransferSource),
        )
    }

    // ── 3. 扫码路径：回填 + snapshotFlow 消费 ──────────────────────────

    @Test
    fun `扫码回填进进程级桥 且消费仍用 snapshotFlow`() {
        val scanBranch = branch(shellSource, "\"g3.qrScan\" ->", "// 2026-10-29 F04")
        assertTrue(
            "扫码收齐的字节没有写回桥（回本页后没有任何事发生）。",
            Regex("""(?m)^\s*transferBridge\.inboundBytes = raw\s*$""")
                .containsMatchIn(scanBranch),
        )
        assertTrue(
            "扫码字节的消费必须走 snapshotFlow（hy模型 3 的写法，2026-11-10 已定）。",
            Regex("""(?m)^\s*snapshotFlow \{ bridge\.inboundBytes \}""")
                .containsMatchIn(dataTransferSource),
        )
        assertFalse(
            "不许改回以 inboundBytes 为 key 的 LaunchedEffect：清空会把正在解码的协程自己取消。",
            dataTransferSource.contains("LaunchedEffect(bridge.inboundBytes)"),
        )
    }

    // ── 4. 导入成功 → 入口页自关（代数信号）────────────────────────────

    @Test
    fun `入口页自关由成功代数驱动 三个写入点都走 markImported`() {
        assertTrue(
            "入口页必须只认挂载之后增长的代数（布尔标记在单例下会被上一趟的旧成功污染）。",
            Regex("""ImportShellBridge\.importGeneration > importGenerationAtMount""")
                .containsMatchIn(importHostsSource),
        )
        assertTrue(
            "入口页必须在组合里读代数（不然被盖住时收不到状态变化）。",
            Regex("""(?m)^\s*LaunchedEffect\(ImportShellBridge\.importGeneration\)""")
                .containsMatchIn(importHostsSource),
        )
        assertTrue(
            "桥必须提供 markImported()。",
            Regex("""(?m)^\s*fun markImported\(\)""").containsMatchIn(importHostsSource),
        )
        assertFalse(
            "旧的布尔标记 completedImport 不许回来（陈旧信号会把下一次进入的入口页秒关）。",
            importHostsSource.contains("bridge.completedImport"),
        )
        assertEquals(
            "ICS / 表格两条成功路径都必须通知入口页。",
            2,
            Regex("""(?m)^\s*bridge\.markImported\(\)\s*$""").findAll(importHostsSource).count(),
        )
        assertTrue(
            "识图导入成功也必须通知入口页（它同样从导入方式页进来）。",
            Regex("""(?m)^\s*bridge\.markImported\(\)\s*$""")
                .containsMatchIn(aiImageHostSource),
        )
        assertFalse(
            "识图宿主里不许残留旧的布尔写入。",
            aiImageHostSource.contains("completedImport"),
        )
    }

    // ── 工具 ────────────────────────────────────────────────────────────

    private fun read(relative: String): String = relativeSource(relative).readText(Charsets.UTF_8)

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
}
