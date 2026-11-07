package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日视图卡面墨色「接线不许回退」守卫（2026-11-07）。
 *
 * ## 为什么需要它
 *
 * 判据本身有真单测（`DayAgendaCardInkTest`，纯函数、L0 直接跑）。但**判据正确 ≠ 卡片在用**：
 * 谁把某张卡改回「恒白字」「只按卡色判」「用主题前景」，或者把 α 写死、把亮度带传错，
 * 纯函数单测全绿而真机立刻回到「深底深字 / 浅底白字」。composeP1 不进 L0 编译单元，
 * 所以这层只能用源码文本钉住。
 *
 * 2026-11-07 复核点名的三个「假绿」绕过面，这里各钉一条：
 * ① 调用点把真实 α 写死（如 `fillAlpha = 0.5f`）；
 * ② 模型层把黑白择优改回写死阈值（0.45 / 0.20）；
 * ③ `DayViewPage` 把亮度带传错（摘要卡拿正文带 / 议程卡拿星期栏带）。
 */
class DayAgendaWallpaperInkWiringGuardTest {

    private val dayDir =
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day"

    private val mainDir =
        "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable"

    private val shellDir =
        "android/app/src/main/kotlin/com/mutx163/qingyu/pages/shell"

    /** 日视图五张卡（四张议程卡 + 摘要卡）都要走共享墨色件。 */
    private val cardFiles = listOf(
        "$dayDir/DayViewCourseCard.kt",
        "$dayDir/DayViewScheduleCard.kt",
        "$dayDir/DayViewExamCard.kt",
        "$dayDir/DayViewTaskBandCard.kt",
        "$dayDir/DayViewSummaryCard.kt",
    )

    @Test
    fun `五张卡都必须调用共享的壁纸墨色件`() {
        for (path in cardFiles) {
            val source = readSource(path)
            assertTrue(
                "$path 没有调用 `CourseCardInk.resolveCardInkOverWallpaper(`：" +
                    "这些卡在玻璃 / 半透明档必须按卡面有效亮度翻黑白，回退成「恒白字 / 只按卡色判」" +
                    "就会重现「深底深字、浅底白字」。",
                source.contains("CourseCardInk.resolveCardInkOverWallpaper("),
            )
        }
    }

    @Test
    fun `旧的墨色取法不许回来`() {
        // 考试卡：曾经 `val ink = Color.White`（液态档染色最低时白字压在浅壁纸上直接消失）。
        val exam = readSource("$dayDir/DayViewExamCard.kt")
        assertFalse(
            "考试卡又写回 `val ink = Color.White`：半透明档必须按卡面有效亮度翻黑白。",
            Regex("""^[ \t]*val ink = Color\.White[ \t]*$""", RegexOption.MULTILINE)
                .containsMatchIn(exam),
        )

        // 课程卡 / 日程卡：曾经只按不透明卡色判，完全不看壁纸。
        for (path in listOf("$dayDir/DayViewCourseCard.kt", "$dayDir/DayViewScheduleCard.kt")) {
            val source = readSource(path)
            assertFalse(
                "$path 又写回 `val ink = calculateCardInk(...)`：那只看不透明卡色，" +
                    "近透明的卡压在深壁纸上会拿到深字。",
                Regex("""^[ \t]*val ink = calculateCardInk\(""", RegexOption.MULTILINE)
                    .containsMatchIn(source),
            )
        }

        // 待办带：曾经标题墨恒取主题前景色（深色主题白字 × 浅壁纸）。
        val taskBand = readSource("$dayDir/DayViewTaskBandCard.kt")
        assertFalse(
            "待办带又写回 `val primaryTextColor = Color(QingyuTheme.primaryText(dark))`：" +
                "它必须走壁纸墨色件。",
            Regex(
                """^[ \t]*val primaryTextColor = Color\(QingyuTheme\.primaryText\(dark\)\)""",
                RegexOption.MULTILINE,
            ).containsMatchIn(taskBand),
        )
    }

    @Test
    fun `四个调用点都必须把壁纸亮度传下去`() {
        val source = readSource("$dayDir/DayViewScrollContent.kt")
        for (marker in listOf(
            "DayViewTaskBandCard(",
            "DayViewCourseCard(",
            "DayViewScheduleCard(",
            "DayViewExamCard(",
        )) {
            val block = callBlock(source, marker)
            assertTrue(
                "$marker 的调用没有传 `wallpaperLuminance = wallpaperLuminance`：" +
                    "参数不传，卡里的判据永远拿到 null，等于没接线。实际调用块：$block",
                block.contains("wallpaperLuminance = wallpaperLuminance"),
            )
        }
        // 摘要卡走的是星期栏那档亮度（与它字面的星期栏字色同源）。
        assertTrue(
            "DayViewSummaryCard( 的调用没有传 `wallpaperLuminance = summaryWallpaperLuminance`",
            callBlock(source, "DayViewSummaryCard(")
                .contains("wallpaperLuminance = summaryWallpaperLuminance"),
        )
    }

    /**
     * 绕过面 ③：亮度带必须由 `DayViewPage` 按「正文带给议程卡 / 星期栏带给摘要卡」传下来。
     * 传反了（摘要卡拿正文带）时文字会按错误亮度判墨，而所有纯函数单测仍全绿。
     */
    @Test
    fun `DayViewPage 必须按区域把亮度带传对`() {
        val page = readSource("$dayDir/DayViewPage.kt")
        // 只看发给日视图滚动内容的那次调用（页面里别的组件按自己的区域取带子）。
        val scrollCall = callBlock(page, "DayViewScrollContent(")
        assertTrue(
            "DayViewPage 没有把**正文带**亮度传给议程列表（`wallpaperLuminance = wallpaperBands?.body`）",
            scrollCall.contains("wallpaperLuminance = wallpaperBands?.body"),
        )
        assertTrue(
            "DayViewPage 没有把**星期栏带**亮度传给摘要卡" +
                "（`summaryWallpaperLuminance = wallpaperBands?.weekday`）",
            scrollCall.contains("summaryWallpaperLuminance = wallpaperBands?.weekday"),
        )
        // 反着传的形态直接判红（这正是复核复现过的假绿绕过面）。
        assertFalse(
            "摘要卡拿成了正文带：`summaryWallpaperLuminance = wallpaperBands?.body`",
            scrollCall.contains("summaryWallpaperLuminance = wallpaperBands?.body"),
        )
    }

    /**
     * 绕过面 ①：α 必须来自渲染层同一个值。
     *
     * 判据（含判墨）与绘制必须共用同一个 alpha —— 写死 0.5 会让近透明的卡被当成中灰，
     * 而纯函数单测（自己传 0.08）依然全绿。
     */
    @Test
    fun `调用点必须把渲染用的真实 alpha 传进去`() {
        val alphaByFile = mapOf(
            "$dayDir/DayViewCourseCard.kt" to "fillAlpha = cardColor.alpha",
            "$dayDir/DayViewScheduleCard.kt" to "fillAlpha = cardColor.alpha",
            "$dayDir/DayViewExamCard.kt" to "fillAlpha = cardColor.alpha",
            "$dayDir/DayViewTaskBandCard.kt" to "fillAlpha = fillAlpha",
            "$dayDir/DayViewSummaryCard.kt" to "fillAlpha = fillAlpha",
        )
        for ((path, expected) in alphaByFile) {
            val source = readSource(path)
            assertTrue(
                "$path 没有传 `$expected`：判墨的 α 必须与 `dayAgendaSurface(fill = …)` 画出来的" +
                    "那个 α 同源，写死常数会在大 alpha 档给出相反的墨色。",
                source.contains(expected),
            )
            assertFalse(
                "$path 出现了写死的 `fillAlpha = 0.`：α 必须来自渲染层，不许写常数。",
                Regex("""fillAlpha = 0\.\d""").containsMatchIn(source),
            )
        }
    }

    /** 绕过面 ②：模型层必须保持「按对比度择优」，不许退回写死阈值。 */
    @Test
    fun `模型层不许退回写死的翻面阈值`() {
        val ink = readSource("$mainDir/CourseCardInk.kt")
        assertFalse(
            "CourseCardInk 又出现 `backgroundLuminance < 0.xx` 这种阈值判据：" +
                "墨色必须由黑白对比度择优决定（相等点 ≈0.2017 是算出来的，不是常量）。",
            Regex("""backgroundLuminance\s*<""").containsMatchIn(ink),
        )
        assertFalse(
            "CourseCardInk 又把染色强度写死（`val t = 0.5`）：必须用调用方传入的真实 alpha。",
            Regex("""val t = 0\.\d""").containsMatchIn(ink),
        )

        val model = readSource("$shellDir/HomeBackgroundModel.kt")
        for (constant in listOf("CHROME_INK_FLIP_LUMINANCE", "CARD_GLASS_INK_FLIP_LUMINANCE")) {
            assertFalse(
                "HomeBackgroundModel 又用回写死的 $constant：顶栏 / 星期栏 / 时间列 / 空态的墨色" +
                    "同样要按黑对比度择优（0.45 在 0.20–0.45 这段会把中灰判成白字）。",
                model.contains(constant),
            )
        }
    }

    @Test
    fun `摘要卡不许再要 glass 门槛 也不许再传 darkThreshold`() {
        val summary = readSource("$dayDir/DayViewSummaryCard.kt")
        assertFalse(
            "摘要卡又要求 `glass != null` 才判墨：`dayAgendaGlassBackdrop` 只认液态档，" +
                "高斯档（α=0.55）与半透明实心档会直接退回主题前景色，不按卡面亮度算。",
            summary.contains("glass != null && wallpaperLuminance != null"),
        )
        assertFalse(
            "摘要卡又传 `darkThreshold`：翻面已改为对比度择优，不该再有写死阈值。",
            summary.contains("darkThreshold"),
        )
        assertTrue(
            "摘要卡没有按「半透明 + 亮度已知」判墨（`if (translucent && wallpaperLuminance != null)`）",
            summary.contains("if (translucent && wallpaperLuminance != null)"),
        )
    }

    /** 实心档不能回退到「gamma 加权 0.55」那套旧口径（`#808080` 会被判成白字）。 */
    @Test
    fun `实心档 fallback 必须按卡色真实亮度择优`() {
        val inkDir = "$dayDir/DayViewCourseCard.kt"
        for (path in listOf(
            inkDir,
            "$dayDir/DayViewScheduleCard.kt",
            "$dayDir/DayViewExamCard.kt",
            "$dayDir/DayViewTaskBandCard.kt",
        )) {
            val source = readSource(path)
            assertTrue(
                "$path 的 `fallbackArgb` 没有走 `CourseCardInk.bestContrastInk(`：" +
                    "实心档不露壁纸，但仍要按卡色自身的 WCAG 亮度择优。",
                source.contains("fallbackArgb = CourseCardInk.bestContrastInk("),
            )
            assertFalse(
                "$path 又用回 `calculateCardInk(` / 写死白字：实心档墨色必须按卡色亮度算。",
                source.contains("calculateCardInk(") || source.contains("fallbackArgb = Color.White"),
            )
        }
        val common = readSource("$dayDir/DayViewCommon.kt")
        assertTrue(
            "`calculateCardInk` 没有走 WCAG 择优（又回 gamma 0.55 加权阈值？）",
            common.contains("Color(CourseCardInk.bestContrastInk(backgroundColor.toArgb()))"),
        )
    }

    /**
     * 绕过面 ②'：三个墨色入口都不许用**字面量阈值**翻面（如 `wallpaperLuminance < 0.45`）。
     *
     * 之前这条只禁常量名与 `backgroundLuminance <`，模型层直接写 `wallpaperLuminance < 0.45`
     * 时守卫全绿、只能靠 `HomeBackgroundModelTest` 兜底。这里按函数体逐块扫，字面量阈值必红。
     */
    @Test
    fun `模型层三个墨色入口不许出现字面量阈值`() {
        val model = readSource("$shellDir/HomeBackgroundModel.kt")
        for (fn in listOf(
            "fun chromeInkPolarity(",
            "fun cardGlassInkPolarity(",
            "fun flipInkArgb(",
        )) {
            val body = memberBlock(model, fn)
            assertTrue(
                "`$fn` 里没有比对比度（`contrastOnLuminance(`），判据可能不是择优",
                body.contains("contrastOnLuminance("),
            )
            assertFalse(
                "`$fn` 里出现字面量阈值比较（如 `wallpaperLuminance < 0.45`）：" +
                    "翻面必须由 WCAG 对比度择优决定，任何 0.45 / 0.20 字面量都是回归。",
                Regex("""(wallpaperLuminance|surfaceLuminance)\s*[<>]=?\s*0\.\d""").containsMatchIn(body),
            )
        }
    }

    @Test
    fun `守卫本身没有空转`() {
        for (path in cardFiles + listOf(
            "$dayDir/DayViewScrollContent.kt",
            "$dayDir/DayViewPage.kt",
            "$mainDir/CourseCardInk.kt",
            "$shellDir/HomeBackgroundModel.kt",
        )) {
            val source = readSource(path)
            assertTrue(
                "$path 源码读取太短（${source.length} 字符），路径解析可能坏了",
                source.length > 1000,
            )
        }
    }

    /**
     * 取出一个成员（函数 / 属性）的源码块：从 `marker` 起到下一个同层成员（KDoc 注释或 `fun`）前。
     *
     * 不用花括号配对 —— 表达式体函数（`fun f(...) = if (...) { ... } else { ... }`）里第一个
     * 花括号只是分支块，配对会截断在 `{ WHITE_ARGB }`。
     */
    private fun memberBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到 `$marker`，判据失效" }
        var end = source.length
        for (next in listOf("\n    /**", "\n    fun ", "\n    private fun ", "\n    const val ")) {
            val idx = source.indexOf(next, start + marker.length)
            if (idx in (start + 1) until end) end = idx
        }
        return source.substring(start, end)
    }

    /** 按括号配对取出 `marker(` 那一整个调用块（含括号内的实参）。 */
    private fun callBlock(source: String, marker: String): String {
        val start = source.indexOf(marker)
        check(start >= 0) { "源码里找不到 `$marker`，判据失效" }
        // marker 自带左括号时配对起点就是它自己，否则往后再找一个 '('。
        val open =
            if (marker.endsWith('(')) {
                start + marker.length - 1
            } else {
                source.indexOf('(', start + marker.length)
            }
        check(open > 0) { "`$marker` 后面没有实参括号，判据失效" }
        var depth = 0
        for (i in open until source.length) {
            when (source[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return source.substring(open, i + 1)
                }
            }
        }
        error("`$marker` 的实参括号没有闭合")
    }

    /** 从工作目录向上找仓库根再定位文件；找不到仍判失败，不静默跳过。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
