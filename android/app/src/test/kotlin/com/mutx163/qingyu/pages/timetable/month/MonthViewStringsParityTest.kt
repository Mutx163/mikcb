package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 月视图文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * Compose Phase 3 验收门槛 3：界面文案与 ARB 原文逐字一致，不私自改写、不省略占位符。
 * 写法照 `pages/timetable/day/DayViewStringsParityTest`（同一条门禁，只是键集不同）。
 *
 * 注意：本用例读的是**工作区里的 ARB 文件**（不是 `app_localizations.dart`），
 * 所以 ARB 改了而 `tool/gen_month_view_strings.py` 没重跑时，这里会先红。
 */
class MonthViewStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `21 条月视图文案与 app_zh_arb 逐字一致`() {
        val texts = MonthViewStrings.allTexts
        assertEquals("月视图上屏文案条数（ARB 的 monthView*/monthOverview* 全集）", 21, texts.size)

        for (item in texts) {
            assertMatchesArb(item.key, item.zh)
        }
    }

    /**
     * 咬合探针：逐字对拍必须能红。
     *
     * 两条都很关键：改写一个字（`月视图` → `月视图页`）与**把占位符写死**
     *（`{year}年` → `2026年`）—— 后者是「文案看着对、换一年就错」的典型，
     * 光比前缀比不出来。不验这一步，对拍用例可能已经变成永远绿的摆设。
     */
    @Test
    fun `咬合探针_逐字对拍能抓住改写与占位符丢失`() {
        assertThrows(AssertionError::class.java) {
            assertMatchesArb("monthViewTitle", "月视图页")
        }
        assertThrows(AssertionError::class.java) {
            assertMatchesArb("monthViewYearSegment", "2026年")
        }
        // 同一判据对真实文案放行。
        assertMatchesArb("monthViewTitle", "月视图")
    }

    private fun assertMatchesArb(key: String, zh: String) {
        val template = arbMap[key]
        assertTrue("ARB(app_zh.arb) 中缺少键 `$key`", template != null)
        assertEquals("键 `$key` 的 Kotlin 文案与 ARB 不一致", template, zh)
    }

    @Test
    fun `键名不重复且全部落在月视图键域`() {
        val keys = MonthViewStrings.allTexts.map { it.key }
        assertEquals("存在重复键：$keys", keys.size, keys.toSet().size)
        for (key in keys) {
            assertTrue(
                "键 `$key` 不属于 monthView* / monthOverview* 键域（月视图不该上屏别的文案）",
                key.startsWith("monthView") || key.startsWith("monthOverview"),
            )
        }
    }

    @Test
    fun `占位符一个不丢也一个不多`() {
        for (item in MonthViewStrings.allTexts) {
            val arbPlaceholders = placeholdersOf(arbMap.getValue(item.key))
            val kotlinPlaceholders = placeholdersOf(item.zh)
            assertEquals(
                "键 `${item.key}` 的占位符集合与 ARB 不一致",
                arbPlaceholders,
                kotlinPlaceholders,
            )
        }
    }

    @Test
    fun `占位符填充生成屏上文案`() {
        assertEquals("2026年", arb("monthViewYearSegment").filled("year", "2026"))
        assertEquals("10月", arb("monthViewMonthSegment").filled("month", "10"))
        assertEquals(
            "10月5日",
            arb("monthViewDaySemantics").filled("month" to "10", "day" to "5"),
        )
        assertEquals("3节课", arb("monthViewCourseCountSemantics").filled("count", "3"))
        assertEquals("1场考试", arb("monthViewExamCountSemantics").filled("count", "1"))
        assertEquals("2个日程", arb("monthViewScheduleCountSemantics").filled("count", "2"))
        assertEquals("有安排 12 天", arb("monthOverviewScheduledDays").filled("count", "12"))
        assertEquals("还有 3 天", arb("monthOverviewMoreDays").filled("count", "3"))
        // 不带占位符的那几条原样返回。
        assertEquals("今天", arb("monthViewBackToCurrentMonthShort").filled("count", "9"))
    }

    @Test
    fun `休班角标与空态文案来自 ARB 而不是手写`() {
        assertEquals("休", arb("monthViewHolidayBadge").zh)
        assertEquals("班", arb("monthViewAdjustedWorkdayBadge").zh)
        assertEquals("这个月还没有安排", arb("monthViewEmptyMonthTitle").zh)
        assertEquals("这天没有安排", arb("monthViewAgendaEmpty").zh)
        // 空态说明句里不该出现「圆点」之外的实现细节（色带已取代圆点，但 ARB 是唯一真源，
        // 这条只钉「取的是 ARB 原文」，不改写）。
        assertFalse(arb("monthViewEmptyMonthHint").zh.isEmpty())
    }

    private fun arb(key: String): ArbText = MonthViewStrings.allTexts.first { it.key == key }

    private fun placeholdersOf(template: String): Set<String> =
        Regex("""\{([^}]*)\}""").findAll(template).map { it.groupValues[1] }.toSet()

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
