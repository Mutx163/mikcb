package com.mutx163.qingyu.pages.statistics.charts

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 图表层文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * 写法照 `pages/statistics/StatisticsStringsParityTest`：从工作目录向上找 ARB，
 * 用仓库自带的 `MiniJson` 解析，不走 Gson/Jackson（JVM 单测 classpath 里没有）。
 */
class ChartsStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处图表文案都与 app_zh_arb 逐字一致`() {
        val texts = ChartsStrings.allTexts
        // 条数下限：漏登记一条新文案时这条会先把关（当前 110 条，留 100 的余量）
        assertTrue("图表文案条数不应少于 100 条，当前 ${texts.size}", texts.size >= 100)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `星期名与 ARB 严格对齐`() {
        assertEquals("周一", ChartsStrings.weekdayFull(1))
        assertEquals("周日", ChartsStrings.weekdayFull(7))
        // 越界回退成数字（对齐 Dart `_weekdayFullLabel` 的 default 分支）
        assertEquals("8", ChartsStrings.weekdayFull(8))
        assertEquals("0", ChartsStrings.weekdayFull(0))

        assertEquals("一", ChartsStrings.weekdayShort(1))
        assertEquals("日", ChartsStrings.weekdayShort(7))
        // 越界返回空串（图表横轴不留数字占位）
        assertEquals("", ChartsStrings.weekdayShort(0))
        assertEquals("", ChartsStrings.weekdayShort(9))
    }

    @Test
    fun `成就名称 描述 解锁条件与 ARB 一致且未知 id 原样返回`() {
        assertEquals("早八战士", ChartsStrings.achievementName("early_bird"))
        assertEquals("全勤达人", ChartsStrings.achievementName("perfect_attendance"))
        assertEquals("周末战士", ChartsStrings.achievementName("weekend_warrior"))
        assertEquals("课王", ChartsStrings.achievementName("class_king"))
        assertEquals("学霸", ChartsStrings.achievementName("scholar"))
        assertEquals("均衡大师", ChartsStrings.achievementName("balanced"))
        assertEquals("夜猫子", ChartsStrings.achievementName("night_owl"))
        assertEquals("教室探索家", ChartsStrings.achievementName("explorer"))
        assertEquals("满课日之王", ChartsStrings.achievementName("full_day_king"))
        assertEquals("跨楼达人", ChartsStrings.achievementName("building_hopper"))
        assertEquals("早起鸟", ChartsStrings.achievementName("morning_person"))
        assertEquals("时间管理大师", ChartsStrings.achievementName("gap_master"))
        // 未知 id 原样返回，不抛不崩
        assertEquals("unknown_id", ChartsStrings.achievementName("unknown_id"))

        assertEquals("有 8:00 的课，真棒", ChartsStrings.achievementDescription("early_bird"))
        assertEquals("某门课每周都有", ChartsStrings.achievementDescription("perfect_attendance"))
        assertEquals("总课时 ≥ 100", ChartsStrings.achievementDescription("scholar"))
        assertEquals("最长课间空档 ≤ 2 节", ChartsStrings.achievementDescription("gap_master"))
        assertEquals("", ChartsStrings.achievementDescription("unknown_id"))

        assertEquals(
            "解锁条件：课表中有 08:00 或更早开始的课程。",
            ChartsStrings.achievementDetail("early_bird"),
        )
        assertEquals(
            "解锁条件：学期累计课时达到 100 节。",
            ChartsStrings.achievementDetail("scholar"),
        )
        assertEquals("", ChartsStrings.achievementDetail("unknown_id"))
    }

    @Test
    fun `成就文案的每条取值也必须在 ARB 里出现`() {
        // 名称/描述/解锁条件是用 when 手写的常量，不是 ChartText；
        // 这里把它们反查一遍 ARB，防止手抄时改字。
        val ids = listOf(
            "early_bird" to "EarlyBird",
            "perfect_attendance" to "PerfectAttendance",
            "weekend_warrior" to "WeekendWarrior",
            "class_king" to "ClassKing",
            "scholar" to "Scholar",
            "balanced" to "Balanced",
            "night_owl" to "NightOwl",
            "explorer" to "Explorer",
            "full_day_king" to "FullDayKing",
            "building_hopper" to "BuildingHopper",
            "morning_person" to "MorningPerson",
            "gap_master" to "GapMaster",
        )
        for ((id, pascal) in ids) {
            assertEquals(
                "ARB statisticsAchievement${pascal}Name 与代码不一致",
                arbMap["statisticsAchievement${pascal}Name"],
                ChartsStrings.achievementName(id),
            )
            assertEquals(
                "ARB statisticsAchievement${pascal}Description 与代码不一致",
                arbMap["statisticsAchievement${pascal}Description"],
                ChartsStrings.achievementDescription(id),
            )
            assertEquals(
                "ARB statisticsAchievement${pascal}Detail 与代码不一致",
                arbMap["statisticsAchievement${pascal}Detail"],
                ChartsStrings.achievementDetail(id),
            )
        }
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals("第 5 周", ChartsStrings.statisticsWeekSelector.filled("week", "5"))
        assertEquals("第 5 周", ChartsStrings.statisticsWeekSelector.filled("week", 5))
        assertEquals("第 5 周 · 12 节", ChartsStrings.statisticsTrendTooltip.filled("week" to "5", "sections" to "12"))
        assertEquals("3 门 · 12 节", ChartsStrings.statisticsNatureLegendDetail.filled("count" to "3", "sections" to "12"))
        assertEquals("周一 第 1～2 节", ChartsStrings.statisticsRankingSlotDetail.filled("day" to "周一", "startSection" to "1", "endSection" to "2"))
        assertEquals("12 次", ChartsStrings.statisticsVenueVisits.filled("count", 12))
        assertEquals("3 门课", ChartsStrings.statisticsTeacherCourseCount.filled("count", 3))
        assertEquals("剩余 96 节", ChartsStrings.statisticsSemesterProgressRemaining.filled("count", 96))
        assertEquals("较上周 +3 节", ChartsStrings.statisticsComparisonVsLastWeek.filled("delta", "+3"))
        assertEquals("6/100", ChartsStrings.statisticsAchievementProgress.filled("current" to "6", "target" to "100"))
        assertEquals("另有 4 门课程未展示", ChartsStrings.statisticsExportRankingMore.filled("count", 4))
    }

    // ────────────── 与已有 StatisticsStrings 的键不冲突（同屏可能同时出现） ──────────────

    @Test
    fun `图表层文案键无重复登记`() {
        val keys = ChartsStrings.allTexts.map { it.key }
        assertEquals("allTexts 里有重复登记的键", keys.size, keys.toSet().size)
    }

    // ────────────── 内部工具 ──────────────

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
                "键 `$key` 的模板片段『$segment』在实现文案『$text』里找不到（模板：$template）",
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
        val file = arbFile ?: error("找不到 i18n/app_zh.arb（工作目录：${File("").absolutePath}）")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
