package com.mutx163.qingyu.pages.conflict

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.course.CourseDomain

/**
 * 冲突详情页的纯结构模型（移植 `lib/screens/course_conflict_screen.dart`，2026-10-26 快照）。
 *
 * ## 分层
 *
 * 与同批的「开源许可」「支持作者」「设置」页一致：本文件在 **main** 源集、
 * 零 Compose/Miuix 依赖（main 对全变体编译，import miuix 会让 Flutter 的
 * prod 包编不过），只承载「配对 / 去重 / 排序 / 文案」；渲染在 composeP1 源集
 * 的 `CourseConflictPage.kt`。
 *
 * ## 数据来源
 *
 * Dart 侧从 `TimetableProvider.courseConflictMap` 取整份课表的冲突索引
 * （`timetable_provider.dart:275`，内部是 `CourseDomain.buildConflictMap`
 * 且 **week=null** —— 按「任意一周」判定，不是当前周）。Kotlin 侧已有同口径的
 * `CourseDomain.buildConflictMap`（`course/CourseDomain.kt:59`），这里直接复用，
 * 不重新实现冲突判定。
 */

/** 一对互相冲突的课表项；[left] 恒为 id 字典序较小的一方（Dart 同一口径）。 */
data class CourseConflictPair(val left: Course, val right: Course)

/** 冲突列表的一行（已把三行文案拼好，渲染层只负责摆位置）。 */
data class CourseConflictRow(
    /** 点这一行要编辑的课表项 id；分组查找由宿主完成（Dart 侧在 _openCourseEditor）。 */
    val courseId: String,
    /** 课程名（Dart `course.name`）。 */
    val title: String,
    /** 「周 一 1～2 节 · 第 1 周-16」——注意区间尾部的 Dart 口径，见 [weeksLabel]。 */
    val scheduleLine: String,
    /** 「与 英语 冲突」（红字）。 */
    val conflictLine: String,
)

/** 一对冲突出现在页面上的样子：分组小标题 + 两行课程。 */
data class CourseConflictPairView(
    /** 1 起的分组序号（Dart `${pairTitle} ${index + 1}`）。 */
    val index: Int,
    val sectionLabel: String,
    val rows: List<CourseConflictRow>,
)

/** 整页视图状态（输入课程表，输出可直接渲染的树；空/非空由 [pairs] 决定）。 */
data class CourseConflictView(
    val title: String,
    val emptyText: String,
    val pairs: List<CourseConflictPairView>,
) {
    val isEmpty: Boolean get() = pairs.isEmpty()
}

/**
 * 按 Dart `CourseConflictScreen._buildConflictPairs`（`course_conflict_screen.dart:65-102`）
 * 逐行移植：
 *
 * 1. 冲突索引来自 [CourseDomain.buildConflictMap]，`week = null`（任意一周重叠即算冲突，
 *    停课周与单双周由 `Course.isActiveInWeek` 排除）；
 * 2. 冲突索引是**双向**的（A→B 与 B→A 各一条），用「字典序小的 id|大的 id」做键去重，
 *    保证每对只出现一次；
 * 3. [CourseConflictPair.left] 取 id 字典序较小的一方（不是节次较早的一方）；
 * 4. 排序键是 `left.dayOfWeek` 再 `left.startSection`；同一天的两门课才可能冲突，
 *    所以 day 相同，实际生效的是「id 较小那门的起始节」；
 * 5. 排序相等时 Dart 用非稳定 `List.sort`（相对顺序无保证），Kotlin 用稳定排序——
 *    已知口径差，真实数据里同键的概率极低，以稳定排序为准。
 *
 * ⚠️ 去重键用 `compareTo` 比较（Dart `String.compareTo` 与 Kotlin 同为 UTF-16 码元序）。
 */
fun buildCourseConflictPairs(courses: List<Course>): List<CourseConflictPair> {
    val conflictMap = CourseDomain.buildConflictMap(courses)
    val coursesById = courses.associateBy { it.id }
    val pairs = LinkedHashMap<String, CourseConflictPair>()

    for ((id, partners) in conflictMap) {
        // Dart：coursesById[entry.key] 为 null 时跳过（索引里出现未知 id 的兜底）。
        val left = coursesById[id] ?: continue
        for (right in partners) {
            val leftFirst = left.id.compareTo(right.id) < 0
            val pairKey = if (leftFirst) "${left.id}|${right.id}" else "${right.id}|${left.id}"
            if (pairs.containsKey(pairKey)) continue
            pairs[pairKey] = if (leftFirst) {
                CourseConflictPair(left = left, right = right)
            } else {
                CourseConflictPair(left = right, right = left)
            }
        }
    }

    return pairs.values.sortedWith(
        compareBy({ it.left.dayOfWeek }, { it.left.startSection }),
    )
}

/** 整页构建：标题 + 空态文案 + 每个冲突组合的分组标题与两行课程。 */
fun buildCourseConflictView(courses: List<Course>): CourseConflictView {
    val pairs = buildCourseConflictPairs(courses)
    return CourseConflictView(
        title = CourseConflictStrings.title,
        emptyText = CourseConflictStrings.emptyText,
        pairs = pairs.mapIndexed { index, pair ->
            val index1Based = index + 1
            CourseConflictPairView(
                index = index1Based,
                sectionLabel = CourseConflictStrings.pairLabel(index1Based),
                rows = listOf(
                    rowFor(course = pair.left, partner = pair.right),
                    rowFor(course = pair.right, partner = pair.left),
                ),
            )
        },
    )
}

private fun rowFor(course: Course, partner: Course): CourseConflictRow = CourseConflictRow(
    courseId = course.id,
    title = course.name,
    scheduleLine = scheduleLine(course),
    conflictLine = CourseConflictStrings.withCourse(partner.name),
)

/**
 * 一行里的「周几第几节 · 第几周」（Dart `_ConflictCourseRow` `:143-152`）：
 * `weekdaySectionSummary(dayLabel, startSection, endSection)` + `' · '` + 周次文案。
 */
fun scheduleLine(course: Course): String {
    val schedule = CourseConflictStrings.weekdaySectionSummary(
        weekday = CourseConflictStrings.weekdayShort(course.dayOfWeek),
        startSection = course.startSection,
        endSection = course.endSection,
    )
    return "$schedule · ${weeksLabel(course)}"
}

/**
 * 周次文案 —— 逐字保留 Dart 的写法（`course_conflict_screen.dart:149-152`）：
 *
 * ```dart
 * final weeks = l10n.weekLabel(course.startWeek) == l10n.weekLabel(course.endWeek)
 *     ? l10n.weekLabel(course.startWeek)
 *     : '${l10n.weekLabel(course.startWeek)}-${course.endWeek}';
 * ```
 *
 * 也就是说：起始与结束**周次字符串相同**时只写一个「第 N 周」；不同时写
 * 「第 {start} 周-{end}」——**结束周用的是裸数字**，不是「第 16 周」。
 * 这是现状 bug-ish 的显示行为，迁移期照抄，不在本批「顺手修正」。
 */
fun weeksLabel(course: Course): String {
    val startLabel = CourseConflictStrings.weekLabel(course.startWeek)
    val endLabel = CourseConflictStrings.weekLabel(course.endWeek)
    return if (startLabel == endLabel) startLabel else "$startLabel-${course.endWeek}"
}

/**
 * 冲突详情页文案（逐字取自 `lib/l10n/app_zh.arb`，2026-10-26 快照）。
 *
 * 纪律：测试用 [com.mutx163.qingyu.core.MiniJson] 直读 ARB 逐字对拍，不手抄信任；
 * 带参文案按同一占位符格式拼装。多语言资源本身在 Phase 4 才接（目前全应用
 * Compose 侧都只落中文），所以这里只钉 zh 一份。
 */
object CourseConflictStrings {
    /** ARB `courseConflictDetailTitle`。 */
    const val title = "冲突详情"

    /** ARB `courseConflictEmpty`。 */
    const val emptyText = "当前没有检测到冲突"

    /** ARB `courseConflictPairTitle`（分组标题前缀，Dart 拼成「冲突组合 1」）。 */
    const val pairTitle = "冲突组合"

    /** ARB `courseConflictWithCourse`（`与 {name} 冲突`）。 */
    fun withCourse(name: String): String = "与 $name 冲突"

    /** ARB `weekLabel`（`第 {week} 周`）。 */
    fun weekLabel(week: Int): String = "第 $week 周"

    /** Dart `${courseConflictPairTitle} ${index + 1}`。 */
    fun pairLabel(index1Based: Int): String = "$pairTitle $index1Based"

    /** ARB `weekdaySectionSummary`（`周 {weekday} {startSection}～{endSection} 节`）。 */
    fun weekdaySectionSummary(weekday: String, startSection: Int, endSection: Int): String =
        "周 $weekday $startSection～$endSection 节"

    /**
     * Dart `_weekdayShort`（`course_conflict_screen.dart:199-210`）：
     * 1-7 映射短名，**其余值原样返回数字串**（不抛错、不回落）。
     */
    fun weekdayShort(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayShortMonday
        2 -> weekdayShortTuesday
        3 -> weekdayShortWednesday
        4 -> weekdayShortThursday
        5 -> weekdayShortFriday
        6 -> weekdayShortSaturday
        7 -> weekdayShortSunday
        else -> dayOfWeek.toString()
    }

    const val weekdayShortMonday = "一"
    const val weekdayShortTuesday = "二"
    const val weekdayShortWednesday = "三"
    const val weekdayShortThursday = "四"
    const val weekdayShortFriday = "五"
    const val weekdayShortSaturday = "六"
    const val weekdayShortSunday = "日"
}
