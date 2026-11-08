package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.CourseNature

/**
 * 字符串上的占位符替换，用于在 [ArbText.filled]（返回 String）的结果上**链式**续填
 * 其余占位符——对拍测试与调用点都是
 * `sectionRangeLabel.filled("startSection", …).filled("endSection", …)` 这种链式写法。
 * 同包可见，测试无需 import。
 */
fun String.filled(name: String, value: String): String = replace("{$name}", value)

/**
 * 加课 / 改课表单（`lib/screens/add_course_screen.dart` +
 * `lib/screens/add_course_week_picker_tiles.dart`）用到的 ARB 文案
 * （`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [AddCourseStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 命名与 ARB 键逐字一致（`addCourseTitle` 等），便于 `grep` 双向核对。
 * [ArbText] 定义在 `CourseOverviewStrings.kt`（同包同源集），本文件复用、不重复声明。
 */
object AddCourseStrings {

    // ── 页面骨架 / 顶栏 ──
    val addCourseTitle = ArbText("addCourseTitle", "添加课程")
    val editCourseTitle = ArbText("editCourseTitle", "编辑课程")
    val saveAction = ArbText("saveAction", "保存")
    val savingAction = ArbText("savingAction", "保存中……")
    val saveFailed = ArbText("saveFailed", "保存失败")
    val cancelAction = ArbText("cancelAction", "取消")
    val confirmAction = ArbText("confirmAction", "确认")
    val deleteAction = ArbText("deleteAction", "删除")
    val deleteFailed = ArbText("deleteFailed", "删除失败")

    // ── 保存 / 删除结果提示 ──
    val courseAddedSuccess = ArbText("courseAddedSuccess", "课程添加成功")
    val courseUpdatedSuccess = ArbText("courseUpdatedSuccess", "课程更新成功")
    val courseDeleted = ArbText("courseDeleted", "课程已删除")
    val deleteCourseTitle = ArbText("deleteCourseTitle", "删除课程")
    val confirmDeleteCourseMessage = ArbText("confirmDeleteCourseMessage", "确定删除课程 {name}？")

    // ── 放弃修改（PopScope 拦截）──
    val courseFormDiscardTitle = ArbText("courseFormDiscardTitle", "放弃修改？")
    val courseFormDiscardMessage = ArbText("courseFormDiscardMessage", "离开后，这门课这次填写的内容不会保存。")
    val courseFormDiscardAction = ArbText("courseFormDiscardAction", "放弃修改")

    // ── 共享信息卡 ──
    val sharedInfoTitle = ArbText("sharedInfoTitle", "共享信息")
    val sharedInfoInlineHint = ArbText("sharedInfoInlineHint", "改动同步到同名课")
    val courseNameLabel = ArbText("courseNameLabel", "课程名称（必填）")
    val courseNameHelper = ArbText("courseNameHelper", "同名课会合并成一门课")
    val pleaseEnterCourseName = ArbText("pleaseEnterCourseName", "请输入课程名称")
    val courseShortNameOptional = ArbText("courseShortNameOptional", "课程简称（可选）")
    val courseShortNameHelper = ArbText("courseShortNameHelper", "超级岛显示，建议 3 字内")
    val courseShortNameAutoFillAction = ArbText("courseShortNameAutoFillAction", "取前两字")
    val courseDescriptionOptional = ArbText("courseDescriptionOptional", "课程简介（可选）")
    val teacherLabel = ArbText("teacherLabel", "授课教师")
    val locationLabel = ArbText("locationLabel", "上课地点")
    val courseColorTitle = ArbText("courseColorTitle", "课程颜色")
    val courseNatureLabel = ArbText("courseNatureLabel", "课程性质")
    val courseNatureRequired = ArbText("courseNatureRequired", "必修")
    val courseNatureElective = ArbText("courseNatureElective", "选修")

    // ── 沿用已有课程 ──
    val reuseExistingCourseLabel = ArbText("reuseExistingCourseLabel", "沿用已有课程")
    val reuseExistingCourseHelper = ArbText("reuseExistingCourseHelper", "带入这门课已有的信息")
    val noTemplateCoursesHint =
        ArbText("noTemplateCoursesHint", "当前课表里还没有现成课程，先手动录入一门，后面临时加课就能直接选了")

    // ── 教师 / 地点选择弹层 ──
    val selectTeacherTitle = ArbText("selectTeacherTitle", "选择教师")
    val selectLocationTitle = ArbText("selectLocationTitle", "选择教室")
    val manualInputLabel = ArbText("manualInputLabel", "手动填写")

    // ── 时间模板行 ──
    val timeSchemeLabel = ArbText("timeSchemeLabel", "时间模板")
    val followLocationAutoTimeScheme = ArbText("followLocationAutoTimeScheme", "跟随课表 / 地点自动")
    val followCurrentTimetableWithName = ArbText("followCurrentTimetableWithName", "跟随当前课表 {name}")
    val timetableAppName = ArbText("timetableAppName", "轻屿课表")
    val locationTimeAutoResolvedByGroup = ArbText("locationTimeAutoResolvedByGroup", "地点组 {group} → {scheme}")
    val locationTimeAutoResolvedByTimetable = ArbText("locationTimeAutoResolvedByTimetable", "课表默认 → {scheme}")
    val locationTimeMatchedSchemeHint = ArbText("locationTimeMatchedSchemeHint", "地点匹配 · {scheme}")

    // ── 节次 / 星期 ──
    val weekdayLabel = ArbText("weekdayLabel", "星期")
    val startSectionLabel = ArbText("startSectionLabel", "开始节次")
    val endSectionLabel = ArbText("endSectionLabel", "结束节次")
    val sectionLabel = ArbText("sectionLabel", "第 {section} 节")
    val sectionRangeLabel = ArbText("sectionRangeLabel", "第 {startSection}～{endSection} 节")
    val scheduleSectionNumberLabel = ArbText("scheduleSectionNumberLabel", "{section} 节")
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")
    val weekdayShortMonday = ArbText("weekdayShortMonday", "一")
    val weekdayShortTuesday = ArbText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = ArbText("weekdayShortWednesday", "三")
    val weekdayShortThursday = ArbText("weekdayShortThursday", "四")
    val weekdayShortFriday = ArbText("weekdayShortFriday", "五")
    val weekdayShortSaturday = ArbText("weekdayShortSaturday", "六")
    val weekdayShortSunday = ArbText("weekdayShortSunday", "日")
    val weekdaySectionSummary = ArbText("weekdaySectionSummary", "周 {weekday} {startSection}～{endSection} 节")

    // ── 排课记录卡 ──
    val scheduleEntrySingleTitle = ArbText("scheduleEntrySingleTitle", "上课安排")
    val scheduleEntryTitle = ArbText("scheduleEntryTitle", "排课记录 {index}")
    val addScheduleEntryAction = ArbText("addScheduleEntryAction", "添加排课时间")
    val conflictLabel = ArbText("conflictLabel", "冲突")

    // ── 周次 ──
    val scheduleEntryWeeksSectionTitle = ArbText("scheduleEntryWeeksSectionTitle", "哪些周上")
    val startWeekLabel = ArbText("startWeekLabel", "开始周")
    val endWeekLabel = ArbText("endWeekLabel", "结束周")
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val allWeeksFilter = ArbText("allWeeksFilter", "全部")
    val oddWeeksFilter = ArbText("oddWeeksFilter", "单周")
    val evenWeeksFilter = ArbText("evenWeeksFilter", "双周")
    val selectAtLeastOneWeek = ArbText("selectAtLeastOneWeek", "请至少选择一个上课周次")
    val weekPickerTitle = ArbText("weekPickerTitle", "选择上课周次")
    val rangeWeeksLabel = ArbText("rangeWeeksLabel", "连续周")
    val customWeeksLabel = ArbText("customWeeksLabel", "自定义周")
    val selectAllAction = ArbText("selectAllAction", "全选")
    val selectOddWeeksAction = ArbText("selectOddWeeksAction", "单周")
    val selectEvenWeeksAction = ArbText("selectEvenWeeksAction", "双周")
    val selectedWeeksSummary = ArbText("selectedWeeksSummary", "已选 {count} 周：第 {weeks} 周")

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            addCourseTitle,
            addScheduleEntryAction,
            allWeeksFilter,
            cancelAction,
            confirmAction,
            confirmDeleteCourseMessage,
            conflictLabel,
            courseAddedSuccess,
            courseColorTitle,
            courseDeleted,
            courseDescriptionOptional,
            courseFormDiscardAction,
            courseFormDiscardMessage,
            courseFormDiscardTitle,
            courseNameHelper,
            courseNameLabel,
            courseNatureLabel,
            courseShortNameAutoFillAction,
            courseShortNameHelper,
            courseShortNameOptional,
            courseUpdatedSuccess,
            customWeeksLabel,
            deleteAction,
            deleteCourseTitle,
            deleteFailed,
            editCourseTitle,
            endSectionLabel,
            endWeekLabel,
            evenWeeksFilter,
            followCurrentTimetableWithName,
            followLocationAutoTimeScheme,
            locationLabel,
            locationTimeAutoResolvedByGroup,
            locationTimeAutoResolvedByTimetable,
            locationTimeMatchedSchemeHint,
            manualInputLabel,
            noTemplateCoursesHint,
            oddWeeksFilter,
            pleaseEnterCourseName,
            rangeWeeksLabel,
            reuseExistingCourseHelper,
            reuseExistingCourseLabel,
            saveAction,
            saveFailed,
            savingAction,
            scheduleEntrySingleTitle,
            scheduleEntryTitle,
            scheduleEntryWeeksSectionTitle,
            scheduleSectionNumberLabel,
            sectionLabel,
            sectionRangeLabel,
            selectAllAction,
            selectAtLeastOneWeek,
            selectEvenWeeksAction,
            selectLocationTitle,
            selectOddWeeksAction,
            selectTeacherTitle,
            selectedWeeksSummary,
            sharedInfoInlineHint,
            sharedInfoTitle,
            startSectionLabel,
            startWeekLabel,
            teacherLabel,
            timeSchemeLabel,
            timetableAppName,
            weekLabel,
            weekPickerTitle,
            weekdayFri,
            weekdayLabel,
            weekdayMon,
            weekdaySat,
            weekdaySectionSummary,
            weekdayShortFriday,
            weekdayShortMonday,
            weekdayShortSaturday,
            weekdayShortSunday,
            weekdayShortThursday,
            weekdayShortTuesday,
            weekdayShortWednesday,
            weekdaySun,
            weekdayThu,
            weekdayTue,
            weekdayWed,
            courseNatureRequired,
            courseNatureElective,
        )
    }

    /** 星期整名（对齐 `add_course_screen.dart:_weekdayLabels`，越界回落空串）。 */
    fun weekdayName(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayMon.text
        2 -> weekdayTue.text
        3 -> weekdayWed.text
        4 -> weekdayThu.text
        5 -> weekdayFri.text
        6 -> weekdaySat.text
        7 -> weekdaySun.text
        else -> ""
    }

    /** 星期短名（对齐 `course_group.dart:_weekdayShortLabel` 的中文部分，越界回落空串）。 */
    fun weekdayShortName(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> weekdayShortMonday.text
        2 -> weekdayShortTuesday.text
        3 -> weekdayShortWednesday.text
        4 -> weekdayShortThursday.text
        5 -> weekdayShortFriday.text
        6 -> weekdayShortSaturday.text
        7 -> weekdayShortSunday.text
        else -> ""
    }

    /** 课程性质（对齐 `lib/l10n/enum_localizations.dart:courseNatureLabel`）。 */
    fun courseNatureName(nature: CourseNature): String = when (nature) {
        CourseNature.REQUIRED -> courseNatureRequired.text
        CourseNature.ELECTIVE -> courseNatureElective.text
    }

    /** 星期整名列表（周一到周日，顺序与 `_weekdayLabels` 一致）。 */
    fun weekdayNames(): List<String> = listOf(
        weekdayMon.text,
        weekdayTue.text,
        weekdayWed.text,
        weekdayThu.text,
        weekdayFri.text,
        weekdaySat.text,
        weekdaySun.text,
    )

    /** 「排课记录 N」标题（N 为 1-based 序号）。 */
    fun scheduleEntryIndexTitle(oneBasedIndex: Int): String =
        scheduleEntryTitle.filled("index", oneBasedIndex.toString())

    /** 节次范围摘要（「第 6～8 节」）。 */
    fun sectionRangeText(startSection: Int, endSection: Int): String =
        sectionRangeLabel.filled("startSection", startSection.toString()).filled("endSection", endSection.toString())
}
