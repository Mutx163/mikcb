package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.weather.CourseWeatherSummary
import com.mutx163.qingyu.weather.WeatherCategory
import java.time.LocalDate
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 课程操作弹层**模型层**单测（L0，真 JVM）。
 *
 * 钉的是 Dart `lib/widgets/course_action_sheet.dart` 的每条可观察口径：
 * 哪一行出现 / 标题写什么 / 副题写什么 / 有没有箭头 / 面板标题与条目顺序 / 动作区开关。
 * 期望值全部按 Dart 的判据手推，**不从实现里抄**。
 */
class CourseActionSheetModelTest {

    // ───────────────────────── 夹具 ─────────────────────────

    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "张老师",
        location: String = "A101",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:40",
        nature: CourseNature = CourseNature.REQUIRED,
        description: String? = null,
        note: String? = null,
        shortName: String? = null,
        color: String = "#2196F3",
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        sessionNotes: Map<Int, com.mutx163.qingyu.core.CourseSessionNote>? = null,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
        suspendedWeeks = suspendedWeeks,
        courseNature = nature,
        description = description,
        note = note,
        sessionNotes = sessionNotes,
    )

    private fun task(
        id: String = "t1",
        title: String = "第三章习题",
        courseId: String? = "c1",
        sourceWeek: Long? = null,
        isCompleted: Boolean = false,
    ): CourseTask = CourseTask(
        id = id,
        title = title,
        courseId = courseId,
        sourceWeek = sourceWeek,
        isCompleted = isCompleted,
        createdAt = LocalDateTime.of(2026, 9, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 9, 1, 8, 0),
    )

    private fun buildOne(
        course: Course,
        week: Int = 1,
        tasks: List<CourseTask> = emptyList(),
        weatherPrefs: CourseSheetWeatherPrefs = CourseSheetWeatherPrefs(),
        date: LocalDate? = null,
        weather: CourseSheetWeatherInfo = CourseSheetWeatherInfo(),
        partner: Boolean = false,
        conflict: Boolean = false,
        coupleKind: CourseCoupleKind? = null,
        now: LocalDateTime = LocalDateTime.of(2026, 11, 2, 10, 0),
        sectionTimes: List<SectionTime> = emptyList(),
    ): CourseActionSection = CourseActionSheetModel.buildSection(
        item = CourseActionPreviewItem(
            course = course,
            isPartnerCourse = partner,
            isConflict = conflict,
            coupleKind = coupleKind,
        ),
        week = week,
        tasks = tasks,
        weatherPrefs = weatherPrefs,
        dateOf = { date },
        weatherOf = { weather },
        now = now,
        sectionTimes = sectionTimes,
    )

    private fun kinds(section: CourseActionSection): List<CourseActionRowKind> =
        section.rows.map { it.kind }

    private fun row(section: CourseActionSection, kind: CourseActionRowKind): CourseActionDetailRow {
        val found = section.rows.firstOrNull { it.kind == kind }
        assertNotNull("期望出现 $kind 行", found)
        return found!!
    }

    // ───────────────────────── 头部块 ─────────────────────────

    @Test
    fun `必修与选修按课程性质显示`() {
        assertEquals(
            "必修",
            buildOne(course(nature = CourseNature.REQUIRED)).header.natureText,
        )
        assertEquals(
            "选修",
            buildOne(course(nature = CourseNature.ELECTIVE)).header.natureText,
        )
    }

    @Test
    fun `对方课不显示性质但显示只读语义`() {
        val section = buildOne(course(), partner = true)
        assertNull("对方课不该出现必修/选修", section.header.natureText)
        assertTrue(section.isReadOnly)
        assertFalse("只读课整块动作区不渲染", section.showActions)
        assertEquals(CourseActionIcon.PARTNER_PERSON, section.header.icon)
    }

    @Test
    fun `冲突课头部有冲突红字且图标回落到课程本体`() {
        val section = buildOne(course(), conflict = true)
        assertEquals("冲突", section.header.conflictText)
        assertEquals(CourseActionIcon.COURSE, section.header.icon)
    }

    @Test
    fun `情侣一起上课时头部用爱心图标与一起上课角标`() {
        val section = buildOne(course(), coupleKind = CourseCoupleKind.TOGETHER)
        assertEquals(CourseActionIcon.COUPLE_HEART, section.header.icon)
        assertEquals("一起上课", section.header.coupleText)
    }

    @Test
    fun `头部第二行是 第N周 加课程简介`() {
        val section = buildOne(course(description = "极限与连续"))
        assertEquals("第 1 周 · 极限与连续", section.header.detailLine)
    }

    @Test
    fun `课程简介缺席时头部第二行回落周次描述_并优先 legacy note`() {
        assertEquals("第 1 周 · 第 1～16 周", buildOne(course()).header.detailLine)
        assertEquals(
            "第 1 周 · 旧备注",
            buildOne(course(note = "旧备注")).header.detailLine,
        )
        // description 优先于 legacy note（Dart `:634-638`）
        assertEquals(
            "第 1 周 · 新简介",
            buildOne(course(description = "新简介", note = "旧备注")).header.detailLine,
        )
    }

    // ───────────────────────── 详情行 ─────────────────────────

    @Test
    fun `行序固定为 时间 教师 地点 备注 作业 说明`() {
        assertEquals(
            listOf(
                CourseActionRowKind.TIME,
                CourseActionRowKind.TEACHER,
                CourseActionRowKind.LOCATION,
                CourseActionRowKind.NOTE,
                CourseActionRowKind.TASK,
                CourseActionRowKind.NOTICE,
            ),
            kinds(buildOne(course())),
        )
    }

    @Test
    fun `只读课没有作业行并且说明句换成只读文案`() {
        val section = buildOne(course(), partner = true)
        assertEquals(
            listOf(
                CourseActionRowKind.TIME,
                CourseActionRowKind.TEACHER,
                CourseActionRowKind.LOCATION,
                CourseActionRowKind.NOTE,
                CourseActionRowKind.NOTICE,
            ),
            kinds(section),
        )
        assertEquals(
            "这是对方课表中的课程，仅供查看，无法编辑或调课",
            row(section, CourseActionRowKind.NOTICE).title,
        )
        assertNull(
            "只读说明句不含周次数字，不该有高亮 token",
            row(section, CourseActionRowKind.NOTICE).emphasizedToken,
        )
    }

    @Test
    fun `闹钟行在数据不齐或不该出现时不产生`() {
        // 没给日期（没设开学日）⇒ 入口不出现。
        assertFalse(kinds(buildOne(course())).contains(CourseActionRowKind.ALARM))
        // 过去的课不出现（2026-11-02 已过 2026-11-01 的课）。
        assertFalse(
            kinds(
                buildOne(
                    course(),
                    date = LocalDate.of(2026, 11, 1),
                    sectionTimes = listOf(SectionTime("08:00", "08:45")),
                ),
            ).contains(CourseActionRowKind.ALARM),
        )
    }

    @Test
    fun `未来的课出现闹钟行 带箭头可点`() {
        // 未来日期不看钟点（Dart `:1157` `isAfter(today) → true` 直接放行），
        // 即便节次表没给（解析不出钟点）也出现——子弹层里按钮再按 Dart 置灰。
        assertTrue(
            kinds(buildOne(course(), date = LocalDate.of(2026, 11, 9))).contains(
                CourseActionRowKind.ALARM,
            ),
        )
        val section = buildOne(
            course(),
            date = LocalDate.of(2026, 11, 9), // 未来的周一
            sectionTimes = listOf(SectionTime("08:00", "08:45")),
        )
        val alarm = row(section, CourseActionRowKind.ALARM)
        assertEquals("设这节课的闹钟", alarm.title)
        assertTrue(alarm.showsChevron)
        assertEquals(CourseActionRowTap.OPEN_ALARM, alarm.tap)
        assertEquals("08:00", section.alarmResolvedStart)
        // 当天已开课 ⇒ 消失（同一份作息表，把 now 拨到 08:00 之后）。
        assertFalse(
            kinds(
                buildOne(
                    course(),
                    date = LocalDate.of(2026, 11, 2),
                    sectionTimes = listOf(SectionTime("08:00", "08:45")),
                    now = LocalDateTime.of(2026, 11, 2, 10, 0),
                ),
            ).contains(CourseActionRowKind.ALARM),
        )
    }

    @Test
    fun `时间行标题是 周X 加节次区间_带箭头之外的时刻在 trailing`() {
        val time = row(buildOne(course(dayOfWeek = 3, startSection = 5, endSection = 6)), CourseActionRowKind.TIME)
        assertEquals("周三 · 第 5～6 节", time.title)
        assertEquals("08:00-09:40", time.trailingText)
        assertFalse("时间行不该有箭头", time.showsChevron)
        assertNull("时间行不可点", time.tap)
    }

    @Test
    fun `时间行副题_有日期时是 日期 第N周 单周`() {
        val section = buildOne(
            course(isOddWeek = true),
            week = 9,
            date = LocalDate.of(2026, 10, 29),
        )
        assertEquals("10月29日 第 9 周 单周", row(section, CourseActionRowKind.TIME).subtitle)
    }

    @Test
    fun `时间行副题_无日期时只剩 第N周 双周`() {
        val section = buildOne(course(isEvenWeek = true), week = 4, date = null)
        assertEquals("第 4 周 双周", row(section, CourseActionRowKind.TIME).subtitle)
    }

    @Test
    fun `时间行副题_普通周没有单双周字样`() {
        assertEquals(
            "第 2 周",
            CourseActionSheetModel.timeTileSubtitle(course(), 2, null),
        )
    }

    @Test
    fun `教师行_有简介时副题是周次描述`() {
        val section = buildOne(course(description = "简介", shortName = "高数"), week = 3)
        assertEquals("张老师", row(section, CourseActionRowKind.TEACHER).title)
        assertEquals("第 1～16 周", row(section, CourseActionRowKind.TEACHER).subtitle)
    }

    @Test
    fun `教师行_无简介但有简称时副题是简称`() {
        val section = buildOne(course(shortName = "高数"))
        assertEquals("简称：高数", row(section, CourseActionRowKind.TEACHER).subtitle)
    }

    @Test
    fun `教师行_既无简介也无简称时副题是周次描述`() {
        val section = buildOne(course())
        assertEquals("第 1～16 周", row(section, CourseActionRowKind.TEACHER).subtitle)
    }

    @Test
    fun `地点行_只有同时有简称与简介时副题才是简称`() {
        assertEquals(
            "简称：高数",
            row(buildOne(course(shortName = "高数", description = "简介")), CourseActionRowKind.LOCATION).subtitle,
        )
        assertEquals(
            "第 1～16 周",
            row(buildOne(course(shortName = "高数")), CourseActionRowKind.LOCATION).subtitle,
        )
    }

    @Test
    fun `教师与地点为空时用 ARB 兜底文案`() {
        val section = buildOne(course(teacher = "  ", location = ""))
        assertEquals("未知教师", row(section, CourseActionRowKind.TEACHER).title)
        assertEquals("未知地点", row(section, CourseActionRowKind.LOCATION).title)
    }

    // ───────────────────────── 备注行 ─────────────────────────

    @Test
    fun `备注行四态副题`() {
        assertEquals("记录携带物品或课堂提醒", CourseActionSheetModel.resolveNoteSubtitle(null, null))
        assertEquals("已有课程简介", CourseActionSheetModel.resolveNoteSubtitle("简介", null))
        assertEquals("已有本节课备注", CourseActionSheetModel.resolveNoteSubtitle(null, "本节"))
        assertEquals("课程简介与本节课均有备注", CourseActionSheetModel.resolveNoteSubtitle("简介", "本节"))
    }

    @Test
    fun `备注行标题按 本周备注 课程简介 备注 的优先级`() {
        assertEquals("本节备注", CourseActionSheetModel.resolveNoteTitle("简介", "本节备注"))
        assertEquals("课程简介", CourseActionSheetModel.resolveNoteTitle("课程简介", null))
        assertEquals("备注", CourseActionSheetModel.resolveNoteTitle(null, null))
    }

    @Test
    fun `备注行带箭头且点了开备注弹层`() {
        val note = row(buildOne(course()), CourseActionRowKind.NOTE)
        assertTrue(note.showsChevron)
        assertEquals(CourseActionRowTap.OPEN_NOTE, note.tap)
    }

    @Test
    fun `本周备注会影响备注行标题`() {
        val section = buildOne(
            course(
                sessionNotes = mapOf(
                    2 to com.mutx163.qingyu.core.CourseSessionNote(text = "带计算器"),
                ),
            ),
            week = 2,
        )
        assertEquals("带计算器", row(section, CourseActionRowKind.NOTE).title)
        assertEquals("已有本节课备注", row(section, CourseActionRowKind.NOTE).subtitle)
    }

    // ───────────────────────── 作业行 ─────────────────────────

    @Test
    fun `没有关联作业时作业行是 添加任务 加 任务清单`() {
        val taskRow = row(buildOne(course()), CourseActionRowKind.TASK)
        assertEquals("添加任务", taskRow.title)
        assertEquals("任务清单", taskRow.subtitle)
        assertTrue(taskRow.showsChevron)
        assertEquals(CourseActionRowTap.OPEN_TASK, taskRow.tap)
    }

    @Test
    fun `有关联作业时作业行显示作业标题_已完成改副题`() {
        val pending = buildOne(course(), tasks = listOf(task(title = "第三章习题")))
        assertEquals("第三章习题", row(pending, CourseActionRowKind.TASK).title)
        assertEquals("任务清单", row(pending, CourseActionRowKind.TASK).subtitle)

        val done = buildOne(course(), tasks = listOf(task(title = "第三章习题", isCompleted = true)))
        assertEquals("已完成", row(done, CourseActionRowKind.TASK).subtitle)
    }

    @Test
    fun `作业标题为空时回落课程作业`() {
        val section = buildOne(course(), tasks = listOf(task(title = "   ")))
        assertEquals("课程作业", row(section, CourseActionRowKind.TASK).title)
    }

    @Test
    fun `别的周的作业不算本周关联_但 sourceWeek 为空的算`() {
        val otherWeek = buildOne(course(), week = 2, tasks = listOf(task(title = "第9周的作业", sourceWeek = 9)))
        assertEquals("添加任务", row(otherWeek, CourseActionRowKind.TASK).title)

        val sameWeek = buildOne(course(), week = 2, tasks = listOf(task(title = "第2周的作业", sourceWeek = 2)))
        assertEquals("第2周的作业", row(sameWeek, CourseActionRowKind.TASK).title)

        val noWeek = buildOne(course(), week = 2, tasks = listOf(task(title = "全周作业", sourceWeek = null)))
        assertEquals("全周作业", row(noWeek, CourseActionRowKind.TASK).title)
    }

    @Test
    fun `别的课的作业不算关联`() {
        val section = buildOne(course(), tasks = listOf(task(title = "别人的作业", courseId = "c2")))
        assertEquals("添加任务", row(section, CourseActionRowKind.TASK).title)
    }

    // ───────────────────────── 天气行 ─────────────────────────

    private val sunnySummary = CourseWeatherSummary(
        category = WeatherCategory.LIGHT_RAIN,
        temperatureC = 23,
        hourCount = 2,
        precipitationProbability = 60,
        showPrecipitationProbability = true,
        representativeWmoCode = 61,
    )

    @Test
    fun `天气行_开关关掉或对方课或停课周或没有日期都不出现`() {
        val date = LocalDate.of(2026, 10, 29)
        val full = CourseSheetWeatherInfo(date = date, summary = sunnySummary)

        assertFalse(
            "weatherShowOnSheet 关掉时整行不出现",
            kinds(buildOne(course(), weatherPrefs = CourseSheetWeatherPrefs(showOnSheet = false), weather = full))
                .contains(CourseActionRowKind.WEATHER),
        )
        assertFalse(
            "对方课不显示天气",
            kinds(buildOne(course(), partner = true, weather = full)).contains(CourseActionRowKind.WEATHER),
        )
        assertFalse(
            "停课周不显示天气",
            kinds(buildOne(course(suspendedWeeks = listOf(1)), week = 1, weather = full))
                .contains(CourseActionRowKind.WEATHER),
        )
        assertFalse(
            "没有日期不显示天气",
            kinds(buildOne(course(), weather = CourseSheetWeatherInfo(date = null, summary = sunnySummary)))
                .contains(CourseActionRowKind.WEATHER),
        )
    }

    @Test
    fun `天气行_有摘要时按三项开关拼成一句`() {
        val date = LocalDate.of(2026, 10, 29)
        val section = buildOne(
            course(),
            weather = CourseSheetWeatherInfo(date = date, summary = sunnySummary),
        )
        val weather = row(section, CourseActionRowKind.WEATHER)
        assertEquals("小雨 · 23°", weather.title)
        assertEquals("该课程时段内的天气", weather.subtitle)

        val withProbability = buildOne(
            course(),
            weatherPrefs = CourseSheetWeatherPrefs(showProbability = true),
            weather = CourseSheetWeatherInfo(date = date, summary = sunnySummary),
        )
        assertEquals("小雨 · 23° · 60%", row(withProbability, CourseActionRowKind.WEATHER).title)

        val temperatureOnly = buildOne(
            course(),
            weatherPrefs = CourseSheetWeatherPrefs(showPhenomenon = false),
            weather = CourseSheetWeatherInfo(date = date, summary = sunnySummary),
        )
        assertEquals("23°", row(temperatureOnly, CourseActionRowKind.WEATHER).title)
    }

    @Test
    fun `天气行_数据没到但该有天气时画加载占位且标题压次要色`() {
        val section = buildOne(
            course(),
            weather = CourseSheetWeatherInfo(
                date = LocalDate.of(2026, 10, 29),
                summary = null,
                awaiting = true,
            ),
        )
        val weather = row(section, CourseActionRowKind.WEATHER)
        assertEquals("天气加载中…", weather.title)
        assertEquals("该课程时段内的天气", weather.subtitle)
        assertTrue("占位行标题压次要色", weather.mutedTitle)
    }

    @Test
    fun `天气行_没有摘要也不在等待时整行不出现`() {
        val section = buildOne(
            course(),
            weather = CourseSheetWeatherInfo(date = LocalDate.of(2026, 10, 29)),
        )
        assertFalse(kinds(section).contains(CourseActionRowKind.WEATHER))
    }

    // ───────────────────────── 说明行周次高亮 ─────────────────────────

    @Test
    fun `说明句里的周次数字切成高亮片`() {
        val notice = row(buildOne(course(), week = 12), CourseActionRowKind.NOTICE)
        assertEquals("12", notice.emphasizedToken)
        val pieces = notice.titlePieces
        assertEquals(3, pieces.size)
        assertFalse(pieces[0].emphasized)
        assertTrue(pieces[1].emphasized)
        assertEquals("12", pieces[1].text)
        assertFalse(pieces[2].emphasized)
        assertEquals(notice.title, pieces.joinToString("") { it.text })
    }

    @Test
    fun `说明句里没有周次 token 时整句原样一片`() {
        val row = CourseActionDetailRow(
            kind = CourseActionRowKind.NOTICE,
            icon = CourseActionIcon.INFO,
            title = "没有数字的说明",
            emphasizedToken = "9",
        )
        assertEquals(1, row.titlePieces.size)
        assertFalse(row.titlePieces[0].emphasized)
    }

    // ───────────────────────── 动作区开关 ─────────────────────────

    @Test
    fun `调课只在本周有这门课时可点`() {
        assertTrue(buildOne(course(), week = 3).canReschedule)
        assertFalse("第 20 周不在 1~16 内", buildOne(course(), week = 20).canReschedule)
        assertFalse("只读课不能调课", buildOne(course(), week = 3, partner = true).canReschedule)
    }

    @Test
    fun `本周已停课时作者区要能显示恢复`() {
        assertTrue(buildOne(course(suspendedWeeks = listOf(4)), week = 4).isSuspendedThisWeek)
        assertFalse(buildOne(course(suspendedWeeks = listOf(4)), week = 5).isSuspendedThisWeek)
    }

    @Test
    fun `删除范围里两件事的可用性来自课程数据`() {
        val section = buildOne(course(suspendedWeeks = listOf(2)), week = 3)
        assertTrue("第 3 周有课 → 可以只删这一节", section.canDeleteOccurrence)
        assertTrue("有任何一周被停过", section.hasAnySuspended)
        assertFalse(buildOne(course(), week = 30).canDeleteOccurrence)
    }

    // ───────────────────────── 详情整体 ─────────────────────────

    @Test
    fun `整份描述与预览条目同序_可按 id 取回`() {
        val primary = CourseActionPreviewItem(course = course(id = "c1"))
        val conflict = CourseActionPreviewItem(course = course(id = "c2", name = "线性代数"), isConflict = true)
        val details = CourseActionSheetModel.build(listOf(primary, conflict), week = 1)
        assertEquals(2, details.sections.size)
        assertEquals("高等数学", details.sectionAt(0)!!.header.courseName)
        assertEquals("线性代数", details.sectionFor("c2")!!.header.courseName)
        assertNull(details.sectionFor("nope"))
        assertTrue(details.isReady)
    }

    @Test
    fun `只有一个预览条目时没有关联面板`() {
        val details = CourseActionSheetModel.build(
            listOf(CourseActionPreviewItem(course = course())),
            week = 1,
        )
        assertNull(details.relatedPanel(0))
    }

    @Test
    fun `关联面板标题按冲突与情侣的条数切换`() {
        val primary = CourseActionPreviewItem(course = course(id = "c1"))
        val c2 = CourseActionPreviewItem(course = course(id = "c2", name = "线性代数"), isConflict = true)
        val c3 = CourseActionPreviewItem(course = course(id = "c3", name = "大学物理"), isConflict = true)

        val conflictsOnly = CourseActionSheetModel.build(listOf(primary, c2, c3), week = 1)
        assertEquals("冲突 2 节", conflictsOnly.relatedPanel(0)!!.title)
        assertEquals(CourseActionIcon.CONFLICT_BADGE, conflictsOnly.relatedPanel(0)!!.icon)
        assertEquals(CourseActionEntryColor.CONFLICT, conflictsOnly.relatedPanel(0)!!.accent)

        val coupleOnly = CourseActionSheetModel.build(
            listOf(primary, CourseActionPreviewItem(course = course(id = "c2"), coupleKind = CourseCoupleKind.TOGETHER)),
            week = 1,
        )
        assertEquals("还有 1 节情侣课表课程", coupleOnly.relatedPanel(0)!!.title)
        assertEquals(CourseActionIcon.COUPLE_HEART, coupleOnly.relatedPanel(0)!!.icon)

        val mixed = CourseActionSheetModel.build(
            listOf(
                primary,
                c2,
                CourseActionPreviewItem(course = course(id = "c3"), coupleKind = CourseCoupleKind.PARTNER),
            ),
            week = 1,
        )
        assertEquals("还有 2 节相关课程", mixed.relatedPanel(0)!!.title)
    }

    @Test
    fun `关联面板条目顺序等于预览顺序_并带各自角标与颜色`() {
        val primary = CourseActionPreviewItem(course = course(id = "c1"))
        val c2 = CourseActionPreviewItem(course = course(id = "c2", name = "线性代数"), isConflict = true)
        val details = CourseActionSheetModel.build(listOf(primary, c2), week = 1)
        val panel = details.relatedPanel(0)!!
        assertEquals(1, panel.entries.size)
        val entry = panel.entries.first()
        assertEquals(1, entry.previewIndex)
        assertEquals("线性代数", entry.courseName)
        assertEquals("冲突", entry.badgeText)
        assertEquals(CourseActionEntryColor.CONFLICT, entry.color)
        assertEquals("切换", entry.switchLabel)
        assertEquals("周一 · 第 1～2 节 · 08:00-09:40", entry.scheduleLine)
        assertEquals("A101", entry.location)
    }

    @Test
    fun `切到冲突课之后面板标题不再出现情侣课字样`() {
        // Dart `:236` 把「非冲突的都算情侣」（`others.size - conflictCount`），于是切到
        // 冲突课后主课会被说成「还有 1 节情侣课表课程」——每次切课都说一句错话。
        // 这里按真实语义数（`coupleKind != null` 才算情侣），标题落回「相关课程」。
        val primary = CourseActionPreviewItem(course = course(id = "c1", name = "高等数学"))
        val c2 = CourseActionPreviewItem(course = course(id = "c2", name = "线性代数"), isConflict = true)
        val details = CourseActionSheetModel.build(listOf(primary, c2), week = 1)

        val panel = details.relatedPanel(1)!!
        assertEquals("还有 1 节相关课程", panel.title)
        assertFalse("屏幕上根本没有情侣数据，不许出现情侣课字样", panel.title.contains("情侣"))
        assertEquals(CourseActionEntryColor.CONFLICT, panel.accent)
        assertEquals(CourseActionIcon.CONFLICT_BADGE, panel.icon)
        assertEquals("高等数学", panel.entries.single().courseName)
        assertNull("主课既不是冲突也不是情侣，不该有角标", panel.entries.single().badgeText)
        assertEquals(CourseActionEntryColor.COURSE, panel.entries.single().color)
    }

    @Test
    fun `情侣计数只数真的情侣课_不把普通课算进去`() {
        val primary = CourseActionPreviewItem(course = course(id = "c1"))
        val conflict = CourseActionPreviewItem(course = course(id = "c2"), isConflict = true)
        val couple = CourseActionPreviewItem(
            course = course(id = "c3"),
            coupleKind = CourseCoupleKind.PARTNER,
        )
        val details = CourseActionSheetModel.build(listOf(primary, conflict, couple), week = 1)
        val panel = details.relatedPanel(0)!!
        // 1 条冲突 + 1 条情侣 ⇒ 混合文案，总数是 others.size = 2
        assertEquals("还有 2 节相关课程", panel.title)
        assertEquals(CourseActionEntryColor.CONFLICT, panel.accent)
    }

    @Test
    fun `折叠条副标题是课名预览_超过两条只显示前两条`() {
        assertEquals("A", CourseActionSheetDetails.conflictPreviewLine(listOf("A")))
        assertEquals("A · B", CourseActionSheetDetails.conflictPreviewLine(listOf("A", "B")))
        assertEquals("A · B…", CourseActionSheetDetails.conflictPreviewLine(listOf("A", "B", "C")))
        assertNull(CourseActionSheetDetails.conflictPreviewLine(emptyList()))
    }

    @Test
    fun `没有课名时折叠条副标题用展开提示`() {
        val primary = CourseActionPreviewItem(course = course(id = "c1", name = "  "))
        val conflict = CourseActionPreviewItem(course = course(id = "c2", name = ""), isConflict = true)
        val details = CourseActionSheetModel.build(listOf(primary, conflict), week = 1)
        assertEquals("展开查看其他冲突课程，点击可切换操作对象", details.relatedPanel(0)!!.subtitle)
        assertEquals("点击收起冲突课程列表", details.relatedPanel(0)!!.expandedSubtitle)
    }

    // ───────────────────────── 预览条目取数 ─────────────────────────

    @Test
    fun `预览条目_第一条是主课_其后是同周冲突课`() {
        val primary = course(id = "c1", dayOfWeek = 1, startSection = 1, endSection = 2)
        val conflict = course(id = "c2", name = "线性代数", dayOfWeek = 1, startSection = 2, endSection = 3)
        val noConflict = course(id = "c3", name = "大学物理", dayOfWeek = 2, startSection = 1, endSection = 2)
        val items = CourseActionSheetModel.buildPreviewItems(
            courses = listOf(primary, conflict, noConflict),
            primary = primary,
            week = 1,
        )
        assertEquals(listOf("c1", "c2"), items.map { it.course.id })
        assertFalse("主课那条不是冲突", items[0].isConflict)
        assertTrue("冲突那条标 isConflict", items[1].isConflict)
    }

    @Test
    fun `预览条目_冲突课按 开始节次 再按 id 排序`() {
        val primary = course(id = "p0", dayOfWeek = 1, startSection = 1, endSection = 2)
        val laterStart = course(id = "a3", dayOfWeek = 1, startSection = 2, endSection = 4)
        val sameStartZ = course(id = "a2", dayOfWeek = 1, startSection = 1, endSection = 2)
        val sameStartA = course(id = "a1", dayOfWeek = 1, startSection = 1, endSection = 2)
        val items = CourseActionSheetModel.buildPreviewItems(
            courses = listOf(laterStart, sameStartZ, sameStartA),
            primary = primary,
            week = 1,
        )
        // 同开始节次（1 节起）的两条按 id 升序 → a1、a2；2 节起的 a3 排其后
        assertEquals(listOf("p0", "a1", "a2", "a3"), items.map { it.course.id })
    }

    @Test
    fun `预览条目_不同星期的课永远不构成冲突`() {
        // Dart `overlapInWeek` 先比 `dayOfWeek`，不同星期直接返回 false——
        // 所以「按星期排序」这条 tiebreak 在冲突场景里实际不会生效（保留 Dart 排序口径，但不指望它有用）。
        val primary = course(id = "c1", dayOfWeek = 1, startSection = 1, endSection = 8)
        val anotherDay = course(id = "c2", dayOfWeek = 5, startSection = 1, endSection = 2)
        val items = CourseActionSheetModel.buildPreviewItems(
            courses = listOf(anotherDay),
            primary = primary,
            week = 1,
        )
        assertEquals(listOf("c1"), items.map { it.course.id })
    }

    @Test
    fun `预览条目_不在这一周的课不算冲突`() {
        val primary = course(id = "c1", startWeek = 1, endWeek = 4)
        val other = course(id = "c2", name = "线性代数", startWeek = 6, endWeek = 10)
        val items = CourseActionSheetModel.buildPreviewItems(
            courses = listOf(primary, other),
            primary = primary,
            week = 2,
        )
        assertEquals(1, items.size)
    }

    @Test
    fun `预览条目_点对方的课_只读且不展开冲突课`() {
        val primary = course(id = "p1", name = "对方课", dayOfWeek = 2, startSection = 1, endSection = 2)
        val mine = course(id = "m1", name = "我的课", dayOfWeek = 2, startSection = 1, endSection = 2)
        val items = CourseActionSheetModel.buildPreviewItems(
            courses = listOf(mine),
            primary = primary,
            week = 1,
            partnerCourses = listOf(primary),
            coupleOverlayActive = true,
        )
        assertEquals(1, items.size)
        assertTrue("对方的课必须只读", items[0].isReadOnly)
        assertEquals(CourseCoupleKind.PARTNER, items[0].coupleKind)
    }

    @Test
    fun `预览条目_叠加开启但点自己的课_不抛错且照常可编辑`() {
        val primary = course(id = "m1", name = "高数", dayOfWeek = 3, startSection = 1, endSection = 2)
        val other = course(id = "m2", name = "线代", dayOfWeek = 3, startSection = 2, endSection = 3)
        val items = CourseActionSheetModel.buildPreviewItems(
            courses = listOf(primary, other),
            primary = primary,
            week = 1,
            partnerCourses = listOf(course(id = "pX", name = "对方课")),
            coupleOverlayActive = true,
        )
        assertTrue(items.isNotEmpty())
        assertFalse("我自己的课不能被当成对方课只读", items[0].isReadOnly)
    }

    // ───────────────────────── 删除确认文案 ─────────────────────────

    @Test
    fun `删除整门课的确认文案`() {
        val section = buildOne(course(name = "高等数学", dayOfWeek = 3, startSection = 1, endSection = 2))
        assertEquals("删除日程", CourseActionSheetModel.deleteWholeCourseTitle())
        assertEquals(
            "确定删除 高等数学 的排课？\n第 1～16 周 · 周三 第 1～2 节",
            CourseActionSheetModel.deleteWholeCourseMessage(section),
        )
    }

    @Test
    fun `删除本周这一节的确认文案`() {
        val section = buildOne(course(name = "高等数学", dayOfWeek = 3), week = 5)
        assertEquals("删除这节课", CourseActionSheetModel.deleteOccurrenceTitle())
        assertEquals(
            "确定删除 高等数学 第 5 周的此节课程？\n周三 第 1～2 节 · 08:00～09:40",
            CourseActionSheetModel.deleteOccurrenceMessage(section, 5),
        )
    }

    // ───────────────────────── 事件带课标识（切换课程后不许对错的课写库）─────────────────────────

    @Test
    fun `切到冲突课之后事件带的是当前选中那条的 courseId`() {
        val primary = CourseActionPreviewItem(course = course(id = "c1", name = "高等数学"))
        val conflict = CourseActionPreviewItem(
            course = course(id = "c2", name = "线性代数"),
            isConflict = true,
        )
        val details = CourseActionSheetModel.build(listOf(primary, conflict), week = 1)
        val first = details.sectionAt(0)!!
        val second = details.sectionAt(1)!!

        assertEquals("c1", CourseActionSheetModel.Events.edit(first).courseId)
        // 切到第 2 条（冲突课）之后，所有事件都必须跟着换成 c2
        assertEquals("c2", CourseActionSheetModel.Events.edit(second).courseId)
        assertEquals("c2", CourseActionSheetModel.Events.addTask(second).courseId)
        assertEquals(
            "c2",
            CourseActionSheetModel.Events
                .delete(second, CourseDeleteScope.THIS_WEEK).courseId,
        )
        assertEquals(
            "c2",
            CourseActionSheetModel.Events
                .suspend(second, CourseSuspendScope.ALL_WEEKS).courseId,
        )
        assertEquals(
            "c2",
            CourseActionSheetModel.Events
                .reschedule(second, CourseRescheduleTarget(2, 3, 1, 2, "B202")).courseId,
        )
        assertEquals(
            "c2",
            CourseActionSheetModel.Events.saveNotes(second, "简介", "本节").courseId,
        )
    }

    @Test
    fun `事件载荷不会被课标识挤掉`() {
        val section = buildOne(course(id = "c9"))
        val target = CourseRescheduleTarget(3, 4, 5, 6, "B303")

        val deleteEvent = CourseActionSheetModel.Events.delete(section, CourseDeleteScope.WHOLE_COURSE)
        assertTrue(deleteEvent is CourseActionEvent.Delete)
        assertEquals(CourseDeleteScope.WHOLE_COURSE, (deleteEvent as CourseActionEvent.Delete).scope)
        assertEquals("c9", deleteEvent.courseId)

        val suspendEvent = CourseActionSheetModel.Events.suspend(section, CourseSuspendScope.THIS_WEEK)
        assertEquals(CourseSuspendScope.THIS_WEEK, (suspendEvent as CourseActionEvent.Suspend).scope)

        val rescheduleEvent = CourseActionSheetModel.Events.reschedule(section, target)
        assertEquals(target, (rescheduleEvent as CourseActionEvent.Reschedule).target)

        val notesEvent = CourseActionSheetModel.Events.saveNotes(section, "课程简介", null)
        assertEquals("课程简介", (notesEvent as CourseActionEvent.SaveNotes).wholeNote)
        assertNull(notesEvent.sessionNote)
    }

    // ───────────────────────── 边角 ─────────────────────────

    @Test
    fun `星期越界退化成数字_与 dart 同口径`() {
        val labels = CourseActionSheetStrings.weekdayLabels
        assertEquals("周三", CourseActionSheetModel.weekdayLabelOf(labels, 3))
        assertEquals("0", CourseActionSheetModel.weekdayLabelOf(labels, 0))
        assertEquals("9", CourseActionSheetModel.weekdayLabelOf(labels, 9))
    }

    @Test
    fun `情侣角标三种角色都有对应文案_没有角色时为空`() {
        assertEquals("一起上课", CourseActionSheetModel.coupleLabel(CourseCoupleKind.TOGETHER))
        assertEquals("TA的课", CourseActionSheetModel.coupleLabel(CourseCoupleKind.PARTNER))
        assertEquals("我的课", CourseActionSheetModel.coupleLabel(CourseCoupleKind.MINE))
        assertNull(CourseActionSheetModel.coupleLabel(null))
    }

    @Test
    fun `冲突课不会被重复画两遍冲突角标`() {
        val section = buildOne(course(), conflict = true)
        assertEquals("冲突", section.header.conflictText)
        assertNull("头部只画一次冲突（Dart 会把「冲突」画两遍，那是重复）", section.header.coupleText)
    }
}
