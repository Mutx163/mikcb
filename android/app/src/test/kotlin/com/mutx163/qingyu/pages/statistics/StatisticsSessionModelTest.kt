package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.CourseSession
import com.mutx163.qingyu.core.CourseSessionPhase
import com.mutx163.qingyu.core.CourseSessionStats
import com.mutx163.qingyu.pages.statistics.charts.SessionCardsModel
import com.mutx163.qingyu.pages.statistics.charts.SessionTone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 单节课明细页模型层测试。
 *
 * 期望值全部从 Dart 源手推：
 * - 选中项收敛：`statistics_session_screen.dart:130-136` `_resolveSelection`；
 * - 四格汇总：`widgets/statistics/session_summary_card.dart`（课次 / 已过 / 课时 / 有备注）；
 * - 覆盖三行：`widgets/statistics/session_coverage_card.dart`，**分母是全部课次**；
 * - 阶段标签：`widgets/statistics/session_list_card.dart:167-172`；
 * - 列表行：同文件 `_SessionRow`（标题「哪一次」+ 考试/阶段角标 + 副标题
 *   （节次 · 钟点 · 教室，缺项跳过））。
 */
class StatisticsSessionModelTest {

    // ── 1. 选中项收敛（Dart _resolveSelection） ──

    @Test
    fun `上次选中的课还在就沿用`() {
        assertEquals(
            "线性代数",
            StatisticsSessionModel.resolveSelection(listOf("高等数学", "线性代数"), "线性代数"),
        )
    }

    @Test
    fun `上次选中的课被删了回落第一门`() {
        // 用户删掉了「线性代数」，上一次选择必须收敛，不能停在已不存在的名字上。
        assertEquals(
            "高等数学",
            StatisticsSessionModel.resolveSelection(listOf("高等数学", "大学物理"), "线性代数"),
        )
    }

    @Test
    fun `没有上次选择时用第一门`() {
        assertEquals(
            "高等数学",
            StatisticsSessionModel.resolveSelection(listOf("高等数学", "大学物理"), null),
        )
    }

    @Test
    fun `一门课都没有时返回 null`() {
        assertNull(StatisticsSessionModel.resolveSelection(emptyList(), "高等数学"))
        assertNull(StatisticsSessionModel.resolveSelection(emptyList(), null))
    }

    // ── 2. 四格汇总（SessionSummaryCard） ──

    @Test
    fun `四格是课次 已过 课时 有备注 且首格强调`() {
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE, start = 1, end = 2, note = "讲了极限"),
            session(phase = CourseSessionPhase.DONE, start = 3, end = 4),
            session(phase = CourseSessionPhase.UPCOMING, start = 1, end = 2),
        )
        val metrics = StatisticsSessionModel.summaryMetrics(stats)

        assertEquals("应有 4 格", 4, metrics.size)
        // 课次 = 全部课次数（含未到）
        assertEquals("3", metrics[0].value)
        assertEquals("课次", metrics[0].label)
        assertTrue("首格（课次）应强调", metrics[0].highlight)
        // 已过 = 2
        assertEquals("2", metrics[1].value)
        assertEquals("已过", metrics[1].label)
        // 课时 = 只算已过的节数：2 + 2 = 4（未到那次不计）
        assertEquals("4", metrics[2].value)
        assertEquals("课时", metrics[2].label)
        // 有备注 = 1
        assertEquals("1", metrics[3].value)
        assertEquals("有备注", metrics[3].label)
        // 其余三格不强调
        assertTrue(metrics.drop(1).none { it.highlight })
    }

    @Test
    fun `没有课次时不画汇总卡`() {
        assertTrue(StatisticsSessionModel.summaryMetrics(statsOf()).isEmpty())
    }

    @Test
    fun `课时只按已过课次累加不按每周节数乘周数`() {
        // 这门课一周两次排课（2 节 + 3 节），上了 1 周：已过课时应为 5，不是 5×周数。
        // 这条对应用户能直接看到的数字：搞错会显示成「16 周 = 80 节」。
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE, start = 1, end = 2),
            session(phase = CourseSessionPhase.DONE, start = 3, end = 5),
        )
        val metrics = StatisticsSessionModel.summaryMetrics(stats)
        assertEquals("4 (课次)", "2", metrics[0].value)
        assertEquals("已过课时应为 2+3=5", "5", metrics[2].value)
    }

    // ── 3. 覆盖三行（SessionCoverageCard） ──

    @Test
    fun `覆盖三行分别是备注 作业 提醒`() {
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE, note = "有笔记", homework = true, reminder = true),
            session(phase = CourseSessionPhase.DONE),
        )
        val rows = StatisticsSessionModel.coverageRows(stats)

        assertEquals("应有 3 行", 3, rows.size)
        assertEquals("有备注", rows[0].label)
        assertEquals("有作业", rows[1].label)
        assertEquals("设过提醒", rows[2].label)
        assertEquals(1, rows[0].count)
        assertEquals(1, rows[1].count)
        assertEquals(1, rows[2].count)
    }

    // ── 3b. 提醒数据拿不到时不画那一行（审核 misc-wiring P1-4 的回归网）──
    //
    // 数据源已接（`core/TimetableSettings.classReminders`，见 `StatisticsFeed`），
    // 生产路径恒传 true；本组用例钉的是「万一将来某个调用方真的拿不到数据」时
    // 不许拿「提醒 0/N」冒充真实读数。满数据/缺数据两个方向都钉住，
    // 免得以后有人为了「三行才对」把假读数加回来。

    @Test
    fun `提醒数据拿不到时只剩两行`() {
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE, note = "有笔记", homework = true, reminder = true),
        )
        val rows = StatisticsSessionModel.coverageRows(stats, reminderDataAvailable = false)

        assertEquals("拿不到提醒数据时不应画第三行", 2, rows.size)
        assertEquals("有备注", rows[0].label)
        assertEquals("有作业", rows[1].label)
        assertTrue(
            "不应出现「设过提醒」这一行：${rows.map { it.label }}",
            rows.none { it.label == "设过提醒" },
        )
    }

    @Test
    fun `提醒数据可用时三行都在`() {
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE, note = "有笔记", homework = true, reminder = true),
        )
        val rows = StatisticsSessionModel.coverageRows(stats, reminderDataAvailable = true)

        assertEquals(3, rows.size)
        assertEquals("设过提醒", rows[2].label)
        assertEquals(1, rows[2].count)
    }

    @Test
    fun `覆盖行分母是全部课次含停课与假期`() {
        // Dart 的坑：分母若用 plannedSessions（不含停课/假期），能构造出 3/1 这种超过 100%。
        // 这里 4 个课次里有 1 节停课 + 1 节假期，分母必须仍是 4。
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE, note = "a"),
            session(phase = CourseSessionPhase.SUSPENDED, note = "停课周也记了笔记"),
            session(phase = CourseSessionPhase.HOLIDAY, note = "假期记了笔记"),
            session(phase = CourseSessionPhase.UPCOMING),
            plannedSessions = 2,
        )
        val rows = StatisticsSessionModel.coverageRows(stats)
        assertEquals("有备注 3 次", 3, rows[0].count)
        assertEquals("分母是全部 4 个课次", 4, rows[0].total)
        assertEquals("3 / 4", rows[0].valueText)
        // 比例必须落在 0~1，不会超过 100%
        assertTrue("比例不该超过 1：${rows[0].ratio}", rows[0].ratio <= 1f)
        assertEquals(0.75f, rows[0].ratio, 0.0001f)
    }

    @Test
    fun `分母为零时比例为 0 不抛除零`() {
        val rows = StatisticsSessionModel.coverageRows(statsOf())
        assertEquals(0, rows[0].total)
        assertEquals("0 / 0", rows[0].valueText)
        assertEquals(0f, rows[0].ratio, 0.0001f)
    }

    @Test
    fun `覆盖卡空态文案取自 ARB`() {
        assertEquals("这门课没有排课", StatisticsSessionModel.coverageEmptyText)
    }

    // ── 4. 阶段标签（session_list_card.dart:167-172） ──

    @Test
    fun `六种阶段标签与 ARB 一致`() {
        assertEquals("已过", StatisticsSessionModel.phaseLabel(CourseSessionPhase.DONE))
        assertEquals("今天", StatisticsSessionModel.phaseLabel(CourseSessionPhase.TODAY))
        assertEquals("未到", StatisticsSessionModel.phaseLabel(CourseSessionPhase.UPCOMING))
        assertEquals("停课", StatisticsSessionModel.phaseLabel(CourseSessionPhase.SUSPENDED))
        assertEquals("假期", StatisticsSessionModel.phaseLabel(CourseSessionPhase.HOLIDAY))
        assertEquals("日期未定", StatisticsSessionModel.phaseLabel(CourseSessionPhase.UNDATED))
    }

    // ── 5. 没设开学日期的提示 ──

    @Test
    fun `没设开学日期才显示提示`() {
        assertNull(StatisticsSessionModel.noCalendarHint(hasCalendar = true))
        assertEquals(
            "没设开学日期，只能按周次列出",
            StatisticsSessionModel.noCalendarHint(hasCalendar = false),
        )
    }

    // ── 6. 列表行拼法（Dart session_list_card.dart `_SessionRow`） ──
    //
    // Dart 行结构：标题「哪一次」（日期 · 周X / 第N周 · 周X）+ 考试角标 + 阶段角标，
    // 第二行副标题是「节次区间 · 钟点 · 教室」。此前 Kotlin 把日期塞进副标题、
    // 用 ASCII 连字符，还漏了钟点与考试角标——用户看不出是哪一天哪一节。

    @Test
    fun `标题写哪一次 副标题写节次钟点教室`() {
        val row = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.DONE, start = 1, end = 2, location = "教三 201"),
            dateText = "10月27日 · 周二",
        )
        assertEquals("已过", row.phaseLabel)
        assertEquals("10月27日 · 周二", row.title)
        assertEquals("第 1～2 节 · 08:00–09:40 · 教三 201", row.subtitle)
    }

    @Test
    fun `没有日期轴时标题回落第N周 副标题不夹日期`() {
        val row = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.UNDATED, start = 3, end = 4, location = "教一 101"),
            dateText = null,
        )
        assertEquals("日期未定", row.phaseLabel)
        assertEquals("第 8 周 · 周二", row.title)
        assertEquals("第 3～4 节 · 08:00–09:40 · 教一 101", row.subtitle)
    }

    @Test
    fun `没有教室时不留多余分隔符`() {
        val row = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.DONE, start = 1, end = 1, location = ""),
            dateText = "10月27日 · 周二",
        )
        assertEquals("第 1～1 节 · 08:00–09:40", row.subtitle)
    }

    @Test
    fun `没有钟点时副标题只留节次与教室`() {
        val row = StatisticsSessionModel.sessionRow(
            session(
                phase = CourseSessionPhase.DONE,
                location = "教三 201",
                startTime = null,
                endTime = null,
            ),
            dateText = "10月27日 · 周二",
        )
        assertEquals("第 1～2 节 · 教三 201", row.subtitle)
    }

    @Test
    fun `六种阶段的语义色与发布版 phaseColor 一致`() {
        // Dart session_list_card.dart `_phaseColor`：绿 / 主题色 / 蓝 / 橙 / 紫 / 灰。
        // 渲染层把 6 色直接取自 SessionCardsModel.tone —— 这条钉住「六色不许再被压回灰」。
        assertEquals(SessionTone.GREEN, SessionCardsModel.tone(CourseSessionPhase.DONE))
        assertEquals(SessionTone.PRIMARY, SessionCardsModel.tone(CourseSessionPhase.TODAY))
        assertEquals(SessionTone.BLUE, SessionCardsModel.tone(CourseSessionPhase.UPCOMING))
        assertEquals(SessionTone.ORANGE, SessionCardsModel.tone(CourseSessionPhase.SUSPENDED))
        assertEquals(SessionTone.PURPLE, SessionCardsModel.tone(CourseSessionPhase.HOLIDAY))
        assertEquals(SessionTone.SECONDARY, SessionCardsModel.tone(CourseSessionPhase.UNDATED))

        // sessionRow 必须把 tone 带上，渲染层不能再用文案反推颜色。
        val row = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.UPCOMING),
            dateText = "10月27日 · 周二",
        )
        assertEquals(SessionTone.BLUE, row.tone)
    }

    @Test
    fun `当天有考试才挂考试角标`() {
        val withExam = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.DONE, examCount = 1),
            dateText = "10月27日 · 周二",
        )
        assertEquals("考试", withExam.examBadge)

        val withoutExam = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.DONE),
            dateText = "10月27日 · 周二",
        )
        assertNull("没有考试不该出现角标", withoutExam.examBadge)
    }

    @Test
    fun `备注为空串时不进列表行`() {
        val blank = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.DONE, note = "   "),
            dateText = null,
        )
        assertNull("全空白的备注不该显示", blank.noteText)

        val kept = StatisticsSessionModel.sessionRow(
            session(phase = CourseSessionPhase.DONE, note = "讲了极限"),
            dateText = null,
        )
        assertEquals("讲了极限", kept.noteText)
    }

    @Test
    fun `逐课次生成的行数与课次数一致`() {
        val stats = statsOf(
            session(phase = CourseSessionPhase.DONE),
            session(phase = CourseSessionPhase.TODAY),
            session(phase = CourseSessionPhase.UPCOMING),
        )
        val rows = StatisticsSessionModel.sessionRows(stats) { "10月27日" }
        assertEquals(3, rows.size)
        assertEquals(listOf("已过", "今天", "未到"), rows.map { it.phaseLabel })
    }

    // ── 夹具 ──

    private fun session(
        phase: CourseSessionPhase,
        start: Int = 1,
        end: Int = 2,
        location: String = "教三 201",
        note: String? = null,
        homework: Boolean = false,
        reminder: Boolean = false,
        startTime: String? = "08:00",
        endTime: String? = "09:40",
        examCount: Int = 0,
    ) = CourseSession(
        courseId = "c1",
        week = 8,
        date = null,
        dayOfWeek = 2,
        startSection = start,
        endSection = end,
        startTime = startTime,
        endTime = endTime,
        location = location,
        phase = phase,
        noteText = note,
        hasHomework = homework,
        taskCount = if (homework) 1 else 0,
        examCount = examCount,
        hasReminder = reminder,
    )

    private fun statsOf(
        vararg sessions: CourseSession,
        plannedSessions: Int = sessions.size,
    ) = CourseSessionStats(
        courseName = "高等数学",
        teacher = "张老师",
        sessions = sessions.toList(),
        plannedSessions = plannedSessions,
        hasCalendar = true,
    )
}
