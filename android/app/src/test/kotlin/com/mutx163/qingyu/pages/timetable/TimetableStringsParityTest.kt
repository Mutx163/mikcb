package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 课表周视图与档案文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * Compose Phase 3 验收门槛 3：界面文案与 ARB 原文逐字一致，不私自改写、不省略占位符。
 */
class TimetableStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = TimetableStrings.arbTexts
        assertTrue("ARB 文案条数不应少于 30 条，当前 ${texts.size}", texts.size >= 30)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `星期名称与 ARB 严格对齐`() {
        assertEquals("周一", TimetableStrings.formatWeekday(1))
        assertEquals("周二", TimetableStrings.formatWeekday(2))
        assertEquals("周三", TimetableStrings.formatWeekday(3))
        assertEquals("周四", TimetableStrings.formatWeekday(4))
        assertEquals("周五", TimetableStrings.formatWeekday(5))
        assertEquals("周六", TimetableStrings.formatWeekday(6))
        assertEquals("周日", TimetableStrings.formatWeekday(7))
        assertEquals("", TimetableStrings.formatWeekday(0))
        assertEquals("", TimetableStrings.formatWeekday(8))
    }

    @Test
    fun `格式化纯函数占位符插值按预期生成文案`() {
        assertEquals("当前周：第 3 周", TimetableStrings.formatCurrentWeek(3))
        assertEquals("4 门课程 · 第 5 周", TimetableStrings.formatCoursesAndWeekSummary(4, 5))
        assertEquals("第 2 节", TimetableStrings.formatSection(2))
        assertEquals("冲突 3 节", TimetableStrings.formatConflictCount(3))
        assertEquals("第 8 周", TimetableStrings.formatWeekLabel(8))
        assertEquals("已切换到 大二下", TimetableStrings.formatSwitchedToProfile("大二下"))
        assertEquals("已创建课表：大三上", TimetableStrings.formatCreatedProfile("大三上"))
        assertEquals("已重命名为 大四", TimetableStrings.formatRenamedProfile("大四"))
        assertEquals("已删除课表：测试课表", TimetableStrings.formatDeletedProfile("测试课表"))
        assertEquals("已清空课表：旧课表", TimetableStrings.formatClearedProfile("旧课表"))
    }

    @Test
    fun `周视图新增格式化函数按 ARB 模板插值`() {
        // 星期栏左端：ARB `currentWeekCompact` = "{week} 周"（半角空格），
        // Dart 调用点 timetable_weekday_header.dart:181。
        assertEquals("8 周", TimetableStrings.formatCurrentWeekCompact(8))
        assertEquals("1 周", TimetableStrings.formatCurrentWeekCompact(1))

        // 课卡时间行：ARB `classStartsAtLabel` / `classEndsAtLabel`（course_card.dart）。
        assertEquals("08:00 开始", TimetableStrings.formatClassStartsAt("08:00"))
        assertEquals("09:35 结束", TimetableStrings.formatClassEndsAt("09:35"))
    }

    /**
     * 周次文案真源：`lib/l10n/course_week_localizations.dart:31-43`（courseWeekDescription）
     * 与 `:4-29`（formatCourseWeekList）。
     *
     * - 有 customWeeks ⇒ 走 `courseWeekListLabel`（「第 {weeks} 周」），压缩后按 `、` 连接；
     * - 否则走 `courseWeekRangeLabel`（「第 {startWeek}～{endWeek} 周{mode}」），
     *   单/双周后缀是**带前导空格**的「 单周」/「 双周」。
     */
    @Test
    fun `课程周次文案按单双周与自定义周次生成`() {
        assertEquals(
            "第 1～16 周",
            TimetableStrings.formatCourseWeekDescription(courseForWeeks(startWeek = 1, endWeek = 16)),
        )
        assertEquals(
            "单周后缀带前导空格（ARB mode 段原样拼在「周」后面）",
            "第 1～16 周 单周",
            TimetableStrings.formatCourseWeekDescription(
                courseForWeeks(startWeek = 1, endWeek = 16, isOddWeek = true),
            ),
        )
        assertEquals(
            "双周后缀带前导空格",
            "第 2～16 周 双周",
            TimetableStrings.formatCourseWeekDescription(
                courseForWeeks(startWeek = 2, endWeek = 16, isEvenWeek = true),
            ),
        )
        assertEquals(
            "customWeeks 优先于 start/end 与单双周",
            "第 1、3、5 周",
            TimetableStrings.formatCourseWeekDescription(
                courseForWeeks(customWeeks = listOf(1, 3, 5), isOddWeek = true),
            ),
        )
        assertEquals(
            "customWeeks 连续段压成区间并用顿号连接",
            "第 1-3、7-8 周",
            TimetableStrings.formatCourseWeekDescription(
                courseForWeeks(startWeek = 1, endWeek = 8, customWeeks = listOf(1, 2, 3, 7, 8)),
            ),
        )
    }

    @Test
    fun `周次列表压缩成区间并用顿号连接`() {
        assertEquals("", TimetableStrings.formatWeekList(emptyList()))
        assertEquals("3", TimetableStrings.formatWeekList(listOf(3)))
        assertEquals("1-3", TimetableStrings.formatWeekList(listOf(1, 2, 3)))
        assertEquals("1、3、5", TimetableStrings.formatWeekList(listOf(1, 3, 5)))
        assertEquals("1-3、7-8", TimetableStrings.formatWeekList(listOf(1, 2, 3, 7, 8)))
        assertEquals("1、3、5-8、12", TimetableStrings.formatWeekList(listOf(1, 3, 5, 6, 7, 8, 12)))
    }

    /** 只为周次文案准备的课程夹具：其余字段不影响 `courseWeekDescription`。 */
    private fun courseForWeeks(
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
    ): Course = Course(
        id = "week-fixture",
        name = "周次夹具",
        teacher = "任课教师",
        location = "教学楼 101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:35",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
    )

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
