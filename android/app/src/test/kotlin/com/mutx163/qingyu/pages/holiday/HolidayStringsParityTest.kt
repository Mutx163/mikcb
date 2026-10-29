package com.mutx163.qingyu.pages.holiday

import com.mutx163.qingyu.calendar.ArbText
import com.mutx163.qingyu.calendar.HolidayStrings
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 节假日日志文案逐字对照 ARB（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * 门槛验收 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * 与 `pages/weather/WeatherStringsParityTest` 同一套判据（那边 33 条，这边 19 条）。
 */
class HolidayStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `19 条日志文案都与 app_zh_arb 逐字一致`() {
        val texts = HolidayStrings.allArbTexts
        assertEquals("19 条 = holiday_log_localizer.dart 的 19 个分支", 19, texts.size)

        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `占位符插值按模板替换且不动其它字符`() {
        val sample = ArbText("testTemplate", "主 API 返回 {count} 条原始数据，正在解析……")
        assertEquals(
            "主 API 返回 365 条原始数据，正在解析……",
            sample.filled("count" to "365"),
        )
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的文案与 arb 不一致", template, text)
            return
        }
        // 有占位符时逐段比对固定文字（占位符位置允许不同实现，但字面文字必须一字不差）。
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的文案『$text』里找不到模板片段『$segment』（模板：$template）",
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
