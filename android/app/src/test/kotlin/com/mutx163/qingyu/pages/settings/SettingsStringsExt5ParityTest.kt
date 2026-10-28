package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「课表页面设置」页文案逐字对照 ARB（`lib/l10n/app_zh.arb` = template，见 `l10n.yaml`）。
 *
 * 钉三件事：
 * 1. [SettingsStringsExt5.allTexts] 里每一条的键都在 ARB 里存在；
 * 2. 每条的 zh 值与 ARB 逐字相等（带占位符的按「模板片段按序出现」判）；
 * 3. 这一页 spec 上屏的每一处文案都能在 ARB 里追到（不只看文案表，要看实际接线）。
 *
 * 第 3 条是关键：文案表对了、但页面引用了别的键（或引用了本文件里没登记的一条），
 * 只看前两条是查不出来的。
 */
class SettingsStringsExt5ParityTest {

    private fun specs(): List<SettingsPageSpec> = listOf(
        SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(screenshotShareSupported = true, imagePath = "/sdcard/a.jpg"),
        ),
        SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(screenshotShareSupported = false),
        ),
    )

    @Test
    fun `文案表里每一条都在 arb 里且逐字一致`() {
        val texts = SettingsStringsExt5.allTexts
        // 防空转：文案表若被清空，下面「零违规」也会绿
        assertTrue("文案条数不该少于 28 条，当前 ${texts.size}", texts.size >= 28)
        for (item in texts) {
            assertMatchesArb(item.key, item.zh)
        }
    }

    @Test
    fun `文案表里没有重复键`() {
        val keys = SettingsStringsExt5.allTexts.map { it.key }
        val duplicated = keys.groupingBy { it }.eachCount().filterValues { it > 1 }.keys
        assertEquals("这些键在文案表里出现了多次：$duplicated", emptySet<String>(), duplicated)
    }

    @Test
    fun `页面 spec 上屏的每处文案都能在 arb 里追到`() {
        var checked = 0
        for (spec in specs()) {
            for ((key, text) in spec.allArbTexts()) {
                assertMatchesArb(key, text)
                checked++
            }
        }
        // 本页两个状态合计应有 30 条以上（截屏行只在支持态出现）
        assertTrue("逐字对照的文案条数太少（$checked），遍历器可能失效", checked >= 30)
    }

    @Test
    fun `文案表里没有本文件之外也会用到的重复声明`() {
        // 与共享件的重复键必须是「引用那边」，不是各写一份：
        // 两处都写会在改 ARB 时漏掉一处，而两处各自对拍都绿。
        val shared = listOf(
            SettingsStrings.frostedSheetSectionTitle.key,
            SettingsStrings.appearanceEditorTitle.key,
            SettingsStrings.settingsResetDefaultsTitle.key,
            SettingsStringsExt2.timetablePageSettingsTitle.key,
            SettingsStringsExt1.homePageWallpaperTitle.key,
            SettingsStringsExt1.homePageWallpaperRecentTitle.key,
            SettingsStringsExt1.homePageBackdropFollowsWeekPagerTitle.key,
            SettingsStringsExt1.homePageBackdropFollowsWeekPagerSubtitle.key,
            SettingsStringsExt1.homePageWallpaperBlurTitle.key,
        )
        val mine = SettingsStringsExt5.allTexts.map { it.key }.toSet()
        val overlap = shared.filter { it in mine }
        assertEquals("这些键已在共享件里定义，本文件不该重复声明：$overlap", emptyList<String>(), overlap)
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
