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
        listOf(
            "WarehouseLoadIssue.MIRRORS_FAILED" to "按档位另写分支",
            "serviceMsgWarehouseFetchFailedMirror" to "把文案原文搬到页面",
            "WarehouseFeedCodes" to "按原始码判断（页面只该看 issue）",
        ).forEach { (forbidden, why) ->
            assertFalse(
                "页面不许出现 `$forbidden`（$why）——映射与文案都在 main 层 `WarehouseLoadIssue.kt`",
                adaptersPageSource.contains(forbidden),
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
            "WarehouseStrings.scriptStatusTitle.zh",
            "WarehouseStrings.scriptLoadedLength.filled(",
            "WarehouseStrings.scriptEmpty.zh",
            "WarehouseStrings.warehouseScriptLoadFailed.zh",
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
        assertTrue(
            "读取中要用 miuix 的进度条，不要自己画",
            detailPageSource.contains("LinearProgressIndicator("),
        )
    }

    // ── 工具 ────────────────────────────────────────────────────────────

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
