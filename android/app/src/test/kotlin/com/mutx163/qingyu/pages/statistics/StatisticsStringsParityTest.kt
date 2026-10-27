package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 统计模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class StatisticsStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = StatisticsStrings.allTexts
        assertTrue("文案条数不应少于 100 条，当前 ${texts.size}", texts.size >= 100)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `星期名与 ARB 严格对齐`() {
        assertEquals("周一", StatisticsStrings.weekdayFull(1))
        assertEquals("周二", StatisticsStrings.weekdayFull(2))
        assertEquals("周三", StatisticsStrings.weekdayFull(3))
        assertEquals("周四", StatisticsStrings.weekdayFull(4))
        assertEquals("周五", StatisticsStrings.weekdayFull(5))
        assertEquals("周六", StatisticsStrings.weekdayFull(6))
        assertEquals("周日", StatisticsStrings.weekdayFull(7))
        assertEquals("8", StatisticsStrings.weekdayFull(8))

        assertEquals("一", StatisticsStrings.weekdayShort(1))
        assertEquals("", StatisticsStrings.weekdayShort(0))
        assertEquals("日", StatisticsStrings.weekdayShort(7))
    }

    @Test
    fun `成就名称映射与 ARB 一致且未知 id 原样返回`() {
        assertEquals("早八战士", StatisticsStrings.achievementName("early_bird"))
        assertEquals("全勤达人", StatisticsStrings.achievementName("perfect_attendance"))
        assertEquals("周末战士", StatisticsStrings.achievementName("weekend_warrior"))
        assertEquals("课王", StatisticsStrings.achievementName("class_king"))
        assertEquals("学霸", StatisticsStrings.achievementName("scholar"))
        assertEquals("均衡大师", StatisticsStrings.achievementName("balanced"))
        assertEquals("夜猫子", StatisticsStrings.achievementName("night_owl"))
        assertEquals("教室探索家", StatisticsStrings.achievementName("explorer"))
        assertEquals("满课日之王", StatisticsStrings.achievementName("full_day_king"))
        assertEquals("跨楼达人", StatisticsStrings.achievementName("building_hopper"))
        assertEquals("早起鸟", StatisticsStrings.achievementName("morning_person"))
        assertEquals("时间管理大师", StatisticsStrings.achievementName("gap_master"))
        assertEquals("unknown_id", StatisticsStrings.achievementName("unknown_id"))
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        val week = StatisticsStrings.statisticsWeekSelector.filled("week", "5")
        assertEquals("第 5 周", week)

        val legend = StatisticsStrings.statisticsNatureLegendDetail.filled("count" to "3", "sections" to "12")
        assertEquals("3 门 · 12 节", legend)

        val progress = StatisticsStrings.statisticsSemesterProgressRange
            .filled("start" to "2026年9月1日", "end" to "2027年1月10日")
        assertEquals("学期 2026年9月1日 - 2027年1月10日", progress)

        val detail = StatisticsStrings.statisticsSemesterProgressDetail
            .filled("week" to "8", "done" to "96", "total" to "192")
        assertEquals("截至第 8 周，已上 96 节 / 共 192 节", detail)

        val nextFire = StatisticsStrings.weeklyReportNextFire.filled("date" to "11月1日", "time" to "21:00")
        assertEquals("下次推送 11月1日 21:00", nextFire)
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
