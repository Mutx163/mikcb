package com.mutx163.qingyu.pages.timetable

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程卡逐卡飞行「接线 + 配对 + 作用域守卫」（C-2 + v2 §0 + P-2/P-3，2026-11-04）。
 *
 * 防的是不会让编译失败、单测也全绿的事故：**零件都写好了却没人接线**，或**两端 key 没一对一对上**。
 *
 * 判据（剥注释后）：
 * - P0-1：`TimetableWeekPage` 建了 `CourseFlightMeasureHost(` 且用 provider 注入；
 * - P-3：**provider 块内**（按大括号配平截取，不靠索引先后）必须同时含
 *   `HorizontalPager(` / `dayContent(` / `TimetableCourseFlightLayer(`——把层移出 provider 也能抓到；
 * - P0-3：`flightWeek = page + 1` 与 `flightWeek = flightWeek` 真传；
 * - v2§0③：cardKeys 过滤含 `weekSurfaces.containsKey(key)`；
 * - v2§0①② + P-2：周侧 `TimetableWeekGrid` 与日侧 `DayViewScrollContent` **各自**调用
 *   `courseFlightCardKey(` 且实参含 `.course.id` 与 `startSection`；层里两端都读、无摘要层。
 *
 * P-1：每条判据都有「负例自测」——喂合成坏串断言必报问题（证明判据有牙齿，不是空转）。
 */
class CourseFlightWiringGuardTest {

    private val weekPageRaw by lazy { readAndroidSource(WEEK_PAGE_PATH) }
    private val layerRaw by lazy { readAndroidSource(LAYER_PATH) }
    private val weekGridRaw by lazy { readAndroidSource(WEEK_GRID_PATH) }
    private val courseCardRaw by lazy { readAndroidSource(COURSE_CARD_PATH) }
    private val dayScrollRaw by lazy { readAndroidSource(DAY_SCROLL_PATH) }

    // ────────────────────────── 真实源码全绿 ──────────────────────────

    @Test
    fun `真实源码接线无问题`() {
        val problems = wiringProblems(weekPageRaw, layerRaw, weekGridRaw, dayScrollRaw)
        assertEquals(
            "接线守卫检出问题：\n" + problems.joinToString("\n"),
            emptyList<String>(),
            problems,
        )
    }

    @Test
    fun `P2 两端都调 courseFlightCardKey 且含 course_id 与 startSection`() {
        assertTrue(
            "周侧（TimetableWeekGrid）没调 courseFlightCardKey 或实参缺 .course.id/startSection",
            keyCallOk(weekGridRaw),
        )
        assertTrue(
            "日侧（DayViewScrollContent）没调 courseFlightCardKey 或实参缺 .course.id/startSection",
            keyCallOk(dayScrollRaw),
        )
        // 周侧四元在 TimetableWeekGrid 生成，CourseGridCard 只**接收算好的 flightCardKey** 并用它登记；
        // 这里补一条：CourseGridCard 必须真的拿着 flightCardKey 去登记（否则算好了也不落到卡上）。
        val cc = stripKotlinComments(courseCardRaw)
        assertTrue("CourseGridCard 没有 flightCardKey 入参/登记", cc.contains("flightCardKey"))
        assertTrue(
            "CourseGridCard 没把 flightCardKey 用于周侧登记（weekTextModifier / weekSurfaceModifier 依赖 flightKey）",
            cc.contains("flightHost.weekTextModifier(flightKey") && cc.contains("weekSurfaceModifier(flightKey"),
        )
    }

    @Test
    fun `层两端必读且绝不含摘要层`() {
        val ly = stripKotlinComments(layerRaw)
        assertTrue("CourseFlightCard 必须读 weekSurfaces[cardKey]", ly.contains("host.weekSurfaces[cardKey]"))
        assertTrue("CourseFlightCard 必须读 daySurfaces[cardKey]", ly.contains("host.daySurfaces[cardKey]"))
        assertFalse("层里出现 DayViewSummaryFlight（v2 明确禁止）", ly.contains("DayViewSummaryFlight"))
    }

    // ────────────────────────── 负例自测（P-1：判据有牙齿）──────────────────────────

    @Test
    fun `负例自测_缺 provider 必红`() {
        val broken = weekPageRaw.replace("CompositionLocalProvider(LocalCourseFlightMeasure provides", "XXXX")
        assertTrue(
            "删掉 provider 后必须报问题",
            wiringProblems(broken, layerRaw, weekGridRaw, dayScrollRaw).isNotEmpty(),
        )
    }

    @Test
    fun `负例自测_缺飞行层必红`() {
        val broken = weekPageRaw.replace("TimetableCourseFlightLayer(", "Dummy(")
        assertTrue(
            "删掉飞行层调用后必须报「provider 块内缺 TimetableCourseFlightLayer」",
            wiringProblems(broken, layerRaw, weekGridRaw, dayScrollRaw).any { it.contains("TimetableCourseFlightLayer") },
        )
    }

    @Test
    fun `负例自测_缺 flightWeek 必红`() {
        val broken = weekPageRaw.replace("flightWeek = page + 1", "weekArg = page + 1")
        assertTrue(
            "删掉 flightWeek = page+1 必须报问题",
            wiringProblems(broken, layerRaw, weekGridRaw, dayScrollRaw).any { it.contains("flightWeek = page + 1") },
        )
    }

    @Test
    fun `负例自测_层被移出 provider 作用域必红`() {
        // 合成串：provider 块内只有 HorizontalPager；dayContent 与飞行层都在块外。
        val synthetic = "val h = 1\n" +
            "CompositionLocalProvider(LocalCourseFlightMeasure provides h) {\n" +
            "    HorizontalPager(state = s) { }\n" +
            "}\n" +
            "dayContent(0.dp, m)\n" +
            "TimetableCourseFlightLayer(progress = { 0f })\n"
        val problems = wiringProblems(synthetic, layerRaw, weekGridRaw, dayScrollRaw)
        assertTrue("层被移出 provider 后必须报「块内缺飞行层」", problems.any { it.contains("TimetableCourseFlightLayer") })
        assertTrue("dayContent 不在 provider 内必须报", problems.any { it.contains("dayContent") })
    }

    @Test
    fun `负例自测_日侧 key 缺 startSection 必红`() {
        val degenerate = "flightCardKey = courseFlightCardKey(viewedWeek, day, course.id)"
        assertFalse("日侧只用 course.id、缺 startSection，判据必须判红", keyCallOk(degenerate))
    }

    // ────────────────────────── 判据 ──────────────────────────

    /** 全部接线问题；空 = 全绿。传入的是**原始**源码（内部剥注释）。 */
    private fun wiringProblems(
        weekPageRaw: String,
        layerRaw: String,
        weekGridRaw: String,
        dayScrollRaw: String,
    ): List<String> {
        val wp = stripKotlinComments(weekPageRaw)
        val ly = stripKotlinComments(layerRaw)
        val wg = stripKotlinComments(weekGridRaw)
        val ds = stripKotlinComments(dayScrollRaw)
        val p = mutableListOf<String>()

        if (!wp.contains("CourseFlightMeasureHost(")) p += "缺 CourseFlightMeasureHost("
        val block = providerBlock(wp)
        if (block == null) {
            p += "缺或无法解析 provider 块"
        } else {
            if (!block.contains("HorizontalPager(")) p += "provider 块内缺 HorizontalPager("
            if (!block.contains("dayContent(")) p += "provider 块内缺 dayContent("
            if (!block.contains("TimetableCourseFlightLayer(")) p += "provider 块内缺 TimetableCourseFlightLayer("
        }
        if (!wp.contains("flightWeek = page + 1")) p += "缺 flightWeek = page + 1"
        if (!wp.contains("flightWeek = flightWeek")) p += "缺 flightWeek = flightWeek"
        if (!wp.contains("weekSurfaces.containsKey(key)")) p += "cardKeys 过滤缺 weekSurfaces.containsKey"
        if (!ly.contains("host.weekSurfaces[cardKey]")) p += "层缺 weekSurfaces[cardKey]"
        if (!ly.contains("host.daySurfaces[cardKey]")) p += "层缺 daySurfaces[cardKey]"
        if (ly.contains("DayViewSummaryFlight")) p += "层出现 DayViewSummaryFlight"
        if (!keyCallOk(wg)) p += "周侧 courseFlightCardKey 缺 .course.id/startSection"
        if (!keyCallOk(ds)) p += "日侧 courseFlightCardKey 缺 .course.id/startSection"
        return p
    }

    /** 截取 `CompositionLocalProvider(LocalCourseFlightMeasure provides` 之后第一对 `{}` 的**内部**文本。 */
    private fun providerBlock(src: String): String? {
        val marker = "CompositionLocalProvider(LocalCourseFlightMeasure provides"
        val m = src.indexOf(marker)
        if (m < 0) return null
        val open = src.indexOf('{', m)
        if (open < 0) return null
        var depth = 0
        var i = open
        while (i < src.length) {
            when (src[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return src.substring(open + 1, i)
                }
            }
            i++
        }
        return null
    }

    /** `courseFlightCardKey(...)` 调用实参里是否既有 `.course.id` 又有 `startSection`（两端四元配对）。 */
    private fun keyCallOk(src: String): Boolean {
        val idx = src.indexOf("courseFlightCardKey(")
        if (idx < 0) return false
        val open = idx + "courseFlightCardKey".length // 指向 '('
        if (open >= src.length || src[open] != '(') return false
        var depth = 0
        var i = open
        while (i < src.length) {
            when (src[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) {
                        val args = src.substring(open + 1, i)
                        return args.contains(".course.id") && args.contains("startSection")
                    }
                }
            }
            i++
        }
        return false
    }

    /** 剥掉 `//` 行注释与 `/* */` 块注释（保留换行；本文件区域无跨行字符串干扰）。 */
    private fun stripKotlinComments(src: String): String {
        val noBlock = Regex("""/\*[\s\S]*?\*/""").replace(src, " ")
        return noBlock.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }
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
        const val LAYER_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableCourseFlightLayer.kt"
        const val WEEK_GRID_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekGrid.kt"
        const val COURSE_CARD_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/CourseGridCard.kt"
        const val DAY_SCROLL_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewScrollContent.kt"
    }
}
