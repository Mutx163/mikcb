package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 四个后续弹层的预算逻辑单测。
 *
 * **期望值全部从 Dart 手推**（`lib/widgets/course_followup_sheets.dart`），不从实现里抄：
 * 每条的出处都写在断言上方，改判据先看那一行对应的 Dart 代码还在不在。
 */
class CourseFollowupModelTest {

    // ── 夹具 ──

    private val sectionTimes: List<SectionTime> = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("08:55", "09:40"),
        SectionTime("10:00", "10:45"),
        SectionTime("10:55", "11:40"),
    )

    private fun course(
        id: String = "c1",
        location: String = "三教-101",
        dayOfWeek: Int = 2,
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:40",
    ): Course = Course(
        id = id,
        name = "高等数学",
        teacher = "张老师",
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
    )

    private val weekdays = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    // ───────────────────────── 删除范围（Dart `:121-143`） ─────────────────────────

    @Test
    fun `本周有这门课时 两个删除选项都可用且副题带周次`() {
        val options = CourseFollowupModel.deleteScopeOptions(canDeleteOccurrence = true, week = 3)

        assertEquals(2, options.size)
        // 第一项：Dart 删掉了原来那句副标题，所以这里必须是空串，不是 null、不是随便一句
        assertEquals(CourseDeleteScope.WHOLE_COURSE, options[0].scope)
        assertEquals("删这个课", options[0].title)
        assertEquals("", options[0].subtitle)
        assertTrue(options[0].enabled)

        // 第二项：`deleteModeHintCurrentWeek(3)`
        assertEquals(CourseDeleteScope.THIS_WEEK, options[1].scope)
        assertEquals("删这节课", options[1].title)
        assertEquals("删除课程将移除全部周次，仅删除此节仅移除第 3 周课程", options[1].subtitle)
        assertTrue(options[1].enabled)
    }

    @Test
    fun `本周没有这门课时 只删这节课置灰并解释`() {
        val options = CourseFollowupModel.deleteScopeOptions(canDeleteOccurrence = false, week = 7)

        // Dart `:139-142`：enabled: canDeleteOccurrence，onTap 为 null
        assertFalse(options[1].enabled)
        assertEquals("当前卡片不是第 7 周的实际排课，所以只能删除整条排课", options[1].subtitle)
        // 「删这个课」不受影响 —— 删整门永远可用
        assertTrue(options[0].enabled)
        assertEquals("", options[0].subtitle)
    }

    // ───────────────────────── 停课范围（Dart `:180-202`） ─────────────────────────

    @Test
    fun `都没停课时两项都是停课文案`() {
        val options = CourseFollowupModel.suspendScopeOptions(
            suspendedThisWeek = false,
            hasAnySuspended = false,
        )

        assertEquals(2, options.size)
        assertEquals(CourseSuspendScope.THIS_WEEK, options[0].scope)
        assertEquals("停本周", options[0].title)
        assertEquals("仅暂停当前周", options[0].subtitle)
        assertFalse(options[0].resuming)

        assertEquals(CourseSuspendScope.ALL_WEEKS, options[1].scope)
        assertEquals("全部停", options[1].title)
        assertEquals("暂停所有周次", options[1].subtitle)
        assertFalse(options[1].resuming)
    }

    @Test
    fun `本周已停课时第一项变成恢复 第二项仍可停全部`() {
        val options = CourseFollowupModel.suspendScopeOptions(
            suspendedThisWeek = true,
            hasAnySuspended = false,
        )

        assertEquals("恢复", options[0].title)
        // Dart 的副标题不跟着切：本周那一项始终是 suspendThisWeekDesc
        assertEquals("仅暂停当前周", options[0].subtitle)
        assertTrue(options[0].resuming)

        assertEquals("全部停", options[1].title)
        assertEquals("暂停所有周次", options[1].subtitle)
        assertFalse(options[1].resuming)
    }

    @Test
    fun `有任一周被停课时第二项变成恢复全部`() {
        val options = CourseFollowupModel.suspendScopeOptions(
            suspendedThisWeek = true,
            hasAnySuspended = true,
        )

        assertEquals("恢复", options[0].title)
        assertEquals("恢复全部", options[1].title)
        assertEquals("恢复所有周次", options[1].subtitle)
        assertTrue(options[1].resuming)
    }

    @Test
    fun `本周没停但别的周停过时 第一项仍是停本周 第二项是恢复全部`() {
        // 这是 Dart 的真实组合：本周没停、但历史上停过别的周
        val options = CourseFollowupModel.suspendScopeOptions(
            suspendedThisWeek = false,
            hasAnySuspended = true,
        )

        assertEquals("停本周", options[0].title)
        assertFalse(options[0].resuming)
        assertEquals("恢复全部", options[1].title)
        assertTrue(options[1].resuming)
    }

    // ───────────────────────── 调课：变化判据（Dart `:399-406`） ─────────────────────────

    @Test
    fun `原位置不动时没有变化`() {
        val draft = CourseRescheduleDraft.initial(course(), sourceWeek = 3)

        assertFalse(draft.hasChanges(course(), sourceWeek = 3))
    }

    @Test
    fun `只改地点也算变化`() {
        // 这一条是旧 Compose 版的病根：地点被漏在判据之外，「只改地点」时确认永远置灰
        val draft = CourseRescheduleDraft.initial(course(), sourceWeek = 3)
            .withLocation("四教-202")

        assertTrue(draft.hasChanges(course(), sourceWeek = 3))
    }

    @Test
    fun `地点两侧空白不算变化`() {
        // Dart 两边都 trim 再比
        val draft = CourseRescheduleDraft.initial(course(location = "三教-101"), sourceWeek = 3)
            .withLocation("  三教-101  ")

        assertFalse(draft.hasChanges(course(location = "三教-101"), sourceWeek = 3))
    }

    @Test
    fun `周次 星期 起止节次 任一项变化都算变化`() {
        val base = CourseRescheduleDraft.initial(course(), sourceWeek = 3)

        assertTrue(base.withWeek(4).hasChanges(course(), sourceWeek = 3))
        assertTrue(base.withDayOfWeek(5).hasChanges(course(), sourceWeek = 3))
        assertTrue(base.withStartSection(3).hasChanges(course(), sourceWeek = 3))
        assertTrue(base.withEndSection(3).hasChanges(course(), sourceWeek = 3))
    }

    // ───────────────────────── 调课：节次夹取（Dart `:663-669` / `:682-690`） ─────────────────────────

    @Test
    fun `开始节次往后挪时结束节次被顶上去`() {
        val draft = CourseRescheduleDraft(
            targetWeek = 3,
            targetDayOfWeek = 2,
            targetStartSection = 1,
            targetEndSection = 2,
            targetLocation = "三教-101",
        ).withStartSection(4)

        assertEquals(4, draft.targetStartSection)
        assertEquals(4, draft.targetEndSection)
    }

    @Test
    fun `开始节次在前时结束节次不受影响`() {
        val draft = CourseRescheduleDraft(
            targetWeek = 3,
            targetDayOfWeek = 2,
            targetStartSection = 1,
            targetEndSection = 4,
            targetLocation = "三教-101",
        ).withStartSection(2)

        assertEquals(2, draft.targetStartSection)
        assertEquals(4, draft.targetEndSection)
    }

    @Test
    fun `结束节次不能小于开始节次 非法值原样保留`() {
        val draft = CourseRescheduleDraft(
            targetWeek = 3,
            targetDayOfWeek = 2,
            targetStartSection = 3,
            targetEndSection = 4,
            targetLocation = "三教-101",
        ).withEndSection(1)

        assertEquals(3, draft.targetStartSection)
        assertEquals(4, draft.targetEndSection)
    }

    @Test
    fun `clamped 只在倒挂时改结束节次`() {
        val inverted = CourseRescheduleDraft(3, 2, 5, 4, "")
        assertEquals(5, inverted.clamped().targetEndSection)

        val normal = CourseRescheduleDraft(3, 2, 2, 4, "")
        assertEquals(normal, normal.clamped())
    }

    // ───────────────────────── 调课：周次步进（Dart `:507-419`） ─────────────────────────

    @Test
    fun `可选周次是 1 到 weekCount`() {
        assertEquals((1..16).toList(), CourseRescheduleDraft.weekOptions(16))
        assertEquals(listOf(1), CourseRescheduleDraft.weekOptions(1))
        assertEquals(emptyList<Int>(), CourseRescheduleDraft.weekOptions(0))
    }

    @Test
    fun `步进到两端时不动也不越界`() {
        val first = CourseRescheduleDraft.initial(course(), sourceWeek = 1)
        assertFalse(first.canDecrementWeek(16))
        assertEquals(1, first.previousWeek(16).targetWeek)
        assertTrue(first.canIncrementWeek(16))
        assertEquals(2, first.nextWeek(16).targetWeek)

        val last = CourseRescheduleDraft.initial(course(), sourceWeek = 16)
        assertFalse(last.canIncrementWeek(16))
        assertEquals(16, last.nextWeek(16).targetWeek)
        assertEquals(15, last.previousWeek(16).targetWeek)
    }

    // ───────────────────────── 调课：可选节次（Dart `:324-335`） ─────────────────────────

    @Test
    fun `节次选项覆盖整张节次表`() {
        val options = CourseRescheduleDraft.startSectionOptions(sectionTimes, course())

        assertEquals(listOf(1, 2, 3, 4), options)
    }

    @Test
    fun `课程自己的幻影节次也必须出现在选项里`() {
        // Dart 注释 `:321-323`：节次越出自己模板的课，若被范围卡掉，结束节次候选会空、
        // 当前值也显示不出来
        val phantom = course(startSection = 13, endSection = 14, startTime = "20:00", endTime = "21:40")

        assertEquals(
            listOf(1, 2, 3, 4, 13, 14),
            CourseRescheduleDraft.startSectionOptions(sectionTimes, phantom),
        )
    }

    @Test
    fun `节次表为空时只剩课程自己的两个节次`() {
        // 与 Dart 的已知差异：Dart 退回 settings.sectionCount，这里没有 settings
        assertEquals(
            listOf(1, 2),
            CourseRescheduleDraft.startSectionOptions(emptyList(), course()),
        )
    }

    @Test
    fun `结束节次候选不早于开始节次`() {
        assertEquals(
            listOf(3, 4),
            CourseRescheduleDraft.endSectionOptions(sectionTimes, course(), startSection = 3),
        )
        assertEquals(
            listOf(1, 2, 3, 4),
            CourseRescheduleDraft.endSectionOptions(sectionTimes, course(), startSection = 1),
        )
    }

    // ───────────────────────── 调课：目标时段（Dart `:368-380`） ─────────────────────────

    @Test
    fun `节次区间取首节开始与末节结束`() {
        assertEquals(
            "08:00-09:40",
            CourseRescheduleDraft.timeRangeForSections(sectionTimes, 1, 2),
        )
        assertEquals(
            "10:00-11:40",
            CourseRescheduleDraft.timeRangeForSections(sectionTimes, 3, 4),
        )
    }

    @Test
    fun `越界与倒挂的节次区间算不出来`() {
        assertNull(CourseRescheduleDraft.timeRangeForSections(sectionTimes, 0, 1))
        assertNull(CourseRescheduleDraft.timeRangeForSections(sectionTimes, 1, 5))
        assertNull(CourseRescheduleDraft.timeRangeForSections(sectionTimes, 3, 2))
        assertNull(CourseRescheduleDraft.timeRangeForSections(emptyList(), 1, 1))
    }

    // ───────────────────────── 调课：行文案（Dart `:382-397`） ─────────────────────────

    @Test
    fun `发生行是 周次 星期 节次 钟点 四段`() {
        assertEquals(
            "第 3 周 · 周二 · 第 1 节-第 2 节 · 08:00-09:40",
            CourseRescheduleDraft.occurrenceLine(
                weekdayLabels = weekdays,
                week = 3,
                dayOfWeek = 2,
                startSection = 1,
                endSection = 2,
                startTime = "08:00",
                endTime = "09:40",
                sectionTimes = sectionTimes,
            ),
        )
    }

    @Test
    fun `星期标签越界时退化成数字`() {
        assertEquals("9", CourseRescheduleDraft.weekdayLabel(weekdays, 9))
        assertEquals("0", CourseRescheduleDraft.weekdayLabel(weekdays, 0))
        assertEquals("周日", CourseRescheduleDraft.weekdayLabel(weekdays, 7))
    }

    @Test
    fun `节次表算不出钟点时退回课程自己的钟点`() {
        // Dart `?? '$startTime-$endTime'`：不是空白，是原课钟点
        assertEquals(
            "第 3 周 · 周二 · 第 13 节-第 14 节 · 20:00-21:40",
            CourseRescheduleDraft.occurrenceLine(
                weekdayLabels = weekdays,
                week = 3,
                dayOfWeek = 2,
                startSection = 13,
                endSection = 14,
                startTime = "20:00",
                endTime = "21:40",
                sectionTimes = sectionTimes,
            ),
        )
    }

    // ───────────────────────── 调课：渲染数据（Dart `build()` `:503-733`） ─────────────────────────

    @Test
    fun `刚打开时没有变化 确认不可点且不显示目标预览`() {
        val course = course()
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3)
        val view = draft.presentation(
            course = course,
            sourceWeek = 3,
            weekCount = 16,
            weekdayLabels = weekdays,
            sectionTimes = sectionTimes,
        )

        assertEquals("调本周这节课", view.title)
        assertEquals("仅改第 3 周本节，原课该周移除，其他周不变", view.subtitle)
        // Dart `:585`：'${currentBadge}：$sourceLine'
        assertEquals("当前：第 3 周 · 周二 · 第 1 节-第 2 节 · 08:00-09:40", view.currentLine)
        assertEquals("地点：三教-101", view.currentLocationLine)
        assertFalse(view.showTargetPreview)
        assertFalse(view.canConfirm)
        assertEquals("08:00-09:40", view.targetTimeRange)
        assertEquals("上课地点", view.locationField.label)
        assertEquals("三教-101", view.locationField.value)
        assertFalse(view.locationIsPlaceholder)
    }

    @Test
    fun `目标周字段列出 1 到 weekCount 且选中当前目标`() {
        val course = course()
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3).withWeek(5)
        val view = draft.presentation(course, 3, 16, weekdays, sectionTimes)

        assertEquals("调到第几周", view.weekField.label)
        assertEquals("第 5 周", view.weekField.value)
        assertEquals(16, view.weekField.options.size)
        assertEquals("第 1 周", view.weekField.options.first().label)
        assertEquals("第 16 周", view.weekField.options.last().label)
        assertFalse(view.weekField.options.first().selected)
        assertTrue(view.weekField.options.first { it.value == 5 }.selected)
        // 只在目标周为 5 时为真 —— 逐条核一遍，防止 selected 判据写反
        assertEquals(
            listOf(5),
            view.weekField.options.filter { it.selected }.map { it.value },
        )
    }

    @Test
    fun `改了就显示目标预览且确认可点`() {
        val course = course()
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3).withWeek(4).withDayOfWeek(4)
        val view = draft.presentation(course, 3, 16, weekdays, sectionTimes)

        assertTrue(view.showTargetPreview)
        assertTrue(view.canConfirm)
        assertEquals("→ 第 4 周 · 周四 · 第 1 节-第 2 节 · 08:00-09:40", view.targetLine)
        assertEquals("地点：三教-101", view.targetLocationLine)
    }

    @Test
    fun `地点清空后显示手动填写占位 且不画地点行`() {
        val course = course()
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3).withLocation("")
        val view = draft.presentation(course, 3, 16, weekdays, sectionTimes)

        assertEquals("手动填写", view.locationField.value)
        assertTrue(view.locationIsPlaceholder)
        // Dart `:721-729`：地点空时「地点：…」整行不画
        assertNull(view.targetLocationLine)
        // 地点也算变化 ⇒ 清空同样要能确认
        assertTrue(view.canConfirm)
    }

    @Test
    fun `原地点为空时当前地点行不画`() {
        val course = course(location = "")
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3)
        val view = draft.presentation(course, 3, 16, weekdays, sectionTimes)

        assertNull(view.currentLocationLine)
        assertEquals("手动填写", view.locationField.value)
        assertTrue(view.locationIsPlaceholder)
    }

    @Test
    fun `结束节次候选随开始节次收窄 且目标时段跟着算`() {
        val course = course()
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3)
            .withStartSection(3)
            .withEndSection(4)
        val view = draft.presentation(course, 3, 16, weekdays, sectionTimes)

        assertEquals("第 3 节", view.startSectionField.value)
        assertEquals("第 4 节", view.endSectionField.value)
        assertEquals(
            listOf(3, 4),
            view.endSectionField.options.map { it.value },
        )
        assertEquals("10:00-11:40", view.targetTimeRange)
        assertEquals(7, view.weekdayLabels.size)
        assertEquals(2, view.selectedDayOfWeek)
    }

    @Test
    fun `节次越界时目标时段整个不显示`() {
        val phantom = course(startSection = 13, endSection = 14, startTime = "20:00", endTime = "21:40")
        val draft = CourseRescheduleDraft.initial(phantom, sourceWeek = 3)
        val view = draft.presentation(phantom, 3, 16, weekdays, sectionTimes)

        assertNull(view.targetTimeRange)
        // 但预览行仍然可用：退回原课钟点（Dart 的 `??` 口径）
        assertEquals("→ 第 3 周 · 周二 · 第 13 节-第 14 节 · 20:00-21:40", view.targetLine)
    }

    @Test
    fun `出口目标与草稿字段一一对应`() {
        val draft = CourseRescheduleDraft.initial(course(), sourceWeek = 3)
            .withWeek(6)
            .withDayOfWeek(5)
            .withStartSection(2)
            .withEndSection(3)
            .withLocation(" 四教-202 ")

        assertEquals(
            CourseRescheduleTarget(
                targetWeek = 6,
                targetDayOfWeek = 5,
                targetStartSection = 2,
                targetEndSection = 3,
                // 原样带出去（Dart pop 的是 controller.text，未 trim）
                targetLocation = " 四教-202 ",
            ),
            draft.toTarget(),
        )
    }

    @Test
    fun `星期注入用调用方给的列表 不自己造`() {
        val course = course()
        val draft = CourseRescheduleDraft.initial(course, sourceWeek = 3)
        val custom = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        val view = draft.presentation(course, 3, 16, custom, sectionTimes)

        assertEquals(custom, view.weekdayLabels)
        assertEquals("当前：第 3 周 · Tue · 第 1 节-第 2 节 · 08:00-09:40", view.currentLine)
    }
}
