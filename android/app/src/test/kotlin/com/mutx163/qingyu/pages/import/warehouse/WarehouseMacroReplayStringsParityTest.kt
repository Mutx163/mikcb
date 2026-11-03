package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 宏回放域文案逐字对照 ARB（`lib/l10n/app_zh.arb`）：`WarehouseMacroReplayStrings`
 * 的全部条目（过程文案 + 失败码表）键存在、值逐字一致（硬要求 6：文案零新增，
 * 只许镜像）。对拍模式与 [WarehouseStringsParityTest] 同款。
 */
class WarehouseMacroReplayStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处宏回放文案都与 app_zh_arb 逐字一致`() {
        val texts = WarehouseMacroReplayStrings.allTexts
        assertTrue("宏回放文案条数不应少于 26 条，当前 ${texts.size}", texts.size >= 26)
        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertEquals("键 `${item.key}` 的屏上文案与 ARB 不一致", template, item.zh)
        }
    }

    @Test
    fun `带参数文案的占位符与 ARB 完全一致`() {
        assertEquals(
            arbMap["macroReplayStatusFailed"]!!.replace("{error}", "未找到元素：#Form1"),
            WarehouseMacroReplayStrings.macroReplayStatusFailed.filled("error" to "未找到元素：#Form1"),
        )
        assertEquals(
            arbMap["macroReplayNavigateTo"]!!.replace("{url}", "http://jw.example.edu.cn/"),
            WarehouseMacroReplayStrings.macroReplayNavigateTo.filled("url" to "http://jw.example.edu.cn/"),
        )
        assertEquals(
            arbMap["quickImportPlaybackStepProgress"]!!
                .replace("{current}", "1")
                .replace("{total}", "6"),
            WarehouseMacroReplayStrings.quickImportPlaybackStepProgress
                .filled("current" to "1", "total" to "6"),
        )
        assertEquals(
            arbMap["serviceMsgMacroElementNotFound"]!!.replace("{selector}", "#Form1"),
            WarehouseMacroReplayStrings.serviceMsgMacroElementNotFound.filled("selector" to "#Form1"),
        )
        assertEquals(
            arbMap["serviceMsgMacroPollTimeout"]!!
                .replace("{stepLabel}", "等待页面加载")
                .replace("{timeoutSeconds}", "15")
                .replace("{lastError}", ""),
            WarehouseMacroReplayStrings.serviceMsgMacroPollTimeout
                .filled("stepLabel" to "等待页面加载", "timeoutSeconds" to "15", "lastError" to ""),
        )
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
        val parsed = com.mutx163.qingyu.core.MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
