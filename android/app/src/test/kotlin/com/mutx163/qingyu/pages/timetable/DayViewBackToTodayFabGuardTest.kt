package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
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
 * 2. **玻璃底**：共用件内部必须是 `drawBackdrop` + `vibrancy()` + `blur()` + `lens()`
 *    + 官方 `Highlight.GlassStrokeSmall*`；旧的 `homeFloatingChipSurface` 自拼面
 *    与实心 `FloatingActionButton` 不得回流；
 * 3. **形状**：`RoundedCornerShape(percent = 50)` 胶囊（不是用户否掉的「圆球」），
 *    且不许出现 CircleShape；
 * 4. **投影与亮棱同时在**（任一项被删即红）；
 * 5. **触摸区**：`heightIn(min = BACK_TO_TODAY_FAB_MIN_HEIGHT_DP.dp)`，且 ≥48dp；
 * 6. **读屏完整语义**：contentDescription 接各自域的既有键，可见字只是单字「今」；
 * 7. **可见字短键**：两处都必须用 `DayViewStrings.backToTodayShort`；
 * 8. **颜色**：共用件与两个调用点都禁写死 `Color(0xFF`。
 *
 * 沿用仓库源码文本守卫做法（判据先整篇剥注释，字符串感知、块注释按 Kotlin 语义可嵌套）。
 */
class DayViewBackToTodayFabGuardTest {

    private val dayPageSource: String by lazy { stripKotlinComments(readAndroidSource(DAY_PAGE_PATH)) }
    private val scrollContentSource: String by lazy { stripKotlinComments(readAndroidSource(SCROLL_CONTENT_PATH)) }
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
                "$name 直接调用 FloatingActionButton(——玻璃/形状/投影只有共用件一处实现，" +
                    "自己画一份等于两颗钮开始漂移（用户口径：周视图也用同一个按钮）。",
                STATEMENT_RAW_FAB_CALL.containsMatchIn(source),
            )
            assertTrue(
                "$name 的可见字没有用 DayViewStrings.backToTodayShort——两处必须是同一个单字「今」。",
                source.contains("DayViewStrings.backToTodayShort.text"),
            )
            assertFalse(
                "$name 又出现 monthViewBackToCurrentMonthShort——那是月视图的键，不得借用。",
                source.contains("monthViewBackToCurrentMonthShort"),
            )
        }
    }

    @Test
    fun `两处必须把玻璃与可见性接进共用件`() {
        for ((name, source) in mapOf("DayViewPage" to dayPageSource, "TimetableWeekPage" to weekPageSource)) {
            assertTrue(
                "$name 没有把可见性交给共用件的 visible——外层 if 会把节点直接摘掉，" +
                    "退场动画没机会播。",
                source.contains("visible = "),
            )
            assertTrue(
                "$name 没有把「真实内容录制层」传给浮钮（backdrop 走 contentBackdrop）——" +
                    "B1 口径：浮钮要采它背后的真实内容，而不是只录壁纸的 pageBackdrop。",
                source.contains("BackToTodayFab(") && source.contains("contentBackdrop"),
            )
            assertTrue(
                "$name 没有把材质快照传给浮钮（material = ...）——浮钮会永远画实底。",
                source.contains("material = material"),
            )
            assertTrue(
                "$name 没有把 hasBackdrop 传给浮钮——没壁纸时也会去模糊空气。",
                source.contains("hasBackdrop = hasBackdrop"),
            )
            assertTrue(
                "$name 没有在浮动玻璃档挂真实内容录制层（layerBackdrop(contentBackdrop)）——" +
                    "B1 口径：浮钮采 contentBackdrop（壁纸+内容），不再只录 pageBackdrop。",
                source.contains("floatingGlassActive") &&
                    source.contains("layerBackdrop(contentBackdrop)"),
            )
        }
    }

    @Test
    fun `共用件内部必须是玻璃胶囊且旧自拼面不得回流`() {
        assertTrue(
            "共用件里没有 drawBackdrop(——玻璃底被换成了实心色块。" +
                "user.dir=${System.getProperty("user.dir")}",
            fabSource.contains("drawBackdrop("),
        )
        assertTrue(
            "共用件没有 vibrancy()——玻璃会发灰。",
            fabSource.contains("vibrancy()"),
        )
        assertTrue(
            "共用件没有 blur(——模糊层被删了。",
            fabSource.contains("blur("),
        )
        assertTrue(
            "共用件没有 lens(——液态档的折射被删了。",
            fabSource.contains("lens("),
        )
        assertTrue(
            "共用件没有官方 Highlight.GlassStrokeSmall*——玻璃亮棱被删了。",
            fabSource.contains("Highlight.GlassStrokeSmall"),
        )
        assertTrue(
            "共用件没有 InteractiveHighlight(——按压提亮 / 指尖光斑被删了。",
            fabSource.contains("InteractiveHighlight("),
        )
        assertTrue(
            "共用件没有 title3（20sp）——字号被改小了，胶囊会显得又矮又空。",
            fabSource.contains("textStyles.title3"),
        )
        assertTrue(
            "共用件没有 AnimatedVisibility(——出入场动画被删了。",
            fabSource.contains("AnimatedVisibility("),
        )
        assertTrue(
            "共用件没有 visible 参数——两处调用点就没办法交给它播退场。",
            fabSource.contains("visible: Boolean"),
        )
        assertFalse(
            "共用件里出现 FloatingActionButton(——实心 FAB 又回来了。",
            fabSource.contains("FloatingActionButton("),
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
    fun `形态必须是胶囊不得回退圆形或实心块`() {
        assertTrue(
            "胶囊形状没有用 RoundedCornerShape(percent = 50) 构造。",
            fabSource.contains("RoundedCornerShape(percent = 50)"),
        )
        assertFalse(
            "共用件出现 CircleShape——形状被改回圆球（用户已否）。",
            fabSource.contains("CircleShape"),
        )
    }

    @Test
    fun `投影与亮棱必须同时在`() {
        assertTrue(
            "共用件没有 dropShadow(——彩色浮影被删了，钮会贴在卡片上。",
            fabSource.contains("dropShadow("),
        )
        assertTrue(
            "共用件没有 Shadow(——dropShadow 缺少投影参数。",
            fabSource.contains("Shadow("),
        )
        assertTrue(
            "共用件没有官方 Highlight.GlassStrokeSmall*——玻璃亮棱被删了。",
            fabSource.contains("Highlight.GlassStrokeSmall"),
        )
    }

    @Test
    fun `触摸区尺寸必须走常量且不低于48dp`() {
        assertTrue(
            "胶囊没有 heightIn(min = BACK_TO_TODAY_FAB_MIN_HEIGHT_DP.dp)——" +
                "命中区下限被删了。",
            fabSource.contains("heightIn(min = BACK_TO_TODAY_FAB_MIN_HEIGHT_DP.dp)"),
        )
        val height = constFloatValue(fabSource, "BACK_TO_TODAY_FAB_MIN_HEIGHT_DP")
        assertTrue("找不到胶囊高度常量 BACK_TO_TODAY_FAB_MIN_HEIGHT_DP", height != null)
        assertTrue(
            "胶囊视觉高 ${height}dp 小于 48dp 的命中下限。",
            height!! >= 48f,
        )
    }

    @Test
    fun `读屏必须念完整语义`() {
        // 两个调用点各自的 contentDescription：日视图「回今日」、周视图「回本周」。
        assertTrue(
            "DayViewPage 的胶囊没有 contentDescription——可见字只是单字「今」，" +
                "读屏必须听到完整动作（backToTodayAction）。",
            dayPageSource.contains("DayViewStrings.backToTodayAction.text"),
        )
        assertTrue(
            "TimetableWeekPage 的胶囊没有 contentDescription——读屏必须听到完整动作" +
                "（backToCurrentWeekAction = 「回本周」）。",
            weekPageSource.contains("TimetableStrings.backToCurrentWeekAction.text"),
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
    fun `首卡顶缝必须在列表里而不是滚动区外`() {
        // 2026-11-07 用户口径：静止时首卡不要贴住星期栏（留 14dp），但上滑时
        // 这道缝要跟着滚走 —— 所以它必须是一个普通 item；挂在滚动区外面
        // 就是一条永远滚不走的空带（用户报「上滑也留着空隙」）。
        assertTrue(
            "DayViewScrollContent 没有 `day-top-seam` 列表项：14dp 留缝丢了，" +
                "首卡会直接贴住星期栏。",
            scrollContentSource.contains("day-top-seam"),
        )
        assertEquals(
            "顶部留缝数值不是 14dp（Dart timetable_day_view_part.dart:37 同值）。",
            14f,
            constFloatValue(scrollContentSource, "DAY_VIEW_TOP_SEAM_DP"),
        )
        assertFalse(
            "DayViewPage 又在滚动区外面加了留缝（DAY_VIEW_CONTENT_TOP_SEAM_DP）：" +
                "那会变成一条永远滚不走的空带。",
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
    // 2026-11-04：两颗「今」钮的两处行为收口（日↔周过渡落定后再淡入 + 阴影不露框）
    // ------------------------------------------------------------------

    @Test
    fun `日钮等展开过渡落定后再淡入_对齐周钮出场动效`() {
        // Part1：日钮 visible 以「嵌入过渡是否落定」为门（独立页/预览恒 true，旧行为不变）。
        assertTrue(
            "DayViewPage 没有声明 LocalEmbeddedDayTransitionSettled——展开过渡落定态没处传。",
            dayPageSource.contains("LocalEmbeddedDayTransitionSettled"),
        )
        assertTrue(
            "日钮 visible 没有接 embeddedTransitionSettled 门控——过渡期间钮会跟着转场一起出现。",
            dayPageSource.contains("!embeddedInHomePanel || embeddedTransitionSettled"),
        )
        // Part1：周页用 dayExpand 的落定态（derivedStateOf，≥0.999 翻一次）provide 下去。
        assertTrue(
            "TimetableWeekPage 缺 dayExpandSettled 的 derivedStateOf 落定判据（≥0.999f）。",
            weekPageSource.contains("dayExpandSettled") && weekPageSource.contains("0.999f"),
        )
        assertTrue(
            "TimetableWeekPage 没在 CompositionLocalProvider 里 provide 落定态——日钮永远等不到 true。",
            weekPageSource.contains(
                "LocalEmbeddedDayTransitionSettled provides dayExpandSettled",
            ),
        )
    }

    @Test
    fun `阴影留白兜进动画节点_不露矩形框`() {
        // Part2：共用件给动画内容加 FAB_SHADOW_REACH_DP 的透明留白，把越界阴影兜进 bounds。
        assertTrue(
            "共用件缺 FAB_SHADOW_REACH_DP 常量——没有阴影外扩留白的口径。",
            fabSource.contains("FAB_SHADOW_REACH_DP"),
        )
        assertTrue(
            "共用件动画内容没有 .padding(FAB_SHADOW_REACH_DP.dp)——越界阴影在出场首帧会被瞬时层框住。",
            fabSource.contains("padding(FAB_SHADOW_REACH_DP.dp)"),
        )
    }

    // 咬合探针（负例自测）：证明上面两条判据有牙齿。
    @Test
    fun `负例自测_去掉settle门或阴影留白应判红`() {
        fun okPart1(day: String, week: String): Boolean =
            day.contains("!embeddedInHomePanel || embeddedTransitionSettled") &&
                week.contains("LocalEmbeddedDayTransitionSettled provides dayExpandSettled")
        assertTrue("真实源码应通过 Part1", okPart1(dayPageSource, weekPageSource))
        assertFalse(
            "去掉日钮 settle 门（visible 退回 showsBackToToday）应判红",
            okPart1(
                dayPageSource.replace(
                    "!embeddedInHomePanel || embeddedTransitionSettled",
                    "true",
                ),
                weekPageSource,
            ),
        )
        assertFalse(
            "去掉周页 provide 落定态应判红",
            okPart1(
                dayPageSource,
                weekPageSource.replace(
                    "LocalEmbeddedDayTransitionSettled provides dayExpandSettled",
                    "",
                ),
            ),
        )

        fun okPart2(fab: String): Boolean = fab.contains("padding(FAB_SHADOW_REACH_DP.dp)")
        assertTrue("真实共用件应通过 Part2", okPart2(fabSource))
        assertFalse(
            "去掉阴影留白 padding 应判红",
            okPart2(fabSource.replace("padding(FAB_SHADOW_REACH_DP.dp)", "")),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具（与 CourseOverviewSortPopupGuardTest 同一套路）
    // ------------------------------------------------------------------

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
        const val SCROLL_CONTENT_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewScrollContent.kt"
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
