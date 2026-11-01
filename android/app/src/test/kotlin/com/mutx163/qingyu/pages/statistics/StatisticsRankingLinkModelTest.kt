package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程排行落点解析（F30）测试。
 *
 * ## 期望值从哪来
 *
 * 全部从 Dart 源手推，不看实现：
 *
 * - `lib/screens/statistics_analysis_screen.dart:190 _openCourseEdit`：
 *   按**课名**在 `provider.courses` 里找**第一门**同名课，找不到直接 `return`；
 * - `lib/providers/timetable_provider.dart:514-518 courseGroupForCourse`：
 *   组 = `_courses.where((c) => c.name == course.name)`（**只按课名**，不比较教师/地点）；
 * - 落点 = `/course/edit` → `AddCourseScreen(courseGroup:, initialCourse:)`，
 *   即壳里的 `d1.addCourse`。
 *
 * 另一半钉的是「渲染层凭什么决定一行可不可点」：`analysisViewState` 的 RANKING 分支
 * 必须把「当前课表里确实存在」的课名放进 `rankingOpenableNames`；其余模块不该有这份集合。
 */
class StatisticsRankingLinkModelTest {

    // ── 1. 解析：课名 → 第一门课 + 同名整组 ──

    @Test
    fun `按课名解析出第一门同名课与整组课次`() {
        val monday = course(id = "c1", name = "高等数学", dayOfWeek = 1)
        val wednesday = course(id = "c2", name = "高等数学", dayOfWeek = 3)
        val other = course(id = "c3", name = "大学物理", dayOfWeek = 5)

        val link = StatisticsRankingLinkModel.resolve(
            courses = listOf(monday, wednesday, other),
            courseName = "高等数学",
        )

        assertEquals("取第一门同名课（Dart firstOrNull）", monday, link?.course)
        assertEquals(
            "组 = 全部同名课次，保持仓储顺序",
            listOf("c1", "c2"),
            link?.groupCourses?.map { it.id },
        )
        assertEquals("课名即查找键", "高等数学", link?.courseName)
    }

    @Test
    fun `课名不存在时返回 null——Dart 静默不动作`() {
        val link = StatisticsRankingLinkModel.resolve(
            courses = listOf(course(id = "c1", name = "高等数学")),
            courseName = "已经删掉的课",
        )

        assertNull("找不到课名不能编造落点（Dart 直接 return）", link)
    }

    @Test
    fun `空课表解析任何课名都返回 null`() {
        assertNull(StatisticsRankingLinkModel.resolve(emptyList(), "高等数学"))
    }

    @Test
    fun `组只按课名划分，同名不同教师也算同一组`() {
        // Dart courseGroupForCourse 的判据只有 `c.name == course.name`。
        val a = course(id = "c1", name = "高等数学", teacher = "张老师")
        val b = course(id = "c2", name = "高等数学", teacher = "李老师")
        val c = course(id = "c3", name = "高等数学（重修）", teacher = "张老师")

        val link = StatisticsRankingLinkModel.resolve(listOf(a, b, c), "高等数学")

        assertEquals("同名即同组，不看教师", listOf("c1", "c2"), link?.groupCourses?.map { it.id })
    }

    // ── 2. 可点性：只有当前课表里存在的课名才算数 ──

    @Test
    fun `可点集合剔除当前课表里已不存在的课名`() {
        val names = StatisticsRankingLinkModel.openableNames(
            courses = listOf(course(id = "c1", name = "高等数学")),
            rankingNames = listOf("高等数学", "已删除的课"),
        )

        assertEquals(setOf("高等数学"), names)
    }

    @Test
    fun `可点集合保持排行行给出的顺序无关，只判断存在性`() {
        val names = StatisticsRankingLinkModel.openableNames(
            courses = listOf(
                course(id = "c1", name = "大学物理"),
                course(id = "c2", name = "高等数学"),
            ),
            rankingNames = listOf("高等数学", "大学物理"),
        )

        assertEquals(setOf("高等数学", "大学物理"), names)
    }

    @Test
    fun `空排行给出空的可点集合`() {
        assertTrue(
            StatisticsRankingLinkModel.openableNames(
                courses = listOf(course(id = "c1", name = "高等数学")),
                rankingNames = emptyList(),
            ).isEmpty(),
        )
    }

    // ── 3. 视图状态接线：排行页携带可点课名 ──

    @Test
    fun `排行视图状态把可点课名接进 rankingOpenableNames`() {
        val state = StatisticsAnalysisModel.analysisViewState(
            module = StatisticsAnalysisModule.RANKING,
            courses = listOf(course(id = "c1", name = "高等数学")),
            currentWeek = 6,
            semesterWeekCount = 16,
        )

        assertEquals("排行确实有一行", 1, state.rankingRows.size)
        assertEquals(
            "排行里那门课在当前课表里存在 ⇒ 可点",
            setOf(state.rankingRows[0].first),
            state.rankingOpenableNames,
        )
        assertEquals(setOf("高等数学"), state.rankingOpenableNames)
    }

    @Test
    fun `非排行模块不产出可点课名`() {
        for (module in StatisticsAnalysisModule.entries - StatisticsAnalysisModule.RANKING) {
            val state = StatisticsAnalysisModel.analysisViewState(
                module = module,
                courses = listOf(course(id = "c1", name = "高等数学")),
                currentWeek = 6,
                semesterWeekCount = 16,
            )
            assertTrue(
                "只有排行页有课程落点，$module 不该有可点课名",
                state.rankingOpenableNames.isEmpty(),
            )
        }
    }

    // ── 夹具 ──

    /** 一门「第 3 天 1～2 节」的课，够统计服务算出课时即可。 */
    private fun course(
        id: String = "c1",
        name: String = "高等数学",
        teacher: String = "张老师",
        dayOfWeek: Int = 3,
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = "教三 201",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
        isOddWeek = false,
        isEvenWeek = false,
        suspendedWeeks = null,
        courseNature = CourseNature.REQUIRED,
    )
}
