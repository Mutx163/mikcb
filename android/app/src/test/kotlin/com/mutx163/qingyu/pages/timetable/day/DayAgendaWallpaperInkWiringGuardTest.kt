package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.readSourceNormalized
import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

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
            val source = readCallSource(path)
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
        val exam = readCallSource("$dayDir/DayViewExamCard.kt")
        assertFalse(
            "考试卡又写回 `val ink = Color.White`：半透明档必须按卡面有效亮度翻黑白。",
            Regex("""^[ \t]*val ink = Color\.White[ \t]*$""", RegexOption.MULTILINE)
                .containsMatchIn(exam),
        )

        // 课程卡 / 日程卡：曾经只按不透明卡色判，完全不看壁纸。
        for (path in listOf("$dayDir/DayViewCourseCard.kt", "$dayDir/DayViewScheduleCard.kt")) {
            val source = readCallSource(path)
            assertFalse(
                "$path 又写回 `val ink = calculateCardInk(...)`：那只看不透明卡色，" +
                    "近透明的卡压在深壁纸上会拿到深字。",
                Regex("""^[ \t]*val ink = calculateCardInk\(""", RegexOption.MULTILINE)
                    .containsMatchIn(source),
            )
        }

        // 待办带：曾经标题墨恒取主题前景色（深色主题白字 × 浅壁纸）。
        val taskBand = readCallSource("$dayDir/DayViewTaskBandCard.kt")
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
        val scrollPath = "$dayDir/DayViewScrollContent.kt"
        for (marker in listOf(
            "DayViewTaskBandCard(",
            "DayViewCourseCard(",
            "DayViewScheduleCard(",
            "DayViewExamCard(",
        )) {
            val block = callBlockNoStrings(scrollPath, marker)
            assertTrue(
                "$marker 的调用没有传 `wallpaperLuminance = wallpaperLuminance`：" +
                    "参数不传，卡里的判据永远拿到 null，等于没接线。实际调用块：$block",
                block.contains("wallpaperLuminance = wallpaperLuminance"),
            )
        }
        // 摘要卡走的是星期栏那档亮度（与它字面的星期栏字色同源）。
        assertTrue(
            "DayViewSummaryCard( 的调用没有传 `wallpaperLuminance = summaryWallpaperLuminance`",
            callBlockNoStrings(scrollPath, "DayViewSummaryCard(")
                .contains("wallpaperLuminance = summaryWallpaperLuminance"),
        )
    }

    /**
     * 绕过面 ③：亮度带必须由 `DayViewPage` 按「正文带给议程卡 / 星期栏带给摘要卡」传下来。
     * 传反了（摘要卡拿正文带）时文字会按错误亮度判墨，而所有纯函数单测仍全绿。
     */
    @Test
    fun `DayViewPage 必须按区域把亮度带传对`() {
        // 只看发给日视图滚动内容的那次调用（页面里别的组件按自己的区域取带子）。
        val scrollCall = callBlockNoStrings("$dayDir/DayViewPage.kt", "DayViewScrollContent(")
        assertTrue(
            "DayViewPage 没有把**正文带**亮度传给议程列表（`wallpaperLuminance = effectiveWallpaperBands?.body`）",
            scrollCall.contains("wallpaperLuminance = effectiveWallpaperBands?.body"),
        )
        assertTrue(
            "DayViewPage 没有把**星期栏带**亮度传给摘要卡" +
                "（`summaryWallpaperLuminance = effectiveWallpaperBands?.weekday`）",
            scrollCall.contains("summaryWallpaperLuminance = effectiveWallpaperBands?.weekday"),
        )
        // 反着传的形态直接判红（这正是复核复现过的假绿绕过面）。
        assertFalse(
            "摘要卡拿成了正文带：`summaryWallpaperLuminance = …?.body`",
            scrollCall.contains("summaryWallpaperLuminance = effectiveWallpaperBands?.body") ||
                scrollCall.contains("summaryWallpaperLuminance = wallpaperBands?.body"),
        )
        // 亮度带必须来自「嵌入时先借宿主那份」的单一变量，不能直接裸用参数。
        assertFalse(
            "DayViewPage 又绕开 `effectiveWallpaperBands` 直接用 `wallpaperBands`：" +
                "嵌入首页时那份是 null（本页不画壁纸 → 量不到），空态 / 卡片会退回主题墨色。",
            scrollCall.contains("wallpaperLuminance = wallpaperBands?") ||
                scrollCall.contains("summaryWallpaperLuminance = wallpaperBands?"),
        )
    }

    /**
     * 嵌入首页的日页拿不到壁纸亮度（2026-11-09 用户报「暂无课程 / 第 N 周不跟壁纸翻黑白」）。
     *
     * 日页在展开层里**不画壁纸**（壁纸由页面级静态底画）⇒ 它自己的
     * `HomeWallpaperBackdrop` / `onInkBands` 永远不会跑，`wallpaperBands` 只能靠缓存撞运气。
     * 宿主 `TimetableWeekPage` 手上有量好的带子，必须经 `LocalEmbeddedDayInkBands` 交下去。
     */
    @Test
    fun `嵌入首页的日页必须借宿主的壁纸亮度带`() {
        val page = readCallSource("$dayDir/DayViewPage.kt")
        assertTrue(
            "DayViewPage 没有定义 `LocalEmbeddedDayInkBands`：嵌入日页永远拿不到亮度带，" +
                "深壁纸上的空态与卡片会退回主题 / 不透明卡色墨（深底深字）。",
            page.contains("val LocalEmbeddedDayInkBands ="),
        )
        assertTrue(
            "DayViewPage 没有「嵌入时优先用宿主那份」的取值" +
                "（缺 `LocalEmbeddedDayInkBands.current ?: wallpaperBands`）",
            page.contains("LocalEmbeddedDayInkBands.current ?: wallpaperBands"),
        )

        val weekPage = readCallSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt",
        )
        val provideCount = Regex("LocalEmbeddedDayInkBands provides wallpaperBands")
            .findAll(weekPage)
            .count()
        assertTrue(
            "TimetableWeekPage 没有把 `wallpaperBands` 交给展开层里的日页" +
                "（实际 `LocalEmbeddedDayInkBands provides wallpaperBands` 出现 $provideCount 次）：" +
                "横滑支与上下翻支两条进日视图的路都要提供，漏一条那条路上的日页就没有亮度带。",
            provideCount >= 2,
        )
    }

    /**
     * 空态的字色必须接**同一条**「亮 / 暗两档星期栏字色」设置（Dart `day_view_empty_state.dart`）。
     *
     * 2026-11-09 之前这里写死 `configuredArgb = null`：设置里改星期栏字色、切换黑白主题，
     * 空态「暂无课程 / 第 N 周」一个字都不变——用户报的「没适配黑白」就是这一条。
     */
    @Test
    fun `空态必须接星期栏的亮暗两档字色`() {
        val empty = readCallSource("$dayDir/DayViewEmptyState.kt")
        assertTrue(
            "DayViewEmptyState 没有把配置字色传进 `inkOverWallpaperArgb`" +
                "（`configuredArgb = HomeBackgroundModel.parseInkArgb(configuredArgbHex)`）",
            empty.contains("configuredArgb = HomeBackgroundModel.parseInkArgb(configuredArgbHex)"),
        )
        assertTrue(
            "DayViewEmptyState 没有传「内置默认值」给翻黑白判据（`builtInDefaultArgb`）：" +
                "不分「没改过」与「用户选中白色」，深壁纸上的默认字会被当成自定义色保留。",
            empty.contains("builtInDefaultArgb = HomeBackgroundModel.parseInkArgb(defaultInkHex)"),
        )
        assertTrue(
            "DayViewEmptyState 的副标题没有压淡标题墨（Dart `homePageOverWallpaperMutedInk(titleColor)`）：" +
                "自定义字色 / 壁纸翻面时主句与副句会分成两套冷暖。",
            empty.contains("mutedInkOverWallpaperArgb(titleArgb)"),
        )

        val emptyCall = callBlockNoStrings("$dayDir/DayViewScrollContent.kt", "DayViewEmptyState(")
        assertTrue(
            "DayViewScrollContent 没有把星期栏字色传给空态（`configuredArgbHex`）",
            emptyCall.contains("configuredArgbHex = summaryWeekdayFontColorHex"),
        )
        assertTrue(
            "DayViewScrollContent 没有把字色的内置默认值传给空态（`defaultInkHex`）",
            emptyCall.contains("defaultInkHex = summaryWeekdayFontDefaultHex"),
        )

        val scrollCall = callBlockNoStrings("$dayDir/DayViewPage.kt", "DayViewScrollContent(")
        assertTrue(
            "DayViewPage 没有按明暗档把星期栏字色传给滚动内容" +
                "（`summaryWeekdayFontColorHex = if (dark) weekdayStyle.weekdayFontColorDark else …`）",
            scrollCall.contains("weekdayStyle.weekdayFontColorDark") &&
                scrollCall.contains("weekdayStyle.weekdayFontColorLight"),
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
            val source = readCallSource(path)
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
        val ink = readCallSource("$mainDir/CourseCardInk.kt")
        assertFalse(
            "CourseCardInk 又出现 `backgroundLuminance < 0.xx` 这种阈值判据：" +
                "墨色必须由黑白对比度择优决定（相等点 ≈0.2017 是算出来的，不是常量）。",
            Regex("""backgroundLuminance\s*<""").containsMatchIn(ink),
        )
        assertFalse(
            "CourseCardInk 又把染色强度写死（`val t = 0.5`）：必须用调用方传入的真实 alpha。",
            Regex("""val t = 0\.\d""").containsMatchIn(ink),
        )

        val model = readCallSource("$shellDir/HomeBackgroundModel.kt")
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
        val summary = readCallSource("$dayDir/DayViewSummaryCard.kt")
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
            val source = readCallSource(path)
            assertTrue(
                "$path 的实心档没有走 `CourseCardInk.bestContrastInk(`：" +
                    "实心档不露壁纸，但仍要按卡色自身的 WCAG 亮度择优。" +
                    "（课程卡关掉「课程颜色」时走主题前景色是另一支：那里卡面就是主题 surface，" +
                    "与摘要卡同口径；非本周灰、其余三张卡仍必须按卡色亮度算。）",
                source.contains("CourseCardInk.bestContrastInk("),
            )
            assertFalse(
                "$path 又用回 `calculateCardInk(` / 写死白字：实心档墨色必须按卡色亮度算。",
                source.contains("calculateCardInk(") || source.contains("fallbackArgb = Color.White"),
            )
        }
        val common = readCallSource("$dayDir/DayViewCommon.kt")
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
        for (fn in listOf(
            "fun chromeInkPolarity(",
            "fun cardGlassInkPolarity(",
            "fun flipInkArgb(",
        )) {
            val body = memberBlockNoStrings("$shellDir/HomeBackgroundModel.kt", fn)
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
            val source = readCallSource(path)
            assertTrue(
                "$path 源码读取太短（${source.length} 字符），路径解析可能坏了",
                source.length > 1000,
            )
        }
    }

    /**
     * 无壁纸（壁纸亮度 null）时，课程 / 日程 / 考试卡必须把**页底亮度**传进判据。
     *
     * 磨砂档卡面是卡色 0.55α，压在页底上；只按不透明卡色回退，中调课色会拿到
     * 深字、深课色会拿到白字（2026-11-07 限制 1）。页底亮度由 `DayViewPage` 统一算：
     * 自定义页底色优先，缺省用主题页底色。
     */
    @Test
    fun `无壁纸时三张卡必须按页底亮度回退`() {
        for (path in listOf(
            "$dayDir/DayViewCourseCard.kt",
            "$dayDir/DayViewScheduleCard.kt",
            "$dayDir/DayViewExamCard.kt",
        )) {
            val source = readCallSource(path)
            assertTrue(
                "$path 没有把 `pageBackgroundLuminance = pageBackgroundLuminance` 传给共享判据：" +
                    "磨砂档无壁纸时卡面是卡色 0.55α 压在页底上，只按不透明卡色回退会反判。",
                source.contains("pageBackgroundLuminance = pageBackgroundLuminance"),
            )
            assertFalse(
                "$path 把页底亮度写死成常数：必须由 `DayViewPage` 按真实页底色算。",
                Regex("""pageBackgroundLuminance = 0\.\d""").containsMatchIn(source),
            )
        }

        val scrollPath = "$dayDir/DayViewScrollContent.kt"
        for (marker in listOf("DayViewCourseCard(", "DayViewScheduleCard(", "DayViewExamCard(")) {
            assertTrue(
                "$marker 的调用没有把 `pageBackgroundLuminance = pageBackgroundLuminance` 传下去",
                callBlockNoStrings(scrollPath, marker)
                    .contains("pageBackgroundLuminance = pageBackgroundLuminance"),
            )
        }

        val page = readCallSource("$dayDir/DayViewPage.kt")
        assertTrue(
            "DayViewPage 没有把页底亮度传给日视图滚动内容",
            callBlockNoStrings("$dayDir/DayViewPage.kt", "DayViewScrollContent(")
                .contains("pageBackgroundLuminance = pageBackgroundLuminance"),
        )
        assertTrue(
            "DayViewPage 没有用 `CourseCardInk.relativeLuminance(` 算页底亮度",
            page.contains("CourseCardInk.relativeLuminance("),
        )
        assertTrue(
            "DayViewPage 的页底亮度没有按「自定义页底色优先、缺省主题页底」取色",
            page.contains("pageColorArgb ?: QingyuTheme.scaffoldBackground(dark)"),
        )
    }

    /**
     * 有壁纸、但亮度还没测出来时，页面必须把页底亮度置空（瞬态回归）。
     *
     * 屏幕上是壁纸、`wallpaperBands` 还是 null 的那一段，按页底判墨会闪一帧反极性：
     * 浅色页底 + 深壁纸 ⇒ 深字压深底。信号必须是**纯**壁纸存在（`homeChrome.hasBackdrop`），
     * 不能拿乘了材质开关的 `hasBackdrop` 代替，也不能直接传页底色。
     */
    @Test
    fun `有壁纸时不许用页底亮度判墨`() {
        val page = readCallSource("$dayDir/DayViewPage.kt")
        assertTrue(
            "DayViewPage 没有用 `dayAgendaPageFallbackLuminance(` 门控页底亮度：" +
                "有壁纸但亮度未就绪时按页底判墨会闪一帧反极性。",
            page.contains("dayAgendaPageFallbackLuminance("),
        )
        assertTrue(
            "DayViewPage 没有把 `hasWallpaper = hasWallpaper` 传给门控（传错值等于没门控）",
            page.contains("hasWallpaper = hasWallpaper"),
        )

        val shellCall = callBlockNoStrings(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
            "DayViewPage(",
        )
        assertTrue(
            "壳的 `c3.day` 没传纯 `hasWallpaper = homeChrome.hasBackdrop`：" +
                "漏了这一行，独立日页/首页展开层仍会在亮度未就绪时按页底反判。",
            shellCall.contains("hasWallpaper = homeChrome.hasBackdrop"),
        )
        assertFalse(
            "壳把壁纸存在信号与材质开关相与了（`hasWallpaper = glassSurfacesEnabled && …`）：" +
                "关掉玻璃时它会把「有壁纸」误报成没有。",
            shellCall.contains("hasWallpaper = glassSurfacesEnabled &&"),
        )

        val editorCall = callBlockNoStrings(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/AppearanceEditorHost.kt",
            "DayViewPage(",
        )
        assertTrue(
            "外观预览没传纯 `hasWallpaper = homeChrome.hasBackdrop`",
            editorCall.contains("hasWallpaper = homeChrome.hasBackdrop"),
        )
        assertFalse(
            "外观预览把壁纸存在信号与材质开关相与了",
            editorCall.contains("hasWallpaper = glassSurfacesEnabled &&"),
        )
    }

    /**
     * 空态必须**钉在页面上**，不许跟着手指滑（2026-11-09 用户口径）。
     *
     * 以前它是 `LazyColumn` 里的一个 item，高度按「一屏 − 缝 − 概览卡 − 避让」算；
     * 下拉橡皮筋 / 上滑时整块跟着走。现在拆成列表**下面**的固定层：静止时位置不变，
     * 拖动时只有列表（概览卡）动，文字不动。
     */
    @Test
    fun `空态必须固定，不进滚动列表`() {
        // ── 选档：**默认档**（剥注释、**保留字符串内容**）──
        // 这条判的正是 `day-empty-state-item` 这个 LazyColumn item key **字面量**在不在源码里。
        // 若图省事用中性化档，字面量会被擦成空格，`assertFalse` 从此永远通过——守卫变摆设。
        // 注释照样剥：注释掉的接线不算接线。
        val scroll = readLiteralSource("$dayDir/DayViewScrollContent.kt")
        assertFalse(
            "`day-empty-state-item` 又回到列表里了：空态一旦是 LazyColumn 的 item，" +
                "上下滑时就会跟着手走（用户 2026-11-09 明要求固定）。",
            scroll.contains("day-empty-state-item"),
        )
        val emptyIndex = scroll.indexOf("DayViewEmptyState(")
        val listIndex = scroll.indexOf("LazyColumn(")
        assertTrue(
            "源码里找不到 `DayViewEmptyState(` 的调用",
            emptyIndex >= 0,
        )
        assertTrue(
            "源码里找不到 `LazyColumn(` 的调用",
            listIndex >= 0,
        )
        assertTrue(
            "`DayViewEmptyState(` 不得出现在 `LazyColumn(` 之后（那样又变成列表里的滚动项）",
            emptyIndex < listIndex,
        )
        assertTrue(
            "空态没有包在固定层里：外层应该是 `Box(modifier = modifier.fillMaxSize())`",
            scroll.contains("Box(modifier = modifier.fillMaxSize()) {"),
        )
    }

    /**
     * 空态也要认**页底亮度**（2026-11-09 用户报「暂无课程位置背景是黑的，字也是黑的」）。
     *
     * 没壁纸时 `wallpaperLuminance` 恒为 null：只认它的空态会退回主题墨色（亮色主题 `#333`），
     * 压在纯黑页底色上直接看不见。四张议程卡从 2026-11-07 起就接了 `pageBackgroundLuminance`，
     * 空态漏了这一层 —— 这里同时钉住「取值的组合」与「逐层下传」。
     */
    @Test
    fun `空态必须按页底亮度兜底`() {
        val empty = readCallSource("$dayDir/DayViewEmptyState.kt")
        assertTrue(
            "DayViewEmptyState 没有把页底亮度纳入判墨（缺 `wallpaperLuminance ?: pageBackgroundLuminance`）：" +
                "没壁纸 + 深页底色时会给深字，深底深字看不见。",
            empty.contains("val backdropLuminance = wallpaperLuminance ?: pageBackgroundLuminance"),
        )
        assertTrue(
            "DayViewEmptyState 没有把组合后的亮度交给 `inkOverWallpaperArgb`",
            empty.contains("wallpaperLuminance = backdropLuminance,"),
        )

        assertTrue(
            "DayViewScrollContent 调用空态时没传 `pageBackgroundLuminance = pageBackgroundLuminance`",
            callBlockNoStrings("$dayDir/DayViewScrollContent.kt", "DayViewEmptyState(")
                .contains("pageBackgroundLuminance = pageBackgroundLuminance"),
        )

        val page = readCallSource("$dayDir/DayViewPage.kt")
        assertTrue(
            "DayViewPage 没有把页底亮度传给日视图滚动内容",
            callBlockNoStrings("$dayDir/DayViewPage.kt", "DayViewScrollContent(")
                .contains("pageBackgroundLuminance = pageBackgroundLuminance"),
        )
        assertTrue(
            "DayViewPage 的页底亮度不再走门控（有壁纸但亮度未就绪时会把页底当壁纸判墨）",
            page.contains("dayAgendaPageFallbackLuminance("),
        )
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
    private fun readCallSource(relative: String): String = readKotlinSourceNoStrings(relative)

    /**
     * 判「某字面量许不许出现」时用这一档：**剥注释、保留字符串内容**。
     *
     * 只有 [空态必须固定，不进滚动列表] 需要它——那条判的正是 `day-empty-state-item`
     * 这个 **LazyColumn item key 字符串**在不在源码里。用中性化档会把被判的字面量自己
     * 擦成空格，`assertFalse` 从此永远通过（洗白），所以这一档不能与其他判据混用。
     */
    private fun readLiteralSource(relative: String): String = readKotlinSourceNormalized(relative)

    /**
     * 取出 `marker(` 那一整个调用块，**再**按「判调用型」剥离（剥注释 + 中性化字符串）。
     *
     * 顺序是硬要求（**先切片、再剥离**）：[callBlock] 靠圆括号配平定位，剥离会改变文本，
     * 先剥后切会对不上原件；剥离也可能吃掉将来新增的块边界标记。
     */
    private fun callBlockNoStrings(relative: String, marker: String): String =
        stripKotlinComments(callBlock(readSourceNormalized(relative), marker), neutralizeStrings = true)

    /**
     * 取出一个成员块，**再**按「判调用型」剥离。顺序理由同 [callBlockNoStrings]：
     * [memberBlock] 的块结束标记是缩进四个空格的 KDoc 起始符（斜杠 + 星号 + 星号）——
     * 剥完注释这个标记就没了，块会一路延长到下一个 `fun`，判据范围跟着漂。
     * （这里刻意不把那个三字符序列写出来：Kotlin 的 KDoc 是块注释，写了会被当嵌套注释，
     * 整份文件收不了尾。）
     */
    private fun memberBlockNoStrings(relative: String, marker: String): String =
        stripKotlinComments(memberBlock(readSourceNormalized(relative), marker), neutralizeStrings = true)
}
