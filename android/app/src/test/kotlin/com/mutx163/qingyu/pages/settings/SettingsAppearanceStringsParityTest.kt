package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P3-B-1 四页的文案逐字对照 ARB（`lib/l10n/app_zh.arb` = template，见 `l10n.yaml`）。
 *
 * ## 为什么这条要单独存在
 *
 * 迁移规格验收要求「与现版本一致」，而这几页 90% 的像素就是文字。「看起来一样」
 * 不能靠人眼抽查——这里把模型里每一处屏上文案与 ARB 的对应值**机械比对**：
 * 键缺失、文案被改写、漏抄一处，都会红。
 *
 * 带占位符的模板（如 `bingWallpaperAutoApplyStale` = `Bing 还没放出今天的图，先用
 * {date} 那张顶一下`）按「模板片段按序出现」判定：渲染值允许替换占位符，但不许
 * 改写片段本身。
 *
 * ## 覆盖面
 *
 * 走的是**最满状态**（液态档 + 深色档独立 + 卡片选液态 + 有壁纸 + 有历史 +
 * 下载中 + 排队中 + 缩略图失败），保证条件分支里的文案也被走到。
 */
class SettingsAppearanceStringsParityTest {

    private fun specs(): List<SettingsPageSpec> {
        val material = MaterialPanelState(
            frostedBlurEnabled = true,
            linkLiquidGlassTuning = false,
            liquidGlassTuningDark = LiquidGlassTuning(blurSigma = 20.0, tintAlpha = 0.8),
            liquidGlassDockEnabled = true,
            hasHomePageBackdrop = true,
            courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
            previewDayView = true,
        )
        val backdrop = BackdropFlowState(
            imagePath = "/w/current.jpg",
            history = listOf("/w/a.jpg", "/w/b.jpg"),
            followsWeekPager = true,
            blurSigma = 12.0,
            bingAutoApplyEnabled = true,
        )
        return listOf(
            SettingsAppearanceEditorPage.spec(SettingsPageState(), material),
            SettingsMaterialGeneralPage.spec(SettingsPageState(), material),
            SettingsMaterialCourseCardPage.spec(
                SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS),
                material,
            ),
            SettingsBackdropFlowPage.selectionPage(
                backdrop,
                SelectionPageState(backdrop, fileMissing = true, armedKey = "/w/b.jpg"),
            ),
            SettingsBackdropFlowPage.settingsPage(backdrop),
            SettingsRecentWallpaperSection.spec(
                RecentWallpaperState(
                    entries = listOf("/w/current.jpg", "/w/a.jpg"),
                    selectedKey = "/w/current.jpg",
                    armedKey = "/w/a.jpg",
                ),
            ),
            SettingsBingWallpaperGalleryPage.spec(
                BingGalleryState(
                    loading = false,
                    items = listOf(
                        BingGalleryItem("20261005", "今日图", "© 摄影师甲", "https://e.com/a.jpg"),
                        BingGalleryItem("20261004", "昨日图", "", "https://e.com/b.jpg"),
                    ),
                    showingCached = true,
                    downloadingDateKey = "20261005",
                    downloadingPercent = 42,
                    queuedDateKey = "20261004",
                    today = java.time.LocalDate.of(2026, 10, 5),
                ),
            ),
            SettingsBingWallpaperGalleryPage.spec(
                BingGalleryState(loading = false, failed = true),
            ),
        )
    }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        var checked = 0
        for (spec in specs()) {
            for ((key, text) in spec.allArbTexts()) {
                assertMatchesArb(key, text)
                checked++
            }
        }
        // 防空转：遍历器若坏掉（返回空清单）这条必须红，而不是「零违规=绿」
        assertTrue("逐字对照的文案条数太少（$checked），遍历器可能失效", checked >= 60)
    }

    @Test
    fun `spec 里用到的每个 ARB 键都真的存在于 arb`() {
        val keys = specs().flatMap { it.allArbTexts() }.map { it.first }.toSet()
        val missing = keys.filter { !ArbZh.strings.containsKey(it) }
        assertEquals("这些键在 app_zh.arb 里不存在", emptyList<String>(), missing)
    }

    @Test
    fun `扩展文案表里每一条都能在 arb 找到且逐字一致`() {
        // SettingsStringsExt1 的每一条都要过一遍（上面的 spec 遍历只覆盖「被页面用到」的）
        val all = ext1Texts()
        assertTrue("扩展文案表条数太少（${all.size}）", all.size >= 60)
        all.forEach { assertMatchesArb(it.key, it.zh) }
    }

    @Test
    fun `扩展文案表的键没有重复`() {
        val keys = ext1Texts().map { it.key }
        assertEquals("SettingsStringsExt1 里有重复键", keys.size, keys.toSet().size)
    }

    @Test
    fun `不与既有 SettingsStrings 重复定义`() {
        // 共享件已有的键不在这里重复（避免同一段文案两份真源）
        val shared = SettingsStrings::class.java.declaredFields
            .filter { ArbText::class.java.isAssignableFrom(it.type) }
            .mapNotNull { field ->
                field.isAccessible = true
                (field.get(SettingsStrings) as? ArbText)?.key
            }
            .toSet()
        val duplicated = ext1Texts().map { it.key }.filter { shared.contains(it) }
        assertEquals("这些键在 SettingsStrings 里已经有了：$duplicated", emptyList<String>(), duplicated)
    }

    @Test
    fun `占位符模板按片段比对而不是整串相等`() {
        // 人推的反例：autoApplyStale 的渲染值是「Bing 还没放出今天的图，先用 10 月 5 日 那张顶一下」，
        // 与模板不同但必须通过；改掉片段（「放出」→「发布」）必须红。
        assertMatchesArb("bingWallpaperAutoApplyStale", "Bing 还没放出今天的图，先用 10 月 5 日 那张顶一下")
        assertEquals(
            "Bing 还没放出今天的图，先用 {date} 那张顶一下",
            ArbZh.value("bingWallpaperAutoApplyStale"),
        )
        val failed = runCatching {
            assertMatchesArb("bingWallpaperAutoApplyStale", "Bing 还没发布今天的图，先用 10 月 5 日 那张顶一下")
        }
        assertTrue("改掉模板片段应当比对失败", failed.isFailure)
    }

    private fun ext1Texts(): List<ArbText> = SettingsStringsExt1::class.java.declaredFields
        .filter { ArbText::class.java.isAssignableFrom(it.type) }
        .mapNotNull { field ->
            field.isAccessible = true
            field.get(SettingsStringsExt1) as? ArbText
        }

    private fun assertMatchesArb(key: String, text: String) {
        val template = ArbZh.value(key)
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
    }
}
