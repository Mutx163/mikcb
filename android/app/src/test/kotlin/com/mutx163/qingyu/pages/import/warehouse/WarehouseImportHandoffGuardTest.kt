package com.mutx163.qingyu.pages.import.warehouse

import java.io.File
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 「点网页导入必须带着目标进登录页，且不许同一次点击里被打回学校列表」守卫。
 *
 * ## 防的是哪一类事故（2026-11-03 用户实报）
 *
 * 「课程导入的时候点击网页导入，就会回答学校列表页面」：点「网页登录导入」后界面回到学校列表。
 * 根因是**跨页暂存没跨过去**——壳里 `warehouseState` 是 `ShellPageContent` 内的
 * `remember { WarehouseShellState() }`，而 `ShellPageContent` 由 `entry<ShellRoute.Page>`
 * **每个路由条目各组合一次**（miuix-nav 用 `key(contentKey)` 把条目分成独立组合作用域）。
 * 推 `g2.webLogin` 拿到的是全新实例（学校/适配器都是 null），登录页旧兜底
 * `onOpenPage(IMPORT_PICKER)` 于是把人静默弹回选校页。
 *
 * 修法是加一次性交接件 [WarehouseImportHandoff]：来源页跳转前 `publish`，目标页首次组合 `take`。
 * 这条守卫把三个环节钉死：
 *
 * 1. **一次性**：取走即清，不把这一趟的选择泄漏到下一次进入导入流程；
 * 2. **不缺发布**：`WarehouseImportHosts` 里每个跳去登录页/详情页的 `onOpenPage` 之前都必须
 *    `publish`（漏一处就是一个新的「点了没反应 / 被打回列表」）；
 * 3. **不静默退回**：登录页与详情页拿不到目标时留在原页给实话，不得再 `onOpenPage(IMPORT_PICKER)`。
 *
 * 读源码的判据**先剥注释**（[stripKotlinComments]）：KDoc 里为了解释根因写了那些字样，
 * 不剥注释会把文档当成违规（同 `OverlayDialog` 守卫踩过的坑）。
 */
class WarehouseImportHandoffGuardTest {

    @Before
    fun resetHandoff() {
        WarehouseImportHandoff.clear()
    }

    // -------------------------------------------------------------------
    // 1. 纯判据：交接件一次性
    // -------------------------------------------------------------------

    @Test
    fun `来源页发布后目标页取得到 且取走即清`() {
        WarehouseImportHandoff.publish(
            school = WarehouseSchoolEntry(id = "BUPT", name = "北京邮电大学"),
            adapter = WarehouseAdapterEntry(
                id = "wps",
                name = "WakeUp 课表",
                script = "wps.js",
                importUrl = "https://example.edu",
            ),
            autoRecordMacro = true,
        )

        val payload = WarehouseImportHandoff.take()

        assertEquals("BUPT", payload?.school?.id)
        assertEquals("wps", payload?.adapter?.id)
        assertTrue("自动录制意图也要跟着过页", payload?.autoRecordMacro == true)
        assertNull(
            "取走即清：下一次进入导入流程不该被这一趟的选择污染",
            WarehouseImportHandoff.take(),
        )
    }

    @Test
    fun `快捷导入的待回放宏跟着过页 普通导入不带回放`() {
        val record = WarehouseMacroRecord(
            schoolId = "BUPT",
            adapterId = "wps",
            schoolName = "北京邮电大学",
            adapterName = "WakeUp 课表",
            importUrl = "https://example.edu",
            schoolResourceFolder = "BUPT",
            adapterAssetJsPath = "resources/BUPT/wps.js",
            steps = listOf(WarehouseMacroStep(WarehouseMacroStepType.CLICK, selector = "#btn")),
            createdAt = LocalDateTime.parse("2026-11-03T09:00:00"),
            updatedAt = LocalDateTime.parse("2026-11-03T09:00:00"),
        )
        WarehouseImportHandoff.publish(
            WarehouseSchoolEntry(id = "BUPT", name = "北京邮电大学"),
            WarehouseAdapterEntry(id = "wps", name = "WakeUp 课表", script = "wps.js"),
            playbackMacro = record,
        )
        assertEquals("快捷导入的宏必须跟着过页", record, WarehouseImportHandoff.take()?.playbackMacro)

        WarehouseImportHandoff.publish(
            WarehouseSchoolEntry(id = "BUPT", name = "北京邮电大学"),
            WarehouseAdapterEntry(id = "wps", name = "WakeUp 课表", script = "wps.js"),
        )
        assertNull("普通导入/查看详情不该带上一趟的待回放宏", WarehouseImportHandoff.take()?.playbackMacro)
    }

    @Test
    fun `先发布后发布 以最后一次为准 不会把两趟目标混在一起`() {
        WarehouseImportHandoff.publish(
            WarehouseSchoolEntry(id = "BUPT", name = "北京邮电大学"),
            WarehouseAdapterEntry(id = "wps", name = "WakeUp 课表", script = "wps.js"),
        )
        WarehouseImportHandoff.publish(
            WarehouseSchoolEntry(id = "SEU", name = "东南大学"),
            WarehouseAdapterEntry(id = "seu", name = "东南大学教务", script = "seu.js"),
        )

        val payload = WarehouseImportHandoff.take()

        assertEquals("SEU", payload?.school?.id)
        assertEquals("seu", payload?.adapter?.id)
    }

    // -------------------------------------------------------------------
    // 2. 源码守卫：每个跳转前必须发布
    // -------------------------------------------------------------------

    @Test
    fun `来源页每个跳去登录页或详情页的 onOpenPage 之前都必须先发布交接件`() {
        val host = stripKotlinComments(source("WarehouseImportHosts.kt").readText(Charsets.UTF_8))
        val nav = Regex("""onOpenPage\(WarehouseRoutes\.(WEB_LOGIN|DETAIL)\)""")

        val matches = nav.findAll(host).toList()
        assertTrue("至少要有「跳登录页」的落点，否则判据本身失效了", matches.isNotEmpty())

        val missing = matches.filterNot { m ->
            host.substring(maxOf(0, m.range.first - 600), m.range.first)
                .contains("WarehouseImportHandoff.publish")
        }
        assertTrue(
            "这些跳转没有先发布交接件（目标页会拿不到学校/适配器）：\n" +
                missing.joinToString("\n") { host.substring(maxOf(0, it.range.first - 160), it.range.first + 60) },
            missing.isEmpty(),
        )
    }

    // -------------------------------------------------------------------
    // 3. 源码守卫：目标页不得静默退回选校页
    // -------------------------------------------------------------------

    @Test
    fun `登录页拿不到目标时不得静默跳回选校页`() {
        val src = stripKotlinComments(source("WarehouseWebLoginHost.kt").readText(Charsets.UTF_8))

        assertTrue(
            "登录页必须从交接件取目标，否则壳每页一个实例时永远拿不到",
            src.contains("WarehouseImportHandoff.take()"),
        )
        assertFalse(
            "不许再用 onOpenPage(IMPORT_PICKER) 静默退回——用户看到的就是「点网页导入被打回学校列表」",
            src.contains("onOpenPage(WarehouseRoutes.IMPORT_PICKER)"),
        )
        assertTrue(
            "拿不到目标时必须渲染诚实空态（带返回键），不是空白页也不是跳走",
            src.contains("WarehouseNoTargetPage("),
        )
    }

    @Test
    fun `详情页拿不到目标时不得静默跳回选校页`() {
        val host = stripKotlinComments(source("WarehouseImportHosts.kt").readText(Charsets.UTF_8))
        val body = functionBody(host, "fun WarehouseAdapterDetailHost(")

        assertTrue("详情页必须从交接件取目标", body.contains("WarehouseImportHandoff.take()"))
        assertFalse(
            "详情页不许再静默退回选校页",
            body.contains("onOpenPage(WarehouseRoutes.IMPORT_PICKER)"),
        )
    }

    @Test
    fun `适配器列表页拿不到学校时不得静默跳回选校页`() {
        val host = stripKotlinComments(source("WarehouseImportHosts.kt").readText(Charsets.UTF_8))
        val body = functionBody(host, "fun WarehouseSchoolAdaptersHost(")

        assertTrue("列表页也必须先看交接件（否则从选校页推进来的新条目拿不到学校）", body.contains("WarehouseImportHandoff.take()"))
        assertFalse(
            "列表页不许再静默退回选校页（用户会以为点击被弹回）",
            body.contains("onOpenPage(WarehouseRoutes.IMPORT_PICKER)"),
        )
        assertTrue("拿不到学校时必须渲染诚实空态", body.contains("WarehouseNoTargetPage("))
    }

    @Test
    fun `壳的详情分支必须交给宿主取交接件 不许再画选校页`() {
        val shell = stripKotlinComments(
            relativeSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
                .readText(Charsets.UTF_8),
        )
        val start = shell.indexOf("\"g2.adapterDetail\" ->")
        assertTrue("壳里找不到 g2.adapterDetail 分派分支", start >= 0)
        val end = shell.indexOf("\"g2.webLogin\" ->", start)
        assertTrue("找不到分支边界 g2.webLogin（解析可能失效）", end > start)
        val branch = shell.substring(start, end)

        assertTrue(
            "详情分支必须调 WarehouseAdapterDetailHost（由宿主 take 交接件并给诚实空态）",
            branch.contains("WarehouseAdapterDetailHost("),
        )
        assertFalse(
            "详情分支不许再直接画选校页 WarehouseImportPickerHost",
            branch.contains("WarehouseImportPickerHost("),
        )
    }

    @Test
    fun `选校页点学校后必须先发布交接件再进适配器列表`() {
        val host = stripKotlinComments(source("WarehouseImportHosts.kt").readText(Charsets.UTF_8))
        val body = functionBody(host, "fun WarehouseImportPickerHost(")
        val selectStart = body.indexOf("onSelectSchool = {")
        assertTrue("选校页里找不到 onSelectSchool 回调（判据本身失效了）", selectStart >= 0)
        val jump = body.indexOf("onOpenPage(WarehouseRoutes.ADAPTERS)", selectStart)
        assertTrue("onSelectSchool 里没有进适配器列表的跳转（判据本身失效了）", jump > selectStart)

        val window = body.substring(selectStart, jump)
        assertTrue(
            "onSelectSchool 在 onOpenPage(ADAPTERS) 之前必须 publish 交接件：壳给每个路由条目" +
                "独立的 WarehouseShellState，新条目读不到学校就会把选校页再画一遍（同一所学校要点两遍，" +
                "「最近使用」还记两次）",
            window.contains("WarehouseImportHandoff.publish(school)"),
        )
    }

    @Test
    fun `壳的导入分流必须先看交接件再判 state 且不许只读 state school`() {
        val shell = stripKotlinComments(
            relativeSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
                .readText(Charsets.UTF_8),
        )
        val body = functionBody(shell, "private fun WarehouseImportBranch(")

        assertTrue(
            "分流必须用只读 peek 看交接件，不能 take——拿走了里面的适配器宿主就取不到学校",
            body.contains("WarehouseImportHandoff.peek()"),
        )
        assertFalse(
            "分流不许再只看 state.school == null：新条目拿到的是全新 state，会再画一遍选校页",
            Regex("""if\s*\(\s*state\.school\s*==\s*null\s*\)""").containsMatchIn(body),
        )
        assertTrue(
            "判断要锁在条目首次组合（remember(state)）：peek 被 take 之后会闪回一次选校页",
            body.contains("remember(state)"),
        )
    }

    // -------------------------------------------------------------------
    // 工具
    // -------------------------------------------------------------------

    /** 从工作目录向上找 composeP1 下的那个文件。 */
    private fun source(fileName: String): File =
        relativeSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/$fileName")

    /** 从工作目录向上找仓库根，再定位任意相对路径。 */
    private fun relativeSource(relative: String): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）；守卫不许因为路径变了静默跳过")
    }

    /** 取顶层函数体文本（从签名到下一个行首 `}`）。 */
    private fun functionBody(src: String, signature: String): String {
        val start = src.indexOf(signature)
        assertTrue("源码里找不到 $signature", start >= 0)
        val end = src.indexOf("\n}", start)
        return if (end < 0) src.substring(start) else src.substring(start, end)
    }

    /**
     * 剥掉行注释（双斜杠开头）与块注释（斜杠星开、星斜杠收）再判，保留换行方便定位。
     *
     * 字符串字面量原样保留（`"https://…"` 里的斜杠不是注释）——否则判据会在含 URL
     * 的那一行提前截断，把真接线当成已注释。
     */
    private fun stripKotlinComments(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var quote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            if (quote != null) {
                out.append(ch)
                if (ch == '\\' && i + 1 < source.length) {
                    out.append(source[i + 1])
                    i += 2
                } else {
                    if (ch == quote) quote = null
                    i += 1
                }
                continue
            }
            when {
                source.startsWith("\"\"\"", i) -> {
                    // 原始字符串：内部的双斜杠 / 星号都不算注释，原样搬到下一个三引号。
                    out.append("\"\"\"")
                    i += 3
                    while (i < source.length && !source.startsWith("\"\"\"", i)) {
                        out.append(source[i])
                        i += 1
                    }
                    if (i < source.length) {
                        out.append("\"\"\"")
                        i += 3
                    }
                }

                source.startsWith("//", i) -> {
                    while (i < source.length && source[i] != '\n') i++
                }

                source.startsWith("/*", i) -> {
                    i += 2
                    while (i < source.length && !source.startsWith("*/", i)) {
                        if (source[i] == '\n') out.append('\n')
                        i++
                    }
                    if (i < source.length) i += 2
                }

                ch == '"' || ch == '\'' -> {
                    quote = ch
                    out.append(ch)
                    i += 1
                }

                else -> {
                    out.append(ch)
                    i += 1
                }
            }
        }
        return out.toString()
    }
}
