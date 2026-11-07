package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.weather.WeatherCategory
import com.mutx163.qingyu.weather.WeatherIconKind
import com.mutx163.qingyu.weather.WeatherLinePlan

/**
 * 课程操作弹层的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [CourseActionSheetStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，再同步这里。
 *
 * ## 为什么另开一份，而不是复用别人文件里的同名键
 *
 * 本仓的既有约定是**每个模块目录各定义一份 `ArbText` 句柄**（`pages/course` 的
 * [ArbText] 定义在 `CourseOverviewStrings.kt:15`；`pages/exam` / `pages/schedule` /
 * `pages/statistics` 各自也重复声明了 `weekdayMon` 等键）。这里沿用同一条约定：
 * 句柄重复、键与值唯一（都由 ARB 对拍兜住），换来的是本模块不依赖别人的文件不被别人改。
 *
 * **不重复定义** `ArbText` 本身 —— 同包顶层类，重复声明会编译不过。
 *
 * ## 边角料/口径
 *
 * - 日期 `10月29日`：ARB 没有通用日期键，Dart 用的是 `DateFormat.MMMd(locale)`。
 *   这里复用 [monthViewAgendaTitle]（`{month}月{day}日`，与 zh 的 `MMMd` 输出逐字一致）；
 *   另一候选 `holidayDateSameDay`（`{month} 月 {day} 日`）**带空格**，与 Dart 输出不一致，弃用。
 * - `courseActionEditPrimary` / `courseActionRescheduleSecondary` / `courseActionSuspendSecondary` /
 *   `courseActionUnsuspend` / `courseActionDeleteSecondary` / `courseActionSheetNotice` /
 *   `unknownTeacher` / `unknownLocation` / `courseActionPartnerReadOnlyNotice` 这 9 条已在
 *   `app/CourseActionStrings.kt`（Lead 拥有、已被 `CourseActionStringsParityTest` 对拍），
 *   本文件**不重复**，直接引用。
 */
object CourseActionSheetStrings {

    // ── 头部：课程性质 / 冲突 / 情侣角标 ──
    val courseNatureRequired = ArbText("courseNatureRequired", "必修")
    val courseNatureElective = ArbText("courseNatureElective", "选修")
    val conflictLabel = ArbText("conflictLabel", "冲突")
    val coupleTimetableLegendTogether = ArbText("coupleTimetableLegendTogether", "一起上课")
    val coupleTimetableLegendPartner = ArbText("coupleTimetableLegendPartner", "TA的课")
    val coupleTimetableLegendMine = ArbText("coupleTimetableLegendMine", "我的课")

    // ── 周次 / 节次 / 星期 ──
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val sectionRangeLabel = ArbText("sectionRangeLabel", "第 {startSection}～{endSection} 节")
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")
    val courseActionOddWeekShort = ArbText("courseActionOddWeekShort", "单周")
    val courseActionEvenWeekShort = ArbText("courseActionEvenWeekShort", "双周")

    /**
     * 日期「10月29日」。
     *
     * **复用理由**（ARB 不新增键）：值与 zh 的 `DateFormat.MMMd` 输出逐字一致，
     * 已 grep 确认全库只有它与 `holidayDateSameDay` 两个候选，后者带空格。
     */
    val monthViewAgendaTitle = ArbText("monthViewAgendaTitle", "{month}月{day}日")

    // ── 周次描述（Dart `course.weekDescription(l10n)` 的 Kotlin 对位件）──
    val shortNamePrefix = ArbText("shortNamePrefix", "简称：{value}")
    val courseWeekRangeLabel = ArbText("courseWeekRangeLabel", "第 {startWeek}～{endWeek} 周{mode}")
    val courseWeekListLabel = ArbText("courseWeekListLabel", "第 {weeks} 周")
    val weekListSeparator = ArbText("weekListSeparator", "、")
    val oddWeeksFilter = ArbText("oddWeeksFilter", "单周")
    val evenWeeksFilter = ArbText("evenWeeksFilter", "双周")

    // ── 备注行 ──
    val courseNoteAction = ArbText("courseNoteAction", "备注")
    val courseNoteTileSubtitleBoth = ArbText("courseNoteTileSubtitleBoth", "课程简介与本节课均有备注")
    val courseNoteTileSubtitleSession = ArbText("courseNoteTileSubtitleSession", "已有本节课备注")
    val courseNoteTileSubtitleWhole = ArbText("courseNoteTileSubtitleWhole", "已有课程简介")
    val courseNoteTileSubtitleEmpty = ArbText("courseNoteTileSubtitleEmpty", "记录携带物品或课堂提醒")

    // ── 作业行 ──
    val taskAddFromCourse = ArbText("taskAddFromCourse", "添加任务")
    val taskListTitle = ArbText("taskListTitle", "任务清单")
    val taskCompletedSection = ArbText("taskCompletedSection", "已完成")
    val taskHomeworkDefaultTitle = ArbText("taskHomeworkDefaultTitle", "课程作业")

    // ── 天气行 ──
    val weatherLoadingPlaceholder = ArbText("weatherLoadingPlaceholder", "天气加载中…")
    val weatherCourseTileSubtitle = ArbText("weatherCourseTileSubtitle", "该课程时段内的天气")
    val weatherTemperatureValue = ArbText("weatherTemperatureValue", "{temperature}°")
    val weatherProbabilityValue = ArbText("weatherProbabilityValue", "{probability}%")
    val weatherSummarySeparator = ArbText("weatherSummarySeparator", " · ")

    // ── 天气现象（Dart `WeatherCategoryLocalizer.label`）──
    val weatherClear = ArbText("weatherClear", "晴")
    val weatherMainlyClear = ArbText("weatherMainlyClear", "晴间多云")
    val weatherPartlyCloudy = ArbText("weatherPartlyCloudy", "多云")
    val weatherOvercast = ArbText("weatherOvercast", "阴")
    val weatherFog = ArbText("weatherFog", "雾")
    val weatherDrizzle = ArbText("weatherDrizzle", "毛毛雨")
    val weatherFreezingDrizzle = ArbText("weatherFreezingDrizzle", "冻毛毛雨")
    val weatherLightRain = ArbText("weatherLightRain", "小雨")
    val weatherRain = ArbText("weatherRain", "中雨")
    val weatherHeavyRain = ArbText("weatherHeavyRain", "大雨")
    val weatherFreezingRain = ArbText("weatherFreezingRain", "冻雨")
    val weatherRainShowers = ArbText("weatherRainShowers", "阵雨")
    val weatherHeavyRainShowers = ArbText("weatherHeavyRainShowers", "强阵雨")
    val weatherLightSnow = ArbText("weatherLightSnow", "小雪")
    val weatherSnow = ArbText("weatherSnow", "中雪")
    val weatherHeavySnow = ArbText("weatherHeavySnow", "大雪")
    val weatherSnowGrains = ArbText("weatherSnowGrains", "米雪")
    val weatherSnowShowers = ArbText("weatherSnowShowers", "阵雪")
    val weatherThunderstorm = ArbText("weatherThunderstorm", "雷阵雨")
    val weatherThunderstormHail = ArbText("weatherThunderstormHail", "雷阵雨伴冰雹")

    // ── 关联课程面板 ──
    val conflictCountLabel = ArbText("conflictCountLabel", "冲突 {count} 节")
    val courseActionCoupleRelatedCount = ArbText("courseActionCoupleRelatedCount", "还有 {count} 节情侣课表课程")
    val courseActionMixedRelatedCount = ArbText("courseActionMixedRelatedCount", "还有 {count} 节相关课程")
    val courseActionConflictCollapseHint = ArbText("courseActionConflictCollapseHint", "点击收起冲突课程列表")
    val courseActionCoupleCollapseHint = ArbText("courseActionCoupleCollapseHint", "点击收起情侣课表课程列表")
    val courseActionConflictExpandHint = ArbText(
        "courseActionConflictExpandHint",
        "展开查看其他冲突课程，点击可切换操作对象",
    )
    val courseActionCoupleExpandHint = ArbText(
        "courseActionCoupleExpandHint",
        "展开查看 TA 的课或一起上课，点击可切换预览",
    )
    val courseActionConflictSwitchAction = ArbText("courseActionConflictSwitchAction", "切换")

    // ── 删除确认（`CourseDeleteConfirmSheet` 的 title / message 由本泳道组装）──
    val deleteScheduleTitle = ArbText("deleteScheduleTitle", "删除日程")
    val deleteScheduleConfirmMessage = ArbText("deleteScheduleConfirmMessage", "确定删除 {name} 的排课？\n{detail}")
    val courseWeekdaySectionSummary = ArbText(
        "courseWeekdaySectionSummary",
        "{weekDescription} · {weekday} 第 {startSection}～{endSection} 节",
    )
    val deleteLessonTitle = ArbText("deleteLessonTitle", "删除这节课")
    val deleteOccurrenceConfirmMessage = ArbText(
        "deleteOccurrenceConfirmMessage",
        "确定删除 {name} 第 {week} 周的此节课程？\n{detail}",
    )
    val weekdaySectionTimeSummary = ArbText(
        "weekdaySectionTimeSummary",
        "{weekday} 第 {startSection}～{endSection} 节 · {startTime}～{endTime}",
    )

    /** 所有对接 ARB 的文案（Parity 测试逐字对拍用）。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            courseNatureRequired, courseNatureElective, conflictLabel,
            coupleTimetableLegendTogether, coupleTimetableLegendPartner, coupleTimetableLegendMine,
            weekLabel, sectionRangeLabel,
            weekdayMon, weekdayTue, weekdayWed, weekdayThu, weekdayFri, weekdaySat, weekdaySun,
            courseActionOddWeekShort, courseActionEvenWeekShort, monthViewAgendaTitle,
            shortNamePrefix, courseWeekRangeLabel, courseWeekListLabel, weekListSeparator,
            oddWeeksFilter, evenWeeksFilter,
            courseNoteAction, courseNoteTileSubtitleBoth, courseNoteTileSubtitleSession,
            courseNoteTileSubtitleWhole, courseNoteTileSubtitleEmpty,
            taskAddFromCourse, taskListTitle, taskCompletedSection, taskHomeworkDefaultTitle,
            weatherLoadingPlaceholder, weatherCourseTileSubtitle, weatherTemperatureValue,
            weatherProbabilityValue, weatherSummarySeparator,
            weatherClear, weatherMainlyClear, weatherPartlyCloudy, weatherOvercast, weatherFog,
            weatherDrizzle, weatherFreezingDrizzle, weatherLightRain, weatherRain, weatherHeavyRain,
            weatherFreezingRain, weatherRainShowers, weatherHeavyRainShowers, weatherLightSnow,
            weatherSnow, weatherHeavySnow, weatherSnowGrains, weatherSnowShowers,
            weatherThunderstorm, weatherThunderstormHail,
            conflictCountLabel, courseActionCoupleRelatedCount, courseActionMixedRelatedCount,
            courseActionConflictCollapseHint, courseActionCoupleCollapseHint,
            courseActionConflictExpandHint, courseActionCoupleExpandHint,
            courseActionConflictSwitchAction,
            deleteScheduleTitle, deleteScheduleConfirmMessage, courseWeekdaySectionSummary,
            deleteLessonTitle, deleteOccurrenceConfirmMessage, weekdaySectionTimeSummary,
        )
    }

    // ───────────────────────── 格式化 ─────────────────────────

    /** 周一到周日的全名，索引 = `dayOfWeek - 1`（越界由 [weekdayLabel] 兜底）。 */
    val weekdayLabels: List<String> = listOf(
        weekdayMon.text, weekdayTue.text, weekdayWed.text, weekdayThu.text,
        weekdayFri.text, weekdaySat.text, weekdaySun.text,
    )

    /** 星期全名；越界退化成数字（与 Dart `_weekdayLabel` 同口径）。 */
    fun weekdayLabel(dayOfWeek: Int): String =
        weekdayLabels.getOrNull(dayOfWeek - 1) ?: dayOfWeek.toString()

    /** `第 N 周`。 */
    fun weekLabel(week: Int): String = weekLabel.filled("week", week.toString())

    /** `第 A～B 节`。 */
    fun sectionRange(startSection: Int, endSection: Int): String =
        sectionRangeLabel
            .filled("startSection", startSection.toString())
            .filled("endSection", endSection.toString())

    /** `10月29日`（复用 [monthViewAgendaTitle]，见对象注释的复用理由）。 */
    fun dateLabel(month: Int, day: Int): String =
        monthViewAgendaTitle.filled("month", month.toString()).filled("day", day.toString())

    /** `简称：X`。 */
    fun shortName(value: String): String = shortNamePrefix.filled("value", value)

    /** `冲突 N 节`。 */
    fun conflictCount(count: Int): String = conflictCountLabel.filled("count", count.toString())

    /** `还有 N 节情侣课表课程`。 */
    fun coupleRelatedCount(count: Int): String =
        courseActionCoupleRelatedCount.filled("count", count.toString())

    /** `还有 N 节相关课程`。 */
    fun mixedRelatedCount(count: Int): String =
        courseActionMixedRelatedCount.filled("count", count.toString())

    /** 温度 `23°`。 */
    fun temperatureValue(celsius: Int): String =
        weatherTemperatureValue.filled("temperature", celsius.toString())

    /** 降水概率 `60%`。 */
    fun probabilityValue(percent: Int): String =
        weatherProbabilityValue.filled("probability", percent.toString())

    /** 天气现象名（Dart `WeatherCategoryLocalizer.label` 的 Kotlin 对位件）。 */
    fun weatherCategoryLabel(category: WeatherCategory): String = when (category) {
        WeatherCategory.CLEAR -> weatherClear.text
        WeatherCategory.MAINLY_CLEAR -> weatherMainlyClear.text
        WeatherCategory.PARTLY_CLOUDY -> weatherPartlyCloudy.text
        WeatherCategory.OVERCAST -> weatherOvercast.text
        WeatherCategory.FOG -> weatherFog.text
        WeatherCategory.DRIZZLE -> weatherDrizzle.text
        WeatherCategory.FREEZING_DRIZZLE -> weatherFreezingDrizzle.text
        WeatherCategory.LIGHT_RAIN -> weatherLightRain.text
        WeatherCategory.RAIN -> weatherRain.text
        WeatherCategory.HEAVY_RAIN -> weatherHeavyRain.text
        WeatherCategory.FREEZING_RAIN -> weatherFreezingRain.text
        WeatherCategory.RAIN_SHOWERS -> weatherRainShowers.text
        WeatherCategory.HEAVY_RAIN_SHOWERS -> weatherHeavyRainShowers.text
        WeatherCategory.LIGHT_SNOW -> weatherLightSnow.text
        WeatherCategory.SNOW -> weatherSnow.text
        WeatherCategory.HEAVY_SNOW -> weatherHeavySnow.text
        WeatherCategory.SNOW_GRAINS -> weatherSnowGrains.text
        WeatherCategory.SNOW_SHOWERS -> weatherSnowShowers.text
        WeatherCategory.THUNDERSTORM -> weatherThunderstorm.text
        WeatherCategory.THUNDERSTORM_HAIL -> weatherThunderstormHail.text
    }

    /**
     * 天气行的一句话（Dart `courseWeatherDisplayFor` + `WeatherTextDensity.full`）。
     *
     * 拼接顺序 = 设置页三项的排列顺序 = 图标认领优先级：现象 → 温度 → 概率，
     * 用 [weatherSummarySeparator] 连成一句（`小雨 · 23° · 60%`）。
     * 计划里图标由谁认领（[WeatherIconKind]）**不影响文字**，只影响图标形状。
     */
    fun weatherLineText(plan: WeatherLinePlan): String {
        val parts = mutableListOf<String>()
        if (plan.showPhenomenon) parts += weatherCategoryLabel(plan.category)
        if (plan.showTemperature) parts += temperatureValue(plan.temperatureC)
        plan.probability?.let { parts += probabilityValue(it) }
        return parts.joinToString(weatherSummarySeparator.text)
    }

    /**
     * 课程周次描述（Dart `course.weekDescription(l10n)` / `courseWeekDescription`）。
     *
     * Kotlin 侧**没有**现成对位件（已 grep `core/Course.kt` 与 `pages/timetable/TimetableStrings.kt`），
     * 这里按 Dart 的两条分支重建：
     * 1. 有自定义周次 → `courseWeekListLabel(压缩后的周次表)`；
     * 2. 否则 → `courseWeekRangeLabel(start, end, 单周/双周/空)`。
     */
    fun weekDescription(course: Course): String {
        val custom = course.normalizedCustomWeeks
        if (custom != null) {
            return courseWeekListLabel.filled("weeks", formatWeekList(custom))
        }
        val mode = when {
            course.isOddWeek -> " ${oddWeeksFilter.text}"
            course.isEvenWeek -> " ${evenWeeksFilter.text}"
            else -> ""
        }
        return courseWeekRangeLabel
            .filled("startWeek", course.startWeek.toString())
            .filled("endWeek", course.endWeek.toString())
            .filled("mode", mode)
    }

    /**
     * 周次表压缩成区间（Dart `formatCourseWeekList`）：`1,2,3,5` → `1-3、5`。
     *
     * 区间用 ASCII 连字符（Dart 原样），分隔符走 ARB [weekListSeparator]。
     */
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
            ranges += if (rangeStart == previous) "$rangeStart" else "$rangeStart-$previous"
            rangeStart = current
            previous = current
        }
        ranges += if (rangeStart == previous) "$rangeStart" else "$rangeStart-$previous"
        return ranges.joinToString(weekListSeparator.text)
    }
}
