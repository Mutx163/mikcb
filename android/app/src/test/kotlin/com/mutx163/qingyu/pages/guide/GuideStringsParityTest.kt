package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 引导与展示模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class GuideStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = GuideStrings.allTexts
        assertTrue("文案条数不应少于 80 条，当前 ${texts.size}", texts.size >= 80)

        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals("第 3 周", "第 {week} 周".filled("week", "3"))
        assertEquals("已就绪 4/6", GuideStrings.guidePermissionsProgressLabel.filled("ready" to "4", "total" to "6"))
        assertEquals("当前值：18", GuideStrings.hyperosShowcasePickerCurrentValue.filled("value", "18"))
        assertEquals("3 周", GuideStrings.currentWeekCompact.filled("week", "3"))
        assertEquals("已同步到第 5 周", GuideStrings.syncedCurrentWeekMessage.filled("week", "5"))
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

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "lib/l10n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 lib/l10n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
