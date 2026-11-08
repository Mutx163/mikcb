package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 导出模块文案逐字对照 ARB（`i18n/app_zh.arb`）。
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

    /**
     * 两条死键 2026-11-06 已删（`icsExportSharing` / `icsExportDateRangeInvalid`：
     * ARB 六份都有、但 Dart 与 Kotlin 代码零引用的遗留文案键）。
     *
     * 这条守卫防「加回」：一旦谁把它们加回 `ExportStrings` 或任何一份 ARB，
     * `gen-l10n` 会重新生成 getter，而死键清单是**只减不增**的棘轮——所以在这里拦。
     */
    @Test
    fun `两条已删死键不许加回来`() {
        val removedKeys = listOf("icsExportSharing", "icsExportDateRangeInvalid")

        for (key in removedKeys) {
            assertFalse(
                "`$key` 又回到了 `ExportStrings.allTexts`（Kotlin 侧把死键加回来了）。",
                ExportStrings.allTexts.any { it.key == key },
            )
        }

        val arbDir = File(repoRoot(), "i18n")
        val arbFiles = listOf(
            "app_zh.arb",
            "app_en.arb",
            "app_ja.arb",
            "app_ko.arb",
            "app_zh_HK.arb",
            "app_zh_TW.arb",
        )
        for (name in arbFiles) {
            val file = File(arbDir, name)
            assertTrue("找不到 ARB 文件：${file.absolutePath}", file.isFile)
            val text = file.readText(Charsets.UTF_8)
            for (key in removedKeys) {
                assertFalse(
                    "`$key` 又回到了 $name（ARB 侧把死键加回来了，gen-l10n 会再生成 getter）。",
                    text.contains("\"$key\""),
                )
            }
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

    /** 仓库根：以 `i18n/app_zh.arb` 为标志文件向上找（L0 与 Gradle 的工作目录不同）。 */
    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（i18n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}
