package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「超级岛 · 显示设置页」模型层单测（重建 Flutter `LiveDisplaySettingsScreen`）。
 *
 * 期望值全部**手推**（照 Dart `LiveDisplaySettings` 默认值、`_formatIslandCountdown`
 * 12 分支、`live_expanded_detail_fields.dart` 的可见字段与工作顺序一条条推出来），
 * 不从实现里抄。
 */
class DisplaySettingsModelTest {

    // ── 1. 22 字段默认值 ──

    @Test
    fun `LiveDisplayState 的 22 个显示字段默认值与 Flutter 一致`() {
        val s = LiveDisplayState()
        assertTrue(s.showCourseName)
        assertTrue(s.showLocation)
        assertTrue(s.showCountdown)
        assertEquals(LiveCountdownTextStyle.SMART, s.countdownTextStyle)
        assertTrue(s.showStageText)
        assertTrue(s.useShortName)
        assertTrue(s.hidePrefixText)
        assertEquals(LiveDuringClassTimeDisplayMode.NEAREST, s.duringClassTimeDisplayMode)
        assertFalse(s.enableMiuiIslandLabelImage)
        assertEquals(MiuiIslandLabelStyle.TEXT_ONLY, s.miuiIslandLabelStyle)
        assertEquals(MiuiIslandLabelContent.COURSE_NAME, s.miuiIslandLabelContent)
        assertEquals("#FFFFFF", s.miuiIslandLabelFontColor)
        assertEquals(MiuiIslandLabelFontWeight.BOLD, s.miuiIslandLabelFontWeight)
        assertEquals(MiuiIslandLabelRenderQuality.STANDARD, s.miuiIslandLabelRenderQuality)
        assertEquals(14.0, s.miuiIslandLabelFontSize, 0.0)
        assertEquals(0.0, s.miuiIslandLabelOffsetX, 0.0)
        assertEquals(0.0, s.miuiIslandLabelOffsetY, 0.0)
        assertNull(s.miuiIslandLabelLogoPath)
        assertEquals(8.0, s.miuiIslandLabelLogoCornerRadius, 0.0)
        assertEquals(MiuiIslandExpandedIconMode.APP_ICON, s.miuiIslandExpandedIconMode)
        assertNull(s.miuiIslandExpandedIconPath)
        assertNull(s.expandedDetailFields)
    }

    @Test
    fun `页面级关联字段默认值与 Flutter 一致`() {
        val s = LiveDisplayState()
        assertEquals(LiveBeforeClassQuickAction.NONE, s.beforeClassQuickAction)
        assertEquals(0, s.beforeClassQuickActionAutoMinutes)
        assertTrue(s.duringEndFollowBeforeClass)
        assertEquals(60, s.endSecondsCountdownThreshold)
        assertTrue(s.promoteDuringClass)
    }

    // ── 2. 倒计时 12 分支格式化（手推）──

    @Test
    fun `智能样式按阈值切换秒与分钟`() {
        // threshold=60：≤60 走秒；60<…≤120 向上取整分钟；>120 向下取整分钟。
        assertEquals("0秒", LiveDisplayLogic.formatCountdown(0, LiveCountdownTextStyle.SMART, 60))
        assertEquals("60秒", LiveDisplayLogic.formatCountdown(60, LiveCountdownTextStyle.SMART, 60))
        assertEquals("59秒", LiveDisplayLogic.formatCountdown(59, LiveCountdownTextStyle.SMART, 60))
        assertEquals("2分钟", LiveDisplayLogic.formatCountdown(61, LiveCountdownTextStyle.SMART, 60))
        assertEquals("2分钟", LiveDisplayLogic.formatCountdown(119, LiveCountdownTextStyle.SMART, 60))
        assertEquals("2分钟", LiveDisplayLogic.formatCountdown(120, LiveCountdownTextStyle.SMART, 60))
        assertEquals("2分钟", LiveDisplayLogic.formatCountdown(121, LiveCountdownTextStyle.SMART, 60))
        assertEquals("10分钟", LiveDisplayLogic.formatCountdown(600, LiveCountdownTextStyle.SMART, 60))
    }

    @Test
    fun `智能英文样式后缀用 min 与 s`() {
        assertEquals("2min", LiveDisplayLogic.formatCountdown(61, LiveCountdownTextStyle.SMART_MIN_S, 60))
        assertEquals("45s", LiveDisplayLogic.formatCountdown(45, LiveCountdownTextStyle.SMART_MIN_S, 60))
    }

    @Test
    fun `分秒样式四种写法`() {
        assertEquals("5分钟19秒", LiveDisplayLogic.formatCountdown(319, LiveCountdownTextStyle.MINUTE_SECOND_CN))
        assertEquals("5分钟", LiveDisplayLogic.formatCountdown(300, LiveCountdownTextStyle.MINUTE_SECOND_CN))
        assertEquals("45秒", LiveDisplayLogic.formatCountdown(45, LiveCountdownTextStyle.MINUTE_SECOND_CN))
        assertEquals("05:19", LiveDisplayLogic.formatCountdown(319, LiveCountdownTextStyle.MINUTE_SECOND_COLON))
        assertEquals("5min19s", LiveDisplayLogic.formatCountdown(319, LiveCountdownTextStyle.MINUTE_SECOND_MIN_S))
        assertEquals("5min/19s", LiveDisplayLogic.formatCountdown(319, LiveCountdownTextStyle.MINUTE_SECOND_MIN_SLASH_S))
        // 只有分钟时去掉 min/ 的尾部斜杠。
        assertEquals("5min", LiveDisplayLogic.formatCountdown(300, LiveCountdownTextStyle.MINUTE_SECOND_MIN_SLASH_S))
    }

    @Test
    fun `纯分钟样式向下取整且至少一分钟`() {
        assertEquals("3分钟", LiveDisplayLogic.formatCountdown(180, LiveCountdownTextStyle.MINUTE_ONLY_CN))
        assertEquals("2分钟", LiveDisplayLogic.formatCountdown(125, LiveCountdownTextStyle.MINUTE_ONLY_CN))
        // 不足一分钟也至少显示 1 分钟。
        assertEquals("1分钟", LiveDisplayLogic.formatCountdown(30, LiveCountdownTextStyle.MINUTE_ONLY_CN))
        assertEquals("3min", LiveDisplayLogic.formatCountdown(180, LiveCountdownTextStyle.MINUTE_ONLY_MIN))
        assertEquals("3/min", LiveDisplayLogic.formatCountdown(180, LiveCountdownTextStyle.MINUTE_ONLY_SLASH))
    }

    @Test
    fun `纯秒样式三种写法`() {
        assertEquals("45秒", LiveDisplayLogic.formatCountdown(45, LiveCountdownTextStyle.SECOND_ONLY_CN))
        assertEquals("45s", LiveDisplayLogic.formatCountdown(45, LiveCountdownTextStyle.SECOND_ONLY_SHORT))
        assertEquals("45/s", LiveDisplayLogic.formatCountdown(45, LiveCountdownTextStyle.SECOND_ONLY_SLASH))
    }

    @Test
    fun `负秒按零处理`() {
        assertEquals("0秒", LiveDisplayLogic.formatCountdown(-5, LiveCountdownTextStyle.SMART, 60))
        assertEquals("0秒", LiveDisplayLogic.formatCountdownMillis(-1000L, LiveCountdownTextStyle.SECOND_ONLY_CN, 60))
    }

    // ── 3. 展开字段可见集与工作顺序 ──

    @Test
    fun `课前可见字段不含阶段进度状态`() {
        val fields = LiveDisplayLogic.defaultDetailFieldsForStage(forDuringEnd = false)
        assertEquals(
            listOf(
                LiveExpandedDetailField.TIME,
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
            ),
            fields,
        )
    }

    @Test
    fun `课中可见字段九项且顺序按提升态`() {
        val fields = LiveDisplayLogic.defaultDetailFieldsForStage(forDuringEnd = true)
        assertEquals(9, fields.size)
        assertEquals(LiveExpandedDetailField.PROGRESS, fields.first())
        assertEquals(LiveExpandedDetailField.STAGE, fields.last())
    }

    @Test
    fun `名单未设置时工作顺序等于可见集全开`() {
        val state = LiveDisplayState()
        assertEquals(
            LiveDisplayLogic.defaultDetailFieldsForStage(false),
            LiveDisplayLogic.resolveDetailWorkOrder(state, forDuringEnd = false),
        )
        assertTrue(LiveDisplayLogic.resolveHiddenDetailFields(state, forDuringEnd = false).isEmpty())
    }

    @Test
    fun `已设置时取名单与可见集的交集并剔除不可见字段`() {
        // 名单里塞了课前页不可见的 STAGE，应被剔除。
        val state = LiveDisplayState(
            expandedDetailFields = listOf(
                LiveExpandedDetailField.STAGE,
                LiveExpandedDetailField.NOTE,
                LiveExpandedDetailField.TIME,
            ),
        )
        assertEquals(
            listOf(LiveExpandedDetailField.NOTE, LiveExpandedDetailField.TIME),
            LiveDisplayLogic.resolveDetailWorkOrder(state, forDuringEnd = false),
        )
        // 可见集里没提到的（LOCATION/TEACHER/SHORT/NEXT）即视为隐藏；TIME 已在名单里 → 不算隐藏。
        assertEquals(
            listOf(
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
            ),
            LiveDisplayLogic.resolveHiddenDetailFields(state, forDuringEnd = false),
        )
    }

    // ── 4. 显隐 / 排序纯函数 ──

    @Test
    fun `关闭一个字段即从工作顺序移除`() {
        val state = LiveDisplayState()
        val next = LiveDisplayLogic.toggleDetailField(state, LiveExpandedDetailField.TIME, forDuringEnd = false)
        assertEquals(
            listOf(
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
            ),
            next,
        )
    }

    @Test
    fun `关到只剩一个时保留最后一行`() {
        val state = LiveDisplayState(expandedDetailFields = listOf(LiveExpandedDetailField.TIME))
        val next = LiveDisplayLogic.toggleDetailField(state, LiveExpandedDetailField.TIME, forDuringEnd = false)
        assertEquals(listOf(LiveExpandedDetailField.TIME), next)
    }

    @Test
    fun `重新打开隐藏字段追加到末尾`() {
        val state = LiveDisplayState(
            expandedDetailFields = listOf(
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
            ),
        )
        val next = LiveDisplayLogic.toggleDetailField(state, LiveExpandedDetailField.TIME, forDuringEnd = false)
        assertEquals(LiveExpandedDetailField.TIME, next.last())
        assertEquals(6, next.size)
    }

    @Test
    fun `拖拽落位把字段挪到目标下标`() {
        val state = LiveDisplayState()
        // 默认顺序 [TIME, LOCATION, TEACHER, SHORT, NEXT, NOTE]，把 TIME(0) 挪到 2。
        val next = LiveDisplayLogic.reorderDetailField(state, oldIndex = 0, newIndex = 2, forDuringEnd = false)
        assertEquals(
            listOf(
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.TIME,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
            ),
            next,
        )
    }

    @Test
    fun `下移一格按插入位校正后落位`() {
        val state = LiveDisplayState()
        val next = LiveDisplayLogic.moveDetailFieldBy(state, LiveExpandedDetailField.TIME, delta = 1, forDuringEnd = false)
        assertEquals(
            listOf(
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TIME,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
            ),
            next,
        )
    }

    @Test
    fun `越界移动与非法下标不改动`() {
        val state = LiveDisplayState()
        assertEquals(
            LiveDisplayLogic.defaultDetailFieldsForStage(false),
            LiveDisplayLogic.moveDetailFieldBy(state, LiveExpandedDetailField.TIME, delta = -1, forDuringEnd = false),
        )
        assertEquals(
            LiveDisplayLogic.defaultDetailFieldsForStage(false),
            LiveDisplayLogic.reorderDetailField(state, oldIndex = 9, newIndex = 0, forDuringEnd = false),
        )
    }

    @Test
    fun `恢复默认返回 null`() {
        assertNull(LiveDisplayLogic.resetDetailFields())
    }

    // ── 5. 显示内容副标题 / 置灰 / 快捷操作 ──

    @Test
    fun `课程名与地点重复提示只在开左侧图标且内容含之出现`() {
        val base = LiveDisplayState(enableMiuiIslandLabelImage = false)
        assertFalse(LiveDisplayLogic.showCourseNameDuplicatedHint(base))
        assertFalse(LiveDisplayLogic.showLocationDuplicatedHint(base))

        val courseLabel = base.copy(
            enableMiuiIslandLabelImage = true,
            miuiIslandLabelContent = MiuiIslandLabelContent.COURSE_NAME,
        )
        assertTrue(LiveDisplayLogic.showCourseNameDuplicatedHint(courseLabel))
        assertFalse(LiveDisplayLogic.showLocationDuplicatedHint(courseLabel))

        val both = base.copy(
            enableMiuiIslandLabelImage = true,
            miuiIslandLabelContent = MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION,
        )
        assertTrue(LiveDisplayLogic.showCourseNameDuplicatedHint(both))
        assertTrue(LiveDisplayLogic.showLocationDuplicatedHint(both))
    }

    @Test
    fun `阶段文案行倒计时开启时置灰 前缀行倒计时关闭时置灰`() {
        assertTrue(LiveDisplayLogic.shouldDimStageText(LiveDisplayState(showCountdown = true)))
        assertFalse(LiveDisplayLogic.shouldDimStageText(LiveDisplayState(showCountdown = false)))
        assertFalse(LiveDisplayLogic.shouldDimHidePrefix(LiveDisplayState(showCountdown = true)))
        assertTrue(LiveDisplayLogic.shouldDimHidePrefix(LiveDisplayState(showCountdown = false)))
    }

    @Test
    fun `快捷操作免打扰权限判定与 Flutter 一致`() {
        assertFalse(LiveDisplayLogic.requiresDoNotDisturbAccess(LiveBeforeClassQuickAction.NONE))
        assertFalse(LiveDisplayLogic.requiresDoNotDisturbAccess(LiveBeforeClassQuickAction.SILENT))
        assertTrue(LiveDisplayLogic.requiresDoNotDisturbAccess(LiveBeforeClassQuickAction.DO_NOT_DISTURB))
        assertTrue(LiveDisplayLogic.requiresDoNotDisturbAccess(LiveBeforeClassQuickAction.PRIORITY_ONLY))
        assertTrue(LiveDisplayLogic.requiresDoNotDisturbAccess(LiveBeforeClassQuickAction.BOTH))
    }

    @Test
    fun `自动执行分钟选项为 0 与 5 的倍数`() {
        assertEquals(listOf(0, 5, 10, 15, 20, 30), LiveDisplayLogic.quickActionAutoMinuteOptions())
    }

    @Test
    fun `六个色点且默认白在首位`() {
        assertEquals(6, LiveDisplayLogic.LABEL_COLORS.size)
        assertEquals("#FFFFFF", LiveDisplayLogic.LABEL_COLORS.first())
    }

    // ── 6. 状态变异与钳制 ──

    @Test
    fun `字号与偏移变异会钳制到合法区间`() {
        val s = LiveDisplayState()
        assertEquals(
            LiveDisplayLogic.LABEL_FONT_SIZE_MAX,
            s.withMiuiIslandLabelFontSize(999.0).miuiIslandLabelFontSize,
            0.0,
        )
        assertEquals(
            LiveDisplayLogic.LABEL_FONT_SIZE_MIN,
            s.withMiuiIslandLabelFontSize(-5.0).miuiIslandLabelFontSize,
            0.0,
        )
        assertEquals(
            LiveDisplayLogic.LABEL_OFFSET_MAX,
            s.withMiuiIslandLabelOffsetX(9.0).miuiIslandLabelOffsetX,
            0.0,
        )
        assertEquals(
            LiveDisplayLogic.LABEL_LOGO_CORNER_MAX,
            s.withMiuiIslandLabelLogoCornerRadius(99.0).miuiIslandLabelLogoCornerRadius,
            0.0,
        )
    }

    @Test
    fun `恢复默认回到全默认值`() {
        val changed = LiveDisplayState(showCountdown = false, useShortName = false, beforeClassQuickAction = LiveBeforeClassQuickAction.BOTH)
        assertEquals(LiveDisplayState(), changed.resetDisplayDefaults())
    }
}
