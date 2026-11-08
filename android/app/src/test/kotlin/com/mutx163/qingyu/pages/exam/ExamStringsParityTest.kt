package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.ExamReminderPreset
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 考试模块文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class ExamStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = ExamStrings.allTexts
        assertTrue("文案条数不应少于 70 条，当前 ${texts.size}", texts.size >= 70)

        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `星期名称与 ARB 严格对齐`() {
        assertEquals("周一", ExamStrings.weekdayLabel(1))
        assertEquals("周二", ExamStrings.weekdayLabel(2))
        assertEquals("周三", ExamStrings.weekdayLabel(3))
        assertEquals("周四", ExamStrings.weekdayLabel(4))
        assertEquals("周五", ExamStrings.weekdayLabel(5))
        assertEquals("周六", ExamStrings.weekdayLabel(6))
        assertEquals("周日", ExamStrings.weekdayLabel(7))
        assertEquals("", ExamStrings.weekdayLabel(0))
        assertEquals("", ExamStrings.weekdayLabel(8))
    }

    @Test
    fun `提醒预设名与 ARB 严格对齐`() {
        assertEquals("不提醒", ExamStrings.presetLabel(ExamReminderPreset.NONE))
        assertEquals("考前 30 分钟", ExamStrings.presetLabel(ExamReminderPreset.MIN_30))
        assertEquals("考前 1 小时", ExamStrings.presetLabel(ExamReminderPreset.HOUR_1))
        assertEquals("考前 1 小时 + 30 分钟", ExamStrings.presetLabel(ExamReminderPreset.HOUR_1_AND_MIN_30))
        assertEquals("考前 1 天", ExamStrings.presetLabel(ExamReminderPreset.DAY_1))
        assertEquals("考前 1 天 + 1 小时", ExamStrings.presetLabel(ExamReminderPreset.DAY_1_AND_HOUR_1))
        assertEquals("自定义", ExamStrings.presetLabel(ExamReminderPreset.CUSTOM))
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals("第 3 周", ExamStrings.weekLabel.filled("week", "3"))
        assertEquals("距离考试还有 5 天", ExamStrings.daysUntilExam.filled("days", "5"))
        assertEquals("今日 2 场", ExamStrings.examOverviewTodayCount.filled("count", "2"))
        assertEquals("共 7 场", ExamStrings.examOverviewUpcomingCount.filled("count", "7"))
        assertEquals("至 10:30", ExamStrings.examOverviewUntilTime.filled("time", "10:30"))
        assertEquals("08:00 – 09:30", ExamStrings.examTimeRange.filled("start" to "08:00", "end" to "09:30"))
        assertEquals("考前 15 分钟", ExamStrings.examReminderOffsetMinutes.filled("minutes", "15"))
        assertEquals("考前 2 小时", ExamStrings.examReminderOffsetHours.filled("hours", "2"))
        assertEquals("考前 3 天", ExamStrings.examReminderOffsetDays.filled("days", "3"))
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
