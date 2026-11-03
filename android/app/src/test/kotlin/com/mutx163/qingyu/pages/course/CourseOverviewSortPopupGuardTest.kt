package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 课程总览页「排序」弹层守卫（2026-11-03 弹窗审计收尾建立）。
 *
 * ## 它防的是哪两类事故
 *
 * 1. **miuix 优先**：排序弹层曾是裸 `androidx.compose.ui.window.Popup` + `QingyuCard`
 *    手拼菜单（审核报告 S6 / 例外表「待核」第一条），没有官方遮罩、进出场动画与返回
 *    手势进度。2026-11-03 迁官方 `OverlayListPopup` + `ListPopupColumn` + `DropdownImpl`。
 *    本守卫钉住「官方组件在场、原生 Popup 不回流」。
 * 2. **条件挂载**：弹层曾被 `if (sortPopupOpen) { … }` 包住——组件随关闭整棵离开组合，
 *    官方组件内部的进出场驱动（`show` false→内部 `internalVisible` 播完退场才卸载）一次
 *    都不会走。现在调用点常驻、按 `show = sortPopupOpen` 切显示；本守卫钉住调用实参里
 *    必须有 `show =`，且全文件不得再出现 `if (sortPopupOpen)` 条件包装。
 *
 * 沿用仓库源码文本守卫做法（`WeekGridWeightGuardTest` / `ComposeSheetGuardTest` 同套路）：
 * 测试设施无 compose-ui-test / Robolectric，跑不了真实布局，退场不崩的运行时行为由
 * 官方 `ListPopupLayout` 组件保证，这里只钉源码形态。
 *
 * **代价写清**：文本判据对格式敏感。真把调用改成别的写法时这条会先红——那是**故意的**，
 * 提醒改接线的人同时更新判据，而不是静默失效。
 */
class CourseOverviewSortPopupGuardTest {

    /** 判据只看**代码**：先整篇剥注释（字符串感知、块注释按 Kotlin 语义可嵌套）。 */
    private val pageSource: String by lazy { stripKotlinComments(readAndroidSource(PAGE_PATH)) }

    @Test
    fun `排序弹层必须走官方 OverlayListPopup`() {
        assertTrue(
            "源码里没有 OverlayListPopup( ——排序弹层被换回自研容器了（miuix 优先标准不许）。" +
                "user.dir=${System.getProperty("user.dir")}",
            pageSource.contains("OverlayListPopup("),
        )
        assertFalse(
            "课程总览页不得再 import androidx.compose.ui.window.Popup——排序弹层已迁官方 " +
                "OverlayListPopup，原生 Popup 回流等于把审核报告 S6 的裸弹层债重新欠上",
            pageSource.contains("androidx.compose.ui.window.Popup"),
        )
    }

    @Test
    fun `排序弹层必须常驻组合按 show 驱动`() {
        val callArgs = popupCallArgs(pageSource)
        assertTrue(
            "一个 CourseOverviewSortPopup( 调用都没扫到，判据已失效（门禁空跑会假绿）。" +
                "user.dir=${System.getProperty("user.dir")}",
            callArgs != null,
        )
        assertTrue(
            "CourseOverviewSortPopup 调用必须传 show =（常驻组合、状态驱动）。" +
                "官方 OverlayListPopup 的进出场由组件内部按 show 驱动，调用点若改成条件挂载，" +
                "退场动画一次都播不了",
            callArgs!!.contains(Regex("""\bshow\s*=""")),
        )
        assertFalse(
            "排序弹层不得再被 if (sortPopupOpen) 条件挂载——组件随关闭整棵离开组合，" +
                "官方退场动画（缩放揭示 + 遮罩淡出）永远不播；请常驻组合、只翻 show",
            CONDITIONAL_MOUNT.containsMatchIn(pageSource),
        )
    }

    // ------------------------------------------------------------------
    // 判据
    // ------------------------------------------------------------------

    /** 取出 `CourseOverviewSortPopup(` **调用语句**的实参文本（按括号配平，含嵌套）。 */
    private fun popupCallArgs(text: String): String? {
        // 只认语句位置的调用（行首到调用名之间只有空白）——定义处 `private fun` 前缀
        // 不会被误抓，注释里顶格写的同名片段理论上可能误抓，改判据时留意。
        val match = STATEMENT_CALL.find(text) ?: return null
        val openParen = match.range.last // 正则把 '(' 吃进匹配末尾，range.last 就是它
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
     * 剥掉 `//` 与 `/* */`（块注释按 Kotlin 语义**可嵌套**），与 `ComposeSheetGuardTest`
     * 同一套路：判据看代码不看注释——注释里提全限定名、写假调用都不许影响判定，
     * 也不许让判据误红（本守卫自己第一版就被 KDoc 里的 FQN 误伤过）。
     * 对字符串字面量感知（`"https://…"` 里的 `//` 不算注释）；块注释里的换行保留。
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
        /** 语句位置的调用：行首到调用名之间只有空白（`private fun` 定义不会被误抓）。 */
        val STATEMENT_CALL = Regex("""(?m)^[ \t]*CourseOverviewSortPopup\(""")

        /** 老的条件挂载写法：`if (sortPopupOpen)`（后跟 `{` 或别的都算，先剥注释再判由调用方保证）。 */
        val CONDITIONAL_MOUNT = Regex("""\bif\s*\(\s*sortPopupOpen\s*\)""")

        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/CourseOverviewPage.kt"
    }
}
