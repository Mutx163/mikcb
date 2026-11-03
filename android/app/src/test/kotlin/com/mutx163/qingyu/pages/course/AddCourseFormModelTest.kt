package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.course.CourseDomain
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 加课表单模型层测试（P3-D1 · add_course_screen.dart / add_course_week_picker_tiles.dart）。
 *
 * 期望值全部从 Dart 源**手推**（`lib/screens/add_course_screen.dart` 的
 * `weeksFromRangeSelection` / `editableSectionNumbers` / `_ScheduleEntryData` /
 * `_selectedWeeksFor` / `_formatWeekList` / `_selectedWeeksSummaryText` / `_saveGroup`），
 * 不抄 Kotlin 实现。
 */
class AddCourseFormModelTest {

    private val availableWeeks20 = (1..20).toList()

    private fun testCourse(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "李老师",
        location: String = "教学楼101",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
        suspendedWeeks: List<Int>? = null,
        note: String? = null,
        sessionNotes: Map<Int, CourseSessionNote>? = null,
        timeSchemeIdOverride: String? = null,
        shortName: String? = null,
        hasCustomTime: Boolean = false,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = teacher,
        location = location,
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
        note = note,
        sessionNotes = sessionNotes,
        timeSchemeIdOverride = timeSchemeIdOverride,
        hasCustomTime = hasCustomTime,
    )

    /** 模拟渲染层 clockResolver：按 `CourseDomain.editCourseClock` 回传 hasCustomTime。 */
    private fun savePayload(original: Course): AddCourseSavePayload {
        val entry = AddCourseScheduleEntryData.fromCourse(original)
        return AddCourseFormLogic.buildSavePayload(
            initialCourse = original,
            courseGroup = null,
            name = original.name,
            shortName = "",
            description = "",
            color = original.color,
            courseNature = original.courseNature,
            entries = listOf(entry),
            clockResolver = { e ->
                val clock = CourseDomain.editCourseClock(
                    original = e.originalCourse,
                    startSection = e.startSection,
                    endSection = e.endSection,
                    templateStartTime = "08:00",
                    templateEndTime = "09:40",
                )
                AddCourseEntryClock(clock.startTime, clock.endTime, clock.hasCustomTime)
            },
        )
    }

    // ==========================================
    // 1. weeksFromRangeSelection（Dart 源 :39-56）
    // ==========================================
    @Test
    fun `范围全选不带单双周得到闭区间`() {
        assertEquals((1..16).toList(), AddCourseFormLogic.weeksFromRangeSelection(1, 16, false, false))
        assertEquals(listOf(3), AddCourseFormLogic.weeksFromRangeSelection(3, 3, false, false))
    }

    @Test
    fun `单周过滤掉偶数周`() {
        // Dart: if (isOddWeek && week.isEven) continue
        assertEquals(
            listOf(1, 3, 5, 7, 9, 11, 13, 15),
            AddCourseFormLogic.weeksFromRangeSelection(1, 16, isOddWeek = true, isEvenWeek = false),
        )
    }

    @Test
    fun `双周过滤掉奇数周`() {
        assertEquals(
            listOf(2, 4, 6, 8, 10, 12, 14, 16),
            AddCourseFormLogic.weeksFromRangeSelection(1, 16, isOddWeek = false, isEvenWeek = true),
        )
    }

    @Test
    fun `范围收在一周又勾了相反侧得空集`() {
        // 第 2 周 + 单周：2 是偶数被 isOddWeek 滤掉 -> 空集
        assertEquals(emptyList<Int>(), AddCourseFormLogic.weeksFromRangeSelection(2, 2, true, false))
        // 第 3 周 + 双周：3 是奇数被 isEvenWeek 滤掉 -> 空集
        assertEquals(emptyList<Int>(), AddCourseFormLogic.weeksFromRangeSelection(3, 3, false, true))
    }

    @Test
    fun `单周与双周同时勾上得空集`() {
        // 两个筛选条件按周逐个 continue，每一条都被某个条件滤掉
        assertEquals(emptyList<Int>(), AddCourseFormLogic.weeksFromRangeSelection(1, 16, true, true))
        assertEquals(emptyList<Int>(), AddCourseFormLogic.weeksFromRangeSelection(5, 10, true, true))
    }

    // ==========================================
    // 2. editableSectionNumbers（Dart 源 :80-96）
    // ==========================================

    @Test
    fun `节次候选默认跟全局节数`() {
        assertEquals((1..12).toList(), AddCourseFormLogic.editableSectionNumbers(12, null, 1, 2))
    }

    @Test
    fun `课程自己的模板节数优先于全局`() {
        assertEquals((1..10).toList(), AddCourseFormLogic.editableSectionNumbers(12, 10, 1, 2))
        assertEquals((1..14).toList(), AddCourseFormLogic.editableSectionNumbers(12, 14, 1, 2))
    }

    @Test
    fun `模板节数非法时回落全局`() {
        // courseSchemeSectionCount <= 0 -> 用 globalSectionCount
        assertEquals((1..12).toList(), AddCourseFormLogic.editableSectionNumbers(12, 0, 1, 2))
    }

    @Test
    fun `现存起止节次越出模板也要并入候选`() {
        // 课程钉着 12 节模板、现存第 14-15 节：候选 = 1..12 并上 {14,15}
        assertEquals(
            (1..12).toList() + listOf(14, 15),
            AddCourseFormLogic.editableSectionNumbers(12, 12, 14, 15),
        )
    }

    @Test
    fun `现存节次在模板内不产生重复`() {
        assertEquals((1..12).toList(), AddCourseFormLogic.editableSectionNumbers(12, null, 6, 8))
    }

    @Test
    fun `模板外只并入现存起止两个端点`() {
        // Dart add_course_screen.dart:92-93 只 add(currentStart)/add(currentEnd)，
        // 不把中间的 15..19 铺进候选。
        assertEquals(
            (1..12).toList() + listOf(14, 20),
            AddCourseFormLogic.editableSectionNumbers(12, 12, 14, 20),
        )
    }

    // ==========================================
    // 3. 条目 <-> Course 互转（_ScheduleEntryData.fromCourse / toCourse）
    // ==========================================

    @Test
    fun `带自定义周的课程转入条目为自定义模式`() {
        val course = testCourse(customWeeks = listOf(2, 4, 6), startWeek = 2, endWeek = 6)
        val entry = AddCourseScheduleEntryData.fromCourse(course)
        assertEquals(AddCourseWeekSelectionMode.CUSTOM, entry.weekSelectionMode)
        assertEquals(setOf(2, 4, 6), entry.selectedCustomWeeks)
        assertEquals(course, entry.originalCourse)
    }

    @Test
    fun `单双周课程转入条目为范围模式`() {
        val course = testCourse(isOddWeek = true, startWeek = 1, endWeek = 15)
        val entry = AddCourseScheduleEntryData.fromCourse(course)
        assertEquals(AddCourseWeekSelectionMode.RANGE, entry.weekSelectionMode)
        assertTrue(entry.selectedCustomWeeks.isEmpty())
        assertTrue(entry.isOddWeek)
        assertFalse(entry.isEvenWeek)
    }

    @Test
    fun `越界自定义周按 Dart 归一后再进编辑器`() {
        // Dart course.dart:169 用的是 normalizedCustomWeeks（丢越界/去重/升序），
        // 不是裸 customWeeks；否则表单会把 0/31/555 这类周次也画进勾选格。
        val mixed = testCourse(customWeeks = listOf(0, 2, 31, 40, 2))
        val entry = AddCourseScheduleEntryData.fromCourse(mixed)
        assertEquals(AddCourseWeekSelectionMode.CUSTOM, entry.weekSelectionMode)
        assertEquals(setOf(2), entry.selectedCustomWeeks)

        val allInvalid = testCourse(customWeeks = listOf(-3, 0, 31, 555))
        val fallback = AddCourseScheduleEntryData.fromCourse(allInvalid)
        assertEquals(AddCourseWeekSelectionMode.RANGE, fallback.weekSelectionMode)
        assertTrue(fallback.selectedCustomWeeks.isEmpty())
    }

    @Test
    fun `编辑自定义时间课保存后仍标记自定义时间`() {
        // 节次没动 → 保留适配脚本钉住的权威钟点（Dart :2022-2039 / course_domain.dart:137-148）。
        val original = testCourse(hasCustomTime = true)
        assertTrue(savePayload(original).courses.single().hasCustomTime)
    }

    @Test
    fun `编辑非自定义时间课保存后不标记自定义时间`() {
        val original = testCourse(hasCustomTime = false)
        assertFalse(savePayload(original).courses.single().hasCustomTime)
    }

    @Test
    fun `越界停课周按 Dart 归一后再进编辑器`() {
        // Dart add_course_screen.dart:185 用 normalizedSuspendedWeeks（丢越界/去重/升序）。
        val mixed = testCourse(suspendedWeeks = listOf(0, 3, 31, 3))
        val entry = AddCourseScheduleEntryData.fromCourse(mixed)
        assertEquals(listOf(3), entry.suspendedWeeks)

        val allInvalid = testCourse(suspendedWeeks = listOf(-1, 0, 31, 555))
        assertNull(AddCourseScheduleEntryData.fromCourse(allInvalid).suspendedWeeks)
    }

    @Test
    fun `条目转回课程保留全部字段`() {
        val entry = AddCourseScheduleEntryData(
            id = "e1",
            dayOfWeek = 3,
            startSection = 5,
            endSection = 6,
            teacher = "王老师",
            location = "A301",
            startWeek = 4,
            endWeek = 12,
            isOddWeek = true,
            isEvenWeek = false,
        )
        val course = entry.toCourse(
            name = "大学英语",
            color = "#2196F3",
            courseNature = CourseNature.ELECTIVE,
            startTime = "10:00",
            endTime = "11:40",
        )
        assertEquals("e1", course.id)
        assertEquals("大学英语", course.name)
        assertEquals("王老师", course.teacher)
        assertEquals("A301", course.location)
        assertEquals(3, course.dayOfWeek)
        assertEquals(5, course.startSection)
        assertEquals(6, course.endSection)
        assertEquals(4, course.startWeek)
        assertEquals(12, course.endWeek)
        assertTrue(course.isOddWeek)
        assertFalse(course.isEvenWeek)
        assertNull(course.customWeeks)
        assertEquals(CourseNature.ELECTIVE, course.courseNature)
        assertEquals("10:00", course.startTime)
        assertEquals("11:40", course.endTime)
    }

    @Test
    fun `自定义模式转课程用勾选集首末当起止周且清掉单双周`() {
        // Dart toCourse: customWeeks != null 时 startWeek/endWeek 取 first/last，
        // isOddWeek/isEvenWeek 强制 false
        val entry = AddCourseScheduleEntryData(
            id = "e2",
            weekSelectionMode = AddCourseWeekSelectionMode.CUSTOM,
            selectedCustomWeeks = setOf(9, 3, 5),
            startWeek = 1,
            endWeek = 16,
            isOddWeek = true,
        )
        val course = entry.toCourse(
            name = "体育",
            color = "#0EA5E9",
            courseNature = CourseNature.REQUIRED,
            startTime = "14:00",
            endTime = "15:40",
        )
        assertEquals(listOf(3, 5, 9), course.customWeeks)
        assertEquals(3, course.startWeek)
        assertEquals(9, course.endWeek)
        assertFalse(course.isOddWeek)
        assertFalse(course.isEvenWeek)
    }

    @Test
    fun `自定义模式下勾选集为空则回落范围字段`() {
        // Dart: selectedCustomWeeks.isNotEmpty 判据，空集时 customWeeks = null
        val entry = AddCourseScheduleEntryData(
            id = "e3",
            weekSelectionMode = AddCourseWeekSelectionMode.CUSTOM,
            selectedCustomWeeks = emptySet(),
            startWeek = 2,
            endWeek = 8,
            isOddWeek = false,
            isEvenWeek = true,
        )
        val course = entry.toCourse(
            name = "选修",
            color = "#2196F3",
            courseNature = CourseNature.REQUIRED,
            startTime = "08:00",
            endTime = "09:40",
        )
        assertNull(course.customWeeks)
        assertEquals(2, course.startWeek)
        assertEquals(8, course.endWeek)
        assertTrue(course.isEvenWeek)
    }

    @Test
    fun `停课周与按周备注原样穿透`() {
        val notes = mapOf(3 to CourseSessionNote(text = "第三章答疑", hasHomework = true))
        val course = testCourse(
            suspendedWeeks = listOf(5, 9),
            sessionNotes = notes,
            timeSchemeIdOverride = "scheme-x",
        )
        val entry = AddCourseScheduleEntryData.fromCourse(course)
        assertEquals(listOf(5, 9), entry.suspendedWeeks)
        assertEquals(notes, entry.sessionNotes)
        assertEquals("scheme-x", entry.timeSchemeIdOverride)
        val rebuilt = entry.toCourse(
            name = course.name,
            color = course.color,
            courseNature = CourseNature.REQUIRED,
            startTime = "08:00",
            endTime = "09:40",
        )
        assertEquals(listOf(5, 9), rebuilt.suspendedWeeks)
        assertEquals(notes, rebuilt.sessionNotes)
        assertEquals("scheme-x", rebuilt.timeSchemeIdOverride)
    }

    @Test
    fun `hasCustomTime 由钟点解析方决定写入课程`() {
        val entry = AddCourseScheduleEntryData(id = "e4")
        val course = entry.toCourse(
            name = "早读",
            color = "#2196F3",
            courseNature = CourseNature.REQUIRED,
            startTime = "07:00",
            endTime = "07:40",
            hasCustomTime = true,
        )
        assertTrue(course.hasCustomTime)
    }

    // ==========================================
    // 4. 表单初始状态（initState 三分支，Dart 源 :291-340）
    // ==========================================

    @Test
    fun `纯新建走默认条目且初始参数全部生效`() {
        val init = AddCourseFormLogic.buildInitialState(
            initialWeek = 8,
            initialDayOfWeek = 3,
            initialStartSection = 5,
        )
        assertTrue(init.isCreatingNewCourse)
        assertEquals(1, init.entries.size)
        val entry = init.entries.single()
        assertEquals(3, entry.dayOfWeek)
        assertEquals(5, entry.startSection)
        // initialEndSection 缺省 = initialStartSection + 1
        assertEquals(6, entry.endSection)
        assertEquals(8, entry.startWeek)
        assertEquals(16, entry.endWeek)
        assertEquals("", init.sharedName)
        assertEquals("", init.sharedShortName)
        assertEquals("", init.sharedDescription)
        assertEquals(CourseNature.REQUIRED, init.courseNature)
        assertEquals("#2196F3", init.color)
    }

    @Test
    fun `初始周超出默认结束周时结束周跟着抬`() {
        // Dart: endWeek = initialStartWeek > 16 ? initialStartWeek : 16
        val entry = AddCourseFormLogic.buildInitialState(initialWeek = 20).entries.single()
        assertEquals(20, entry.startWeek)
        assertEquals(20, entry.endWeek)
    }

    @Test
    fun `编辑单门课共享字段来自该课`() {
        val course = testCourse(
            name = "线性代数",
            shortName = "线代",
            teacher = "张老师",
            location = "B202",
            note = "旧备注",
        )
        val init = AddCourseFormLogic.buildInitialState(initialCourse = course)
        assertFalse(init.isCreatingNewCourse)
        assertEquals("线性代数", init.sharedName)
        assertEquals("线代", init.sharedShortName)
        assertEquals("张老师", init.sharedTeacher)
        assertEquals("B202", init.sharedLocation)
        // description ?? note ?? '' 的回落链：无 description 时取 note
        assertEquals("旧备注", init.sharedDescription)
        assertEquals(listOf(course), init.entries.map { it.originalCourse })
    }

    @Test
    fun `编辑课程组所有课都成为条目`() {
        val c1 = testCourse(id = "g1", name = "数学", dayOfWeek = 1)
        val c2 = testCourse(id = "g2", name = "数学", dayOfWeek = 3)
        val group = AddCourseGroupData(name = "数学", courses = listOf(c1, c2))
        val init = AddCourseFormLogic.buildInitialState(courseGroup = group)
        assertFalse(init.isCreatingNewCourse)
        // 共享字段取第一条课
        assertEquals("数学", init.sharedName)
        assertEquals(2, init.entries.size)
        assertEquals("g1", init.entries[0].id)
        assertEquals("g2", init.entries[1].id)
        // 组编辑入口不填共享教师/地点（Dart 侧 _teacherController 只有单课编辑才写）
        assertEquals("", init.sharedTeacher)
    }

    @Test
    fun `组编辑带 initialCourse 时被点的课排第一条`() {
        // Dart initState: ordered = [initialCourse] + courses.where(id != initialCourse.id)
        val c1 = testCourse(id = "g1", name = "数学", dayOfWeek = 1)
        val c2 = testCourse(id = "g2", name = "数学", dayOfWeek = 3)
        val c3 = testCourse(id = "g3", name = "数学", dayOfWeek = 5)
        val group = AddCourseGroupData(name = "数学", courses = listOf(c1, c2, c3))
        val init = AddCourseFormLogic.buildInitialState(courseGroup = group, initialCourse = c2)
        assertEquals(listOf("g2", "g1", "g3"), init.entries.map { it.id })
        // 共享字段取排第一的那条（被点的课）
        assertEquals(3, init.entries.first().dayOfWeek)
    }

    // ==========================================
    // 5. 保存目标与载荷（_saveGroup 分支，Dart 源 :2044-2064）
    // ==========================================

    @Test
    fun `保存目标三分支互不顶替`() {
        val course = testCourse(name = "英语")
        val group = AddCourseGroupData(name = "大学英语", courses = listOf(course))

        // 组编辑：目标组名 = 组名（course 在场也不顶替）
        val groupTarget = AddCourseFormLogic.resolveSaveTarget(initialCourse = course, courseGroup = group)
        assertEquals(AddCourseSaveMode.UPDATE_GROUP, groupTarget.mode)
        assertEquals("大学英语", groupTarget.targetGroupName)

        // 单课编辑：目标组名 = 该课原名
        val courseTarget = AddCourseFormLogic.resolveSaveTarget(initialCourse = course, courseGroup = null)
        assertEquals(AddCourseSaveMode.UPDATE_GROUP, courseTarget.mode)
        assertEquals("英语", courseTarget.targetGroupName)

        // 新建：无目标组
        val addTarget = AddCourseFormLogic.resolveSaveTarget(initialCourse = null, courseGroup = null)
        assertEquals(AddCourseSaveMode.ADD, addTarget.mode)
        assertNull(addTarget.targetGroupName)
    }

    @Test
    fun `新建判定要求两个参数都为空`() {
        // Dart: _isCreatingNewCourse = course == null && courseGroup == null
        // 只看 course 会把「总览 -> 编辑」（只传 courseGroup）误判成新建
        val course = testCourse(name = "英语")
        assertTrue(AddCourseFormLogic.isCreatingNewCourse(null, null))
        assertFalse(AddCourseFormLogic.isCreatingNewCourse(course, null))
        assertFalse(AddCourseFormLogic.isCreatingNewCourse(null, AddCourseGroupData("英语", listOf(course))))
    }

    @Test
    fun `保存载荷按条目展开且带共享字段`() {
        val entries = listOf(
            AddCourseScheduleEntryData(id = "e1", dayOfWeek = 1, startSection = 1, endSection = 2, teacher = "甲", location = "L1"),
            AddCourseScheduleEntryData(id = "e2", dayOfWeek = 3, startSection = 3, endSection = 4, teacher = "乙", location = "L2"),
        )
        val payload = AddCourseFormLogic.buildSavePayload(
            initialCourse = null,
            courseGroup = null,
            name = "高等数学",
            shortName = "高数",
            description = "微积分",
            color = "#2196F3",
            courseNature = CourseNature.REQUIRED,
            entries = entries,
            clockResolver = { entry ->
                if (entry.id == "e1") {
                    AddCourseEntryClock("08:00", "09:40")
                } else {
                    AddCourseEntryClock("10:00", "11:40")
                }
            },
        )
        assertEquals(AddCourseSaveMode.ADD, payload.mode)
        assertNull(payload.targetGroupName)
        assertEquals(2, payload.courses.size)
        val first = payload.courses[0]
        assertEquals("高等数学", first.name)
        assertEquals("高数", first.shortName)
        assertEquals("微积分", first.description)
        assertEquals("甲", first.teacher)
        assertEquals("L1", first.location)
        assertEquals(1, first.dayOfWeek)
        assertEquals("08:00", first.startTime)
        assertEquals("09:40", first.endTime)
        val second = payload.courses[1]
        assertEquals("乙", second.teacher)
        assertEquals("10:00", second.startTime)
        assertEquals("11:40", second.endTime)
    }

    @Test
    fun `短名称与简介空串落库为null`() {
        // Dart: _shortNameController.text.isEmpty ? null : text（isEmpty 判据，不 trim）
        val payload = AddCourseFormLogic.buildSavePayload(
            initialCourse = null,
            courseGroup = null,
            name = "体育",
            shortName = "",
            description = "",
            color = "#2196F3",
            courseNature = CourseNature.REQUIRED,
            entries = listOf(AddCourseScheduleEntryData(id = "e1")),
            clockResolver = { AddCourseEntryClock("08:00", "08:45") },
        )
        assertNull(payload.courses.single().shortName)
        assertNull(payload.courses.single().description)
    }

    // ==========================================
    // 6. 校验（_saveCourse / _saveGroup，Dart 源 :1925-2007）
    // ==========================================

    @Test
    fun `课程名为空或纯空白判为必填`() {
        // 期望文案即 ARB pleaseEnterCourseName 的原文
        assertEquals("请输入课程名称", AddCourseFormLogic.validateCourseName(""))
        assertEquals("请输入课程名称", AddCourseFormLogic.validateCourseName("   "))
        assertNull(AddCourseFormLogic.validateCourseName("高等数学"))
        // 非空白内容即通过（trim 判据）
        assertNull(AddCourseFormLogic.validateCourseName(" 高数 "))
    }

    @Test
    fun `条目周次空集判为无效`() {
        // 范围模式：第 2 周 + 单周 -> 空集
        val badRange = AddCourseScheduleEntryData(startWeek = 2, endWeek = 2, isOddWeek = true)
        assertEquals(AddCourseEntryIssue.WEEKS_EMPTY, AddCourseFormLogic.validateEntry(badRange))
        // 自定义模式：勾选集为空
        val badCustom = AddCourseScheduleEntryData(weekSelectionMode = AddCourseWeekSelectionMode.CUSTOM)
        assertEquals(AddCourseEntryIssue.WEEKS_EMPTY, AddCourseFormLogic.validateEntry(badCustom))
        // 正常范围
        val good = AddCourseScheduleEntryData(startWeek = 1, endWeek = 16)
        assertNull(AddCourseFormLogic.validateEntry(good))
    }

    @Test
    fun `条目周次报错文案按排课记录编号拼接`() {
        // Dart: '${l10n.scheduleEntryTitle(i + 1)}: ${l10n.selectAtLeastOneWeek}'
        assertEquals(
            "排课记录 2: 请至少选择一个上课周次",
            AddCourseFormLogic.entryWeeksErrorMessage(1),
        )
    }

    // ==========================================
    // 7. 周次摘要（_selectedWeeksSummaryText / _formatWeekList，Dart 源 :1546-1608）
    // ==========================================

    @Test
    fun `连续周列表压缩成区间并以顿号相连`() {
        assertEquals("", AddCourseFormLogic.formatWeekList(emptyList()))
        assertEquals("5", AddCourseFormLogic.formatWeekList(listOf(5)))
        assertEquals("1-3", AddCourseFormLogic.formatWeekList(listOf(1, 2, 3)))
        assertEquals("1-3、5、7-8", AddCourseFormLogic.formatWeekList(listOf(1, 2, 3, 5, 7, 8)))
    }

    @Test
    fun `范围模式摘要覆盖全部周次时显示全部`() {
        // startWeek == availableWeeks.first && endWeek == availableWeeks.last && 无单双周
        assertEquals(
            "全部",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = availableWeeks20,
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 20,
                isOddWeek = false,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.RANGE,
            ),
        )
        // 同样跨度但叠了单周 -> 不是「全部」
        assertEquals(
            "第 1 周 – 第 20 周 · 单周",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = availableWeeks20.filter { it % 2 == 1 },
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 20,
                isOddWeek = true,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.RANGE,
            ),
        )
    }

    @Test
    fun `范围模式摘要单周不写空区间`() {
        // 起止同周只留一个周次词
        assertEquals(
            "第 6 周",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = listOf(6),
                availableWeeks = availableWeeks20,
                startWeek = 6,
                endWeek = 6,
                isOddWeek = false,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.RANGE,
            ),
        )
    }

    @Test
    fun `范围模式摘要区间用带空格的短破折号`() {
        // Dart: '${weekLabel(start)} – ${weekLabel(end)}'（en dash 带空格）
        assertEquals(
            "第 1 周 – 第 16 周",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = (1..16).toList(),
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.RANGE,
            ),
        )
        assertEquals(
            "第 2 周 – 第 8 周 · 双周",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = (2..8).filter { it % 2 == 0 },
                availableWeeks = availableWeeks20,
                startWeek = 2,
                endWeek = 8,
                isOddWeek = false,
                isEvenWeek = true,
                mode = AddCourseWeekSelectionMode.RANGE,
            ),
        )
    }

    @Test
    fun `范围模式单双周同时为真时单周先命中`() {
        // Dart `add_course_screen.dart:1599-1600` 是两个独立 `if`：两者都为 true 时
        // 先返回单周后缀（不是把后缀整个吞掉，也不是拼两段）。
        // 这种状态能从既有数据/导入回填进来（该文件 :27-30 明说「单双周可以都为 true」）。
        assertEquals(
            "第 1 周 – 第 16 周 · 单周",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = emptyList(),
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = true,
                isEvenWeek = true,
                mode = AddCourseWeekSelectionMode.RANGE,
            ),
        )
    }

    @Test
    fun `自定义模式摘要空集为空串全选为全部`() {
        assertEquals(
            "",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = emptyList(),
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.CUSTOM,
            ),
        )
        assertEquals(
            "全部",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = availableWeeks20,
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.CUSTOM,
            ),
        )
        assertEquals(
            "1-3、5、7-8",
            AddCourseFormLogic.selectedWeeksSummaryText(
                selectedWeeks = listOf(1, 2, 3, 5, 7, 8),
                availableWeeks = availableWeeks20,
                startWeek = 1,
                endWeek = 16,
                isOddWeek = false,
                isEvenWeek = false,
                mode = AddCourseWeekSelectionMode.CUSTOM,
            ),
        )
    }

    @Test
    fun `条目最终周次按模式取值`() {
        val rangeEntry = AddCourseScheduleEntryData(startWeek = 1, endWeek = 16, isOddWeek = true)
        assertEquals(listOf(1, 3, 5, 7, 9, 11, 13, 15), AddCourseFormLogic.selectedWeeksFor(rangeEntry))
        val customEntry = AddCourseScheduleEntryData(
            weekSelectionMode = AddCourseWeekSelectionMode.CUSTOM,
            selectedCustomWeeks = setOf(9, 1, 5),
        )
        // 自定义模式取勾选集升序，不看起止周
        assertEquals(listOf(1, 5, 9), AddCourseFormLogic.selectedWeeksFor(customEntry))
    }

    // ==========================================
    // 8. 周选择弹层草稿状态机（_showEntryWeekPickerDialog，Dart 源 :1623-1905）
    // ==========================================

    private fun rangeDraft(
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
    ) = AddCourseWeekDraft(
        mode = AddCourseWeekSelectionMode.RANGE,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = emptySet(),
    )

    @Test
    fun `弹层从条目生成草稿并整体回写`() {
        val entry = AddCourseScheduleEntryData(
            startWeek = 4,
            endWeek = 12,
            isOddWeek = true,
            weekSelectionMode = AddCourseWeekSelectionMode.RANGE,
            selectedCustomWeeks = setOf(3, 5),
        )
        val draft = AddCourseWeekDraftLogic.fromEntry(entry)
        assertEquals(4, draft.startWeek)
        assertEquals(12, draft.endWeek)
        assertTrue(draft.isOddWeek)
        assertEquals(setOf(3, 5), draft.customWeeks)

        val applied = AddCourseWeekDraftLogic.applyToEntry(
            entry,
            draft.copy(startWeek = 6, endWeek = 14, isOddWeek = false, isEvenWeek = true),
        )
        assertEquals(6, applied.startWeek)
        assertEquals(14, applied.endWeek)
        assertFalse(applied.isOddWeek)
        assertTrue(applied.isEvenWeek)
        // 回写不改条目身份与其余字段
        assertEquals(entry.id, applied.id)
        assertEquals(entry.dayOfWeek, applied.dayOfWeek)
    }

    @Test
    fun `切到自定义模式且勾选集为空时用范围周播种`() {
        // Dart: tempCustomWeeks = buildTempWeeksFromRange().toSet(); 空则 {tempStartWeek}
        val next = AddCourseWeekDraftLogic.selectMode(rangeDraft(startWeek = 5, endWeek = 8, isOddWeek = true), AddCourseWeekSelectionMode.CUSTOM, availableWeeks20)
        assertEquals(setOf(5, 7), next.customWeeks)
        val emptyRange = AddCourseWeekDraftLogic.selectMode(rangeDraft(startWeek = 2, endWeek = 2, isOddWeek = true), AddCourseWeekSelectionMode.CUSTOM, availableWeeks20)
        assertEquals(setOf(2), emptyRange.customWeeks)
    }

    @Test
    fun `range 与 custom 往返后勾选保留不被范围重播种`() {
        // Dart 判据是 tempCustomWeeks.isEmpty（add_course_screen.dart:1671-1677），
        // 不是「当前模式是不是 custom」。用「模式」当判据时，range→custom→range→custom
        // 回程会把用户在 custom 下勾的周用范围整段冲掉。
        val range = rangeDraft(startWeek = 2, endWeek = 12)

        // 第一步：range → custom，用范围播种
        val custom = AddCourseWeekDraftLogic.selectMode(range, AddCourseWeekSelectionMode.CUSTOM, availableWeeks20)
        assertEquals(setOf(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), custom.customWeeks)

        // 第二步：用户在 custom 下改勾选（只留 3、5、9）
        val picked = custom.copy(customWeeks = setOf(3, 5, 9))

        // 第三步：切回 range —— 勾选集非空，起止周取首末
        val backToRange = AddCourseWeekDraftLogic.selectMode(picked, AddCourseWeekSelectionMode.RANGE, availableWeeks20)
        assertEquals(3, backToRange.startWeek)
        assertEquals(9, backToRange.endWeek)

        // 第四步：再切回 custom —— 勾选集非空，必须原样保留，不能被 3..9 范围重播种
        val backToCustom = AddCourseWeekDraftLogic.selectMode(backToRange, AddCourseWeekSelectionMode.CUSTOM, availableWeeks20)
        assertEquals(setOf(3, 5, 9), backToCustom.customWeeks)
        assertEquals(AddCourseWeekSelectionMode.CUSTOM, backToCustom.mode)
    }

    @Test
    fun `自定义模式下勾选被清空后再切换仍会重播种`() {
        // 保留分支只在勾选集非空时生效；清空后切走再切回，仍要播种，
        // 否则用户看到的是「一周都没选 + 确认键灰掉」。
        val emptied = AddCourseWeekDraft(
            mode = AddCourseWeekSelectionMode.RANGE,
            startWeek = 4,
            endWeek = 6,
            isOddWeek = false,
            isEvenWeek = false,
            customWeeks = emptySet(),
        )
        val next = AddCourseWeekDraftLogic.selectMode(emptied, AddCourseWeekSelectionMode.CUSTOM, availableWeeks20)
        assertEquals(setOf(4, 5, 6), next.customWeeks)
    }

    @Test
    fun `切回范围模式用勾选集首末当起止周并清单双周`() {
        // Dart: tempStartWeek = sorted.first; tempEndWeek = sorted.last; 单双周清 false
        val draft = AddCourseWeekDraft(
            mode = AddCourseWeekSelectionMode.CUSTOM,
            startWeek = 1,
            endWeek = 16,
            isOddWeek = true,
            isEvenWeek = false,
            customWeeks = setOf(6, 2, 9),
        )
        val next = AddCourseWeekDraftLogic.selectMode(draft, AddCourseWeekSelectionMode.RANGE, availableWeeks20)
        assertEquals(2, next.startWeek)
        assertEquals(9, next.endWeek)
        assertFalse(next.isOddWeek)
        assertFalse(next.isEvenWeek)
    }

    @Test
    fun `改开始周时结束周被抬到不低于开始周`() {
        // Dart: if (tempEndWeek < tempStartWeek) tempEndWeek = tempStartWeek
        val next = AddCourseWeekDraftLogic.setStartWeek(rangeDraft(startWeek = 2, endWeek = 9), 12, availableWeeks20)
        assertEquals(12, next.startWeek)
        assertEquals(12, next.endWeek)
        val normal = AddCourseWeekDraftLogic.setStartWeek(rangeDraft(startWeek = 2, endWeek = 9), 5, availableWeeks20)
        assertEquals(9, normal.endWeek)
    }

    @Test
    fun `网格磁贴点选保留最后一个已选周`() {
        // Dart: isSelected && tempCustomWeeks.length > 1 才允许移除
        val single = AddCourseWeekDraft(
            mode = AddCourseWeekSelectionMode.CUSTOM,
            startWeek = 1,
            endWeek = 16,
            isOddWeek = false,
            isEvenWeek = false,
            customWeeks = setOf(7),
        )
        assertEquals(setOf(7), AddCourseWeekDraftLogic.toggleCustomWeek(single, 7).customWeeks)
        val multiple = single.copy(customWeeks = setOf(7, 9))
        assertEquals(setOf(9), AddCourseWeekDraftLogic.toggleCustomWeek(multiple, 7).customWeeks)
        assertEquals(setOf(7, 9, 12), AddCourseWeekDraftLogic.toggleCustomWeek(multiple, 12).customWeeks)
    }

    @Test
    fun `全选单周双周快捷键按可选周过滤`() {
        // Dart: availableWeeks.where((week) => week.isOdd / isEven).toSet()
        val draft = AddCourseWeekDraft(
            mode = AddCourseWeekSelectionMode.CUSTOM,
            startWeek = 1,
            endWeek = 16,
            isOddWeek = false,
            isEvenWeek = false,
            customWeeks = setOf(3),
        )
        val available = listOf(1, 2, 3, 4, 5)
        assertEquals(setOf(1, 2, 3, 4, 5), AddCourseWeekDraftLogic.selectAllCustom(draft, available).customWeeks)
        assertEquals(setOf(1, 3, 5), AddCourseWeekDraftLogic.selectOddCustom(draft, available).customWeeks)
        assertEquals(setOf(2, 4), AddCourseWeekDraftLogic.selectEvenCustom(draft, available).customWeeks)
    }

    @Test
    fun `确认键按最终周次是否为空启用`() {
        // 空集两种来源：范围收一周 + 相反侧；单双周同勾
        assertFalse(AddCourseWeekDraftLogic.canConfirm(rangeDraft(2, 2, isOddWeek = true)))
        assertFalse(AddCourseWeekDraftLogic.canConfirm(rangeDraft(1, 16, isOddWeek = true, isEvenWeek = true)))
        assertTrue(AddCourseWeekDraftLogic.canConfirm(rangeDraft(1, 16, isOddWeek = true)))
        assertFalse(
            AddCourseWeekDraftLogic.canConfirm(
                AddCourseWeekDraft(AddCourseWeekSelectionMode.CUSTOM, 1, 16, false, false, emptySet()),
            ),
        )
        assertTrue(
            AddCourseWeekDraftLogic.canConfirm(
                AddCourseWeekDraft(AddCourseWeekSelectionMode.CUSTOM, 1, 16, false, false, setOf(5)),
            ),
        )
    }

    @Test
    fun `弹层草稿的最终周次与条目口径一致`() {
        // 范围模式按单双周过滤；自定义模式取勾选集升序
        val range = rangeDraft(3, 10, isEvenWeek = true)
        assertEquals(listOf(4, 6, 8, 10), AddCourseWeekDraftLogic.selectedWeeks(range))
        val custom = AddCourseWeekDraft(AddCourseWeekSelectionMode.CUSTOM, 1, 16, false, false, setOf(8, 2, 5))
        assertEquals(listOf(2, 5, 8), AddCourseWeekDraftLogic.selectedWeeks(custom))
    }

    // ==========================================
    // 9. 其他表单规则（_addScheduleEntry / 短简称补全 / 卡片标题）
    // ==========================================

    @Test
    fun `新增排课条目沿用上一条的时段与教师`() {
        // Dart _addScheduleEntry: dayOfWeek/startSection/endSection/startWeek/endWeek/teacher/location 取 last
        val last = AddCourseScheduleEntryData(
            id = "e1",
            dayOfWeek = 3,
            startSection = 5,
            endSection = 6,
            startWeek = 4,
            endWeek = 12,
            teacher = "张老师",
            location = "B202",
        )
        val next = AddCourseFormLogic.nextEntryAfter(last)
        assertEquals(3, next.dayOfWeek)
        assertEquals(5, next.startSection)
        assertEquals(6, next.endSection)
        assertEquals(4, next.startWeek)
        assertEquals(12, next.endWeek)
        assertEquals("张老师", next.teacher)
        assertEquals("B202", next.location)
        // 新条目是新身份
        assertTrue(next.id != last.id)
    }

    @Test
    fun `没有上一条时新条目回落共享字段与默认值`() {
        // Dart: last?.dayOfWeek ?? 1 / teacher: last?.teacher ?? _teacherController.text
        val next = AddCourseFormLogic.nextEntryAfter(last = null, sharedTeacher = "李老师", sharedLocation = "C102")
        assertEquals(1, next.dayOfWeek)
        assertEquals(1, next.startSection)
        assertEquals(2, next.endSection)
        assertEquals(1, next.startWeek)
        assertEquals(16, next.endWeek)
        assertEquals("李老师", next.teacher)
        assertEquals("C102", next.location)
    }

    @Test
    fun `自动补全简称取课程名前两个字符`() {
        // Dart: _nameController.text.trim().characters.take(2)
        assertEquals("高等", AddCourseFormLogic.autofillShortName("高等数学"))
        assertEquals("英语", AddCourseFormLogic.autofillShortName("  英语听力  "))
        assertEquals("数", AddCourseFormLogic.autofillShortName("数"))
        assertEquals("", AddCourseFormLogic.autofillShortName(""))
    }

    @Test
    fun `排课卡标题单条与多条两种口径`() {
        // Dart: 多条时 scheduleEntryTitle(1).replaceFirst(RegExp(r'\s?1$'), '')
        assertEquals("上课安排", AddCourseFormLogic.scheduleEntryCardTitle(entryCount = 1))
        assertEquals("排课记录", AddCourseFormLogic.scheduleEntryCardTitle(entryCount = 3))
    }

    @Test
    fun `周次标签与节次标签插值`() {
        assertEquals("第 8 周", AddCourseStrings.weekLabel.filled("week", "8"))
        assertEquals("第 3 节", AddCourseStrings.sectionLabel.filled("section", "3"))
        assertEquals("3 节", AddCourseStrings.scheduleSectionNumberLabel.filled("section", "3"))
        assertEquals("第 6～8 节", AddCourseStrings.sectionRangeLabel.filled("startSection", "6").filled("endSection", "8"))
    }
}
