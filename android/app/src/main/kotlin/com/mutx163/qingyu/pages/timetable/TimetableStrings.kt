package com.mutx163.qingyu.pages.timetable

/**
 * 封装 ARB 键名与中文原文的数据结构，便于单测机械化对拍。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板中的单占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    /** 替换模板中的多个占位符。 */
    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

/**
 * 课表周视图与课表档案管理模块用到的全部 ARB 文案与纯格式化函数（`lib/l10n/app_zh.arb`）。
 *
 * **逐字抄录，不许改写**：每一条都在 [TimetableStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。
 */
object TimetableStrings {

    // ── 课表档案管理 ──
    val timetableProfilesTitle = ArbText("timetableProfilesTitle", "课表管理")
    val createTimetableTooltip = ArbText("createTimetableTooltip", "新建课表")
    val createTimetableTitle = ArbText("createTimetableTitle", "新建课表")
    val timetableNameLabel = ArbText("timetableNameLabel", "课表名称")
    val timetableNameHint = ArbText("timetableNameHint", "例如：大二下")
    val createdProfile = ArbText("createdProfile", "已创建课表：{name}")
    val switchProfileHint = ArbText("switchProfileHint", "点击切换课表")
    val switchToThisTimetable = ArbText("switchToThisTimetable", "切换到此课表")
    val switchedToProfile = ArbText("switchedToProfile", "已切换到 {name}")
    val renameTimetableTitle = ArbText("renameTimetableTitle", "重命名课表")
    val renamedProfile = ArbText("renamedProfile", "已重命名为 {name}")
    val duplicateAction = ArbText("duplicateAction", "复制")
    val copiedCurrentTimetable = ArbText("copiedCurrentTimetable", "已复制当前课表")
    val clearCoursesAction = ArbText("clearCoursesAction", "清空课程")
    val clearCurrentTimetableTitle = ArbText("clearCurrentTimetableTitle", "清空当前课表")
    val clearedProfile = ArbText("clearedProfile", "已清空课表：{name}")
    val noCoursesInCurrentProfile = ArbText("noCoursesInCurrentProfile", "当前课表已经没有课程")
    val deleteTimetableTitle = ArbText("deleteTimetableTitle", "删除课表")
    val deletedProfile = ArbText("deletedProfile", "已删除课表：{name}")
    val keepAtLeastOneProfile = ArbText("keepAtLeastOneProfile", "至少保留一个课表")
    val unnamedTimetableProfile = ArbText("unnamedTimetableProfile", "未命名课表")
    val saveFailed = ArbText("saveFailed", "保存失败")
    val deleteFailed = ArbText("deleteFailed", "删除失败")
    val clearFailed = ArbText("clearFailed", "清空失败，课表内容没有变化")

    // ── 周视图导航与网格展示 ──
    val backToCurrentWeekAction = ArbText("backToCurrentWeekAction", "回本周")
    val nonCurrentWeekLabel = ArbText("nonCurrentWeekLabel", "非本周")
    val currentWeekBullet = ArbText("currentWeekBullet", "当前周：第 {week} 周")
    val coursesAndWeekSummary = ArbText("coursesAndWeekSummary", "{count} 门课程 · 第 {week} 周")
    val sectionLabel = ArbText("sectionLabel", "第 {section} 节")
    val conflictCountLabel = ArbText("conflictCountLabel", "冲突 {count} 节")
    val conflictLabel = ArbText("conflictLabel", "冲突")
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val todayTimetableTitle = ArbText("todayTimetableTitle", "今日课表")
    val dayViewEmptyTitle = ArbText("dayViewEmptyTitle", "暂无课程")

    // ── 星期几名称 ──
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    // ── 周视图空态专用文案（新UI规范定义） ──
    val noCourseThisWeek = ArbText("noCourseThisWeek", "本周无课")

    // ── 纯函数格式化 ──

    fun formatCurrentWeek(week: Int): String =
        currentWeekBullet.filled("week", week.toString())

    fun formatCoursesAndWeekSummary(count: Int, week: Int): String =
        coursesAndWeekSummary.filled("count" to count.toString(), "week" to week.toString())

    fun formatSection(section: Int): String =
        sectionLabel.filled("section", section.toString())

    fun formatConflictCount(count: Int): String =
        conflictCountLabel.filled("count", count.toString())

    fun formatWeekLabel(week: Int): String =
        weekLabel.filled("week", week.toString())

    fun formatSwitchedToProfile(name: String): String =
        switchedToProfile.filled("name", name)

    fun formatCreatedProfile(name: String): String =
        createdProfile.filled("name", name)

    fun formatRenamedProfile(name: String): String =
        renamedProfile.filled("name", name)

    fun formatDeletedProfile(name: String): String =
        deletedProfile.filled("name", name)

    fun formatClearedProfile(name: String): String =
        clearedProfile.filled("name", name)

    fun formatWeekday(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayMon.zh
        2 -> weekdayTue.zh
        3 -> weekdayWed.zh
        4 -> weekdayThu.zh
        5 -> weekdayFri.zh
        6 -> weekdaySat.zh
        7 -> weekdaySun.zh
        else -> ""
    }

    /**
     * 所有严格收录在 `lib/l10n/app_zh.arb` 的条目清单，供机械化单测逐字对拍。
     */
    val arbTexts: List<ArbText> by lazy {
        listOf(
            timetableProfilesTitle,
            createTimetableTooltip,
            createTimetableTitle,
            timetableNameLabel,
            timetableNameHint,
            createdProfile,
            switchProfileHint,
            switchToThisTimetable,
            switchedToProfile,
            renameTimetableTitle,
            renamedProfile,
            duplicateAction,
            copiedCurrentTimetable,
            clearCoursesAction,
            clearCurrentTimetableTitle,
            clearedProfile,
            noCoursesInCurrentProfile,
            deleteTimetableTitle,
            deletedProfile,
            keepAtLeastOneProfile,
            unnamedTimetableProfile,
            saveFailed,
            deleteFailed,
            clearFailed,
            backToCurrentWeekAction,
            nonCurrentWeekLabel,
            currentWeekBullet,
            coursesAndWeekSummary,
            sectionLabel,
            conflictCountLabel,
            conflictLabel,
            weekLabel,
            todayTimetableTitle,
            dayViewEmptyTitle,
            weekdayMon,
            weekdayTue,
            weekdayWed,
            weekdayThu,
            weekdayFri,
            weekdaySat,
            weekdaySun,
        )
    }
}
