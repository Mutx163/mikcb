package com.mutx163.qingyu.pages.conflict

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 冲突详情页模型层测试。
 *
 * 期望值来源（独立于实现，不抄实现）：
 * - 配对/去重/排序：逐条对照 `lib/screens/course_conflict_screen.dart:65-102`
 *   的行号语义，以及 `lib/domain/course_domain.dart:52-67` 的双向索引形态；
 * - 行文案：对照 `course_conflict_screen.dart:143-152` 的拼装方式（含
 *   「结束周用裸数字」这条现状怪癖）；
 * - 文案：直读 `lib/l10n/app_zh.arb` 逐字对拍（不手抄）；
 * - 边界（停课周/单双周/自定义周/未知星期/同 id）：人推得出。
 */
class CourseConflictModelTest {

    private fun course(
        id: String,
        name: String = "课程$id",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
    ) = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
    )

    // ---------- 空态 ----------

    @Test
    fun `没有冲突时页面为空态`() {
        val view = buildCourseConflictView(
            listOf(course("a", dayOfWeek = 1), course("b", dayOfWeek = 2)),
        )
        assertTrue(view.isEmpty)
        assertTrue(view.pairs.isEmpty())
        assertEquals(CourseConflictStrings.title, view.title)
        assertEquals(CourseConflictStrings.emptyText, view.emptyText)
    }

    @Test
    fun `空课程表也是空态`() {
        assertTrue(buildCourseConflictView(emptyList()).isEmpty)
    }

    // ---------- 配对与去重 ----------

    @Test
    fun `同一天时段重叠算一对且left是id较小的一方`() {
        val view = buildCourseConflictView(
            listOf(course("a", name = "高数"), course("b", name = "英语")),
        )
        assertEquals(1, view.pairs.size)
        val pair = view.pairs[0]
        assertEquals(1, pair.index)
        assertEquals("冲突组合 1", pair.sectionLabel)
        // Dart：left/right 按 id 字典序，不按节次先后。
        assertEquals("a", pair.rows[0].courseId)
        assertEquals("b", pair.rows[1].courseId)
        assertEquals(listOf("高数", "英语"), pair.rows.map { it.title })
        assertEquals("与 英语 冲突", pair.rows[0].conflictLine)
        assertEquals("与 高数 冲突", pair.rows[1].conflictLine)
    }

    @Test
    fun `冲突索引双向但页面每对只出现一次`() {
        // 三门互冲 = 3 对（不是 6 对）；插入序来自 buildConflictMap 的 i<j 双循环。
        val view = buildCourseConflictView(
            listOf(course("a"), course("b"), course("c")),
        )
        assertEquals(
            listOf("a|b", "a|c", "b|c"),
            view.pairs.map { "${it.rows[0].courseId}|${it.rows[1].courseId}" },
        )
    }

    @Test
    fun `同一id的多条课次永不互相冲突`() {
        val view = buildCourseConflictView(
            listOf(course("a"), course("a", startSection = 2, endSection = 3)),
        )
        assertTrue(view.isEmpty)
    }

    @Test
    fun `不在同一行的两门课不冲突`() {
        val view = buildCourseConflictView(
            listOf(course("a", dayOfWeek = 3), course("b", dayOfWeek = 4)),
        )
        assertTrue(view.isEmpty)
    }

    @Test
    fun `节次不重叠不冲突`() {
        val view = buildCourseConflictView(
            listOf(
                course("a", startSection = 1, endSection = 2),
                course("b", startSection = 3, endSection = 4),
            ),
        )
        assertTrue(view.isEmpty)
    }

    // ---------- 周次语义 ----------

    @Test
    fun `停课周覆盖全部候选周时不算冲突`() {
        val view = buildCourseConflictView(
            listOf(course("a"), course("b", suspendedWeeks = (1..16).toList())),
        )
        assertTrue(view.isEmpty)
    }

    @Test
    fun `单周与双周同段不冲突`() {
        val view = buildCourseConflictView(
            listOf(
                course("a", isOddWeek = true),
                course("b", isEvenWeek = true),
            ),
        )
        assertTrue(view.isEmpty)
    }

    @Test
    fun `自定义周不相交不冲突`() {
        val view = buildCourseConflictView(
            listOf(
                course("a", customWeeks = listOf(1, 2)),
                course("b", customWeeks = listOf(3, 4)),
            ),
        )
        assertTrue(view.isEmpty)
    }

    @Test
    fun `自定义周相交仍算冲突`() {
        val view = buildCourseConflictView(
            listOf(
                course("a", customWeeks = listOf(1, 2)),
                course("b", customWeeks = listOf(2, 3)),
            ),
        )
        assertEquals(1, view.pairs.size)
    }

    // ---------- 排序 ----------

    @Test
    fun `按left的起始节升序排列`() {
        val view = buildCourseConflictView(
            listOf(
                course("a", startSection = 5, endSection = 6),
                course("b", startSection = 5, endSection = 6),
                course("c", startSection = 2, endSection = 3),
                course("d", startSection = 2, endSection = 3),
            ),
        )
        assertEquals(
            listOf("c|d", "a|b"),
            view.pairs.map { "${it.rows[0].courseId}|${it.rows[1].courseId}" },
        )
        // 排序后的分组序号从 1 起，跟着新顺序走。
        assertEquals(listOf(1, 2), view.pairs.map { it.index })
        assertEquals(listOf("冲突组合 1", "冲突组合 2"), view.pairs.map { it.sectionLabel })
    }

    // ---------- 行文案 ----------

    @Test
    fun `行文案按Dart口径拼周一第几节与周次`() {
        val view = buildCourseConflictView(
            listOf(course("a"), course("b", endSection = 3)),
        )
        val row = view.pairs[0].rows[0]
        // 1-16 周：起止「第 N 周」字符串不同 → 尾部是裸数字 16（现状口径，照抄）。
        assertEquals("周 一 1～2 节 · 第 1 周-16", row.scheduleLine)
    }

    @Test
    fun `起止周相同时只写一个第N周`() {
        val view = buildCourseConflictView(
            listOf(course("a", startWeek = 5, endWeek = 5), course("b")),
        )
        assertEquals("周 一 1～2 节 · 第 5 周", view.pairs[0].rows[0].scheduleLine)
    }

    @Test
    fun `未知星期原样输出数字`() {
        val view = buildCourseConflictView(
            listOf(course("a", dayOfWeek = 8), course("b", dayOfWeek = 8)),
        )
        assertEquals(1, view.pairs.size)
        assertEquals("周 8 1～2 节 · 第 1 周-16", view.pairs[0].rows[0].scheduleLine)
    }

    @Test
    fun `星期短名七个取值`() {
        assertEquals("一", CourseConflictStrings.weekdayShort(1))
        assertEquals("二", CourseConflictStrings.weekdayShort(2))
        assertEquals("三", CourseConflictStrings.weekdayShort(3))
        assertEquals("四", CourseConflictStrings.weekdayShort(4))
        assertEquals("五", CourseConflictStrings.weekdayShort(5))
        assertEquals("六", CourseConflictStrings.weekdayShort(6))
        assertEquals("日", CourseConflictStrings.weekdayShort(7))
    }

    @Test
    fun `周次文案函数本身`() {
        assertEquals("第 3 周", CourseConflictStrings.weekLabel(3))
    }

    @Test
    fun `分组标题序号`() {
        assertEquals("冲突组合 2", CourseConflictStrings.pairLabel(2))
    }

    @Test
    fun `非空视图不是空态`() {
        val view = buildCourseConflictView(listOf(course("a"), course("b")))
        assertFalse(view.isEmpty)
    }

    // ---------- ARB 逐字对拍 ----------

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../lib/l10n/app_zh.arb"),
            File("../lib/l10n/app_zh.arb"),
            File("lib/l10n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 lib/l10n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    @Test
    fun `普通文案与ARB逐字一致`() {
        val pairs = listOf(
            "courseConflictDetailTitle" to CourseConflictStrings.title,
            "courseConflictEmpty" to CourseConflictStrings.emptyText,
            "courseConflictPairTitle" to CourseConflictStrings.pairTitle,
            "weekdayShortMonday" to CourseConflictStrings.weekdayShortMonday,
            "weekdayShortTuesday" to CourseConflictStrings.weekdayShortTuesday,
            "weekdayShortWednesday" to CourseConflictStrings.weekdayShortWednesday,
            "weekdayShortThursday" to CourseConflictStrings.weekdayShortThursday,
            "weekdayShortFriday" to CourseConflictStrings.weekdayShortFriday,
            "weekdayShortSaturday" to CourseConflictStrings.weekdayShortSaturday,
            "weekdayShortSunday" to CourseConflictStrings.weekdayShortSunday,
        )
        for ((key, value) in pairs) {
            assertEquals("ARB 键 $key 与模型不一致", arbString(key), value)
        }
    }

    @Test
    fun `带参文案与ARB占位符一致`() {
        assertEquals(
            arbString("courseConflictWithCourse").replace("{name}", "英语"),
            CourseConflictStrings.withCourse("英语"),
        )
        assertEquals(
            arbString("weekLabel").replace("{week}", "3"),
            CourseConflictStrings.weekLabel(3),
        )
        assertEquals(
            arbString("weekdaySectionSummary")
                .replace("{weekday}", "一")
                .replace("{startSection}", "1")
                .replace("{endSection}", "2"),
            CourseConflictStrings.weekdaySectionSummary("一", 1, 2),
        )
    }
}
