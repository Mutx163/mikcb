package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 周网格「顶进星期栏底下」接线守卫（2026-11-08）。
 *
 * 用户口径：课卡往上滑，插进星期栏以后就没了（硬切），看不到被玻璃糊住。
 * 四件缺一件，现象就回到改前：
 *
 * 1. 网格**下穿**（`bandUnderlap`）：视口不接到带子底下，卡片永远进不去；
 * 2. 滚动内容顶部补**等高留白**（`underlapHeightDp`）：不补，第 1 节会钻到带子里；
 * 3. 带子**画在网格之后**（`zIndex`）：不带，玻璃盖不住钻进去的那一截；
 * 4. 带子采**第二遍**玻璃（`underlayBackdrop`）：不采，玻璃只看得到壁纸、看不到课卡。
 *
 * 判据先整篇剥注释（字符串感知、块注释按 Kotlin 语义可嵌套），免得注释里的词
 * 让守卫假绿。
 */
class TimetableBandUnderlapGuardTest {

    private val weekPageSource: String by lazy {
        stripKotlinComments(readAndroidSource(WEEK_PAGE_PATH))
    }
    private val bandGlassSource: String by lazy {
        stripKotlinComments(readAndroidSource(BAND_GLASS_PATH))
    }

    @Test
    fun `周网格必须下穿到带子底下`() {
        assertTrue(
            "TimetableWeekPage 没挂 bandUnderlap —— 网格视口仍停在带子下沿，课卡进不去。",
            weekPageSource.contains(".bandUnderlap {") || weekPageSource.contains(".bandUnderlap{"),
        )
        assertTrue(
            "WeekPageContent 没有收到 underlapHeightDp —— 第 1 节会钻进带子里。",
            weekPageSource.contains(Regex("""underlapHeightDp\s*=""")),
        )
        assertTrue(
            "WeekPageContent 里没有顶部等高留白 —— 下穿以后第 1 节位置会错。",
            weekPageSource.contains("Spacer(modifier = Modifier.height(underlapHeightDp))"),
        )
    }

    @Test
    fun `带子必须画在网格之后`() {
        assertTrue(
            "TimetableChromeBandGlass 没挂 zIndex —— 网格与带子是 Column 里的上下两块，" +
                "下穿以后课卡会画在玻璃上面，不是被玻璃盖住。",
            weekPageSource.contains(".zIndex(1f)"),
        )
    }

    @Test
    fun `带子必须采第二遍玻璃`() {
        assertTrue(
            "周页面没有把录制层交给带子的 underlayBackdrop —— 玻璃只看得到壁纸，看不到课卡。",
            weekPageSource.contains(
                Regex("""underlayBackdrop\s*=\s*bandStripBackdrop\.takeIf"""),
            ),
        )
        assertTrue(
            "录制层没有按带子高度夹住（clipRect / timetableBandStripPx 不在场）—— " +
                "会退化成整屏离屏重画。",
            weekPageSource.contains("timetableBandStripPx(") &&
                weekPageSource.contains("clipRect("),
        )
        assertTrue(
            "TimetableChromeBandGlass 没有 underlayBackdrop 参数 —— 第二遍玻璃被删了。",
            bandGlassSource.contains("underlayBackdrop: Backdrop? = null"),
        )
        assertFalse(
            "第二遍玻璃把折射也挂上了 —— 卡片在交界处会读成被撕开。",
            bandGlassSource.contains(Regex("""underlay[\s\S]{0,600}?lens\(""")),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具
    // ------------------------------------------------------------------

    /** 剥掉 `//` 与块注释（可嵌套），字符串字面量感知；块注释里的换行保留。 */
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
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val BAND_GLASS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableChromeBandGlass.kt"
    }
}
