package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 导入·仓库适配域文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * 覆盖仓库适配、学校适配器、网页登录、宏录制、自定义调试与 AI 识图导入共 8 件 Dart 页面。
 */
class WarehouseStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = WarehouseStrings.allTexts
        assertTrue("文案条数不应少于 180 条，当前 ${texts.size}", texts.size >= 180)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `带参数文案的占位符与 ARB 完全一致`() {
        assertEquals(
            arbMap["quickImportTitle"]!!.replace("{name}", "北京大学"),
            WarehouseStrings.quickImportTitle.filled("name", "北京大学"),
        )
        assertEquals(
            arbMap["quickImportMacroSteps"]!!
                .replace("{adapterName}", "正方新版")
                .replace("{steps}", "3"),
            WarehouseStrings.quickImportMacroSteps.filled("adapterName", "正方新版").filled("steps", "3"),
        )
        assertEquals(
            arbMap["warehouseMatchedAdaptersLabel"]!!.replace("{adapters}", "正方教务、强智教务"),
            WarehouseStrings.warehouseMatchedAdaptersLabel.filled("adapters", "正方教务、强智教务"),
        )
        assertEquals(
            arbMap["aiPreviewSummary"]!!
                .replace("{count}", "10")
                .replace("{section}", "12")
                .replace("{warningSuffix}", "（3 条提示）"),
            WarehouseStrings.aiPreviewSummary.filled("count", "10").filled("section", "12").filled("warningSuffix", "（3 条提示）"),
        )
        assertEquals(
            arbMap["aiPreviewCourseCount"]!!.replace("{count}", "8"),
            WarehouseStrings.aiPreviewCourseCount.filled("count", "8"),
        )
        assertEquals(
            arbMap["aiPreviewMaxSection"]!!.replace("{section}", "10"),
            WarehouseStrings.aiPreviewMaxSection.filled("section", "10"),
        )
        assertEquals(
            arbMap["aiWarningCountSuffix"]!!.replace("{count}", "2"),
            WarehouseStrings.aiWarningCountSuffix.filled("count", "2"),
        )
        assertEquals(
            arbMap["deleteDebugRecordMessage"]!!.replace("{name}", "清华调试"),
            WarehouseStrings.deleteDebugRecordMessage.filled("name", "清华调试"),
        )
        assertEquals(
            arbMap["debugScriptLength"]!!.replace("{length}", "1024"),
            WarehouseStrings.debugScriptLength.filled("length", "1024"),
        )
        assertEquals(
            arbMap["scriptLoadedLength"]!!.replace("{length}", "2048"),
            WarehouseStrings.scriptLoadedLength.filled("length", "2048"),
        )
        assertEquals(
            arbMap["rememberPasswordMessage"]!!.replace("{username}", "2024001"),
            WarehouseStrings.rememberPasswordMessage.filled("username", "2024001"),
        )
        assertEquals(
            arbMap["rememberedAccountLabel"]!!.replace("{username}", "student1"),
            WarehouseStrings.rememberedAccountLabel.filled("username", "student1"),
        )
        assertEquals(
            arbMap["executeFailedWithError"]!!.replace("{error}", "网络异常"),
            WarehouseStrings.executeFailedWithError.filled("error", "网络异常"),
        )
        assertEquals(
            arbMap["saveSectionTimesFailedWithError"]!!.replace("{error}", "格式错误"),
            WarehouseStrings.saveSectionTimesFailedWithError.filled("error", "格式错误"),
        )
        assertEquals(
            arbMap["courseImportSaveRecordingMessage"]!!
                .replace("{schoolName}", "浙江大学")
                .replace("{adapterName}", "URP教务")
                .replace("{stepCount}", "5"),
            WarehouseStrings.courseImportSaveRecordingMessage
                .filled("schoolName", "浙江大学")
                .filled("adapterName", "URP教务")
                .filled("stepCount", "5"),
        )
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
        val parsed = com.mutx163.qingyu.core.MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
