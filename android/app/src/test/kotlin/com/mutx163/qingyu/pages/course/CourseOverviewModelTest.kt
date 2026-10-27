package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程总览页模型层测试（对应 `lib/screens/course_overview_screen.dart` 的
 * `_sortGroups` / `_displayName` / `_subtitle` / `_groupHasConflict` 与
 * `lib/utils/course_group.dart` 的 `CourseGroup.buildFrom`）。
 *
 * 期望值全部手推：中文名按 Unicode 码位排（体 U+4F53 < 大 U+5927 < 线 U+7EBF），
 * 不从实现里抄。
 */
class CourseOverviewModelTest {

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        teacher: String = "李老师",
        shortName: String? = null,
        nature: CourseNature = CourseNature.REQUIRED,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = teacher,
        location = "教学楼101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        courseNature = nature,
    )

    /** 线代A(day3 5-6节) + 线代B(day1 2-3节)：同名两时段，最早槽位 (1, 2)。 */
    private val linearA = course("la", "线性代数", dayOfWeek = 3, startSection = 5, endSection = 6, teacher = "张三")
    private val linearB = course("lb", "线性代数", dayOfWeek = 1, startSection = 2, endSection = 3, teacher = "张三")
    private val english = course("en", "大学英语", dayOfWeek = 1, startSection = 4, endSection = 5, teacher = "李老师")
    private val pe = course("pe", "体育", dayOfWeek = 3, startSection = 1, endSection = 2, teacher = "", shortName = "体")

    // ==========================================
    // 1. 同名聚合（CourseGroup.buildFrom）
    // ==========================================

    @Test
    fun `buildFrom 按名字聚合并保持首次出现顺序`() {
        val groups = CourseGroup.buildFrom(listOf(linearA, linearB, english, pe))

        assertEquals(3, groups.size)
        assertEquals(listOf("线性代数", "大学英语", "体育"), groups.map { it.name })

        // 同名课程聚合进同一组，保持列表内出现顺序
        val linear = groups[0]
        assertEquals(listOf("la", "lb"), linear.courses.map { it.id })
    }

    @Test
    fun `组内共享字段取自第一门课`() {
        val group = CourseGroup.buildFrom(listOf(linearA, linearB)).first()

        assertEquals("张三", group.teacher)
        assertEquals(linearA.color, group.color)
        assertEquals(linearA.courseNature, group.courseNature)
    }

    @Test
    fun `最早星期与最早节次取全组最小值`() {
        val group = CourseGroup.buildFrom(listOf(linearA, linearB)).first()

        // min(3, 1) = 1；min(5, 2) = 2
        assertEquals(1, group.earliestDayOfWeek)
        assertEquals(2, group.earliestStartSection)
    }

    // ==========================================
    // 2. 排序（_sortGroups 三档）
    // ==========================================

    @Test
    fun `排序 added 档保持添加顺序`() {
        val groups = CourseGroup.buildFrom(listOf(linearA, english, pe))

        val sorted = CourseOverviewLogic.sortGroups(groups, CourseOverviewSortMode.ADDED)

        assertEquals(listOf("线性代数", "大学英语", "体育"), sorted.map { it.name })
    }

    @Test
    fun `排序 name 档按 Unicode 码位升序`() {
        val groups = CourseGroup.buildFrom(listOf(linearA, english, pe))

        val sorted = CourseOverviewLogic.sortGroups(groups, CourseOverviewSortMode.NAME)

        // 手推：体 U+4F53 < 大 U+5927 < 线 U+7EBF
        assertEquals(listOf("体育", "大学英语", "线性代数"), sorted.map { it.name })
    }

    @Test
    fun `排序 schedule 档先比最早星期、平手比最早节次`() {
        // 线代必须带线性代数的两个时段（linearA 周三 5-6 节 + linearB 周一 2-3 节），
        // 否则该组最早槽位是 (3,5)，与本用例「靠节次平手裁决」的意图不符。
        val groups = CourseGroup.buildFrom(listOf(linearA, linearB, english, pe))

        val sorted = CourseOverviewLogic.sortGroups(groups, CourseOverviewSortMode.SCHEDULE)

        // 手推：线性代数 (1,2) < 大学英语 (1,4) < 体育 (3,1)
        // 线代排前面靠的是节次平手裁决（2 < 4），不是星期。
        assertEquals(listOf("线性代数", "大学英语", "体育"), sorted.map { it.name })
    }

    @Test
    fun `排序不改动入参列表本身`() {
        val groups = CourseGroup.buildFrom(listOf(linearA, english, pe))
        val before = groups.map { it.name }

        CourseOverviewLogic.sortGroups(groups, CourseOverviewSortMode.NAME)

        // Dart 侧 sort 作用在 List.of 复制上，原列表顺序不变
        assertEquals(before, groups.map { it.name })
    }

    // ==========================================
    // 3. 行展示数据（_displayName / _subtitle / courseNatureLabel）
    // ==========================================

    @Test
    fun `displayName 有短名时拼成 名称 (短名)`() {
        val group = CourseGroup.buildFrom(listOf(pe)).first()
        assertEquals("体育 (体)", group.displayName())

        // 短名为空串视同没有
        val blank = CourseGroup.buildFrom(
            listOf(course("x", "大学英语", 1, 1, 2, shortName = "")),
        ).first()
        assertEquals("大学英语", blank.displayName())
    }

    @Test
    fun `subtitle 多时段拼点号、教师为空则只留课表摘要`() {
        val linear = CourseGroup.buildFrom(listOf(linearA, linearB)).first()
        assertEquals("张三 · 周 三 5～6 节 · 周 一 2～3 节", linear.subtitle())

        val peGroup = CourseGroup.buildFrom(listOf(pe)).first()
        assertEquals("周 三 1～2 节", peGroup.subtitle())
    }

    @Test
    fun `星期短名越界回落数字`() {
        assertEquals("一", CourseOverviewStrings.weekdayShortLabel(1))
        assertEquals("日", CourseOverviewStrings.weekdayShortLabel(7))
        assertEquals("0", CourseOverviewStrings.weekdayShortLabel(0))
        assertEquals("9", CourseOverviewStrings.weekdayShortLabel(9))
    }

    // ==========================================
    // 4. 冲突标记（_groupHasConflict 与冲突入口）
    // ==========================================

    @Test
    fun `组内任一课程命中冲突表即标冲突`() {
        val conflictMap = mapOf("la" to listOf(linearA))
        val groups = CourseGroup.buildFrom(listOf(linearA, english))

        assertTrue(CourseOverviewLogic.groupHasConflict(groups[0], conflictMap))
        assertFalse(CourseOverviewLogic.groupHasConflict(groups[1], conflictMap))
    }

    @Test
    fun `冲突计数取冲突表条数并填进入口文案`() {
        val conflictMap = mapOf("la" to listOf(linearA), "en" to listOf(english))

        val state = CourseOverviewLogic.buildViewState(
            listOf(linearA, linearB, english),
            conflictMap,
        )

        assertEquals(2, state.conflictCount)
        assertEquals("冲突 2 节", state.conflictEntryDetail)
        assertEquals("查看冲突详情", state.conflictEntryTitle)
        // 两组都命中：线性代数（la 在表里）、大学英语（en 在表里）
        assertTrue(state.rows[0].hasConflict)
        assertTrue(state.rows[1].hasConflict)
    }

    // ==========================================
    // 5. 整页视图状态（buildViewState）
    // ==========================================

    @Test
    fun `空课表给出空态与添加按钮文案`() {
        val state = CourseOverviewLogic.buildViewState(emptyList(), emptyMap())

        assertTrue(state.isEmpty)
        assertTrue(state.rows.isEmpty())
        assertEquals("长按课表或点击右上角添加课程", state.emptyHint)
        assertEquals("添加新课程", state.addCourseAction)
        assertEquals(0, state.conflictCount)
    }

    @Test
    fun `默认排序档是按添加顺序，弹层三项按 added-name-schedule 排布`() {
        val state = CourseOverviewLogic.buildViewState(listOf(linearA, english), emptyMap())

        assertEquals(CourseOverviewSortMode.ADDED, state.sortMode)
        assertEquals(3, state.sortOptions.size)
        assertEquals(CourseOverviewSortMode.ADDED, state.sortOptions[0].mode)
        assertEquals(CourseOverviewSortMode.NAME, state.sortOptions[1].mode)
        assertEquals(CourseOverviewSortMode.SCHEDULE, state.sortOptions[2].mode)
        assertEquals("按添加顺序", state.sortOptions[0].label)
        assertEquals("按课程名称", state.sortOptions[1].label)
        assertEquals("按排课时间", state.sortOptions[2].label)
        // 只有当前档被选中
        assertTrue(state.sortOptions[0].isSelected)
        assertFalse(state.sortOptions[1].isSelected)
        assertFalse(state.sortOptions[2].isSelected)
    }

    @Test
    fun `buildViewState 行数据按指定排序档组装`() {
        val state = CourseOverviewLogic.buildViewState(
            listOf(linearA, linearB, english, pe),
            emptyMap(),
            CourseOverviewSortMode.SCHEDULE,
        )

        assertFalse(state.isEmpty)
        assertEquals(listOf("线性代数", "大学英语", "体育"), state.rows.map { it.group.name })
        // 行携带渲染所需的全部字符串，渲染层不再做计算
        assertEquals("大学英语", state.rows[1].displayName)
        assertEquals("李老师 · 周 一 4～5 节", state.rows[1].subtitle)
        assertEquals("必修", state.rows[1].natureLabel)
    }

    @Test
    fun `课程性质标签按枚举映射`() {
        val elective = course("el", "影视鉴赏", 6, 1, 2, nature = CourseNature.ELECTIVE)

        val state = CourseOverviewLogic.buildViewState(listOf(elective), emptyMap())

        assertEquals("选修", state.rows[0].natureLabel)
    }
}
