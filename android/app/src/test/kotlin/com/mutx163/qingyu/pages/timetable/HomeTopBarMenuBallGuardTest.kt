package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 首页顶栏「更多」按钮必须是**常驻玻璃球**（2026-11-10）。
 *
 * 用户口径：「三个点要圆圈底 + 阴影」。发布版顶栏动作键本来就是一颗浮着的玻璃球
 * （`FHeaderActionBall`），迁移时两档都退成了裸图标 —— miuix `IconButton` 默认
 * `backgroundColor = Color.Unspecified`，`squircleSurface` 不画底，肉眼就是一根光秃秃的「⋯」。
 *
 * 这条守卫钉三件事（写明"长什么样"的文本级判据，像素观感归真机）：
 *
 * 1. 列表档 / 八宫格档**都要**走 [HomeTopBarActionBall] 那套球（`HomeTopBarActionBallChrome`
 *    是纯视觉层，列表档要用它垫在官方菜单下面）；
 * 2. 八宫格档不许再退回裸官方 `IconButton`（那正是「没有圆圈底」的原状）；
 * 3. 列表档的官方菜单必须把底色让成透明 —— 它自己会画一层 squircle 圆底，不让位就是
 *    「双重圈圈」（2026-11-08 用户实报）。
 */
class HomeTopBarMenuBallGuardTest {

    private val source by lazy { stripKotlinComments(readSource(TOP_BAR_PATH)) }

    @Test
    fun `两个菜单档都必须画玻璃球`() {
        val listBranch = branch("if (homeMenuStyle == HomeMenuStyle.LIST)")
        assertTrue(
            "列表档没有把 `HomeTopBarActionBallChrome(` 垫在官方级联菜单下面：右上角又会变回裸图标。",
            listBranch.contains("HomeTopBarActionBallChrome("),
        )
        // 列表档的点击归官方菜单，所以球只画视觉层；球体整件（自带点击）属于八宫格档。
        assertTrue(
            "列表档没有调用官方级联菜单（`OverlayIconCascadingDropdownMenu(`）",
            listBranch.contains("OverlayIconCascadingDropdownMenu("),
        )
        assertTrue(
            "八宫格档没有用 `HomeTopBarActionBall(` 画球（自带点击的那件）：" +
                "又退回裸 `IconButton` 了吗？",
            source.contains("HomeTopBarActionBall("),
        )
    }

    @Test
    fun `八宫格档不许退回裸官方 IconButton`() {
        assertFalse(
            "又出现了 `IconButton(onClick = { showMenu = true })`：miuix IconButton 默认不画底，" +
                "这颗按钮就会变回「没有圆圈底」的裸图标。",
            source.contains("IconButton(onClick = { showMenu = true })"),
        )
    }

    @Test
    fun `列表档的官方菜单必须让出圆底`() {
        val menuBlock = callBlock(source, "OverlayIconCascadingDropdownMenu(")
        assertTrue(
            "官方级联菜单没有 `backgroundColor = Color.Transparent`：它自己会画一层 squircle 圆底，" +
                "套在玻璃球里就是「双重圈圈」（2026-11-08 实报）。",
            menuBlock.contains("backgroundColor = Color.Transparent"),
        )
        assertTrue(
            "官方级联菜单的按钮尺寸没有对齐球（`minWidth` / `minHeight` = HomeTopBarBallSize）：" +
                "尺寸不一致时球与按钮会错位半个身位。",
            menuBlock.contains("minWidth = HomeTopBarBallSize") &&
                menuBlock.contains("minHeight = HomeTopBarBallSize"),
        )
    }

    @Test
    fun `球配方与全站顶栏玻璃钮同档`() {
        assertTrue(
            "球直径不是 44dp（`private val HomeTopBarBallSize: Dp = 44.dp`）：" +
                "全站顶栏玻璃钮都是 44dp，两种尺寸并存会一眼看出不齐。",
            Regex("""val HomeTopBarBallSize: Dp = 44\.dp""").containsMatchIn(source),
        )
        assertTrue(
            "球缺 `shadow(elevation = 2.dp`：用户明确要了「圆圈底 + 阴影」，没有浮影就还是一块平贴的色块。",
            source.contains("shadow(elevation = 2.dp"),
        )
        assertTrue(
            "球缺 0.75dp 细边（`border(width = 0.75.dp`）：这是玻璃球在白底上不出「灰盘」的那一圈边。",
            source.contains("border(width = 0.75.dp"),
        )
        assertTrue(
            "球的玻璃 spec 不是按 `GlassSpecResolver.resolve(` 重建的那一档：与顶栏玻璃钮的观感会漂开。",
            source.contains("val HomeTopBarBallGlassSpec: GlassSpec = GlassSpecResolver.resolve("),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        assertTrue(
            "TimetableTopBar.kt 源码读取太短（${source.length} 字符），路径解析可能坏了",
            source.length > 10_000,
        )
        assertTrue(
            "列表档分支截取失败（判据可能匹配到 KDoc 里的字样）",
            branch("if (homeMenuStyle == HomeMenuStyle.LIST)").length > 200,
        )
    }

    /** 取 `marker` 起的那段 `if (...) { … }` 块体（剥注释后）。 */
    private fun branch(marker: String): String {
        val start = source.indexOf(marker)
        if (start < 0) throw AssertionError("找不到 $marker —— 守卫无法验证，按失败处理")
        val braceStart = source.indexOf('{', start)
        if (braceStart < 0) throw AssertionError("$marker 没有块体 —— 守卫无法验证")
        var depth = 0
        for (i in braceStart until source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(braceStart, i + 1)
                }
            }
        }
        throw AssertionError("$marker 的块体花括号不配平 —— 源文件可能被截断")
    }

    /** 按括号配对取出 `marker(` 那一整个调用块。 */
    private fun callBlock(text: String, marker: String): String {
        val start = text.indexOf(marker)
        if (start < 0) throw AssertionError("找不到 $marker —— 守卫无法验证，按失败处理")
        val open = start + marker.length - 1
        var depth = 0
        for (i in open until text.length) {
            when (text[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return text.substring(open, i + 1)
                }
            }
        }
        throw AssertionError("$marker 的实参括号没有闭合")
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

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val TOP_BAR_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableTopBar.kt"
    }
}
