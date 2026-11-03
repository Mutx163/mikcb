package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 试弹触发管线纯逻辑的 JVM 单测（源：`lib/services/live_testing_trigger.dart`）。
 *
 * 期望值全部手推：窗口算术、载荷契约（逐键比对 `buildServiceIntentFromMethodPayload`
 * 的读取口径）、会话惰性过期、设置指纹、四条选课规则、快照结构。
 */
class LiveCourseTestTriggerTest {

    private val minute = 60_000L
    private val second = 1_000L

    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        dayOfWeek: Int = 3,
        startSection: Int = 2,
        startTime: String = "10:00",
        endTime: String = "11:40",
        shortName: String? = "高数",
        note: String? = null,
        description: String? = null,
        endWeek: Int = 16,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = "张老师",
        location = "教一 101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = startSection,
        startTime = startTime,
        endTime = endTime,
        note = note,
        description = description,
        endWeek = endWeek,
    )

    // ───────────────── 合成时间窗 ─────────────────

    @Test
    fun classicBeforeClassWindowIsThreePlusThreeMinutes() {
        val window = buildCourseTestWindow(0L, LiveCourseTestStage.BEFORE_CLASS, null)
        assertEquals(3 * minute, window.startMillis)
        assertEquals(6 * minute, window.endMillis)
        // 3 分钟窗口 ≥ 1 分钟：钟面终点就是真实终点
        assertEquals(6 * minute, window.clockEndMillis)
        assertEquals(20 * second, window.suspendBufferMillis)
    }

    @Test
    fun classicDuringClassWindowAnchorsOneMinuteAgo() {
        val window = buildCourseTestWindow(0L, LiveCourseTestStage.DURING_CLASS, null)
        assertEquals(-minute, window.startMillis)
        assertEquals(4 * minute, window.endMillis)
        assertEquals(20 * second, window.suspendBufferMillis)
    }

    @Test
    fun quickBeforeClassWindowLocksSingleStage() {
        val window = buildCourseTestWindow(0L, LiveCourseTestStage.BEFORE_CLASS, 30 * second)
        assertEquals(29 * second, window.startMillis)
        assertEquals(30 * second, window.endMillis)
        // 1 秒窗口 < 1 分钟：钟面终点拉到 start+1min，避免零时长观感
        assertEquals(89 * second, window.clockEndMillis)
        assertEquals(second, window.suspendBufferMillis)
    }

    @Test
    fun quickDuringClassWindowStartsTwoSecondsAgo() {
        val window = buildCourseTestWindow(0L, LiveCourseTestStage.DURING_CLASS, 30 * second)
        assertEquals(-2 * second, window.startMillis)
        assertEquals(30 * second, window.endMillis)
        // 32 秒窗口 < 1 分钟：钟面终点 = start + 1min
        assertEquals(58 * second, window.clockEndMillis)
        assertEquals(second, window.suspendBufferMillis)
    }

    // ───────────────── 会话槽 ─────────────────

    @Test
    fun sessionExpiresLazilyAndClearsSlot() {
        LiveCourseTestSessions.clear()
        try {
            LiveCourseTestSessions.install(
                LiveCourseTestSession(
                    stage = LiveCourseTestStage.BEFORE_CLASS,
                    courseName = "高数",
                    course = course(),
                    sessionEndMillis = 100L,
                    startMillis = 0L,
                    endMillis = 90L,
                    clockEndMillis = 90L,
                ),
                signature = "sig-1",
            )
            assertEquals("sig-1", LiveCourseTestSessions.signature())
            assertEquals("高数", LiveCourseTestSessions.current(50L)?.courseName)
            // 过终点 → 惰性清槽，指纹一并失效
            assertNull(LiveCourseTestSessions.current(101L))
            assertNull(LiveCourseTestSessions.signature())
            assertNull(LiveCourseTestSessions.current(200L))
        } finally {
            LiveCourseTestSessions.clear()
        }
    }

    @Test
    fun newSessionReplacesOldAndClearWipesBoth() {
        LiveCourseTestSessions.clear()
        try {
            LiveCourseTestSessions.install(
                LiveCourseTestSession(
                    LiveCourseTestStage.BEFORE_CLASS, "旧课", null, 10_000L, 0L, 9_000L, 9_000L,
                ),
                "sig-old",
            )
            LiveCourseTestSessions.install(
                LiveCourseTestSession(
                    LiveCourseTestStage.DURING_CLASS, "新课", null, 20_000L, 0L, 19_000L, 19_000L,
                ),
                "sig-new",
            )
            assertEquals("新课", LiveCourseTestSessions.current(0L)?.courseName)
            LiveCourseTestSessions.clear()
            assertNull(LiveCourseTestSessions.current(0L))
            assertNull(LiveCourseTestSessions.signature())
        } finally {
            LiveCourseTestSessions.clear()
        }
    }

    // ───────────────── 设置指纹 ─────────────────

    @Test
    fun signatureChangesOnlyWhenIslandRenderingFieldsChange() {
        val base = LiveDisplayState()
        val same = computeTestSessionSettingsSignature(LiveCourseTestStage.BEFORE_CLASS, base)
        assertEquals(same, computeTestSessionSettingsSignature(LiveCourseTestStage.BEFORE_CLASS, base))

        // 影响渲染的字段变了 → 指纹必须变
        assertTrue(
            same != computeTestSessionSettingsSignature(
                LiveCourseTestStage.BEFORE_CLASS,
                base.copy(showCountdown = false),
            ),
        )
        assertTrue(
            same != computeTestSessionSettingsSignature(
                LiveCourseTestStage.BEFORE_CLASS,
                base.copy(miuiIslandLabelFontColor = "#FF0000"),
            ),
        )
        assertTrue(
            same != computeTestSessionSettingsSignature(
                LiveCourseTestStage.BEFORE_CLASS,
                base.copy(beforeClassQuickAction = LiveBeforeClassQuickAction.DO_NOT_DISTURB),
            ),
        )
        // 阶段本身也在指纹里
        assertTrue(
            same != computeTestSessionSettingsSignature(LiveCourseTestStage.DURING_CLASS, base),
        )
    }

    // ───────────────── 下发载荷 ─────────────────

    @Test
    fun payloadBeforeClassForcesStageSwitchesOpen() {
        val payload = buildCourseTestPayload(
            stage = LiveCourseTestStage.BEFORE_CLASS,
            course = course(note = null, description = "带上课本"),
            nextCourse = null,
            startMillis = 180 * second,
            endMillis = 360 * second,
            beforeClassLeadMillis = 180 * second,
            display = LiveDisplayState(),
            progressBreakOffsetsMillis = listOf(1L),
            progressMilestoneLabels = listOf("节点"),
            progressMilestoneTimeTexts = listOf("10:30"),
        )

        assertEquals("beforeClass", payload["stage"])
        assertEquals(false, payload["validateAgainstSchedule"])
        assertEquals(180_000L, payload["beforeClassLeadMillis"])
        assertEquals(0L, payload["endReminderLeadMillis"])
        // 课前档：课前开、课中关、提升关
        assertEquals(true, payload["enableBeforeClass"])
        assertEquals(false, payload["enableDuringClass"])
        assertEquals(false, payload["promoteDuringClass"])
        assertEquals(false, payload["showNotificationDuringClass"])
        assertEquals(false, payload["enableBeforeEnd"])
        // 课前档带用户的快捷动作选择（默认 NONE → "none"）
        assertEquals("none", payload["beforeClassQuickAction"])

        val current = payload["currentCourse"] as Map<*, *>
        assertEquals("高等数学", current["name"])
        assertEquals("高数", current["shortName"])
        // liveNote：note 空、description 有值 → 下发 description（与 Dart liveNote 同源）
        assertEquals("带上课本", current["note"])
        assertEquals(setOf("name", "shortName", "teacher", "location", "note", "startTime", "endTime"), current.keys)

        // 下一节为 null 时载荷不带这个键（解析侧按缺失跳行）
        assertFalse(payload.containsKey("nextCourse"))

        val island = payload["islandConfig"] as Map<*, *>
        assertEquals(true, island["showCourseName"])
        assertEquals(true, island["showLocation"])
        assertEquals(true, island["useShortName"])
        assertEquals("nearest", island["duringClassTimeDisplayMode"])
        assertEquals("#FFFFFF", island["miuiIslandLabelFontColor"])
        // 默认（未自定义）展开字段为 null → 键缺省，解析侧按「全部显示」兜
        assertFalse(island.containsKey("expandedDetailFields"))
        assertEquals(listOf(1L), payload["progressBreakOffsetsMillis"])
        assertEquals(listOf("节点"), payload["progressMilestoneLabels"])
        assertEquals(listOf("10:30"), payload["progressMilestoneTimeTexts"])
    }

    @Test
    fun payloadDuringClassCarriesUserQuickActionOnlyInBeforeStage() {
        val display = LiveDisplayState(
            beforeClassQuickAction = LiveBeforeClassQuickAction.DO_NOT_DISTURB,
            beforeClassQuickActionAutoMinutes = 10,
            showCountdown = false,
            expandedDetailFields = listOf(LiveExpandedDetailField.TIME, LiveExpandedDetailField.NOTE),
        )
        val during = buildCourseTestPayload(
            LiveCourseTestStage.DURING_CLASS,
            course(),
            course(id = "c2", name = "大学英语", startSection = 3, startTime = "13:00", endTime = "14:40"),
            startMillis = -60 * second,
            endMillis = 240 * second,
            beforeClassLeadMillis = 0,
            display = display,
            progressBreakOffsetsMillis = emptyList(),
            progressMilestoneLabels = emptyList(),
            progressMilestoneTimeTexts = emptyList(),
        )
        assertEquals("duringClass", during["stage"])
        assertEquals(true, during["enableDuringClass"])
        assertEquals(false, during["enableBeforeClass"])
        assertEquals(true, during["promoteDuringClass"])
        // 课中档不带快捷动作（Dart 同口径：only isBeforeClass 才传用户选择）
        assertEquals("none", during["beforeClassQuickAction"])
        assertEquals(10, during["beforeClassQuickActionAutoMinutes"])

        val next = during["nextCourse"] as Map<*, *>
        assertEquals("大学英语", next["name"])

        val island = during["islandConfig"] as Map<*, *>
        assertEquals(listOf("time", "note"), island["expandedDetailFields"])
    }

    // ───────────────── 下一节解析 ─────────────────

    @Test
    fun nextCourseFollowsSameDaySectionOrder() {
        val monday = course(id = "a", name = "第一节", dayOfWeek = 1, startSection = 1)
        val mondayLate = course(id = "b", name = "第三节", dayOfWeek = 1, startSection = 3)
        val tuesday = course(id = "c", name = "周二课", dayOfWeek = 2, startSection = 1)
        val courses = listOf(mondayLate, tuesday, monday)

        assertEquals(mondayLate, resolveNextCourseForTest(courses, monday, calendarWeek = 5))
        assertNull(resolveNextCourseForTest(courses, mondayLate, calendarWeek = 5))
        // 超出周次有效范围的课不参与
        val expired = course(id = "d", name = "已结课", dayOfWeek = 1, startSection = 5, endWeek = 2)
        assertNull(resolveNextCourseForTest(listOf(expired), monday, calendarWeek = 5))
    }

    // ───────────────── 试弹选课 ─────────────────

    @Test
    fun previewPrefersCurrentSelection() {
        val selected = course(id = "sel")
        assertEquals(
            selected,
            resolveLivePreviewTestCourse(
                courses = listOf(course(id = "other")),
                calendarWeek = 5,
                semesterWeekCount = 16,
                now = LocalDateTime.of(2026, 11, 3, 10, 0),
                currentSelection = selected,
            ),
        )
    }

    @Test
    fun previewScansNearestFutureCourseAcrossDays() {
        val now = LocalDateTime.of(2026, 11, 3, 12, 0) // 周二
        val tomorrow = course(id = "tomorrow", name = "明早课", dayOfWeek = 3, startTime = "08:00", endTime = "09:40")
        val laterToday = course(id = "today", name = "今天稍晚", dayOfWeek = 2, startTime = "14:00", endTime = "15:40")
        assertEquals(
            laterToday,
            resolveLivePreviewTestCourse(listOf(tomorrow, laterToday), calendarWeek = 5, semesterWeekCount = 16, now = now, currentSelection = null),
        )
    }

    @Test
    fun previewFallsBackToShortNamedCourseWhenAllPast() {
        // 两门课都在「今天早上」（now 为当天 20:00）→ 规则 2 扫不到未来课
        val now = LocalDateTime.of(2026, 11, 3, 20, 0) // 周二
        val plain = course(id = "plain", name = "无简称", shortName = null, startTime = "08:00", endTime = "09:40", dayOfWeek = 2)
        val named = course(id = "named", name = "有简称", shortName = "简", startTime = "09:00", endTime = "10:40", dayOfWeek = 2)
        assertEquals(
            named,
            resolveLivePreviewTestCourse(listOf(plain, named), calendarWeek = 5, semesterWeekCount = 16, now = now, currentSelection = null),
        )
    }

    @Test
    fun previewUsesPresetCourseWhenTimetableEmpty() {
        val preset = resolveLivePreviewTestCourse(
            courses = emptyList(),
            calendarWeek = 5,
            semesterWeekCount = 16,
            now = LocalDateTime.of(2026, 11, 3, 10, 0),
            currentSelection = null,
        )
        assertEquals("live_test_preset_a", preset.id)
        assertEquals("自检预设课 A", preset.name)
    }

    // ───────────────── 原生快照 ─────────────────

    @Test
    fun snapshotBuilderProducesNativeParserContract() {
        val json = LiveNativeSnapshotBuilder.buildJson(
            courses = listOf(course(description = "备好草稿纸")),
            settingsJson = mapOf("liveEnableBeforeClass" to true, "sections" to listOf(mapOf("startTime" to "08:00", "endTime" to "08:45"))),
            currentWeek = 7,
            semesterStartMillis = 1_700_000_000_000L,
        )
        val root = MiniJson.tryParse(json) as Map<*, *>
        // MiniJson round-trip 把整数变 Long，断言一律走 Number 归一。
        assertEquals(7, (root["currentWeek"] as Number).toInt())
        assertEquals(1_700_000_000_000L, (root["semesterStartMillis"] as Number).toLong())
        assertEquals(false, root["isHoliday"])

        val courses = root["courses"] as List<*>
        assertEquals(1, courses.size)
        val courseJson = courses[0] as Map<*, *>
        assertEquals("c1", courseJson["id"])
        assertEquals("高等数学", courseJson["name"])
        assertEquals("高数", courseJson["shortName"])
        // note = liveNote（description 兜底）
        assertEquals("备好草稿纸", courseJson["note"])

        val settings = root["settings"] as Map<*, *>
        assertEquals(true, settings["liveEnableBeforeClass"])
        assertEquals(1, (settings["liveExpandedDetailSchemaVersion"] as Number).toInt())
    }

    @Test
    fun snapshotBuilderOmitsSemesterStartWhenUnset() {
        val json = LiveNativeSnapshotBuilder.buildJson(
            courses = emptyList(),
            settingsJson = emptyMap(),
            currentWeek = 1,
            semesterStartMillis = null,
        )
        val root = MiniJson.tryParse(json) as Map<*, *>
        assertFalse(root.containsKey("semesterStartMillis"))
        assertTrue(root.containsKey("settings"))
    }
}
