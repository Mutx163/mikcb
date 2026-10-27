package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 导出模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class ExportStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = ExportStrings.allTexts
        assertTrue("文案条数不应少于 45 条，当前 ${texts.size}", texts.size >= 45)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals(
            "已导出并分享 12 个日历事件",
            ExportStrings.icsExportShared.filled("count", "12"),
        )
        assertEquals(
            "日历已保存，共 3 个事件",
            ExportStrings.icsExportSavedCount.filled("count", "3"),
        )
        assertEquals(
            "轻屿课表·2026 春",
            ExportStrings.icsExportSyncCalendarName.filled("profileName", "2026 春"),
        )
        assertEquals(
            "将在系统日历中创建日历 轻屿课表·2026 春 并同步所选日程，重复同步将覆盖旧数据。首次同步需要日历权限。",
            ExportStrings.icsExportSyncCalendarBody.filled(
                "calendarName",
                "轻屿课表·2026 春",
            ),
        )
        assertEquals(
            "已跳过假期中的 5 个课程",
            ExportStrings.icsExportSyncCalendarSkipped.filled("count", "5"),
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
