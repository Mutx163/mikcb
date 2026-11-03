package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「今」悬浮胶囊守卫（2026-11-03，随共用件 [BackToTodayFab] 建立）。
 *
 * 日视图「回今日」与周视图「回本周」共用**同一颗**组件（用户口径
 * 「周视图也用同一个按钮」）——玻璃、形状、描边、投影、字号只有一处实现：
 *
 * 1. **两处必须引用同一个组件**：`DayViewPage` / `TimetableWeekPage` 都必须是
 *    `BackToTodayFab(` 调用，且谁都不许再直接调 `FloatingActionButton(` 自己画一份；
 * 2. **官方组件**：共用件内部必须是 miuix `FloatingActionButton` + 官方 border，
 *    旧的 `BackToTodayButton(` / `homeFloatingChipSurface(` 自拼面不得回流；
 * 3. **形状**：圆角 < 高度一半（胶囊，不是用户否掉的「圆球」），且不许出现 CircleShape；
 * 4. **描边与投影同时在**（任一项被删即红）；
 * 5. **触摸区**：尺寸走常量（视觉高 40dp）+ 外层 padding 兜到 ≥48dp；
 * 6. **读屏完整语义**：contentDescription 接各自域的既有键，可见字只是单字「今」；
 * 7. **可见字短键**：两处都必须用 `DayViewStrings.backToTodayShort`；
 * 8. **颜色**：共用件与两个调用点都禁写死 `Color(0xFF`。
 *
 * 沿用仓库源码文本守卫做法（判据先整篇剥注释，字符串感知、块注释按 Kotlin 语义可嵌套）。
 */
class DayViewBackToTodayFabGuardTest {

    private val dayPageSource: String by lazy { stripKotlinComments(readAndroidSource(DAY_PAGE_PATH)) }
    private val weekPageSource: String by lazy { stripKotlinComments(readAndroidSource(WEEK_PAGE_PATH)) }
    private val fabSource: String by lazy { stripKotlinComments(readAndroidSource(FAB_PATH)) }
    private val stringsSource: String by lazy { stripKotlinComments(readAndroidSource(STRINGS_PATH)) }
    private val monthStringsSource: String by lazy { stripKotlinComments(readAndroidSource(MONTH_STRINGS_PATH)) }

    @Test
    fun `两处必须引用同一个共用件`() {
        for ((name, source) in mapOf("DayViewPage" to dayPageSource, "TimetableWeekPage" to weekPageSource)) {
            assertTrue(
                "$name 没有 BackToTodayFab( 调用——「今」胶囊被换成了别的东西。",
                STATEMENT_FAB_CALL.containsMatchIn(source),
            )
            assertFalse(
                "$name 直接调用 FloatingActionButton(——玻璃/形状/描边只有共用件一处实现，" +
                    "自己画一份等于两颗钮开始漂移（用户口径：周视图也用同一个按钮）。",
                STATEMENT_RAW_FAB_CALL.containsMatchIn(source),
            )
            assertTrue(
                "$name 的可见字没有用 DayViewStrings.backToTodayShort——两处必须是同一个单字「今」。",
                source.contains("DayViewStrings.backToTodayShort.zh"),
            )
            assertFalse(
                "$name 又出现 monthViewBackToCurrentMonthShort——那是月视图的键，不得借用。",
                source.contains("monthViewBackToCurrentMonthShort"),
            )
        }
    }

    @Test
    fun `共用件内部必须是官方件且旧自拼面不得回流`() {
        val callArgs = fabCallArgs(fabSource)
        assertTrue(
            "共用件里没有 FloatingActionButton( 调用——官方件被换掉了。" +
                "user.dir=${System.getProperty("user.dir")}",
            callArgs != null,
        )
        assertFalse(
            "旧的自拼磨砂面 homeFloatingChipSurface 不得进共用件。",
            fabSource.contains("homeFloatingChipSurface"),
        )
        assertFalse(
            "共用件里出现 CircleShape——形状被改回圆球（用户已否）。",
            fabSource.contains("CircleShape"),
        )
    }

    @Test
    fun `形态必须是圆角胶囊不得回退圆形`() {
        val corner = constFloatValue(fabSource, "BACK_TO_TODAY_FAB_CORNER_DP")
        val height = constFloatValue(fabSource, "BACK_TO_TODAY_FAB_HEIGHT_DP")
        assertTrue("找不到胶囊圆角常量 BACK_TO_TODAY_FAB_CORNER_DP", corner != null)
        assertTrue("找不到胶囊高度常量 BACK_TO_TODAY_FAB_HEIGHT_DP", height != null)
        assertTrue(
            "圆角 ${corner}dp ≥ 高度 ${height}dp 的一半——胶囊会读成圆形/圆球" +
                "（用户口径：不是圆形、不是圆球）。",
            corner!! < height!! / 2f,
        )
        assertTrue(
            "胶囊形状没有用圆角常量构造（RoundedCornerShape(BACK_TO_TODAY_FAB_CORNER_DP.dp)）。",
            fabSource.contains("RoundedCornerShape(BACK_TO_TODAY_FAB_CORNER_DP.dp)"),
        )
    }

    @Test
    fun `描边与投影必须同时在`() {
        val callArgs = fabCallArgs(fabSource) ?: throw AssertionError("共用件里 FAB 调用不存在")
        assertTrue(
            "FAB 实参没有 shadowElevation——柔和投影（把钮从卡片上托起来）被删了。",
            callArgs.contains(Regex("""shadowElevation\s*=""")),
        )
        assertTrue(
            "胶囊没有描边（border）——玻璃亮棱那圈细边被删了。",
            fabSource.contains(Regex("""\.border\(1\.dp,\s*MiuixTheme\.colorScheme\.onPrimary""")),
        )
    }

    @Test
    fun `触摸区尺寸必须走常量且外层兜满48dp`() {
        val callArgs = fabCallArgs(fabSource) ?: throw AssertionError("共用件里 FAB 调用不存在")
        assertTrue(
            "胶囊的 minHeight 必须用 BACK_TO_TODAY_FAB_HEIGHT_DP 常量——视觉高 40dp，" +
                "命中区靠外层 padding 兜到 ≥48dp。",
            callArgs.contains(Regex("""minHeight\s*=\s*BACK_TO_TODAY_FAB_HEIGHT_DP\.dp""")),
        )
        assertTrue(
            "胶囊的 minWidth 必须用 BACK_TO_TODAY_FAB_WIDTH_DP 常量。",
            callArgs.contains(Regex("""minWidth\s*=\s*BACK_TO_TODAY_FAB_WIDTH_DP\.dp""")),
        )
        assertTrue(
            "胶囊外层缺少垂直 padding 兜底——视觉高 40dp 时命中区必须兜到 ≥48dp。",
            fabSource.contains("padding(vertical = 4.dp)"),
        )
    }

    @Test
    fun `读屏必须念完整语义`() {
        // 两个调用点各自的 contentDescription：日视图「回今日」、周视图「回本周」。
        assertTrue(
            "DayViewPage 的胶囊没有 contentDescription——可见字只是单字「今」，" +
                "读屏必须听到完整动作（backToTodayAction）。",
            dayPageSource.contains("DayViewStrings.backToTodayAction.zh"),
        )
        assertTrue(
            "TimetableWeekPage 的胶囊没有 contentDescription——读屏必须听到完整动作" +
                "（backToCurrentWeekAction = 「回本周」）。",
            weekPageSource.contains("TimetableStrings.backToCurrentWeekAction.zh"),
        )
    }

    @Test
    fun `短字键值不得超过两个字且月视图原键未被改动`() {
        val declared = Regex("""ArbText\(\s*"timetableBackToTodayShort"\s*,\s*"([^"]*)"\s*\)""")
            .find(stringsSource)
        assertTrue(
            "DayViewStrings 里找不到 timetableBackToTodayShort 的 ArbText 声明——键被删了。",
            declared != null,
        )
        val zh = declared!!.groupValues[1]
        assertTrue(
            "timetableBackToTodayShort 的中文值是『$zh』（${zh.length} 个字）——" +
                "可见字必须是 ≤2 个字的短字（用户口径：单字「今」）。",
            zh.length <= 2,
        )
        val monthValue = Regex("""ArbText\(\s*"monthViewBackToCurrentMonthShort"\s*,\s*"([^"]*)"\s*\)""")
            .find(monthStringsSource)?.groupValues[1]
        assertTrue(
            "MonthViewStrings 里找不到 monthViewBackToCurrentMonthShort——月视图的键不许删。",
            monthValue != null,
        )
        assertTrue(
            "monthViewBackToCurrentMonthShort 的值被改成了『$monthValue』——" +
                "月视图原键只许保持「今天」，不许删也不许改值。",
            monthValue == "今天",
        )
    }

    @Test
    fun `首卡顶缝必须在场`() {
        assertTrue(
            "DayViewPage 没有 DAY_VIEW_CONTENT_TOP_SEAM_DP——星期栏与滚动区之间的 14dp 缝" +
                "（Dart timetable_day_view_part.dart:37）丢了，摘要卡吸顶会重新贴死星期栏。",
            dayPageSource.contains("DAY_VIEW_CONTENT_TOP_SEAM_DP"),
        )
    }

    @Test
    fun `不得写死颜色`() {
        for ((name, source) in mapOf(
            "BackToTodayFab" to fabSource,
            "DayViewPage" to dayPageSource,
            "TimetableWeekPage" to weekPageSource,
        )) {
            assertFalse(
                "$name 出现 Color(0xFF 写死色——颜色只许走 MiuixTheme/QingyuTheme 主题槽" +
                    "（R5），写死色深色模式与换主题必错。",
                HARDCODED_COLOR.containsMatchIn(source),
            )
        }
    }

    // ------------------------------------------------------------------
    // 判据工具（与 CourseOverviewSortPopupGuardTest 同一套路）
    // ------------------------------------------------------------------

    /** 取出 `FloatingActionButton(` **调用语句**的实参文本（按括号配平，含嵌套）。 */
    private fun fabCallArgs(text: String): String? {
        val match = STATEMENT_RAW_FAB_CALL.find(text) ?: return null
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

    /** 抽 `const val NAME = <float>f` 的值（剥注释后的源码）。 */
    private fun constFloatValue(source: String, name: String): Float? {
        val m = Regex("""const val $name\s*=\s*([0-9.]+)f""").find(source) ?: return null
        return m.groupValues[1].toFloatOrNull()
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
        val STATEMENT_FAB_CALL = Regex("""(?m)^[ \t]*BackToTodayFab\(""")
        val STATEMENT_RAW_FAB_CALL = Regex("""(?m)^[ \t]*FloatingActionButton\(""")
        val HARDCODED_COLOR = Regex("""Color\(0xFF""")

        const val DAY_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewPage.kt"
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val FAB_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/BackToTodayFab.kt"
        const val STRINGS_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewStrings.kt"
        const val MONTH_STRINGS_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewStrings.kt"
    }
}
