package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 首页右上角「更多」八宫格瓷贴「带框框」守卫（2026-11-04）。
 *
 * 用户口径：八宫格（GRID 档）现在直接显示图标和文字、**没有框框**；已发布 Flutter 版
 * `v2.1.4.1` 每格是一块圆角卡片。对齐后每格必须包成 [com.mutx163.qingyu.components.QingyuCard]
 * （官方 miuix Card 薄封装），圆角取 `QingyuCardDefaults.SettingsGroupCorner`（24dp，
 * = Flutter `HyperosMiuixSpec.settingsGroupRadius`）。
 *
 * 钉的是「渲染层有没有用整格卡片」这条文本可判的结构，不是像素观感（真机归用户）。
 * 一旦有人把 `TimetableMenuTile` 退回成「裸 Column + clickable」，本守卫即红；
 * 与 `ComposePageStyleGuardTest` 的 R3（禁止裸 `Card(`）互补——那条拦裸 Card，
 * 这条拦「连卡片都没有」。
 *
 * 判据先剥注释/字符串：KDoc 里提到的 `[QingyuCard]`、示例代码都不算数。
 */
class TimetableHomeMenuTileGuardTest {

    private val source: String by lazy { stripKotlinComments(readAndroidSource(TOP_BAR_PATH)) }

    @Test
    fun `八宫格瓷贴必须包成 QingyuCard 并有 24dp 语义圆角`() {
        val tile = tileBody()
        assertTrue(
            "TimetableMenuTile 里没有 QingyuCard( —— 八宫格瓷贴退回成「裸图标+文字」，" +
                "已发布 Flutter 版的圆角卡片框会消失（用户口径「没有框框」复发）。",
            tile.contains("QingyuCard("),
        )
        assertTrue(
            "TimetableMenuTile 的 QingyuCard 没有传 cornerRadius = " +
                "QingyuCardDefaults.SettingsGroupCorner —— 圆角不再是 Flutter 的 24dp。",
            tile.contains("cornerRadius = QingyuCardDefaults.SettingsGroupCorner"),
        )
        assertTrue(
            "TimetableMenuTile 的 QingyuCard 内边距不是 横 7 / 纵 13（Flutter " +
                "`_HomeMenuActionTile` 的 EdgeInsets.symmetric(horizontal: 7, vertical: 13)）。",
            tile.contains("insideMargin = PaddingValues(horizontal = 7.dp, vertical = 13.dp)"),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具
    // ------------------------------------------------------------------

    /** 取 `private fun TimetableMenuTile(` 到其配套右花括号之间的函数体（剥注释后）。 */
    private fun tileBody(): String {
        val marker = "private fun TimetableMenuTile("
        val start = source.indexOf(marker)
        if (start < 0) {
            throw AssertionError("找不到 $marker —— 守卫无法验证，按失败处理")
        }
        val braceStart = source.indexOf('{', start)
        if (braceStart < 0) {
            throw AssertionError("TimetableMenuTile 没有函数体左花括号 —— 守卫无法验证，按失败处理")
        }
        var depth = 0
        var i = braceStart
        while (i < source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(braceStart, i + 1)
                }
            }
            i++
        }
        throw AssertionError("TimetableMenuTile 的函数体花括号不配平 —— 源文件可能被截断")
    }

    /** 剥掉 `//` 与块注释（可嵌套），字符串/字符字面量感知；块注释里的换行保留。 */
    private fun stripKotlinComments(text: String): String {
        val sb = StringBuilder(text.length)
        var i = 0
        var inLineComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < text.length) {
            val ch = text[i]
            val next = if (i + 1 < text.length) text[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                blockDepth > 0 -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < text.length) {
                        sb.append(text[i + 1])
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
        const val TOP_BAR_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableTopBar.kt"
    }
}
