package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 超级岛预览「模型」单测：把渲染层用到的纯逻辑（窗口、摘要文本、展开标题/正文/详情行）
 * 单独钉住，期望值全部手推，不依赖 Compose。
 *
 * 用 `anchored = true` 的固定锚点让窗口可预测：
 * - 课前窗口 = [anchor, anchor + 1s]
 * - 课中/下课窗口 = [anchor - 2s, anchor + 28s]
 */
class LiveIslandPreviewModelTest {

    private val anchor = 1_000_000L

    private fun info(
        nextCourseName: String? = "大学物理",
        note: String? = "带教材与习题册",
    ) = LiveIslandPreviewInfo(
        courseName = "高等数学",
        courseShortName = "高数",
        location = "三教-401",
        teacher = "张老师",
        startTime = "08:00",
        endTime = "08:45",
        note = note,
        nextCourseName = nextCourseName,
        anchorMillis = anchor,
    )

    // ── 窗口 ──

    @Test
    fun `预览窗口静态与锚定两种口径`() {
        val beforeStatic = LiveDisplayLogic.previewBeforeWindow(0L, anchored = false)
        // start = 0 + 12分37秒 = 757_000ms；end = start + 45分。
        assertEquals(757_000L, beforeStatic.startMillis)
        assertEquals(757_000L + 45 * 60 * 1000L, beforeStatic.endMillis)

        val beforeAnchored = LiveDisplayLogic.previewBeforeWindow(anchor, anchored = true)
        assertEquals(anchor, beforeAnchored.startMillis)
        assertEquals(anchor + 1_000L, beforeAnchored.endMillis)

        val endStatic = LiveDisplayLogic.previewEndWindow(0L, anchored = false)
        // start = 0 - 41分40秒 = -2_500_000ms；end = start + 45分。
        assertEquals(-2_500_000L, endStatic.startMillis)
        assertEquals(-2_500_000L + 45 * 60 * 1000L, endStatic.endMillis)

        val endAnchored = LiveDisplayLogic.previewEndWindow(anchor, anchored = true)
        assertEquals(anchor - 2_000L, endAnchored.startMillis)
        assertEquals(anchor + 28_000L, endAnchored.endMillis)
    }

    @Test
    fun `剩余毫秒计算`() {
        val window = LiveDisplayLogic.previewEndWindow(anchor, anchored = true)
        assertEquals(29_000L, LiveDisplayLogic.remainingMillis(window, nowMillis = 999_000L))
        assertEquals(1_000L, LiveDisplayLogic.millisUntilStart(LiveDisplayLogic.previewBeforeWindow(anchor, true), 999_000L))
    }

    // ── 摘要态 ──

    @Test
    fun `摘要胶囊三段拼接为课程名地点状态`() {
        val state = LiveDisplayState()
        // now = 999_000：距课前窗口开始 1s（前置 true 不显示前缀）；地点开启。
        val text = LiveDisplayLogic.islandCriticalText(
            state = state,
            stage = LivePreviewStage.BEFORE_CLASS,
            info = info(),
            nowMillis = 999_000L,
        )
        assertEquals("高数 三教-401 1秒", text)
    }

    @Test
    fun `关掉地点后摘要不含地点`() {
        val state = LiveDisplayState(showLocation = false)
        val text = LiveDisplayLogic.islandCriticalText(state, LivePreviewStage.BEFORE_CLASS, info(), 999_000L)
        assertEquals("高数 1秒", text)
    }

    @Test
    fun `课中显示倒计时用裸倒计时`() {
        val state = LiveDisplayState()
        val status = LiveDisplayLogic.statusLine(state, LivePreviewStage.DURING_CLASS, info(), 999_000L)
        // end 窗口 end = anchor + 28s = 1_028_000；now = 999_000 → 29s。
        assertEquals("29秒", status)
    }

    @Test
    fun `关倒计时时状态退化为阶段词或空`() {
        val offStageOn = LiveDisplayState(showCountdown = false, showStageText = true)
        assertEquals(
            "即将上课",
            LiveDisplayLogic.visibleStatusText(offStageOn, LivePreviewStage.BEFORE_CLASS, info(), 999_000L),
        )
        val offStageOff = LiveDisplayState(showCountdown = false, showStageText = false)
        assertEquals(
            "",
            LiveDisplayLogic.visibleStatusText(offStageOff, LivePreviewStage.BEFORE_CLASS, info(), 999_000L),
        )
    }

    @Test
    fun `前缀开关控制距上课字样`() {
        val noPrefix = LiveDisplayState(hidePrefixText = true)
        assertEquals(
            "1秒",
            LiveDisplayLogic.visibleStatusText(noPrefix, LivePreviewStage.BEFORE_CLASS, info(), 999_000L),
        )
        val withPrefix = LiveDisplayState(hidePrefixText = false)
        assertEquals(
            "距上课 1秒",
            LiveDisplayLogic.visibleStatusText(withPrefix, LivePreviewStage.BEFORE_CLASS, info(), 999_000L),
        )
    }

    @Test
    fun `课程名五字截断且可切简称`() {
        val longInfo = LiveIslandPreviewInfo(
            courseName = "高等数学分析",
            courseShortName = null,
            location = "三教-401",
            teacher = "张老师",
            startTime = "08:00",
            endTime = "08:45",
            anchorMillis = anchor,
        )
        // useShortName 但没简称 → 用全称并截 5 字。
        assertEquals("高等数学分", LiveDisplayLogic.islandCourseName(LiveDisplayState(useShortName = true), longInfo))
        // 关掉简称 → 也截 5 字。
        assertEquals("高等数学分", LiveDisplayLogic.islandCourseName(LiveDisplayState(useShortName = false), longInfo))
        // 显示课程名关掉 → 空串。
        assertEquals("", LiveDisplayLogic.islandCourseName(LiveDisplayState(showCourseName = false), longInfo))
    }

    // ── 展开态 ──

    @Test
    fun `展开标题课前带前缀课中只有课程名`() {
        val state = LiveDisplayState()
        assertEquals("即将上课：高数", LiveDisplayLogic.expandedTitle(state, LivePreviewStage.BEFORE_CLASS, info()))
        assertEquals("高数", LiveDisplayLogic.expandedTitle(state, LivePreviewStage.DURING_CLASS, info()))
    }

    @Test
    fun `展开标题课程名八字截断补两点`() {
        val longInfo = LiveIslandPreviewInfo(
            courseName = "马克思主义基本原理概论",
            courseShortName = null,
            location = "三教-401",
            teacher = "张老师",
            startTime = "08:00",
            endTime = "08:45",
            anchorMillis = anchor,
        )
        // "马克思主义基本原理概论" 前 8 字 = "马克思主义基本原" + ".."
        assertEquals("马克思主义基本原..", LiveDisplayLogic.titleCourseName(LiveDisplayState(useShortName = false), longInfo))
    }

    @Test
    fun `展开正文课前为状态时间地点教师四段`() {
        val state = LiveDisplayState()
        val summary = LiveDisplayLogic.expandedSummaryLine(state, LivePreviewStage.BEFORE_CLASS, info(), 999_000L)
        assertEquals("1秒 · 08:00 - 08:45 · 三教-401 · 张老师", summary)
    }

    @Test
    fun `展开正文课中带进度只剩倒计时与地点`() {
        val state = LiveDisplayState()
        val summary = LiveDisplayLogic.expandedSummaryLine(state, LivePreviewStage.DURING_CLASS, info(), 999_000L)
        assertEquals("29秒 · 三教-401", summary)
    }

    @Test
    fun `课前默认展开详情六行`() {
        val state = LiveDisplayState()
        val lines = LiveDisplayLogic.expandedDetailLines(state, LivePreviewStage.BEFORE_CLASS, info(), 999_000L)
        assertEquals(
            listOf(
                LiveDetailLine("时间：08:00 - 08:45"),
                LiveDetailLine("地点：三教-401"),
                LiveDetailLine("教师：张老师"),
                LiveDetailLine("简称：高数"),
                LiveDetailLine("下一节：大学物理"),
                LiveDetailLine("备注：带教材与习题册"),
            ),
            lines,
        )
    }

    @Test
    fun `课中默认展开详情含两行进度`() {
        val state = LiveDisplayState()
        val lines = LiveDisplayLogic.expandedDetailLines(state, LivePreviewStage.DURING_CLASS, info(), 999_000L)
        assertEquals(8, lines.size)
        assertEquals(LiveDetailLine("下一节点：下课提醒"), lines[0])
        assertEquals(LiveDetailLine("整节下课：29秒"), lines[1])
    }

    @Test
    fun `缺失字段显示占位且标记 unfilled`() {
        val state = LiveDisplayState()
        val lines = LiveDisplayLogic.expandedDetailLines(
            state,
            LivePreviewStage.BEFORE_CLASS,
            info(nextCourseName = null, note = null),
            999_000L,
        )
        // 下一节 / 备注各为占位行。
        assertEquals(LiveDetailLine("下一节：无", unfilled = true), lines[4])
        assertEquals(LiveDetailLine("备注：无", unfilled = true), lines[5])
    }

    @Test
    fun `全部隐藏时详情为空`() {
        val state = LiveDisplayState(expandedDetailFields = emptyList())
        val lines = LiveDisplayLogic.expandedDetailLines(state, LivePreviewStage.BEFORE_CLASS, info(), 999_000L)
        assertTrue(lines.isEmpty())
    }

    @Test
    fun `阶段文案与阶段列表`() {
        assertEquals("即将上课", LiveDisplayLogic.stageWord(LivePreviewStage.BEFORE_CLASS))
        assertEquals("上课中", LiveDisplayLogic.stageWord(LivePreviewStage.DURING_CLASS))
        assertEquals("下课提醒", LiveDisplayLogic.stageWord(LivePreviewStage.BEFORE_END))
        assertEquals(listOf(LivePreviewStage.BEFORE_CLASS), LiveDisplayLogic.stagesFor(forDuringEnd = false))
        assertEquals(
            listOf(LivePreviewStage.DURING_CLASS, LivePreviewStage.BEFORE_END),
            LiveDisplayLogic.stagesFor(forDuringEnd = true),
        )
    }

    @Test
    fun `简称等于全名时不单独出行`() {
        val sameName = LiveIslandPreviewInfo(
            courseName = "高数",
            courseShortName = "高数",
            location = "三教-401",
            teacher = "张老师",
            startTime = "08:00",
            endTime = "08:45",
            anchorMillis = anchor,
        )
        assertEquals(null, LiveDisplayLogic.shortNameLabel(sameName))
        val lines = LiveDisplayLogic.expandedDetailLines(LiveDisplayState(), LivePreviewStage.BEFORE_CLASS, sameName, 999_000L)
        assertFalse(lines.any { it.text.startsWith("简称：") })
    }
}
