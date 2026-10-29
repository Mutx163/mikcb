package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入域服务消息本地化的行为测试（F07 · 2026-10-29）。
 *
 * 三件事各钉一层：
 * 1. **文案与 ARB 逐字一致**（键抄错 / 改写 / 丢占位符都会红）；
 * 2. **两层载荷解析**：外层 `spreadsheet_row_warning` 递归内层码，且内层参数是平铺的
 *    （Dart `service_message_localizer.dart:59-72` 的注释写的就是这个坑，
 *    不把外层参数传下去，`field_cannot_be_empty` 会渲染成「 不能为空」）；
 * 3. **兜底口径**：像机器码才替换成「发生未知错误」，人话原样透传。
 *
 * 期望值全部按 Dart 源手推，不从本实现里抄。
 */
class ImportServiceMessagesTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    // ------------------------------------------------------------------
    // 1. 文案对拍
    // ------------------------------------------------------------------

    @Test
    fun `每一处文案都与 app_zh_arb 逐字一致`() {
        val texts = ImportServiceMessages.allTexts
        assertTrue("文案条数不应少于 20 条，当前 ${texts.size}", texts.size >= 20)
        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `文案键没有重复`() {
        val keys = ImportServiceMessages.allTexts.map { it.key }
        assertEquals(
            "存在重复键：${keys.groupBy { it }.filterValues { it.size > 1 }.keys}",
            keys.size,
            keys.toSet().size,
        )
    }

    // ------------------------------------------------------------------
    // 2. 两层行级警告
    // ------------------------------------------------------------------

    @Test
    fun `行级警告渲染成第几行加内层原因`() {
        val raw = "spreadsheet_row_warning|rowNumber=5|inner=course_name_required"
        assertEquals("第 5 行：课程名称不能为空", ImportServiceMessages.localize(raw))
    }

    @Test
    fun `内层参数平铺时字段名不丢`() {
        // `encodeServiceRowWarning` 把内层 payload 塞进外层 `inner=`，两层共用 `|`，
        // 于是内层的 field= 直接平铺在外层参数表里（Dart 注释点名的场景）。
        val raw = "spreadsheet_row_warning|rowNumber=3|inner=field_cannot_be_empty|field=course_name"
        assertEquals("第 3 行：课程名称 不能为空", ImportServiceMessages.localize(raw))
    }

    @Test
    fun `未登记的字段码原样透传`() {
        val raw = "spreadsheet_row_warning|rowNumber=2|inner=field_must_be_integer|field=whatever"
        assertEquals("第 2 行：whatever 必须是整数", ImportServiceMessages.localize(raw))
    }

    // ------------------------------------------------------------------
    // 3. 单个码
    // ------------------------------------------------------------------

    @Test
    fun `裸码渲染成 ARB 原句`() {
        assertEquals(
            "未识别表格格式，请使用轻屿课表模板；也兼容 WakeUp 等同列格式",
            ImportServiceMessages.localize("spreadsheet_format_unrecognized"),
        )
        assertEquals(
            "无法识别表格格式或编码，请将 CSV 另存为 UTF-8 后重试",
            ImportServiceMessages.localize("spreadsheet_format_or_encoding_unrecognized"),
        )
    }

    @Test
    fun `带参数的码按模板填值`() {
        assertEquals(
            "节次 12 超出作息范围 1 至 10",
            ImportServiceMessages.localize("section_out_of_range|section=12|maxSection=10"),
        )
        assertEquals(
            "第 4 行：结束周 25 超过学期周数 20，已调整为 20",
            ImportServiceMessages.localize(
                "spreadsheet_end_week_clamped|rowNumber=4|endWeek=25|semesterWeekCount=20",
            ),
        )
        assertEquals(
            "XLSX 文件解析失败：boom",
            ImportServiceMessages.localize("spreadsheet_xlsx_parse_failed|error=boom"),
        )
    }

    @Test
    fun `结束周小于开始周时两个字段名都对`() {
        assertEquals(
            "结束节数 不能小于 开始节数",
            ImportServiceMessages.localize(
                "field_cannot_be_less_than|startField=start_section|endField=end_section",
            ),
        )
    }

    // ------------------------------------------------------------------
    // 4. 兜底
    // ------------------------------------------------------------------

    @Test
    fun `空白输入给兜底文案`() {
        assertEquals("发生未知错误", ImportServiceMessages.localize(null))
        assertEquals("发生未知错误", ImportServiceMessages.localize(""))
        assertEquals("发生未知错误", ImportServiceMessages.localize("   "))
    }

    @Test
    fun `未登记的机器码落兜底`() {
        assertEquals("发生未知错误", ImportServiceMessages.localize("some_unregistered_code"))
        assertEquals(
            "发生未知错误",
            ImportServiceMessages.localize("settings_mirror_snapshot_invalid:key1"),
        )
    }

    @Test
    fun `不像机器码的人话原样透传`() {
        assertEquals("导入失败，文件内容无法识别", ImportServiceMessages.localize("导入失败，文件内容无法识别"))
        assertEquals("ImportFileTooLarge", ImportServiceMessages.localize("ImportFileTooLarge"))
        assertEquals("Bad state: xxx", ImportServiceMessages.localize("Bad state: xxx"))
    }

    // ------------------------------------------------------------------

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val index = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的模板片段『$segment』在『$text』里找不到（模板：$template）",
                index >= 0,
            )
            cursor = index + segment.length
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
        val file = arbFile ?: error("找不到 lib/l10n/app_zh.arb（从 ${File("").absolutePath} 向上找了 8 层）")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        // `@key` 元数据不是文案，跳过（调用方只查真实键）。
        parsed.forEach { (key, value) -> if (key is String && value is String) map[key] = value }
        return map
    }
}
