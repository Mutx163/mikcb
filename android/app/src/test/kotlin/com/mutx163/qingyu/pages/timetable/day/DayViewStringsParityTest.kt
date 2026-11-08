package com.mutx163.qingyu.pages.timetable.day

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日视图文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * Compose Phase 3 验收门槛 3：界面文案与 ARB 原文逐字一致，不私自改写、不省略占位符。
 */
class DayViewStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = DayViewStrings.allTexts
        // 2026-10-31 审核：门槛原写 `>= 40`，而当时声明了 50 条——新加两条没进 allTexts
        // 也能照样绿（逐字对拍只遍历 allTexts）。门槛按「声明条数」卡死，见下一条用例。
        assertTrue("文案条数不应少于 49 条，当前 ${texts.size}", texts.size >= 49)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `allTexts 必须收录本对象的每一条 ArbText 声明`() {
        // 防的是「新增了 ArbText、忘了登记 allTexts」——那时上面那条逐字对拍
        // 根本不会看它，文案错了也全绿（2026-10-31 审核 P0）。
        val source = readRepoFile(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewStrings.kt",
        )
        val declared = Regex("""ArbText\(\s*"([^"]+)"\s*,""").findAll(source)
            .map { it.groupValues[1] }
            .toSet()
        val listed = DayViewStrings.allTexts.map { it.key }
        val missing = declared - listed.toSet()
        val extra = listed.toSet() - declared
        assertTrue("DayViewStrings 声明了但没进 allTexts（逐字对拍漏检）：$missing", missing.isEmpty())
        assertTrue("allTexts 里有 DayViewStrings 不存在的键：$extra", extra.isEmpty())
        assertEquals("allTexts 条数与声明条数不一致", declared.size, listed.size)
    }

    @Test
    fun `星期名称与 ARB 严格对齐`() {
        assertEquals("周一", DayViewStrings.weekdayLabel(1))
        assertEquals("周二", DayViewStrings.weekdayLabel(2))
        assertEquals("周三", DayViewStrings.weekdayLabel(3))
        assertEquals("周四", DayViewStrings.weekdayLabel(4))
        assertEquals("周五", DayViewStrings.weekdayLabel(5))
        assertEquals("周六", DayViewStrings.weekdayLabel(6))
        assertEquals("周日", DayViewStrings.weekdayLabel(7))
        assertEquals("", DayViewStrings.weekdayLabel(0))
        assertEquals("", DayViewStrings.weekdayLabel(8))
    }

    @Test
    fun `格式化纯函数占位符插值按预期生成文案`() {
        assertEquals("第 3 周", DayViewStrings.weekLabel(3))
        assertEquals("4 门课", DayViewStrings.courseCountSummary(4))
        assertEquals("日程 2 项", DayViewStrings.scheduleCountSummary(2))
        assertEquals("作业 5 项", DayViewStrings.dayTaskBandCountSummary(5))
        assertEquals("逾期 3 天", DayViewStrings.dayTaskBandOverdueBadge(3))
        assertEquals("还有 4 项逾期", DayViewStrings.dayTaskBandOverdueMore(4))
        assertEquals("7 天后", DayViewStrings.examCountdownDays(7))
        assertEquals("08:00 开始", DayViewStrings.classStartsAtLabel("08:00"))
        assertEquals("20:30 结束", DayViewStrings.classEndsAtLabel("20:30"))
        assertEquals("冲突 2 节", DayViewStrings.conflictCountLabel(2))
        assertEquals("进行中 · 剩余 15 分钟", DayViewStrings.dayAgendaInProgressStatus(15))
        assertEquals("快下课了 · 剩余 5 分钟", DayViewStrings.dayAgendaEndingSoonStatus(5))
        assertEquals("进行中 · 剩余 20 分钟", DayViewStrings.scheduleAgendaInProgressStatus(20))
        assertEquals("即将结束 · 剩余 8 分钟", DayViewStrings.scheduleAgendaEndingSoonStatus(8))
        assertEquals("第 1～2 节", DayViewStrings.sectionRangeLabel(1, 2))
        assertEquals("教师：张老师", DayViewStrings.teacherPrefix("张老师"))
        assertEquals("地点：教二201", DayViewStrings.locationPrefix("教二201"))
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

    private fun readRepoFile(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
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
