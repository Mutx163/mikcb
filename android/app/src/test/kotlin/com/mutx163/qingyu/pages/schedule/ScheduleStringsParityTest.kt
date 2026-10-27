package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日程模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class ScheduleStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = ScheduleStrings.allTexts
        assertTrue("文案条数不应少于 70 条，当前 ${texts.size}", texts.size >= 70)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `星期名称与 ARB 严格对齐`() {
        assertEquals("周一", ScheduleStrings.weekdayLabel(1))
        assertEquals("周二", ScheduleStrings.weekdayLabel(2))
        assertEquals("周三", ScheduleStrings.weekdayLabel(3))
        assertEquals("周四", ScheduleStrings.weekdayLabel(4))
        assertEquals("周五", ScheduleStrings.weekdayLabel(5))
        assertEquals("周六", ScheduleStrings.weekdayLabel(6))
        assertEquals("周日", ScheduleStrings.weekdayLabel(7))
        assertEquals("", ScheduleStrings.weekdayLabel(0))
        assertEquals("", ScheduleStrings.weekdayLabel(8))
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        val deleteMsg = ScheduleStrings.deleteScheduleMessage.filled("title", "团队周会")
        assertEquals("确定删除日程 团队周会？", deleteMsg)

        val timeRange = ScheduleStrings.scheduleTimeRange.filled("start" to "08:00", "end" to "09:30")
        assertEquals("08:00 – 09:30", timeRange)

        val weekly = ScheduleStrings.scheduleWeeklyWithDay.filled("day", "周三")
        assertEquals("每周 周三", weekly)

        val reminder = ScheduleStrings.scheduleReminderMinutes.filled("minutes", "15")
        assertEquals("提前 15 分钟", reminder)

        val crossDay = ScheduleStrings.scheduleCrossDaySpanHint
            .filled("start" to "9月1日 08:00", "end" to "9月3日 18:00")
        assertEquals("从 9月1日 08:00 持续到 9月3日 18:00", crossDay)
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
