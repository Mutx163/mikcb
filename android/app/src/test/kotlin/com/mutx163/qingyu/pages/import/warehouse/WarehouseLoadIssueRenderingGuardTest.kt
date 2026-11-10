package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **失败原因与脚本状态的渲染守卫**（2026-11-05）：读两份页面源码，钉住「槽位真的被画出来」。
 *
 * ## 为什么需要它
 *
 * 宿主把 `failure` / `scriptStatus` 传进页面是一回事，页面**真的用它出文案**是另一回事。
 * 上一批（批 1）只落了参数槽位、页面一次都没读，于是「宿主填得很对、用户什么都看不见」——
 * 这种「传了但不画」的空转，L0 的单测看不见（页面在 composeP1，不在 L0 编译范围）。
 *
 * ## 守卫能证什么 / 不能证什么
 *
 * - **能证**：四态分支都在、文案取自 `WarehouseStrings`/main 层的 `warehouseLoadIssueText`、
 *   提示以「列表还在」为前提、页面没有自己另写一套按 `code` 解析的映射。
 * - **不能证**：运行时排版观感与真实数据落到哪一支（那要 L2/真机）。凡是靠读源码判的守卫
 *   都只能管结构，不许把它当成「页面已验证」。
 */
class WarehouseLoadIssueRenderingGuardTest {

    private val adaptersPageSource: String by lazy {
        stripKotlinComments(
            readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseSchoolAdaptersPage.kt"),
        )
    }
    private val detailPageSource: String by lazy {
        stripKotlinComments(
            readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseAdapterDetailPage.kt"),
        )
    }

    // ── 选校/适配器列表页：失败原因 ──────────────────────────────────────

    @Test
    fun `适配器列表页把失败原因真的翻成文案`() {
        assertTrue(
            "页面必须调用 main 层的 warehouseLoadIssueText(...) 出文案（不许自己拼句子）",
            adaptersPageSource.contains("warehouseLoadIssueText("),
        )
        assertTrue(
            "failure 槽位必须有默认值，未接宿主的调用点行为不变",
            adaptersPageSource.contains("failure: WarehouseLoadFailed? = null"),
        )
    }

    @Test
    fun `有缓存保留列表时 提示以列表还在为前提`() {
        // 缓存列表还在（phase 已是 Idle）时只出一条轻提示；无缓存才走整块失败页。
        assertTrue(
            "轻提示必须以 adapters.isNotEmpty() 为前提，否则会把「有名单」说成「读不到」",
            adaptersPageSource.contains("adapters.isNotEmpty() && failureText != null"),
        )
        assertTrue(
            "整块失败页里也要把原因补在通用标题下面",
            adaptersPageSource.contains("phase == WarehouseListPhase.Failed && failureText != null"),
        )
        assertTrue(
            "「名单还在」这件事必须当参数传给 `warehouseLoadIssueText(..., showingCachedList = …)`，" +
                "否则缓存场景会说出「已尝试 N 条线路」那种吓人的细节",
            adaptersPageSource.contains("showingCachedList = adapters.isNotEmpty()"),
        )
    }

    @Test
    fun `失败原因不许在页面里另写一套按 code 解析的映射`() {
        // 判据针对**生产代码**：把 @Preview 样例函数剥掉后再判——预览样例为了展示
        // 某态会直接构造 `WarehouseLoadIssue.MIRRORS_FAILED` 这类已存在的值，
        // 那不是「按 code 解析的映射」，与本守卫要管的运行时自写映射是两回事（2026-11-08）。
        val production = stripPreviewFunctions(adaptersPageSource)
        listOf(
            "WarehouseLoadIssue.MIRRORS_FAILED" to "按档位另写分支",
            "serviceMsgWarehouseFetchFailedMirror" to "把文案原文搬到页面",
            "WarehouseFeedCodes" to "按原始码判断（页面只该看 issue）",
        ).forEach { (forbidden, why) ->
            assertFalse(
                "页面不许出现 `$forbidden`（$why）——映射与文案都在 main 层 `WarehouseLoadIssue.kt`",
                production.contains(forbidden),
            )
        }
    }

    // ── 详情页：脚本四态 ────────────────────────────────────────────────

    @Test
    fun `详情页脚本状态四态都有渲染分支`() {
        listOf(
            "WarehouseScriptStatus.Loading",
            "WarehouseScriptStatus.Loaded",
            "WarehouseScriptStatus.Empty",
            "WarehouseScriptStatus.Failed",
        ).forEach { branch ->
            assertTrue("脚本状态缺 `$branch` 分支：那一态会变成空白", detailPageSource.contains(branch))
        }
    }

    @Test
    fun `详情页脚本状态用的是现成 ARB 文案`() {
        listOf(
            "WarehouseStrings.scriptStatusTitle.text",
            "WarehouseStrings.scriptLoadedLength.filled(",
            "WarehouseStrings.scriptEmpty.text",
            "WarehouseStrings.warehouseScriptLoadFailed.text",
        ).forEach { key ->
            assertTrue("脚本状态卡必须用 ARB 键 `$key`，不许自拟中文", detailPageSource.contains(key))
        }
    }

    @Test
    fun `详情页真的把 scriptStatus 传进渲染`() {
        assertTrue(
            "槽位默认值必须是 Loading（未接宿主时看起来就是「正在读取」，不会误报脚本坏了）",
            detailPageSource.contains("scriptStatus: WarehouseScriptStatus = WarehouseScriptStatus.Loading"),
        )
        assertTrue(
            "分组必须把 scriptStatus 交给 ScriptStatusBody 渲染，只声明参数不画等于没接",
            detailPageSource.contains("ScriptStatusBody(scriptStatus)"),
        )
        // D1-2（2026-11-10 评审）：原先这条钉的是「页面里有 `LinearProgressIndicator(`」——
        // 页面一迁到 D1 档 D 的套件入口（`QingyuLoadingProgressBar`），这条就会变成「修好了反而红」
        // 的雷。按 PickupCodes 的双向规格改成：正向必须出现套件入口，反向不许再直接调官方裸组件。
        assertTrue(
            "读取中要走 D1 档 D 的套件入口 QingyuLoadingProgressBar（条高/配色由套件钉住），不要自己画",
            detailPageSource.contains("QingyuLoadingProgressBar("),
        )
        assertFalse(
            "详情页又直接调官方 LinearProgressIndicator 了——裸进度条回退，D1 套件白做",
            Regex("""(?<!\w)LinearProgressIndicator\s*\(""").containsMatchIn(detailPageSource),
        )
    }

    // ── 工具 ────────────────────────────────────────────────────────────

    /**
     * 把带 `@Preview` 注解的用户函数整体挖掉（替换成空格，行号不漂）。
     * 判据（与剥注释同一纪律）：样例只为展示某态，构造样本值不算页面自写映射。
     */
    private fun stripPreviewFunctions(source: String): String {
        val out = source.toCharArray()
        var searchFrom = 0
        while (true) {
            val annIdx = source.indexOf("@Preview", searchFrom)
            if (annIdx < 0) break
            // 找到注解之后最近的 fun 及其开括号（注解参数里也可能有括号——用“fun ”锚定）。
            val funIdx = source.indexOf("fun ", annIdx)
            if (funIdx < 0) break
            // 从 fun 的开括号起配平大括号（字符串字面量原样跳过）。
            var i = funIdx
            var brace: Int? = null
            var depth = 0
            var quote: Char? = null
            while (i < source.length) {
                val ch = source[i]
                if (quote != null) {
                    if (ch == '\\') {
                        i += 2
                        continue
                    }
                    if (ch == quote) quote = null
                    i++
                    continue
                }
                when {
                    ch == '"' || ch == '\'' -> quote = ch
                    ch == '{' -> {
                        if (brace == null) brace = i
                        depth++
                    }
                    ch == '}' -> {
                        depth--
                        if (brace != null && depth == 0) break
                    }
                }
                i++
            }
            if (brace != null && i < source.length) {
                for (j in annIdx..i) {
                    if (out[j] != '\n') out[j] = ' '
                }
                searchFrom = i + 1
            } else {
                break
            }
        }
        return String(out)
    }

    /** 剥预览的判据自检：只在预览里引用不算，生产代码里引用才算。 */
    @Test
    fun `剥预览自检——预览引用不判、生产引用仍判`() {
        val previewOnly = """
            @Preview(name = "p")
            @Composable
            private fun PreviewIt() {
                val issue = WarehouseLoadIssue.MIRRORS_FAILED
            }
            @Composable
            fun Page() { }
        """.trimIndent()
        assertFalse(
            "只在 @Preview 样例里的引用不该判红",
            stripPreviewFunctions(previewOnly).contains("WarehouseLoadIssue.MIRRORS_FAILED"),
        )
        val production = """
            @Composable
            fun Page() {
                val issue = WarehouseLoadIssue.MIRRORS_FAILED
            }
        """.trimIndent()
        assertTrue(
            "生产代码里写回引用必须仍判红",
            stripPreviewFunctions(production).contains("WarehouseLoadIssue.MIRRORS_FAILED"),
        )
    }

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    /**
     * 剥掉行注释与块注释再判（与 `WarehouseWebLoginHostWiringGuardTest` 同款）：
     * 把接线注释掉不算还接着线，字符串字面量原样保留。
     */
    private fun stripKotlinComments(source: String): String {
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
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    i += 2
                }
                ch == '"' -> {
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
}
