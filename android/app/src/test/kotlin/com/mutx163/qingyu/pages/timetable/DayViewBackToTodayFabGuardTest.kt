package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日视图「回今日」浮钮守卫（2026-11-03，随官方 `FloatingActionButton` 重做建立）。
 *
 * ## 它钉住哪四件事
 *
 * 1. **官方组件**：按钮必须是 miuix `FloatingActionButton(`——此前是 38dp 磨砂胶囊
 *    （`QingyuCard` + `homeFloatingChipSurface` 自拼面）装「回今日」长文案，用户口径
 *    「长的非常的丑陋」。旧的 `BackToTodayButton(` 自拼件不得回流。
 * 2. **触摸区 ≥ 48dp**：判据是 FAB 调用**不得覆写** `minWidth` / `minHeight`——官方默认
 *    60dp（`FloatingActionButtonDefaults`）满足触摸区；一旦有人覆写小尺寸，这里先红。
 * 3. **无障碍**：`contentDescription` 必须带完整语义（`backToTodayAction`）——可见字
 *    只有「今天」两个字，读屏用户必须听到完整动作。
 * 4. **首卡顶缝**：`DAY_VIEW_CONTENT_TOP_SEAM_DP` 必须在场——星期栏与滚动区之间的
 *    14dp 缝（Dart `timetable_day_view_part.dart:37`）钉在滚动区外，摘要卡吸顶时
 *    不得贴死星期栏（用户口径「第一个卡片插到星期栏下面，重叠了」）。
 *
 * 沿用仓库源码文本守卫做法（`CourseOverviewSortPopupGuardTest` 同套路）：判据先整篇
 * 剥注释（字符串感知、块注释按 Kotlin 语义可嵌套）。
 */
class DayViewBackToTodayFabGuardTest {

    /** 判据只看**代码**：先整篇剥注释。 */
    private val pageSource: String by lazy { stripKotlinComments(readAndroidSource(PAGE_PATH)) }

    @Test
    fun `回今日必须是官方 FloatingActionButton`() {
        val callArgs = fabCallArgs(pageSource)
        assertTrue(
            "一个 FloatingActionButton( 调用都没扫到——「回今日」被换回自研件了" +
                "（miuix 组件优先铁律不许）。user.dir=${System.getProperty("user.dir")}",
            callArgs != null,
        )
        assertFalse(
            "旧的 BackToTodayButton( 自拼磨砂胶囊不得回流——用户口径「长的非常的丑陋」。",
            pageSource.contains("BackToTodayButton("),
        )
    }

    @Test
    fun `触摸区必须保持官方默认不得覆写小尺寸`() {
        val callArgs = fabCallArgs(pageSource) ?: throw AssertionError("FAB 调用不存在，前一条已红")
        assertFalse(
            "FAB 调用覆写了 minWidth/minHeight——官方默认 60dp 满足 48dp 触摸区，" +
                "覆写小尺寸会让触摸区缩水（用户口径：触摸区至少 48dp）。",
            callArgs.contains("minWidth") || callArgs.contains("minHeight"),
        )
    }

    @Test
    fun `无障碍必须念完整语义`() {
        assertTrue(
            "FAB 没有 contentDescription——可见字只有「今天」，读屏用户必须听到完整动作" +
                "（backToTodayAction = 「回今日」）。",
            pageSource.contains(Regex("""contentDescription\s*=\s*\w+Strings\.\w+\.zh""")),
        )
        assertTrue(
            "contentDescription 没有接 backToTodayAction——语义键丢了。",
            pageSource.contains("backToTodayAction"),
        )
    }

    @Test
    fun `首卡顶缝必须在场`() {
        assertTrue(
            "DayViewPage 没有 DAY_VIEW_CONTENT_TOP_SEAM_DP——星期栏与滚动区之间的 14dp 缝" +
                "（Dart timetable_day_view_part.dart:37）丢了，摘要卡吸顶会重新贴死星期栏。",
            pageSource.contains("DAY_VIEW_CONTENT_TOP_SEAM_DP"),
        )
    }

    @Test
    fun `页面不得写死颜色`() {
        assertFalse(
            "DayViewPage 出现 Color(0xFF 写死色——颜色只许走 MiuixTheme/QingyuTheme 主题槽" +
                "（R5），写死色深色模式与换主题必错。",
            HARDCODED_COLOR.containsMatchIn(pageSource),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具（与 CourseOverviewSortPopupGuardTest 同一套路）
    // ------------------------------------------------------------------

    /** 取出 `FloatingActionButton(` **调用语句**的实参文本（按括号配平，含嵌套）。 */
    private fun fabCallArgs(text: String): String? {
        val match = STATEMENT_CALL.find(text) ?: return null
        val openParen = match.range.last
        val close = matchingParen(text, openParen)
        if (close < 0) return null
        return text.substring(openParen + 1, close)
    }

    private fun matchingParen(text: String, openIndex: Int): Int {
        var depth = 0
        var i = openIndex
        while (i < text.length) {
            when (text[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }

    /**
     * 剥掉 `//` 与块注释（块注释按 Kotlin 语义**可嵌套**），字符串字面量感知；
     * 块注释里的换行保留。
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

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        /** 语句位置的调用：行首到调用名之间只有空白。 */
        val STATEMENT_CALL = Regex("""(?m)^[ \t]*FloatingActionButton\(""")
        val HARDCODED_COLOR = Regex("""Color\(0xFF""")

        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt"
    }
}
