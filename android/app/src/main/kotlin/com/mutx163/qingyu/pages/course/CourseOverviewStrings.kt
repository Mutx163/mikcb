package com.mutx163.qingyu.pages.course

/**
 * 课程总览 (Course Overview) 模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [CourseOverviewStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 命名与 ARB 键逐字一致（`courseOverviewTitle` 等），便于 `grep` 双向核对。
 * 对应页面：`lib/screens/course_overview_screen.dart`；课表摘要模板
 * `weekdaySectionSummary` 与星期短名来自 `lib/utils/course_group.dart` 的
 * `scheduleChipLabels`。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

object CourseOverviewStrings {

    // ── 课程总览页（course_overview_screen.dart）──
    val courseOverviewTitle = ArbText("courseOverviewTitle", "课程总览与编辑")
    val addNewCourseTooltip = ArbText("addNewCourseTooltip", "添加新课程")
    val emptyCourseOverviewHint = ArbText("emptyCourseOverviewHint", "长按课表或点击右上角添加课程")
    val sortAction = ArbText("sortAction", "排序")
    val sortByAdded = ArbText("sortByAdded", "按添加顺序")
    val sortByName = ArbText("sortByName", "按课程名称")
    val sortBySchedule = ArbText("sortBySchedule", "按排课时间")

    // ── 冲突入口与标记 ──
    val conflictLabel = ArbText("conflictLabel", "冲突")
    val conflictCountLabel = ArbText("conflictCountLabel", "冲突 {count} 节")
    val courseConflictDetailEntryTitle = ArbText("courseConflictDetailEntryTitle", "查看冲突详情")

    // ── 课程性质（lib/l10n/enum_localizations.dart:courseNatureLabel）──
    val courseNatureRequired = ArbText("courseNatureRequired", "必修")
    val courseNatureElective = ArbText("courseNatureElective", "选修")

    // ── 通用（返回键无障碍描述沿用 ARB 通用键，对齐 ScheduleListPage 先例）──
    val cancelAction = ArbText("cancelAction", "取消")

    // ── 星期短名与课表摘要（course_group.dart:scheduleChipLabels）──
    val weekdayShortMonday = ArbText("weekdayShortMonday", "一")
    val weekdayShortTuesday = ArbText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = ArbText("weekdayShortWednesday", "三")
    val weekdayShortThursday = ArbText("weekdayShortThursday", "四")
    val weekdayShortFriday = ArbText("weekdayShortFriday", "五")
    val weekdayShortSaturday = ArbText("weekdayShortSaturday", "六")
    val weekdayShortSunday = ArbText("weekdayShortSunday", "日")
    val weekdaySectionSummary = ArbText("weekdaySectionSummary", "周 {weekday} {startSection}～{endSection} 节")

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            courseOverviewTitle,
            addNewCourseTooltip,
            emptyCourseOverviewHint,
            sortAction,
            cancelAction,
            sortByAdded,
            sortByName,
            sortBySchedule,
            conflictLabel,
            conflictCountLabel,
            courseConflictDetailEntryTitle,
            courseNatureRequired,
            courseNatureElective,
            weekdayShortMonday,
            weekdayShortTuesday,
            weekdayShortWednesday,
            weekdayShortThursday,
            weekdayShortFriday,
            weekdayShortSaturday,
            weekdayShortSunday,
            weekdaySectionSummary,
        )
    }

    /** 星期短名（对齐 course_group.dart:_weekdayShortLabel，越界回落数字）。 */
    fun weekdayShortLabel(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayShortMonday.zh
        2 -> weekdayShortTuesday.zh
        3 -> weekdayShortWednesday.zh
        4 -> weekdayShortThursday.zh
        5 -> weekdayShortFriday.zh
        6 -> weekdayShortSaturday.zh
        7 -> weekdayShortSunday.zh
        else -> dayOfWeek.toString()
    }
}
