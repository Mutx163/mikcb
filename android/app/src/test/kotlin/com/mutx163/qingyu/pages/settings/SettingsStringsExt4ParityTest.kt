package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P3-B-4 文案逐字对照 ARB（`lib/l10n/app_zh.arb` = template，见 `l10n.yaml`）。
 *
 * 验收门槛 3：界面文字与 ARB 原文一字不差。这条测试同时钉三件事：
 *
 * 1. [SettingsStringsExt4.allTexts] 里每一条的键都在 ARB 里存在；
 * 2. 每一条的 zh 值都与 ARB 逐字相等（带占位符的按「模板片段按序出现」判）；
 * 3. 三份 spec 上屏的每一处文案，都能在 ARB 里追到（不只看文案表，要看实际接线）。
 */
class SettingsStringsExt4ParityTest {

    private fun specs(): List<SettingsPageSpec> = listOf(
        SettingsGlassDockEditorPage.spec(
            SettingsPageState(),
            GlassDockEditorState(
                enabledIds = listOf("day", "week", "tasks"),
                debugBuild = true,
            ),
        ),
        SettingsGlassDockIconEditorPage.spec(
            SettingsPageState(),
            IconPickerState(
                names = listOf("alarm-clock", "camera"),
                selectedName = "camera",
                query = "",
            ),
            contentWidthDp = 328.0,
        ),
        SettingsResetPage.spec(SettingsPageState()),
    )

    @Test
    fun `文案表里每一条都在 arb 里且逐字一致`() {
        val texts = SettingsStringsExt4.allTexts
        // 防空转：文案表若被清空，下面「零违规」也会绿
        assertTrue("文案条数不该少于 80 条，当前 ${texts.size}", texts.size >= 80)
        for (item in texts) {
            val template = ArbZh.value(item.key)
            assertMatchesArb(item.key, item.zh, template)
        }
    }

    @Test
    fun `文案表里没有重复键`() {
        val keys = SettingsStringsExt4.allTexts.map { it.key }
        val duplicated = keys.groupingBy { it }.eachCount().filter { it.value > 1 }.keys
        assertEquals("这些键在文案表里出现了多次：$duplicated", emptySet<String>(), duplicated)
    }

    @Test
    fun `三份 spec 上屏的每处文案都能在 arb 里追到`() {
        var checked = 0
        for (spec in specs()) {
            for ((key, text) in spec.allArbTexts()) {
                assertMatchesArb(key, text, ArbZh.value(key))
                checked++
            }
        }
        // 防空转：三页加起来远不止几处文案
        assertTrue("逐字对照的文案条数太少（$checked），遍历器可能失效", checked >= 40)
    }

    @Test
    fun `带占位符的模板按片段比对`() {
        // glassDock 的提示是唯一带占位符的一条：homeGridEditorHintBody {max}
        assertEquals("最多放置 {max} 个按钮；按住条目拖动即可排序。", ArbZh.value("homeGridEditorHintBody"))
        assertMatchesArb("homeGridEditorHintBody", "最多放置 5 个按钮；按住条目拖动即可排序。", ArbZh.value("homeGridEditorHintBody"))
        val failed = runCatching {
            assertMatchesArb("homeGridEditorHintBody", "最多能放 5 个按钮；按住条目拖动即可排序。", ArbZh.value("homeGridEditorHintBody"))
        }
        assertTrue("改掉模板片段应当比对失败", failed.isFailure)
    }

    @Test
    fun `底栏编辑器实际填好的提示语与模板拼合一致`() {
        val hint = SettingsGlassDockEditorPage.spec(
            SettingsPageState(),
            GlassDockEditorState(enabledIds = listOf("day")),
        ).flatten().filterIsInstance<SettingsDescription>().single { it.id == "dock.hint" }
        assertEquals(SettingsStringsExt4.homeGridEditorHintBody.filled("max", "5"), hint.text)
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
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
