package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 文案逐字对照 ARB（`i18n/app_zh.arb` = template，见 `l10n.yaml`）。
 *
 * ## 为什么这条要单独存在
 *
 * 迁移规格验收第 4/5 条要求「与现版本一致」，而设置页 90% 的像素就是文字。
 * 「看起来一样」不能靠人眼抽查——这里把模型里每一处屏上文案与 ARB 的对应值
 * **机械比对**：键缺失、文案被改写、漏抄一处，都会红。
 *
 * 带占位符的模板（如 `themeBasedOnModified` = `基于 {baseName} 已修改`）按
 * 「模板片段按序出现」判定：渲染值允许替换占位符，但不许改写片段本身。
 *
 * 覆盖的页面：通用设置 / 外观与配色 / 主题管理 / 课程卡片（共 4 份 spec，
 * 其中主题管理给了「有存档主题 + 有修改」的最满状态，保证条件分支里的文案
 * 也被走到）。
 */
class SettingsArbParityTest {

    private fun specs(): List<SettingsPageSpec> = listOf(
        SettingsGeneralPage.spec(
            SettingsPageState(
                autoRefresh = AutoRefreshState(
                    enabled = true,
                    mode = CourseAutoRefreshMode.DAILY_AT,
                    lastSuccessLabel = "9-21 07:30",
                    nextRunLabel = "9-22 07:30",
                ),
            ),
        ),
        SettingsAppearancePage.spec(SettingsPageState(appTextScale = 1.0)),
        SettingsThemeManagePage.spec(
            SettingsPageState(
                themeCheckpointName = "小米",
                themeHasModifications = true,
                savedThemes = listOf(SavedThemeRow(id = "t1", name = "我的主题", selected = true)),
            ),
        ),
        SettingsCourseCardPage.spec(SettingsPageState(timetableUseUnifiedCardColor = true)),
    )

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        var checked = 0
        for (spec in specs()) {
            for ((key, text) in spec.allArbTexts()) {
                assertMatchesArb(key, text)
                checked++
            }
        }
        // 防空转：遍历器若坏掉（返回空清单）这条必须红，而不是「零违规=绿」。
        assertTrue("逐字对照的文案条数太少（$checked），遍历器可能失效", checked >= 70)
    }

    @Test
    fun `spec 里用到的每个 ARB 键都真的存在于 arb`() {
        val keys = specs().flatMap { it.allArbTexts() }.map { it.first }.toSet()
        val missing = keys.filter { !ArbZh.strings.containsKey(it) }
        assertEquals("这些键在 app_zh.arb 里不存在", emptyList<String>(), missing)
    }

    @Test
    fun `占位符模板按片段比对而不是整串相等`() {
        // 人推的反例：themeBasedOnModified 的渲染值是「基于 小米 已修改」，
        // 与模板不同但必须通过；改掉片段（「依据」）必须红。
        assertMatchesArb("themeBasedOnModified", "基于 小米 已修改")
        val template = ArbZh.value("themeBasedOnModified")
        assertEquals("基于 {baseName} 已修改", template)
        val failed = runCatching { assertMatchesArb("themeBasedOnModified", "依据 小米 已修改") }
        assertTrue("改掉模板片段应当比对失败", failed.isFailure)
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
