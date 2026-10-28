package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 地点作息匹配页（含编辑页）文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 与 `TimeSchemeManagementStringsParityTest` 同一套机制：编辑页是 Kotlin 重写、不读
 * gen-l10n，所以每条屏上文案都必须被机械证明与 ARB 原文一致。编辑页用到的
 * 组名/模板/关键词/楼栋/保存等文案都经 [LocationTimeMatchStrings]（本测试逐条比对）。
 */
class LocationTimeMatchStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = LocationTimeMatchStrings.allTexts
        assertTrue("文案条数不应少于 60 条，当前 ${texts.size}", texts.size >= 60)
        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `键名不重复`() {
        val duplicated = LocationTimeMatchStrings.allTexts.groupBy { it.key }.filterValues { it.size > 1 }.keys
        assertTrue("ARB 键被登记了多次：$duplicated", duplicated.isEmpty())
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var from = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, from)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            from = idx + segment.length
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
        val file = arbFile ?: error("找不到 lib/l10n/app_zh.arb，当前工作目录 ${File("").absolutePath}")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        assertTrue("app_zh.arb 解析出的键过少（${map.size}）", map.size > 100)
        return map
    }
}
