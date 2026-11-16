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
    fun `带子必须采独立内容层 不许采自己所在的录制层`() {
        // 2026-11-16 P0（367e86ec4 的漏 + 修正笔）：顶栏玻璃就在 contentBackdrop 的录制子树里。
        // 唯一正确采样源是 bandContentBackdrop —— 那一层只录「带子以下的内容」，不含带子自己。
        // 采 contentBackdrop = shader 读自己正在写的层 ⇒ 真机 SIGSEGV（SEGV_ACCERR）。
        assertTrue(
            "周页没有把 bandContentBackdrop（不含带子的内容层）交给带子。",
            weekPageSource.contains("backdrop = bandContentBackdrop"),
        )
        // 判据要钉「带子这一次调用」而不是全文件：回本周浮钮仍合法地采 contentBackdrop。
        val bandCall = weekPageSource.substringAfter("TimetableChromeBandGlass(", "")
            .substringBefore("overdrawDp", "")
        assertFalse(
            "带子又开始采 contentBackdrop —— 它就在那层的录制子树里，" +
                "这是真机 SIGSEGV 的根因（渲染线程读自己正在写的层）。",
            bandCall.contains("contentBackdrop"),
        )
        assertTrue(
            "带子组件不再收 backdrop 参数（backdrop: Backdrop?）——采样源没有交接点。",
            bandGlassSource.contains("backdrop: Backdrop?"),
        )
        assertTrue(
            "色散没有先关掉（dispersion = 0f）——色散着色器有除 halfSize 的路径，" +
                "首帧 size 为 0 会算出非法坐标。",
            bandGlassSource.contains("dispersion = 0f"),
        )
        assertTrue(
            "日页没有接到带子底下（bandUnderlap / LocalEmbeddedDayUnderlapBand 缺一）—— " +
                "日视图上滑仍会在带子下沿硬切。",
            weekPageSource.contains("LocalEmbeddedDayUnderlapBand") &&
                weekPageSource.contains(".bandUnderlap {"),
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
