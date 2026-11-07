package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime

/**
 * 周视图课程弹层的四个「后续弹层」：预算值与判据（纯 Kotlin，JVM 可测）。
 *
 * Dart 唯一判据是 `lib/widgets/course_followup_sheets.dart`（1015 行）。本文件把那份
 * 文件里**「算什么」的部分**逐条搬过来（选项构造、可选范围、时间区间、行文案、变化判据），
 * 渲染层 [com.mutx163.qingyu.pages.course.CourseFollowupSheets] 只负责摆出来。
 *
 * ## 为什么三个纯数据类型在这里而不是渲染层
 *
 * `scripts/test-kotlin-module.ps1 -Module "pages/course"` 只收 `main/pages/course` +
 * `test/pages/course` + 共享模型目录，**不收 `composeP1`**。而 S 泳道的
 * `CourseActionEvent.Delete(scope)` / `.Suspend(scope)` / `.Reschedule(target)` 要用它们作
 * payload —— 若声明在 `composeP1`，S 的模型层 L0 会永远 Unresolved reference；若两边都声明，
 * `composeP1` 与 `main` 是同一个编译单元（`build.gradle` 把 composeP1 目录追加进 main 的
 * srcDirs），同包同名 = redeclaration，L1 编不过。所以**只在这里声明一次**，
 * 渲染层与 S 泳道都直接用（同包，无需 import）。签名见 audit §三，一个字不能改。
 *
 * ## 本层不许有 Android / Compose 依赖
 *
 * 不 import `android.*` / `androidx.compose.*` / `top.yukonga.miuix.*`：L0 是真 JVM。
 * 图标、颜色、字阶全在渲染层选。
 */

// ───────────────────────── 契约类型（签名冻结） ─────────────────────────

/** 删除范围（Dart `CourseDeleteMode`）。 */
enum class CourseDeleteScope { WHOLE_COURSE, THIS_WEEK }

/** 停课范围（Dart `CourseSuspendMode`）。 */
enum class CourseSuspendScope { THIS_WEEK, ALL_WEEKS }

/** 调课目标（Dart `CourseRescheduleDraft`）。字段名与顺序见 audit §三。 */
data class CourseRescheduleTarget(
    val targetWeek: Int,
    val targetDayOfWeek: Int,
    val targetStartSection: Int,
    val targetEndSection: Int,
    val targetLocation: String,
)

// ───────────────────────── 删除范围弹层 ─────────────────────────

/**
 * 删除范围弹层的一项（Dart `_FollowupOptionTile` 的数据侧）。
 *
 * [subtitle] 为空串表示没有副标题（Dart 里「删这个课」那一项就**没有**副题）。
 * [enabled] 为 false 时渲染层要置灰、不可点，并且 [subtitle] 就是「为什么不能删」的解释。
 */
data class CourseDeleteScopeOption(
    val scope: CourseDeleteScope,
    val title: String,
    val subtitle: String,
    val enabled: Boolean,
)

// ───────────────────────── 停课范围弹层 ─────────────────────────

/**
 * 停课范围弹层的一项。
 *
 * [resuming] 为 true 表示这一项执行的是「恢复」语义，渲染层据此换 Play 图标
 * （Dart `:172-202`：`isSuspendedThisWeek ? play_circle : pause_circle`）。
 */
data class CourseSuspendScopeOption(
    val scope: CourseSuspendScope,
    val title: String,
    val subtitle: String,
    val resuming: Boolean,
)

// ───────────────────────── 选择器 ─────────────────────────

/** 一个可点的候选项（弹层里的「第 N 周」「第 N 节」）。 */
data class CourseFollowupPickerItem(
    val label: String,
    val value: Int,
    val selected: Boolean,
)

/** 一个「标签 + 取值 + 点击后列出候选」的字段（Dart `_buildCompactSelectField`）。 */
data class CourseFollowupField(
    val label: String,
    val value: String,
    val pickerTitle: String,
    val options: List<CourseFollowupPickerItem>,
)

// ───────────────────────── 调课弹层 ─────────────────────────

/**
 * 调课弹层的当前编辑态（Dart `_CourseRescheduleSheetBodyState` 的五个字段）。
 *
 * 不可变快照：每一次改动返回一个新的 draft（Dart 那边是 `setState` 改字段，
 * 这里改成 copy —— 判据与文案都是纯函数，能 JVM 单测）。
 *
 * ⚠️ [targetLocation] 保留**用户输入的原文**（不 trim），与 Dart 一致：
 * Dart 确认时 pop 的是 `_locationController.text`（未 trim），而 [hasChanges]
 * 比较的是两侧 trim 后的值。落库前由 provider / 分派器自己 trim。
 */
data class CourseRescheduleDraft(
    val targetWeek: Int,
    val targetDayOfWeek: Int,
    val targetStartSection: Int,
    val targetEndSection: Int,
    val targetLocation: String,
) {

    // ── 变化判据（Dart `:399-406`） ──

    /**
     * 与「原位置」相比有没有变化。**地点也算**：Dart 在原实现里把地点漏在判断之外
     * （旧 Compose 版就是这样），于是「只改地点」时确认按钮是灰的、点不动。
     * 这里按 Dart 口径把 trim 后的地点纳入比较。
     *
     * @param course 被调的那门课（提供原星期 / 节次 / 地点）
     * @param sourceWeek 被调的那一次课所在周（提供原周次）
     */
    fun hasChanges(course: Course, sourceWeek: Int): Boolean =
        sourceWeek != targetWeek ||
            course.dayOfWeek != targetDayOfWeek ||
            course.startSection != targetStartSection ||
            course.endSection != targetEndSection ||
            course.location.trim() != targetLocation.trim()

    /**
     * 把结束节次顶到不早于开始节次（Dart `:663-669`：改开始节次时若结束小于开始，
     * 结束跟着变成开始）。其它情况原样返回。
     */
    fun clamped(): CourseRescheduleDraft =
        if (targetEndSection < targetStartSection) {
            copy(targetEndSection = targetStartSection)
        } else {
            this
        }

    // ── 单项改动 ──

    fun withWeek(week: Int): CourseRescheduleDraft = copy(targetWeek = week)

    fun withDayOfWeek(dayOfWeek: Int): CourseRescheduleDraft = copy(targetDayOfWeek = dayOfWeek)

    /** 改开始节次并顺手把结束顶上去（Dart `:663-669` 的行为）。 */
    fun withStartSection(section: Int): CourseRescheduleDraft =
        copy(targetStartSection = section).clamped()

    /**
     * 改结束节次。只接受 ≥ 当前开始节次的值（Dart 的结束选项本来就过滤成
     * `>= _targetStartSection`，`:682-686`）；给更小的值视为非法，原样返回。
     */
    fun withEndSection(section: Int): CourseRescheduleDraft =
        if (section < targetStartSection) this else copy(targetEndSection = section)

    fun withLocation(text: String): CourseRescheduleDraft = copy(targetLocation = text)

    // ── 周次步进（Dart `:507-419`：在 availableWeeks 的区间内挪，到边界不动） ──

    fun canDecrementWeek(weekCount: Int): Boolean = targetWeek > 1 && weekCount >= 1

    fun canIncrementWeek(weekCount: Int): Boolean = targetWeek < weekCount

    /** 减一周；已经在第一周时原样返回（不越界、不报错）。 */
    fun previousWeek(weekCount: Int): CourseRescheduleDraft =
        if (canDecrementWeek(weekCount)) copy(targetWeek = targetWeek - 1) else this

    /** 加一周；已经在最后一周时原样返回。 */
    fun nextWeek(weekCount: Int): CourseRescheduleDraft =
        if (canIncrementWeek(weekCount)) copy(targetWeek = targetWeek + 1) else this

    // ── 出口 ──

    /** 交给壳 / 分派器的目标（Dart pop 出来的 `CourseRescheduleDraft`）。 */
    fun toTarget(): CourseRescheduleTarget = CourseRescheduleTarget(
        targetWeek = targetWeek,
        targetDayOfWeek = targetDayOfWeek,
        targetStartSection = targetStartSection,
        targetEndSection = targetEndSection,
        targetLocation = targetLocation,
    )

    /**
     * 渲染层要的全部文案与判据（Dart `build()` 里现算的那些）。
     *
     * @param course 原课程
     * @param sourceWeek 原周次
     * @param weekCount 可选周次上界（Dart `settings.availableWeeks` 的长度）
     * @param weekdayLabels 7 条星期文案（ARB `weekdayMon..Sun`，由调用方注入）
     * @param sectionTimes 这门课解析后的作息节次表（Dart
     *   `resolvedSectionsForCourse(course) ?? scheme?.sections ?? settings.sections`）
     */
    fun presentation(
        course: Course,
        sourceWeek: Int,
        weekCount: Int,
        weekdayLabels: List<String>,
        sectionTimes: List<SectionTime>,
    ): CourseReschedulePresentation {
        val currentLine = occurrenceLine(
            weekdayLabels = weekdayLabels,
            week = sourceWeek,
            dayOfWeek = course.dayOfWeek,
            startSection = course.startSection,
            endSection = course.endSection,
            startTime = course.startTime,
            endTime = course.endTime,
            sectionTimes = sectionTimes,
        )
        val targetLine = occurrenceLine(
            weekdayLabels = weekdayLabels,
            week = targetWeek,
            dayOfWeek = targetDayOfWeek,
            startSection = targetStartSection,
            endSection = targetEndSection,
            startTime = course.startTime,
            endTime = course.endTime,
            sectionTimes = sectionTimes,
        )
        val changed = hasChanges(course, sourceWeek)
        val locationText = targetLocation.trim()
        val currentLocation = course.location.trim()
        val weekChoices = weekOptions(weekCount)

        return CourseReschedulePresentation(
            title = CourseFollowupStrings.rescheduleCurrentOccurrenceTitle.text,
            subtitle = CourseFollowupStrings.rescheduleCurrentOccurrenceSubtitle
                .filled("week", sourceWeek.toString()),
            // Dart `:585`：`'${l10n.currentBadge}：$sourceLine'` —— 全角冒号是 Dart 源码里
            // 写死的分隔符，ARB 没有对应键，此处逐字照抄。
            currentLine = "${CourseFollowupStrings.currentBadge.text}：$currentLine",
            currentLocationLine = if (currentLocation.isEmpty()) {
                null
            } else {
                CourseFollowupStrings.locationPrefix.filled("value", currentLocation)
            },
            weekField = CourseFollowupField(
                label = CourseFollowupStrings.rescheduleTargetWeekLabel.text,
                value = CourseFollowupStrings.week(targetWeek),
                pickerTitle = CourseFollowupStrings.rescheduleTargetWeekLabel.text,
                options = weekChoices.map { week ->
                    CourseFollowupPickerItem(
                        label = CourseFollowupStrings.week(week),
                        value = week,
                        selected = week == targetWeek,
                    )
                },
            ),
            startSectionField = sectionField(
                label = CourseFollowupStrings.startSectionLabel.text,
                current = targetStartSection,
                sectionTimes = sectionTimes,
                course = course,
                filter = { true },
            ),
            endSectionField = sectionField(
                label = CourseFollowupStrings.endSectionLabel.text,
                current = targetEndSection,
                sectionTimes = sectionTimes,
                course = course,
                filter = { value -> value >= targetStartSection },
            ),
            targetTimeRange = timeRangeForSections(
                sectionTimes = sectionTimes,
                startSection = targetStartSection,
                endSection = targetEndSection,
            ),
            locationField = CourseFollowupField(
                label = CourseFollowupStrings.locationLabel.text,
                value = if (locationText.isEmpty()) {
                    CourseFollowupStrings.manualInputLabel.text
                } else {
                    locationText
                },
                pickerTitle = CourseFollowupStrings.selectLocationTitle.text,
                options = emptyList(),
            ),
            locationIsPlaceholder = locationText.isEmpty(),
            targetLine = "→ $targetLine",
            targetLocationLine = if (locationText.isEmpty()) {
                null
            } else {
                CourseFollowupStrings.locationPrefix.filled("value", locationText)
            },
            showTargetPreview = changed,
            canConfirm = changed,
            weekdayLabels = weekdayLabels,
            selectedDayOfWeek = targetDayOfWeek,
            canDecrementWeek = canDecrementWeek(weekCount),
            canIncrementWeek = canIncrementWeek(weekCount),
        )
    }

    private fun sectionField(
        label: String,
        current: Int,
        sectionTimes: List<SectionTime>,
        course: Course,
        filter: (Int) -> Boolean,
    ): CourseFollowupField = CourseFollowupField(
        label = label,
        value = CourseFollowupStrings.section(current),
        pickerTitle = label,
        options = startSectionOptions(sectionTimes, course)
            .filter(filter)
            .map { value ->
                CourseFollowupPickerItem(
                    label = CourseFollowupStrings.section(value),
                    value = value,
                    selected = value == current,
                )
            },
    )

    companion object {

        /** 原位置（Dart `initState` `:337-346`）。 */
        fun initial(course: Course, sourceWeek: Int): CourseRescheduleDraft = CourseRescheduleDraft(
            targetWeek = sourceWeek,
            targetDayOfWeek = course.dayOfWeek,
            targetStartSection = course.startSection,
            targetEndSection = course.endSection,
            targetLocation = course.location,
        )

        /** 可选周次：1..[weekCount]（Dart `settings.availableWeeks`）。 */
        fun weekOptions(weekCount: Int): List<Int> =
            if (weekCount < 1) emptyList() else (1..weekCount).toList()

        /**
         * 可选节次（Dart `_sectionNumbers`，`:324-335`）。
         *
         * 口径是「节次表长度内的全部节次 ∪ 这门课自己的起止节次」，去重排序。
         * 课程自己的节次要无条件收进来：幻影节次的课（节次越出它自己的作息模板）若被范围卡掉，
         * 结束节次候选会滤成空表，弹层里当前值也显示不出来。
         *
         * ⚠️ 与 Dart 的差异：Dart 在 `sectionTimes` 为空时退回 `settings.sectionCount`；
         * 本函数的入参没有 settings，所以为空时只剩课程自己的两个节次。调用方传的是
         * 「解析后的节次表」（`resolvedSectionsForCourse(course) ?? scheme?.sections ??
         * settings.sections`），正常不会为空。
         */
        fun startSectionOptions(sectionTimes: List<SectionTime>, course: Course): List<Int> {
            val count = sectionTimes.size
            val numbers = linkedSetOf<Int>()
            for (index in 1..count) numbers.add(index)
            numbers.add(course.startSection)
            numbers.add(course.endSection)
            return numbers.filter { it >= 1 }.sorted()
        }

        /** 可选结束节次：从 [startSectionOptions] 里滤掉早于 [startSection] 的（Dart `:682-686`）。 */
        fun endSectionOptions(
            sectionTimes: List<SectionTime>,
            course: Course,
            startSection: Int,
        ): List<Int> = startSectionOptions(sectionTimes, course).filter { it >= startSection }

        /**
         * 第 [startSection] 节开始到第 [endSection] 节结束的钟点区间（Dart
         * `_timeRangeForSections`，`:368-380`）。
         *
         * 返回 `null` 的条件与 Dart 逐条一致：索引越界（<0 或 ≥ 节次表长度）或
         * `startSection > endSection`。`null` 时渲染层整行不画，绝不拿原课的钟点顶替。
         */
        fun timeRangeForSections(
            sectionTimes: List<SectionTime>,
            startSection: Int,
            endSection: Int,
        ): String? {
            val startIndex = startSection - 1
            val endIndex = endSection - 1
            if (startIndex < 0 ||
                endIndex < 0 ||
                startIndex >= sectionTimes.size ||
                endIndex >= sectionTimes.size ||
                startSection > endSection
            ) {
                return null
            }
            return "${sectionTimes[startIndex].startTime}-${sectionTimes[endIndex].endTime}"
        }

        /**
         * 「第 N 周 · 周X · 第 A 节-第 B 节 · HH:mm-HH:mm」（Dart `_occurrenceLine`，`:382-397`）。
         *
         * 钟点优先按节次表算；节次表算不出来时退回课程自己的 `startTime-endTime`
         * （Dart 的 `?? '$startTime-$endTime'`，不是空白）。
         */
        fun occurrenceLine(
            weekdayLabels: List<String>,
            week: Int,
            dayOfWeek: Int,
            startSection: Int,
            endSection: Int,
            startTime: String,
            endTime: String,
            sectionTimes: List<SectionTime>,
        ): String {
            val resolvedTime = timeRangeForSections(sectionTimes, startSection, endSection)
                ?: "$startTime-$endTime"
            return "${CourseFollowupStrings.week(week)} · " +
                "${weekdayLabel(weekdayLabels, dayOfWeek)} · " +
                "${CourseFollowupStrings.section(startSection)}-${CourseFollowupStrings.section(endSection)} · " +
                resolvedTime
        }

        /** 单日星期标签；越界退化成数字（Dart `:361-366`，与搬迁前的 `_weekdayLabel` 同口径）。 */
        fun weekdayLabel(weekdayLabels: List<String>, dayOfWeek: Int): String =
            if (dayOfWeek < 1 || dayOfWeek > weekdayLabels.size) {
                dayOfWeek.toString()
            } else {
                weekdayLabels[dayOfWeek - 1]
            }
    }
}

/** 调课弹层要摆出来的全部内容（[CourseRescheduleDraft.presentation] 产出）。 */
data class CourseReschedulePresentation(
    /** 「调本周这节课」 */
    val title: String,
    /** 「仅改第 {week} 周本节，原课该周移除，其他周不变」 */
    val subtitle: String,
    /** 「当前：第 N 周 · 周X · 第 A 节-第 B 节 · HH:mm-HH:mm」 */
    val currentLine: String,
    /** 「地点：…」；原地点为空时为 null（Dart `:591-599` 整行不画） */
    val currentLocationLine: String?,
    /** 目标周字段 */
    val weekField: CourseFollowupField,
    /** 开始节次字段 */
    val startSectionField: CourseFollowupField,
    /** 结束节次字段（候选项已按「不早于开始节次」过滤） */
    val endSectionField: CourseFollowupField,
    /** 目标时段的钟点区间，算不出来时为 null（整行不画） */
    val targetTimeRange: String?,
    /** 地点字段；空地点时 [value] 是「手动填写」占位 */
    val locationField: CourseFollowupField,
    val locationIsPlaceholder: Boolean,
    /** 「→ 第 N 周 · 周X · 第 A 节-第 B 节 · HH:mm-HH:mm」 */
    val targetLine: String,
    /** 目标地点的「地点：…」行；空地点时为 null */
    val targetLocationLine: String?,
    /** 有没有变化（决定「→」预览显不显示） */
    val showTargetPreview: Boolean,
    /** 「确认调课」可不可点（无变化置灰；与 [showTargetPreview] 同判据） */
    val canConfirm: Boolean,
    val weekdayLabels: List<String>,
    val selectedDayOfWeek: Int,
    val canDecrementWeek: Boolean,
    val canIncrementWeek: Boolean,
)

/** 删除范围 / 停课范围的选项构造（Dart `_CourseDeleteModeSheetBody` / `_CourseSuspendModeSheetBody`）。 */
object CourseFollowupModel {

    /**
     * 删除范围的两个选项（Dart `:121-143`）。
     *
     * - 「删这个课」：永远可用、**没有副标题**（Dart 注释 `:118-120` 说明原来那句副标题被删掉了）；
     * - 「删这节课」：只有 [canDeleteOccurrence]（= 本周本来就有这门课）为真才可点，
     *   副标题给「为什么能 / 为什么不能」，两种情况都用 [week] 填占位符。
     */
    fun deleteScopeOptions(canDeleteOccurrence: Boolean, week: Int): List<CourseDeleteScopeOption> {
        val hint = if (canDeleteOccurrence) {
            CourseFollowupStrings.deleteModeHintCurrentWeek.filled("week", week.toString())
        } else {
            CourseFollowupStrings.deleteModeHintUnavailable.filled("week", week.toString())
        }
        return listOf(
            CourseDeleteScopeOption(
                scope = CourseDeleteScope.WHOLE_COURSE,
                title = CourseFollowupStrings.deleteCourseAction.text,
                subtitle = "",
                enabled = true,
            ),
            CourseDeleteScopeOption(
                scope = CourseDeleteScope.THIS_WEEK,
                title = CourseFollowupStrings.deleteOccurrenceAction.text,
                subtitle = hint,
                enabled = canDeleteOccurrence,
            ),
        )
    }

    /**
     * 停课范围的两个选项（Dart `:180-202`）。
     *
     * 文案按**当前状态**切换，这是 Dart 的行为，不是我们在「优化」：
     * - 本周已停 → 第一项变成「恢复」；
     * - 有任何一周被停 → 第二项变成「恢复全部」+「恢复所有周次」。
     *
     * 两项的副标题各自独立：第一项**始终**是 `suspendThisWeekDesc`（Dart 就是这么写的，
     * 恢复时副标题仍是「仅暂停当前周」）。
     */
    fun suspendScopeOptions(
        suspendedThisWeek: Boolean,
        hasAnySuspended: Boolean,
    ): List<CourseSuspendScopeOption> = listOf(
        CourseSuspendScopeOption(
            scope = CourseSuspendScope.THIS_WEEK,
            title = if (suspendedThisWeek) {
                CourseFollowupStrings.courseActionUnsuspend.text
            } else {
                CourseFollowupStrings.suspendThisWeek.text
            },
            subtitle = CourseFollowupStrings.suspendThisWeekDesc.text,
            resuming = suspendedThisWeek,
        ),
        CourseSuspendScopeOption(
            scope = CourseSuspendScope.ALL_WEEKS,
            title = if (hasAnySuspended) {
                CourseFollowupStrings.unsuspendAllWeeks.text
            } else {
                CourseFollowupStrings.suspendAllWeeks.text
            },
            subtitle = if (hasAnySuspended) {
                CourseFollowupStrings.unsuspendAllWeeksDesc.text
            } else {
                CourseFollowupStrings.suspendAllWeeksDesc.text
            },
            resuming = hasAnySuspended,
        ),
    )
}
