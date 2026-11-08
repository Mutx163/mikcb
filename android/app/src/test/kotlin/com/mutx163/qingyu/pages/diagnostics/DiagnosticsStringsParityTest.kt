package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 诊断模块文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * `loadArbZh()` 照抄 `pages/schedule/ScheduleStringsParityTest.kt`：从工作目录
 * 向上找 `i18n/app_zh.arb`，不写死绝对路径（Gradle 的工作目录随任务变）。
 */
class DiagnosticsStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = DiagnosticsStrings.allTexts
        assertTrue("文案条数不应少于 45 条，当前 ${texts.size}", texts.size >= 45)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `等级名与 ARB 严格对齐`() {
        // 顺序与 `DiagnosticsLogLevel` 枚举一致（芯片按此顺序排列，Dart 同款）。
        assertEquals(
            listOf("全部", "错误", "警告", "信息", "调试", "详细"),
            com.mutx163.qingyu.infra.DiagnosticsLogLevel.entries.map {
                DiagnosticsStrings.levelLabel(it)
            },
        )
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        val earlier = DiagnosticsStrings.diagnosticsLoadEarlierLabel.filled("count", "120")
        assertEquals("加载更早日志 剩余 120 条", earlier)

        val showing = DiagnosticsStrings.diagnosticsShowingCount
            .filled("shown" to "200", "total" to "300")
        assertEquals("显示 200 / 300 条日志", showing)
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
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 i18n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
