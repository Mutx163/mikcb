package com.mutx163.qingyu.pages.timetable

/**
 * 封装 ARB 键名与中文原文的数据结构，便于单测机械化对拍。
 */
typealias ArbText = com.mutx163.qingyu.app.ArbText

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

    // ── 课表管理页动作与确认正文（2026-11-03 自 composeP1 渲染层中文常量对象迁入）──
    // 十条键全部是 ARB 既有键，无新增文案；原来散在 TimetableProfilesStrings 里的
    // 常量按 ArbText 口径逐字抄录，入 [arbTexts] 清单随 parity 测试对拍。
    val createAction = ArbText("createAction", "创建")
    val cancelAction = ArbText("cancelAction", "取消")
    val renameAction = ArbText("renameAction", "重命名")
    val clearAction = ArbText("clearAction", "清空")
    val deleteAction = ArbText("deleteAction", "删除")
    val moreActionsTooltip = ArbText("moreActionsTooltip", "更多操作")
    val coupleTimetablePartnerReadOnlyBadge = ArbText("coupleTimetablePartnerReadOnlyBadge", "对方课表 只读")
    val coupleTimetableTitle = ArbText("coupleTimetableTitle", "情侣课表")
    /** 课表管理页当前生效课表的徽章无障碍描述（`TimetableProfilesPage` 激活态图标）。 */
    val timetableProfileActiveBadge = ArbText("timetableProfileActiveBadge", "已激活")
    val clearCurrentTimetableMessage =
        ArbText("clearCurrentTimetableMessage", "确定清空 {name} 的全部课程？课表设置将保留")
    val deleteTimetableMessage = ArbText("deleteTimetableMessage", "确定删除课表 {name}？")

    /** 清空当前课表的确认正文（Dart `l10n.clearCurrentTimetableMessage`）。 */
    fun formatClearCurrentTimetableMessage(name: String): String =
        clearCurrentTimetableMessage.filled("name", name)

    /** 删除课表的确认正文（Dart `l10n.deleteTimetableMessage`）。 */
    fun formatDeleteTimetableMessage(name: String): String =
        deleteTimetableMessage.filled("name", name)

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

    // ── 顶栏「轻屿课表」+ 右上角「更多」菜单（Dart HomeGridMenu.defaultActions 的默认 8 条）──
    // 标题与菜单标题都复用既有 ARB 键（appTitle / moreTooltip / homeMenuXxx），
    // 与 Flutter 版同源，不另拟说法。
    val appTitle = ArbText("appTitle", "轻屿课表")
    val moreTooltip = ArbText("moreTooltip", "更多")
    val homeMenuOverviewTitle = ArbText("homeMenuOverviewTitle", "课程总览")
    val homeMenuStatisticsTitle = ArbText("homeMenuStatisticsTitle", "课程统计")
    val homeMenuAddCourseTitle = ArbText("homeMenuAddCourseTitle", "添加")
    val examListTitle = ArbText("examListTitle", "考试安排")
    val homeMenuTasksTitle = ArbText("homeMenuTasksTitle", "任务清单")
    val homeMenuImportTitle = ArbText("homeMenuImportTitle", "导入课程")
    val homeMenuSettingsTitle = ArbText("homeMenuSettingsTitle", "课表设置")
    val homeMenuCoffeeTitle = ArbText("homeMenuCoffeeTitle", "请喝咖啡")

    // ── 「添加」行的二级列表（Dart `kAddCourseSubmenu`，`home_top_menu.dart:88-96`）──
    // 列表档菜单里「添加」不是直接跳转，而是展开成这三项。文案复用三宫格添加弹层
    // 已有的 ARB 键，不另拟说法（Dart 同口径）。
    val addCourseTitle = ArbText("addCourseTitle", "添加课程")
    val addScheduleAction = ArbText("addScheduleAction", "添加日程")
    val addExam = ArbText("addExam", "添加考试")

    // ── 星期几名称 ──
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    // ── 截屏「分享课表图」提示与导出分享（Dart timetable_screen.dart:956-961 的胶囊 +
    // timetable_share_service.dart 的分享正文 + timetable_export_document.dart 的图内标题）──
    // 提示壳见 composeP1 的 ScreenshotSharePromptHost。导出面板已随 2026-11-03 的
    // 「干净课表图」落地（TimetableShareImageModel/Render/Launcher），动作按钮接
    // AppToastCapsule 的 actionLabel/onAction，动作 = 直接分享当前视图的图（Dart
    // _shareTimetableImage 同口径：没有中间面板）。
    val timetableSharePromptMessage = ArbText("timetableSharePromptMessage", "要分享一张干净的课表图吗？")
    val timetableSharePromptAction = ArbText("timetableSharePromptAction", "分享")

    /** 分享正文（Dart `ShareParams(text: l10n.timetableShareText)`，`timetable_share_service.dart:84`）。 */
    val timetableShareText = ArbText("timetableShareText", "来自轻屿课表的课表")

    /** 导出图标题：周图「第 {week} 周课表」（Dart `timetableShareExportWeekTitle`）。 */
    val timetableShareExportWeekTitle = ArbText("timetableShareExportWeekTitle", "第 {week} 周课表")

    /** 导出图标题：日图「第 {week} 周 · {weekday}」（Dart `timetableShareExportDayTitle`）。 */
    val timetableShareExportDayTitle = ArbText("timetableShareExportDayTitle", "第 {week} 周 · {weekday}")

    /** 日图空态「这天没有课」（Dart `timetableShareExportEmptyDay`）。 */
    val timetableShareExportEmptyDay = ArbText("timetableShareExportEmptyDay", "这天没有课")

    fun timetableShareExportWeek(week: Int): String =
        timetableShareExportWeekTitle.filled("week", week.toString())

    fun timetableShareExportDay(week: Int, weekday: String): String =
        timetableShareExportDayTitle.filled("week" to week.toString(), "weekday" to weekday)

    // ── 周视图表头 / 课卡 / 周次选择器（全部来自 ARB，2026-10-29 重做时补齐）──
    /** 星期栏左端周次简写（Dart `timetable_weekday_header.dart:181`，`{week} 周` 带半角空格）。 */
    val currentWeekCompact = ArbText("currentWeekCompact", "{week} 周")
    val selectWeekTitle = ArbText("selectWeekTitle", "选择周次")
    val closeAction = ArbText("closeAction", "关闭")

    /** 周次弹层说明行「共 N 周」（Dart `l10n.availableWeeksCount`，`week_selector_picker_sheet.dart:44`）。 */
    val availableWeeksCount = ArbText("availableWeeksCount", "共 {count} 周")

    /** 周次弹层里的一格「第 N 周」（Dart `l10n.goToWeekLabel`，`:96`）。 */
    val goToWeekLabel = ArbText("goToWeekLabel", "第 {week} 周")

    fun availableWeeks(count: Int): String =
        availableWeeksCount.filled("count", count.toString())

    fun goToWeek(week: Int): String = goToWeekLabel.filled("week", week.toString())

    /** 课卡「开始 / 结束」时间行（Dart `course_card.dart` `classStartsAtLabel`）。 */
    val classStartsAtLabel = ArbText("classStartsAtLabel", "{time} 开始")
    val classEndsAtLabel = ArbText("classEndsAtLabel", "{time} 结束")

    /** 周网格里的考试 / 日程徽标（Dart `week_grid_agenda_card.dart`）。 */
    val examBadgeLabel = ArbText("examBadgeLabel", "考试")
    val scheduleBadgeLabel = ArbText("scheduleBadgeLabel", "日程")

    /**
     * 课卡右上角「假期 / 停课」角标（Dart `course_card.dart:_buildBadgeRow`，
     * `:622-639`：`l10n.holidayBadgeLabel` / `l10n.suspendedBadgeLabel`）。
     *
     * 2026-10-29 二轮审核：Compose 课卡只有「冲突」一枚角标，假/停两枚从来没画过。
     */
    val holidayBadgeLabel = ArbText("holidayBadgeLabel", "假")
    val suspendedBadgeLabel = ArbText("suspendedBadgeLabel", "停")

    /**
     * 课卡作业角标的无障碍描述（ARB `courseTaskAction` = 「作业」）。
     *
     * 与 `DayViewStrings.courseTaskAction` 同源同键：两个字面同一句 ARB 原文，
     * 周视图与日视图各自引用自己域的对象，避免跨域 import 与重复维护。
     */
    val courseTaskAction = ArbText("courseTaskAction", "作业")

    /**
     * 课卡天气行的片段（Dart `CourseWeatherDisplay`）。
     *
     * 复用 ARB 里既有的三条模板（`weatherTemperatureValue` 等），不另拟说法。
     */
    val weatherTemperatureValue = ArbText("weatherTemperatureValue", "{temperature}°")
    val weatherProbabilityValue = ArbText("weatherProbabilityValue", "{probability}%")
    val weatherSummarySeparator = ArbText("weatherSummarySeparator", " · ")

    /** 课卡周次行（Dart `l10n/course_week_localizations.dart`）。 */
    val oddWeeksFilter = ArbText("oddWeeksFilter", "单周")
    val evenWeeksFilter = ArbText("evenWeeksFilter", "双周")
    val weekListSeparator = ArbText("weekListSeparator", "、")
    val courseWeekListLabel = ArbText("courseWeekListLabel", "第 {weeks} 周")
    val courseWeekRangeLabel = ArbText("courseWeekRangeLabel", "第 {startWeek}～{endWeek} 周{mode}")

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
        1 -> weekdayMon.text
        2 -> weekdayTue.text
        3 -> weekdayWed.text
        4 -> weekdayThu.text
        5 -> weekdayFri.text
        6 -> weekdaySat.text
        7 -> weekdaySun.text
        else -> ""
    }

    /** 星期栏左端「{week} 周」（Dart `l10n.currentWeekCompact`）。 */
    fun formatCurrentWeekCompact(week: Int): String =
        currentWeekCompact.filled("week", week.toString())

    /** 课卡开始时间行（Dart `l10n.classStartsAtLabel`）。 */
    fun formatClassStartsAt(time: String): String = classStartsAtLabel.filled("time", time)

    /** 课卡结束时间行（Dart `l10n.classEndsAtLabel`）。 */
    fun formatClassEndsAt(time: String): String = classEndsAtLabel.filled("time", time)

    /**
     * 课卡天气一行：`小雨 · 23° · 60%`（Dart `CourseWeatherDisplay` 的紧凑口径）。
     *
     * 片段顺序与开关一一对应（现象 / 温度 / 降水概率），任一段为空就不出现，
     * 中间用 ARB `weatherSummarySeparator`（` · `）连接。
     *
     * @param phenomenon 天气现象中文名（由宿主从 ARB `weatherXxx` 取，见 `WeatherStrings.categoryLabel`）
     * @param temperatureC 温度（摄氏度整数）
     * @param probability 降水概率百分比；为 null 或开关关闭时不出现
     */
    fun formatWeatherLine(
        phenomenon: String?,
        temperatureC: Int?,
        probability: Int?,
        showPhenomenon: Boolean = true,
        showTemperature: Boolean = true,
        showProbability: Boolean = false,
    ): String? {
        val parts = mutableListOf<String>()
        if (showPhenomenon) phenomenon?.trim()?.takeIf { it.isNotEmpty() }?.let { parts += it }
        if (showTemperature && temperatureC != null) {
            parts += weatherTemperatureValue.filled("temperature", temperatureC.toString())
        }
        if (showProbability && probability != null) {
            parts += weatherProbabilityValue.filled("probability", probability.toString())
        }
        if (parts.isEmpty()) return null
        return parts.joinToString(weatherSummarySeparator.text)
    }

    /**
     * 课程周次文案（Dart `courseWeekDescription`，`lib/l10n/course_week_localizations.dart:27`）。
     *
     * customWeeks 存在 ⇒ 「第 1、3、5 周」；否则「第 1～16 周 + 单/双周后缀」。
     */
    fun formatCourseWeekDescription(course: com.mutx163.qingyu.core.Course): String {
        val custom = course.normalizedCustomWeeks
        if (custom != null) {
            return courseWeekListLabel.filled("weeks", formatWeekList(custom))
        }
        val mode = when {
            course.isOddWeek -> " ${oddWeeksFilter.text}"
            course.isEvenWeek -> " ${evenWeeksFilter.text}"
            else -> ""
        }
        return courseWeekRangeLabel.filled(
            "startWeek" to course.startWeek.toString(),
            "endWeek" to course.endWeek.toString(),
            "mode" to mode,
        )
    }

    /** 连续周次压成区间后用 `、` 连接（Dart `formatCourseWeekList`）。 */
    fun formatWeekList(weeks: List<Int>): String {
        if (weeks.isEmpty()) return ""
        val sorted = weeks.sorted()
        val ranges = mutableListOf<String>()
        var rangeStart = sorted.first()
        var previous = sorted.first()
        for (index in 1 until sorted.size) {
            val current = sorted[index]
            if (current == previous + 1) {
                previous = current
                continue
            }
            ranges.add(if (rangeStart == previous) "$rangeStart" else "$rangeStart-$previous")
            rangeStart = current
            previous = current
        }
        ranges.add(if (rangeStart == previous) "$rangeStart" else "$rangeStart-$previous")
        return ranges.joinToString(weekListSeparator.text)
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
            createAction,
            cancelAction,
            renameAction,
            clearAction,
            deleteAction,
            moreActionsTooltip,
            coupleTimetablePartnerReadOnlyBadge,
            coupleTimetableTitle,
            timetableProfileActiveBadge,
            clearCurrentTimetableMessage,
            deleteTimetableMessage,
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
            appTitle,
            moreTooltip,
            homeMenuOverviewTitle,
            homeMenuStatisticsTitle,
            homeMenuAddCourseTitle,
            examListTitle,
            homeMenuTasksTitle,
            homeMenuImportTitle,
            homeMenuSettingsTitle,
            homeMenuCoffeeTitle,
            addCourseTitle,
            addScheduleAction,
            addExam,
            timetableSharePromptMessage,
            timetableSharePromptAction,
            timetableShareText,
            timetableShareExportWeekTitle,
            timetableShareExportDayTitle,
            timetableShareExportEmptyDay,
            weekdayMon,
            weekdayTue,
            weekdayWed,
            weekdayThu,
            weekdayFri,
            weekdaySat,
            weekdaySun,
            currentWeekCompact,
            selectWeekTitle,
            closeAction,
            availableWeeksCount,
            goToWeekLabel,
            classStartsAtLabel,
            classEndsAtLabel,
            examBadgeLabel,
            scheduleBadgeLabel,
            oddWeeksFilter,
            evenWeeksFilter,
            weekListSeparator,
            courseWeekListLabel,
            courseWeekRangeLabel,
            holidayBadgeLabel,
            suspendedBadgeLabel,
            courseTaskAction,
            weatherTemperatureValue,
            weatherProbabilityValue,
            weatherSummarySeparator,
        )
    }
}
