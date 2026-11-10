package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.app.AppLocaleRuntime
import com.mutx163.qingyu.transfer.IcsExportEventKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * ICS 导出页模型层单元测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/ics_export_screen.dart` + `lib/services/ics_export_service.dart`），
 * 不从 Kotlin 实现里抄：
 * - `_defaultRangeFor`（ics_export_screen.dart:318-330）：学期起始日的周一 → + 周数*7-1；否则今天 → +30。
 * - `_handleFromDateChanged` / `_handleToDateChanged`（420-435）：起止互相顶。
 * - `_profileItems`（296-316）：重名课表追加序号，且序号冲突时继续往后找空位。
 * - `_buildSummary`（353-404）：标题 = 课表名，随后「标签: 值」三行 + 可选两行。
 * - `_export` / `_syncToSystemCalendar` 的前置校验（442-466、588-612）。
 * - `buildFileName`（ics_export_service.dart:272-281、651-655、726-740）。
 */
class IcsExportModelTest {

    private val spring = IcsExportProfile(
        id = "p1",
        name = "2026 春",
        semesterStartDate = LocalDate.of(2026, 3, 4),
        semesterWeekCount = 18,
    )

    private fun options(
        from: LocalDate = LocalDate.of(2026, 3, 2),
        to: LocalDate = LocalDate.of(2026, 7, 5),
        kinds: Set<IcsExportEventKind> = IcsExportLogic.defaultEventKinds,
        skipHolidayCourses: Boolean = true,
    ) = IcsExportOptions(
        fromDate = from,
        toDate = to,
        eventKinds = kinds,
        skipHolidayCourses = skipHolidayCourses,
    )

    // ── 默认区间 ──

    @Test
    fun `默认区间从学期起始日的周一算到周数末周的周日`() {
        // 2026-03-04 是周三，归一到 2026-03-02（周一）；18 周共 125 天 → 2026-07-05
        val range = IcsExportLogic.defaultRangeFor(spring, LocalDate.of(2026, 10, 27))
        assertEquals(LocalDate.of(2026, 3, 2), range.from)
        assertEquals(LocalDate.of(2026, 7, 5), range.to)
    }

    @Test
    fun `周数小于一时按一周计算`() {
        val range = IcsExportLogic.defaultRangeFor(
            spring.copy(semesterWeekCount = 0),
            LocalDate.of(2026, 10, 27),
        )
        assertEquals(LocalDate.of(2026, 3, 2), range.from)
        assertEquals(LocalDate.of(2026, 3, 8), range.to)
    }

    @Test
    fun `没设学期起始日期时退回今天加三十天`() {
        val range = IcsExportLogic.defaultRangeFor(
            spring.copy(semesterStartDate = null),
            LocalDate.of(2026, 10, 27),
        )
        assertEquals(LocalDate.of(2026, 10, 27), range.from)
        assertEquals(LocalDate.of(2026, 11, 26), range.to)
    }

    @Test
    fun `没有课表时默认区间同样按今天加三十天`() {
        val range = IcsExportLogic.defaultRangeFor(null, LocalDate.of(2026, 1, 1))
        assertEquals(LocalDate.of(2026, 1, 1), range.from)
        assertEquals(LocalDate.of(2026, 1, 31), range.to)
    }

    @Test
    fun `周一归一对周日也有效`() {
        // 2026-03-08 是周日 → 该周周一 2026-03-02
        assertEquals(LocalDate.of(2026, 3, 2), IcsExportLogic.mondayOf(LocalDate.of(2026, 3, 8)))
        assertEquals(LocalDate.of(2026, 3, 2), IcsExportLogic.mondayOf(LocalDate.of(2026, 3, 2)))
    }

    // ── 起止日期互相顶 ──

    @Test
    fun `开始日期推后到结束日期之后会把结束日期一起顶过去`() {
        val next = IcsExportLogic.onFromDateChanged(
            options(from = LocalDate.of(2026, 3, 2), to = LocalDate.of(2026, 3, 20)),
            LocalDate.of(2026, 4, 1),
        )
        assertEquals(LocalDate.of(2026, 4, 1), next.fromDate)
        assertEquals(LocalDate.of(2026, 4, 1), next.toDate)
    }

    @Test
    fun `开始日期提前时结束日期保持不变`() {
        val next = IcsExportLogic.onFromDateChanged(
            options(from = LocalDate.of(2026, 3, 2), to = LocalDate.of(2026, 3, 20)),
            LocalDate.of(2026, 2, 1),
        )
        assertEquals(LocalDate.of(2026, 2, 1), next.fromDate)
        assertEquals(LocalDate.of(2026, 3, 20), next.toDate)
    }

    @Test
    fun `结束日期早于开始日期时被顶回开始日期`() {
        val next = IcsExportLogic.onToDateChanged(
            options(from = LocalDate.of(2026, 3, 2), to = LocalDate.of(2026, 3, 20)),
            LocalDate.of(2026, 1, 5),
        )
        assertEquals(LocalDate.of(2026, 3, 2), next.fromDate)
        assertEquals(LocalDate.of(2026, 3, 2), next.toDate)
    }

    @Test
    fun `结束日期晚于开始日期时原样接受`() {
        val next = IcsExportLogic.onToDateChanged(
            options(from = LocalDate.of(2026, 3, 2), to = LocalDate.of(2026, 3, 20)),
            LocalDate.of(2026, 5, 5),
        )
        assertEquals(LocalDate.of(2026, 5, 5), next.toDate)
    }

    // ── 节假日开关可见性 ──

    @Test
    fun `跳过节假日课程的开关只在勾了课程时出现`() {
        assertTrue(
            IcsExportLogic.skipHolidayCoursesVisible(setOf(IcsExportEventKind.COURSE)),
        )
        assertTrue(
            IcsExportLogic.skipHolidayCoursesVisible(IcsExportLogic.defaultEventKinds),
        )
        assertFalse(
            IcsExportLogic.skipHolidayCoursesVisible(
                setOf(IcsExportEventKind.EXAM, IcsExportEventKind.SCHEDULE_ITEM),
            ),
        )
        assertFalse(IcsExportLogic.skipHolidayCoursesVisible(emptySet()))
    }

    // ── 课表下拉项命名 ──

    @Test
    fun `重名课表追加序号`() {
        val items = IcsExportLogic.profileItems(
            listOf(
                IcsExportProfile("a", "课表甲"),
                IcsExportProfile("b", "课表甲"),
                IcsExportProfile("c", "课表甲"),
            ),
            blankFallbackLabel = "课表",
        )
        assertEquals(listOf("课表甲", "课表甲 (2)", "课表甲 (3)"), items.keys.toList())
        assertEquals(listOf("a", "b", "c"), items.values.toList())
    }

    @Test
    fun `空名课表用占位标题并在重复时追加序号`() {
        val items = IcsExportLogic.profileItems(
            listOf(
                IcsExportProfile("x", "   "),
                IcsExportProfile("y", ""),
            ),
            blankFallbackLabel = "课表",
        )
        assertEquals(listOf("课表", "课表 (2)"), items.keys.toList())
    }

    @Test
    fun `课表名自带序号时冲突会继续往后找空位`() {
        // Dart while 循环：第二个 "A" 先试 "A (2)"（已被第一个占用），再试 "A (3)"
        val items = IcsExportLogic.profileItems(
            listOf(
                IcsExportProfile("p1", "A (2)"),
                IcsExportProfile("p2", "A"),
                IcsExportProfile("p3", "A"),
            ),
            blankFallbackLabel = "课表",
        )
        assertEquals(listOf("A (2)", "A", "A (3)"), items.keys.toList())
        assertEquals(listOf("p1", "p2", "p3"), items.values.toList())
    }

    @Test
    fun `课表名两端空白会被裁掉`() {
        val items = IcsExportLogic.profileItems(
            listOf(IcsExportProfile("p1", "  2026 春  ")),
            blankFallbackLabel = "课表",
        )
        assertEquals(listOf("2026 春"), items.keys.toList())
    }

    // ── 导出前置校验 ──

    @Test
    fun `没有课表时导出被拦下`() {
        assertEquals(IcsExportBlocker.NO_PROFILES, IcsExportLogic.validate(null, options()))
    }

    @Test
    fun `一种内容都没勾时导出被拦下`() {
        assertEquals(
            IcsExportBlocker.NO_SELECTION,
            IcsExportLogic.validate(spring, options(kinds = emptySet())),
        )
    }

    @Test
    fun `勾了课程但没设学期开始日期时导出被拦下`() {
        assertEquals(
            IcsExportBlocker.SEMESTER_START_REQUIRED,
            IcsExportLogic.validate(
                spring.copy(semesterStartDate = null),
                options(kinds = setOf(IcsExportEventKind.COURSE)),
            ),
        )
    }

    @Test
    fun `没勾课程时缺学期开始日期不算问题`() {
        assertNull(
            IcsExportLogic.validate(
                spring.copy(semesterStartDate = null),
                options(kinds = setOf(IcsExportEventKind.EXAM, IcsExportEventKind.SCHEDULE_ITEM)),
            ),
        )
    }

    @Test
    fun `课表与内容都在时校验通过`() {
        assertNull(IcsExportLogic.validate(spring, options()))
    }

    // ── 摘要 ──

    @Test
    fun `摘要标题是课表名且三行标签取值`() {
        val summary = IcsExportLogic.summary(
            spring,
            options(
                from = LocalDate.of(2026, 3, 2),
                to = LocalDate.of(2026, 7, 5),
                kinds = setOf(IcsExportEventKind.COURSE, IcsExportEventKind.EXAM),
            ),
        )
        assertEquals("2026 春", summary.title)
        assertEquals(
            listOf(
                "开始日期: 2026年3月2日",
                "结束日期: 2026年7月5日",
                "日历内容: 课程, 考试",
                "已跳过节假日课程",
            ),
            summary.lines.map { it.text },
        )
        assertTrue(summary.lines.none { it.isError })
    }

    @Test
    fun `没勾任何内容时内容行显示短横且不显示跳过节假日`() {
        val summary = IcsExportLogic.summary(spring, options(kinds = emptySet()))
        assertEquals(
            listOf(
                "开始日期: 2026年3月2日",
                "结束日期: 2026年7月5日",
                "日历内容: -",
            ),
            summary.lines.map { it.text },
        )
    }

    @Test
    fun `关掉跳过节假日开关后摘要不再出现那一行`() {
        val summary = IcsExportLogic.summary(
            spring,
            options(kinds = setOf(IcsExportEventKind.COURSE), skipHolidayCourses = false),
        )
        assertFalse(summary.lines.any { it.text == "已跳过节假日课程" })
    }

    @Test
    fun `没课表时摘要标题退回占位文案`() {
        val summary = IcsExportLogic.summary(null, options())
        assertEquals("暂无可导出的课表", summary.title)
    }

    @Test
    fun `勾了课程但缺学期开始日期时摘要补一行错误提示`() {
        val summary = IcsExportLogic.summary(
            spring.copy(semesterStartDate = null),
            options(kinds = setOf(IcsExportEventKind.COURSE)),
        )
        val last = summary.lines.last()
        assertEquals("导出课程前，请先设置学期开始日期", last.text)
        assertTrue(last.isError)
    }

    @Test
    fun `三种内容按 课程 考试 日程 的顺序拼接`() {
        assertEquals(
            "课程, 考试, 日程",
            IcsExportLogic.selectedTypesLabel(IcsExportLogic.defaultEventKinds),
        )
        assertEquals(
            "课程, 日程",
            IcsExportLogic.selectedTypesLabel(
                setOf(IcsExportEventKind.SCHEDULE_ITEM, IcsExportEventKind.COURSE),
            ),
        )
    }

    @Test
    fun `日期按界面语言渲染，六种语言与发布版 yMMMd 一致`() {
        val date = LocalDate.of(2026, 9, 1)
        // 发布版 Dart `_formatDate` = DateFormat.yMMMd(localeName)（ics_export_screen.dart:835-841）。
        assertEquals("2026年9月1日", IcsExportLogic.formatDate(date, language = "zh"))
        assertEquals("2026年9月1日", IcsExportLogic.formatDate(date, language = "zh_HK"))
        assertEquals("2026年9月1日", IcsExportLogic.formatDate(date, language = "zh_TW"))
        assertEquals("2026年9月1日", IcsExportLogic.formatDate(date, language = "ja"))
        assertEquals("2026년 9월 1일", IcsExportLogic.formatDate(date, language = "ko"))
        assertEquals("Sep 1, 2026", IcsExportLogic.formatDate(date, language = "en"))
        // 回归守护：3.0 曾把「年月日」写死，中英必须真的不同。
        assertNotEquals(
            IcsExportLogic.formatDate(date, language = "zh"),
            IcsExportLogic.formatDate(date, language = "en"),
        )
    }

    @Test
    fun `语言未初始化或不认识时回落简体中文`() {
        // L0 / 纯 JVM 没走宿主 ⇒ AppLocaleRuntime 是 UNSET，默认参数按中文出字
        // （与 ArbText.text 的兜底同口径）。先复位，避免同 JVM 里别的用例留下的语言标签串味。
        AppLocaleRuntime.resetForTest()
        try {
            val date = LocalDate.of(2026, 3, 2)
            assertEquals("2026年3月2日", IcsExportLogic.formatDate(date))
            assertEquals("2026年3月2日", IcsExportLogic.formatDate(date, language = null))
            // 不认识的语言标签不猜格式，回落中文（中文四种标签本来就同一条 pattern）。
            assertEquals("2026年3月2日", IcsExportLogic.formatDate(date, language = "fr"))
            assertEquals("2026年12月31日", IcsExportLogic.formatDate(LocalDate.of(2026, 12, 31)))
        } finally {
            AppLocaleRuntime.resetForTest()
        }
    }

    // ── 文件名 ──

    @Test
    fun `文件名是课表名加起止日期`() {
        assertEquals(
            "2026_春-20260302-20260705.ics",
            IcsExportLogic.buildFileName(
                "2026 春",
                LocalDate.of(2026, 3, 2),
                LocalDate.of(2026, 7, 5),
            ),
        )
    }

    @Test
    fun `文件名把非法字符换成下划线并压平连续下划线`() {
        assertEquals(
            "a_b_c_d-20260302-20260705.ics",
            IcsExportLogic.buildFileName(
                " a/b:c  d ",
                LocalDate.of(2026, 3, 2),
                LocalDate.of(2026, 7, 5),
            ),
        )
    }

    @Test
    fun `课表名为空时文件名退回 timetable`() {
        assertEquals(
            "timetable-20260302-20260705.ics",
            IcsExportLogic.buildFileName(
                "  ",
                LocalDate.of(2026, 3, 2),
                LocalDate.of(2026, 7, 5),
            ),
        )
    }

    private fun buildName(profileName: String): String =
        IcsExportLogic.buildFileName(
            profileName,
            LocalDate.of(2026, 3, 2),
            LocalDate.of(2026, 7, 5),
        )

    @Test
    fun `文件名课表名按 codePoint 截到 80`() {
        val suffix = "-20260302-20260705.ics"
        assertEquals("a".repeat(80) + suffix, buildName("a".repeat(80)))
        assertEquals("a".repeat(80) + suffix, buildName("a".repeat(81)))
    }

    @Test
    fun `含 emoji 的课表名按 codePoint 截断且不留孤立代理项`() {
        val suffix = "-20260302-20260705.ics"
        val eighty = "😀".repeat(80)
        assertEquals(eighty + suffix, buildName(eighty))
        val truncated = buildName("😀".repeat(81)).removeSuffix(suffix)
        assertEquals(eighty, truncated)
        assertEquals(80, Character.codePointCount(truncated, 0, truncated.length))
        assertNoLoneSurrogate(truncated)
    }

    @Test
    fun `混合 ASCII 与 emoji 时截断落在字符边界`() {
        val suffix = "-20260302-20260705.ics"
        val eighty = "a" + "😀".repeat(79)
        assertEquals(eighty + suffix, buildName(eighty))
        // 81 个 codePoint：多出来的那个 emoji 必须整颗丢掉，不能只留半个代理对。
        assertEquals(eighty + suffix, buildName("a" + "😀".repeat(80)))
    }

    private fun assertNoLoneSurrogate(text: String) {
        var index = 0
        while (index < text.length) {
            val ch = text[index]
            if (Character.isHighSurrogate(ch)) {
                assertTrue(
                    "index=$index 的高位代理项没有配对",
                    index + 1 < text.length && Character.isLowSurrogate(text[index + 1]),
                )
                index += 2
            } else {
                assertFalse("index=$index 是孤立低位代理项", Character.isLowSurrogate(ch))
                index += 1
            }
        }
    }

    @Test
    fun `文件名日期补足位数`() {
        assertEquals(
            "春-20260101-20260105.ics",
            IcsExportLogic.buildFileName(
                "春",
                LocalDate.of(2026, 1, 1),
                LocalDate.of(2026, 1, 5),
            ),
        )
    }

    // ── 同步到系统日历的文案 ──

    @Test
    fun `同步日历名带产品前缀`() {
        assertEquals("轻屿课表·2026 春", IcsExportLogic.syncCalendarName("2026 春"))
    }

    @Test
    fun `同步成功提示在有跳过课程时追加一行`() {
        assertEquals(
            "已同步 12 个日程到系统日历",
            IcsExportLogic.syncSuccessMessage(12, 0),
        )
        assertEquals(
            "已同步 12 个日程到系统日历\n已跳过假期中的 3 个课程",
            IcsExportLogic.syncSuccessMessage(12, 3),
        )
    }
}
