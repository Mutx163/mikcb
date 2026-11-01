package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.Course

/**
 * 「课程排行」一行的落点解析。
 *
 * ## 为什么单独一层
 *
 * Dart 深度分析页点课程排行时并**不**进该课统计明细，也不进单节会话列表，而是：
 * `lib/screens/statistics_analysis_screen.dart:129` → `_openCourseEdit`（`:190`）：
 *
 * 1. 在当前课表 `provider.courses` 里按**课名**找**第一门**同名课；
 * 2. 找不到就 `return`（**静默不动作**——不是报错、不是进别的页）；
 * 3. 找到后用 `provider.courseGroupForCourse(course)`（`timetable_provider.dart:514-518`）
 *    取**同名课次整组**，push `/course/edit` → `AddCourseScreen(courseGroup:, initialCourse:)`。
 *
 * 这一步「课名 → 课程对象 + 同名整组」是纯数据换算，放在模型层才能在 JVM 单测里钉住；
 * 留在渲染层或壳里写，就成了两处各抄一遍的隐式契约（且「找不到课名时到底该不该跳」
 * 这种边界只会在真机上被发现）。
 *
 * ## 谁用
 *
 * - 渲染层：用 [openableNames] 的结果决定**哪些行可点**（不在集合里的行保持纯展示，
 *   避免「按下去没反应」的假热区）；
 * - 壳（`e.analysis` 分支）：用 [resolve] 拿到目标课程与同名整组，再写
 *   `wiring.pendingEditCourse` / `wiring.pendingEditGroup` 并打开 `d1.addCourse`。
 *   壳侧接线由 Lead 落，本文件不依赖 `pages.course.CourseGroup`，只给出 `List<Course>`，
 *   由壳自己组装 `CourseGroup(name, courses)`，避免模型层反向依赖页面包。
 */
object StatisticsRankingLinkModel {

    /**
     * 一次「点课程排行」的目标。
     *
     * @param course 按课名找到的第一门课（Dart `courses.where(...).firstOrNull`）。
     * @param groupCourses 同名课次整组（Dart `courseGroupForCourse`）；顺序沿用仓储顺序。
     *   至少含 [course] 本身。
     */
    data class RankingCourseLink(
        val course: Course,
        val groupCourses: List<Course>,
    ) {
        /** 课程名，也是 [groupCourses] 里每门课的 `name`。 */
        val courseName: String get() = course.name
    }

    /**
     * 按课名解析落点；课名不在当前课表里时返回 `null`。
     *
     * 与 Dart 逐条对齐：
     * - 匹配条件只有 `name`（不比较教师/地点/ID）；
     * - 取**第一门**同名课，不做去重或挑选；
     * - 空课名也按普通字符串匹配（Dart 没有额外判空），是否会出现空名由上游数据负责。
     */
    fun resolve(courses: List<Course>, courseName: String): RankingCourseLink? {
        val first = courses.firstOrNull { it.name == courseName } ?: return null
        return RankingCourseLink(
            course = first,
            groupCourses = courses.filter { it.name == courseName },
        )
    }

    /**
     * 排行行里**确实能打开**的课名集合。
     *
     * 用途：渲染层逐行判定可点性。以排行行给出的课名为准，只保留当前课表里存在的那些——
     * Dart 对不存在的课名是静默 `return`，若 Compose 仍挂点击热区，用户会看到
     * 「按下去什么都不发生」，这正是本次要消掉的 P0。
     */
    fun openableNames(courses: List<Course>, rankingNames: List<String>): Set<String> =
        rankingNames.filterTo(mutableSetOf()) { name -> courses.any { it.name == name } }
}
