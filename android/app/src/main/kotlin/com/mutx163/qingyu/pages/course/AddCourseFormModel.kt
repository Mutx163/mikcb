package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.CourseSessionNote

/**
 * 加课 / 改课表单的模型层（P3-D1）。
 *
 * 移植自 `lib/screens/add_course_screen.dart` 的纯逻辑部分：
 * `weeksFromRangeSelection` / `editableSectionNumbers` / `_ScheduleEntryData` /
 * `_selectedWeeksFor` / `_formatWeekList` / `_selectedWeeksSummaryText` /
 * `_saveGroup` / `_saveCourse` / `initState` 三分支。
 *
 * **纯 Kotlin**：不许 import Compose / Android —— 这些逻辑全部走 JVM 单测。
 * 渲染层（[com.mutx163.qingyu.pages.course.AddCoursePage]）只消费这里的结果，
 * 不自己算业务。
 */

// ----------------------------------------------------------------------
// 值类型
// ----------------------------------------------------------------------

/** 周次选择模式（Dart `_WeekSelectionMode`）。 */
enum class AddCourseWeekSelectionMode {
    /** 起止周 + 单/双周过滤。 */
    RANGE,

    /** 手工勾选的周次集合。 */
    CUSTOM,
}

/** 生成条目 id（新建条目用；Dart 侧由 repository 发号，这里只需局部唯一）。 */
internal fun newEntryId(): String = "entry-" + java.util.UUID.randomUUID().toString()

/** 一条排课记录（Dart `_ScheduleEntryData`）：一门课可以在多个时段上。 */
data class AddCourseScheduleEntryData(
    val id: String = newEntryId(),
    val dayOfWeek: Int = 1,
    val startSection: Int = 1,
    val endSection: Int = 2,
    val teacher: String = "",
    val location: String = "",
    val startWeek: Int = 1,
    val endWeek: Int = 16,
    val isOddWeek: Boolean = false,
    val isEvenWeek: Boolean = false,
    val weekSelectionMode: AddCourseWeekSelectionMode = AddCourseWeekSelectionMode.RANGE,
    val selectedCustomWeeks: Set<Int> = emptySet(),
    /** 备注（沿用 Course.note 的 legacy 字段语义）。 */
    val note: String? = null,
    val sessionNotes: Map<Int, CourseSessionNote>? = null,
    val suspendedWeeks: List<Int>? = null,
    val timeSchemeIdOverride: String? = null,
    /** 编辑既有课时的原对象（新建时 null）。 */
    val originalCourse: Course? = null,
) {

    companion object {
        /**
         * 从既有课程建条目（Dart `_ScheduleEntryData.fromCourse`）。
         *
         * `customWeeks != null` → 自定义模式并勾选这些周；否则范围模式。
         */
        fun fromCourse(course: Course): AddCourseScheduleEntryData {
            val custom = course.customWeeks
            return AddCourseScheduleEntryData(
                id = course.id,
                dayOfWeek = course.dayOfWeek,
                startSection = course.startSection,
                endSection = course.endSection,
                teacher = course.teacher,
                location = course.location,
                startWeek = course.startWeek,
                endWeek = course.endWeek,
                isOddWeek = course.isOddWeek,
                isEvenWeek = course.isEvenWeek,
                weekSelectionMode = if (custom != null) {
                    AddCourseWeekSelectionMode.CUSTOM
                } else {
                    AddCourseWeekSelectionMode.RANGE
                },
                selectedCustomWeeks = custom?.toSet() ?: emptySet(),
                note = course.note,
                sessionNotes = course.sessionNotes,
                suspendedWeeks = course.suspendedWeeks,
                timeSchemeIdOverride = course.timeSchemeIdOverride,
                originalCourse = course,
            )
        }
    }

    /**
     * 转回课程（Dart `toCourse`）。
     *
     * 自定义模式下 `customWeeks` 非空时：起止周取勾选集首末、单双周强制清零；
     * 勾选集为空则回落范围字段（`customWeeks = null`）。
     */
    fun toCourse(
        name: String,
        color: String,
        courseNature: CourseNature,
        startTime: String,
        endTime: String,
        shortName: String? = null,
        description: String? = null,
        hasCustomTime: Boolean = false,
    ): Course {
        val sortedCustom = selectedCustomWeeks.sorted()
        val useCustom = weekSelectionMode == AddCourseWeekSelectionMode.CUSTOM && sortedCustom.isNotEmpty()
        return Course(
            id = id,
            name = name,
            shortName = shortName,
            teacher = teacher,
            location = location,
            dayOfWeek = dayOfWeek,
            startSection = startSection,
            endSection = endSection,
            startTime = startTime,
            endTime = endTime,
            color = color,
            startWeek = if (useCustom) sortedCustom.first() else startWeek,
            endWeek = if (useCustom) sortedCustom.last() else endWeek,
            isOddWeek = if (useCustom) false else isOddWeek,
            isEvenWeek = if (useCustom) false else isEvenWeek,
            customWeeks = if (useCustom) sortedCustom else null,
            suspendedWeeks = suspendedWeeks,
            courseNature = courseNature,
            description = description,
            note = note,
            sessionNotes = sessionNotes,
            timeSchemeIdOverride = timeSchemeIdOverride,
            hasCustomTime = hasCustomTime,
        )
    }
}

/** 保存模式（Dart `_saveGroup` vs `_saveCourse` 的分支）。 */
enum class AddCourseSaveMode {
    /** 新建课程（无既有课、无课程组）。 */
    ADD,

    /** 更新既有课程所在的整个组。 */
    UPDATE_GROUP,
}

/** 保存目标判定结果。 */
data class AddCourseSaveTarget(
    val mode: AddCourseSaveMode,
    /** 组编辑时的目标组名；新建为 null。 */
    val targetGroupName: String?,
)

/** 表单校验问题（Dart 里是直接返回文案，这里用枚举便于测试断言）。 */
enum class AddCourseEntryIssue {
    /** 周次最终为空集。 */
    WEEKS_EMPTY,
}

/** 条目时刻解析结果（由渲染层按作息模板注入，模型层不做时间计算）。 */
data class AddCourseEntryClock(val startTime: String, val endTime: String)

/** 保存载荷。 */
data class AddCourseSavePayload(
    val mode: AddCourseSaveMode,
    val targetGroupName: String?,
    val courses: List<Course>,
)

/** 课程组（Dart `TimetableProfile` 里的同名课程聚合，这里只取表单需要的部分）。 */
data class AddCourseGroupData(
    val name: String,
    val courses: List<Course>,
)

/** 表单初始状态（Dart `initState` 三分支的结果）。 */
data class AddCourseFormState(
    val isCreatingNewCourse: Boolean,
    val sharedName: String,
    val sharedShortName: String,
    val sharedTeacher: String,
    val sharedLocation: String,
    val sharedDescription: String,
    val color: String,
    val courseNature: CourseNature,
    val entries: List<AddCourseScheduleEntryData>,
)

/** 周选择弹层的草稿（Dart `_showEntryWeekPickerDialog` 的临时状态）。 */
data class AddCourseWeekDraft(
    val mode: AddCourseWeekSelectionMode,
    val startWeek: Int,
    val endWeek: Int,
    val isOddWeek: Boolean,
    val isEvenWeek: Boolean,
    val customWeeks: Set<Int>,
)

// ----------------------------------------------------------------------
// 逻辑
// ----------------------------------------------------------------------

object AddCourseFormLogic {

    /** 默认配色（Dart `_selectedColor` 初值）。 */
    private const val DEFAULT_COLOR = "#2196F3"

    /** 默认学期周数（Dart 的 16）。 */
    private const val DEFAULT_END_WEEK = 16

    // ------------------------------------------------------------------
    // 1. 周次区间 → 周次列表（Dart :39-56 weeksFromRangeSelection）
    // ------------------------------------------------------------------

    /**
     * 起止周 → 周次列表，按单/双周过滤。
     *
     * **单周与双周同时勾上得空集**：两个条件按周逐个过滤，每一条都会被某一个滤掉。
     * 这与 Dart 源 `if (isOddWeek && week.isEven) continue; if (isEvenWeek && week.isOdd) continue;`
     * 的写法同口径——不是「两个都满足」的与，而是两道独立筛子。
     */
    fun weeksFromRangeSelection(
        startWeek: Int,
        endWeek: Int,
        isOddWeek: Boolean,
        isEvenWeek: Boolean,
    ): List<Int> {
        if (startWeek > endWeek) return emptyList()
        val result = mutableListOf<Int>()
        for (week in startWeek..endWeek) {
            if (isOddWeek && week % 2 == 0) continue
            if (isEvenWeek && week % 2 != 0) continue
            result.add(week)
        }
        return result
    }

    // ------------------------------------------------------------------
    // 2. 节次候选（Dart :80-96 editableSectionNumbers）
    // ------------------------------------------------------------------

    /**
     * 可编辑节次候选。
     *
     * 课程自己的模板节数优先于全局；`courseSchemeSectionCount <= 0`（或 null）回落全局。
     * 现存起止节次若越出模板范围，额外并入候选（否则编辑老课时看不到自己那几节）。
     */
    fun editableSectionNumbers(
        globalSectionCount: Int,
        courseSchemeSectionCount: Int?,
        currentStartSection: Int,
        currentEndSection: Int,
    ): List<Int> {
        val count = if (courseSchemeSectionCount != null && courseSchemeSectionCount > 0) {
            courseSchemeSectionCount
        } else {
            globalSectionCount
        }
        val base = if (count <= 0) emptyList() else (1..count).toList()
        val merged = LinkedHashSet(base)
        // 现存节次越界时并入：起止都可能越界，逐节加。
        if (currentEndSection >= currentStartSection) {
            for (section in currentStartSection..currentEndSection) {
                if (section > 0) merged.add(section)
            }
        }
        return merged.sorted()
    }

    // ------------------------------------------------------------------
    // 3. 表单初始状态（Dart initState :291-340）
    // ------------------------------------------------------------------

    /**
     * 建表单初始状态。
     *
     * 三分支：
     * - 纯新建：默认条目一条，`initialStartWeek`/`initialDayOfWeek`/`initialStartSection` 生效；
     *   `initialEndSection` 缺省 = `initialStartSection + 1`。
     * - 单课编辑：共享字段来自该课，`description ?? note ?? ''`；
     * - 组编辑：每门课一条，共享字段取**排序后的第一条**；
     *   若同时给了 `initialCourse`，被点的课排第一（Dart `ordered = [initialCourse] + rest`）。
     *
     * 组编辑入口**不填**共享教师/地点（Dart 只在单课编辑分支写 controller）。
     */
    fun buildInitialState(
        initialCourse: Course? = null,
        courseGroup: AddCourseGroupData? = null,
        initialWeek: Int = 1,
        initialDayOfWeek: Int = 1,
        initialStartSection: Int = 1,
        initialEndSection: Int? = null,
    ): AddCourseFormState {
        val creating = isCreatingNewCourse(initialCourse, courseGroup)

        if (creating) {
            val endWeek = if (initialWeek > DEFAULT_END_WEEK) initialWeek else DEFAULT_END_WEEK
            val entry = AddCourseScheduleEntryData(
                id = newEntryId(),
                dayOfWeek = initialDayOfWeek,
                startSection = initialStartSection,
                endSection = initialEndSection ?: (initialStartSection + 1),
                startWeek = initialWeek,
                endWeek = endWeek,
            )
            return AddCourseFormState(
                isCreatingNewCourse = true,
                sharedName = "",
                sharedShortName = "",
                sharedTeacher = "",
                sharedLocation = "",
                sharedDescription = "",
                color = DEFAULT_COLOR,
                courseNature = CourseNature.REQUIRED,
                entries = listOf(entry),
            )
        }

        // 组编辑 / 单课编辑：先排出条目顺序。
        val ordered: List<Course> = when {
            courseGroup != null -> {
                val all = courseGroup.courses
                if (initialCourse != null) {
                    // Dart: [initialCourse] + courses.where(id != initialCourse.id)
                    listOf(initialCourse) + all.filter { it.id != initialCourse.id }
                } else {
                    all
                }
            }
            initialCourse != null -> listOf(initialCourse)
            else -> emptyList()
        }

        val head = ordered.firstOrNull()
        // 组编辑入口不填共享教师/地点（Dart 只在单课编辑分支写 controller）。
        val isGroupEdit = courseGroup != null
        return AddCourseFormState(
            isCreatingNewCourse = false,
            sharedName = head?.name ?: (courseGroup?.name ?: ""),
            sharedShortName = head?.shortName ?: "",
            sharedTeacher = if (isGroupEdit) "" else (head?.teacher ?: ""),
            sharedLocation = if (isGroupEdit) "" else (head?.location ?: ""),
            sharedDescription = head?.description ?: head?.note ?: "",
            color = head?.color ?: DEFAULT_COLOR,
            courseNature = head?.courseNature ?: CourseNature.REQUIRED,
            entries = ordered.map { AddCourseScheduleEntryData.fromCourse(it) },
        )
    }

    /**
     * 是否「新建课程」。
     *
     * Dart `_isCreatingNewCourse = course == null && courseGroup == null`：
     * **两个参数都为空**才算新建。只看 `course` 会把「总览 → 编辑」（只传 courseGroup）
     * 误判成新建，保存时新建一门同组名的课。
     */
    fun isCreatingNewCourse(initialCourse: Course?, courseGroup: AddCourseGroupData?): Boolean =
        initialCourse == null && courseGroup == null

    // ------------------------------------------------------------------
    // 4. 保存目标与载荷（Dart :1925-2064）
    // ------------------------------------------------------------------

    /**
     * 保存目标判定。
     *
     * - 组编辑（courseGroup 非空）：目标组名 = **组名**（course 在场也不顶替）；
     * - 单课编辑（只有 course）：目标组名 = 该课原名；
     * - 新建：ADD，无目标组。
     */
    fun resolveSaveTarget(
        initialCourse: Course?,
        courseGroup: AddCourseGroupData?,
    ): AddCourseSaveTarget = when {
        courseGroup != null -> AddCourseSaveTarget(
            mode = AddCourseSaveMode.UPDATE_GROUP,
            targetGroupName = courseGroup.name,
        )
        initialCourse != null -> AddCourseSaveTarget(
            mode = AddCourseSaveMode.UPDATE_GROUP,
            targetGroupName = initialCourse.name,
        )
        else -> AddCourseSaveTarget(mode = AddCourseSaveMode.ADD, targetGroupName = null)
    }

    /**
     * 建保存载荷：每条排课记录一辆车，带共享字段。
     *
     * `clockResolver` 由渲染层注入（按作息模板把节次解析成钟点）；模型层不碰时间。
     * 短名 / 简介按 Dart 的 `isEmpty` 判据落 null——**不 trim**（"  " 会原样存下）。
     */
    fun buildSavePayload(
        initialCourse: Course?,
        courseGroup: AddCourseGroupData?,
        name: String,
        shortName: String,
        description: String,
        color: String,
        courseNature: CourseNature,
        entries: List<AddCourseScheduleEntryData>,
        clockResolver: (AddCourseScheduleEntryData) -> AddCourseEntryClock,
    ): AddCourseSavePayload {
        val target = resolveSaveTarget(initialCourse, courseGroup)
        val courses = entries.map { entry ->
            val clock = clockResolver(entry)
            entry.toCourse(
                name = name,
                color = color,
                courseNature = courseNature,
                startTime = clock.startTime,
                endTime = clock.endTime,
                shortName = shortName.ifEmpty { null },
                description = description.ifEmpty { null },
            )
        }
        return AddCourseSavePayload(
            mode = target.mode,
            targetGroupName = target.targetGroupName,
            courses = courses,
        )
    }

    // ------------------------------------------------------------------
    // 5. 校验（Dart :1925-2007）
    // ------------------------------------------------------------------

    /** 课程名必填：空或纯空白不通过。通过时返回 null。 */
    fun validateCourseName(name: String): String? =
        if (name.trim().isEmpty()) AddCourseStrings.pleaseEnterCourseName.zh else null

    /** 条目周次校验：最终周次为空集则无效。 */
    fun validateEntry(entry: AddCourseScheduleEntryData): AddCourseEntryIssue? =
        if (selectedWeeksFor(entry).isEmpty()) AddCourseEntryIssue.WEEKS_EMPTY else null

    /**
     * 条目周次报错文案（Dart `'${l10n.scheduleEntryTitle(i + 1)}: ${l10n.selectAtLeastOneWeek}'`）。
     *
     * @param entryIndex 0-based 条目下标；文案里显示 1-based 编号。
     */
    fun entryWeeksErrorMessage(entryIndex: Int): String =
        AddCourseStrings.scheduleEntryTitle.filled("index", (entryIndex + 1).toString()) +
            ": " +
            AddCourseStrings.selectAtLeastOneWeek.zh

    // ------------------------------------------------------------------
    // 6. 周次摘要（Dart :1546-1608）
    // ------------------------------------------------------------------

    /**
     * 周次列表压缩成区间串（Dart `_formatWeekList`）：连续段 `1-3`，顿号相连。
     *
     * 空列表 → 空串。
     */
    fun formatWeekList(weeks: List<Int>): String {
        if (weeks.isEmpty()) return ""
        val sorted = weeks.sorted()
        val parts = mutableListOf<String>()
        var rangeStart = sorted.first()
        var rangeEnd = sorted.first()
        for (i in 1 until sorted.size) {
            val week = sorted[i]
            if (week == rangeEnd + 1) {
                rangeEnd = week
            } else {
                parts.add(if (rangeStart == rangeEnd) "$rangeStart" else "$rangeStart-$rangeEnd")
                rangeStart = week
                rangeEnd = week
            }
        }
        parts.add(if (rangeStart == rangeEnd) "$rangeStart" else "$rangeStart-$rangeEnd")
        return parts.joinToString("、")
    }

    /**
     * 条目最终周次（Dart `_selectedWeeksFor`）。
     *
     * 自定义模式取勾选集升序（不看起止周）；范围模式按单双周过滤。
     */
    fun selectedWeeksFor(entry: AddCourseScheduleEntryData): List<Int> =
        if (entry.weekSelectionMode == AddCourseWeekSelectionMode.CUSTOM) {
            entry.selectedCustomWeeks.sorted()
        } else {
            weeksFromRangeSelection(entry.startWeek, entry.endWeek, entry.isOddWeek, entry.isEvenWeek)
        }

    /**
     * 周次摘要文案（Dart `_selectedWeeksSummaryText`）。
     *
     * 三种形态：
     * - 覆盖全部可选周 → 「全部」；
     * - 自定义模式 → `formatWeekList`（空集为空串）；
     * - 范围模式 → 「第 a 周 – 第 b 周」（起止同周时只留一个）+ 单/双周后缀。
     *
     * 注意区间用 **en dash 带空格**（`–`，Dart 原文如此）。
     */
    fun selectedWeeksSummaryText(
        selectedWeeks: List<Int>,
        availableWeeks: List<Int>,
        startWeek: Int,
        endWeek: Int,
        isOddWeek: Boolean,
        isEvenWeek: Boolean,
        mode: AddCourseWeekSelectionMode,
    ): String {
        // 覆盖全部可选周 → 「全部」（不区分模式）
        if (availableWeeks.isNotEmpty() && selectedWeeks.toSet() == availableWeeks.toSet()) {
            return AddCourseStrings.allWeeksFilter.zh
        }
        if (mode == AddCourseWeekSelectionMode.CUSTOM) {
            return formatWeekList(selectedWeeks)
        }
        // 范围模式
        val label = if (startWeek == endWeek) {
            AddCourseStrings.weekLabel.filled("week", startWeek.toString())
        } else {
            AddCourseStrings.weekLabel.filled("week", startWeek.toString()) +
                " – " +
                AddCourseStrings.weekLabel.filled("week", endWeek.toString())
        }
        val suffix = when {
            isOddWeek && !isEvenWeek -> " · " + AddCourseStrings.oddWeeksFilter.zh
            isEvenWeek && !isOddWeek -> " · " + AddCourseStrings.evenWeeksFilter.zh
            else -> ""
        }
        return label + suffix
    }

    // ------------------------------------------------------------------
    // 7. 新增排课条目（Dart `_addScheduleEntry`）
    // ------------------------------------------------------------------

    /**
     * 新增一条排课记录：沿用上一条的时段与教师/地点。
     *
     * 无上一条时回落默认时段与**共享字段**（Dart `last?.teacher ?? _teacherController.text`）。
     */
    fun nextEntryAfter(
        last: AddCourseScheduleEntryData?,
        sharedTeacher: String = "",
        sharedLocation: String = "",
    ): AddCourseScheduleEntryData = AddCourseScheduleEntryData(
        id = newEntryId(),
        dayOfWeek = last?.dayOfWeek ?: 1,
        startSection = last?.startSection ?: 1,
        endSection = last?.endSection ?: 2,
        startWeek = last?.startWeek ?: 1,
        endWeek = last?.endWeek ?: DEFAULT_END_WEEK,
        teacher = last?.teacher ?: sharedTeacher,
        location = last?.location ?: sharedLocation,
    )

    // ------------------------------------------------------------------
    // 8. 其他表单规则
    // ------------------------------------------------------------------

    /**
     * 自动补全简称：课程名前**两个字符**（Dart `characters.take(2)`，按字素簇而非码元）。
     *
     * 先 trim；空串 → 空串。用 codePoint 迭代保证 emoji / 组合字符不会被劈开。
     */
    fun autofillShortName(name: String): String {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return ""
        val out = StringBuilder()
        var count = 0
        var i = 0
        while (i < trimmed.length && count < 2) {
            val cp = trimmed.codePointAt(i)
            out.appendCodePoint(cp)
            i += Character.charCount(cp)
            count++
        }
        return out.toString()
    }

    /**
     * 排课卡标题（Dart：多条时 `scheduleEntryTitle(1).replaceFirst(RegExp(r'\s?1$'), '')`）。
     *
     * 单条 → 「上课安排」；多条 → 「排课记录」（去掉尾部编号）。
     */
    fun scheduleEntryCardTitle(entryCount: Int): String =
        if (entryCount <= 1) {
            AddCourseStrings.scheduleEntrySingleTitle.zh
        } else {
            AddCourseStrings.scheduleEntryTitle.filled("index", "1")
                .replace(Regex("""\s?1$"""), "")
        }

    /** 生成条目 id（新建条目用；Dart 侧由 repository 发号，这里只需局部唯一）。 */
    fun newEntryId(): String = "entry-" + java.util.UUID.randomUUID().toString()
}

// ----------------------------------------------------------------------
// 周选择弹层草稿状态机（Dart :1623-1905）
// ----------------------------------------------------------------------

object AddCourseWeekDraftLogic {

    /** 从条目生成草稿。 */
    fun fromEntry(entry: AddCourseScheduleEntryData): AddCourseWeekDraft = AddCourseWeekDraft(
        mode = entry.weekSelectionMode,
        startWeek = entry.startWeek,
        endWeek = entry.endWeek,
        isOddWeek = entry.isOddWeek,
        isEvenWeek = entry.isEvenWeek,
        customWeeks = entry.selectedCustomWeeks,
    )

    /** 把草稿整体回写到条目（不改条目身份与其余字段）。 */
    fun applyToEntry(
        entry: AddCourseScheduleEntryData,
        draft: AddCourseWeekDraft,
    ): AddCourseScheduleEntryData = entry.copy(
        weekSelectionMode = draft.mode,
        startWeek = draft.startWeek,
        endWeek = draft.endWeek,
        isOddWeek = draft.isOddWeek,
        isEvenWeek = draft.isEvenWeek,
        selectedCustomWeeks = draft.customWeeks,
    )

    /**
     * 切换选择模式。
     *
     * - 切到自定义：只在**勾选集为空**时用当前范围周播种；若范围算出来是空集，则退化为
     *   `{startWeek}`（否则用户切过去就是「一周都没选」，确认键直接灰掉，像坏了）。
     *   判据用「勾选集是否为空」而不是「当前模式是不是 CUSTOM」（Dart
     *   `add_course_screen.dart:1671-1677` 的 `tempCustomWeeks.isEmpty`）：用户
     *   range → custom → range → custom 往返时，回程已经在 custom 下勾过的周不能被范围
     *   重播种冲掉。
     * - 切回范围：勾选集首末当起止周，并**清掉单双周**（否则「自定义 3,5,9」变回范围会
     *   叠加旧单周过滤，选出与用户勾选不一致的集合）。
     */
    fun selectMode(
        draft: AddCourseWeekDraft,
        newMode: AddCourseWeekSelectionMode,
        availableWeeks: List<Int>,
    ): AddCourseWeekDraft = when (newMode) {
        AddCourseWeekSelectionMode.CUSTOM -> {
            if (draft.customWeeks.isNotEmpty()) {
                draft.copy(mode = newMode)
            } else {
                val seeded = AddCourseFormLogic.weeksFromRangeSelection(
                    draft.startWeek,
                    draft.endWeek,
                    draft.isOddWeek,
                    draft.isEvenWeek,
                ).toSet()
                draft.copy(
                    mode = newMode,
                    customWeeks = if (seeded.isEmpty()) setOf(draft.startWeek) else seeded,
                )
            }
        }
        AddCourseWeekSelectionMode.RANGE -> {
            if (draft.mode == AddCourseWeekSelectionMode.RANGE) {
                draft.copy(mode = newMode)
            } else {
                val sorted = draft.customWeeks.sorted()
                if (sorted.isEmpty()) {
                    draft.copy(mode = newMode, isOddWeek = false, isEvenWeek = false)
                } else {
                    draft.copy(
                        mode = newMode,
                        startWeek = sorted.first(),
                        endWeek = sorted.last(),
                        isOddWeek = false,
                        isEvenWeek = false,
                    )
                }
            }
        }
    }

    /** 改开始周：结束周被抬到不低于开始周（Dart `if (tempEndWeek < tempStartWeek) tempEndWeek = tempStartWeek`）。 */
    fun setStartWeek(
        draft: AddCourseWeekDraft,
        week: Int,
        availableWeeks: List<Int>,
    ): AddCourseWeekDraft = draft.copy(
        startWeek = week,
        endWeek = if (draft.endWeek < week) week else draft.endWeek,
    )

    /**
     * 改结束周：不得小于开始周。
     *
     * Dart 侧结束周选项从 `tempStartWeek` 起算；这里对称地做下界夹紧——区间反了会让
     * [AddCourseFormLogic.selectedWeeksFor] 返回空集，用户只看到「请至少选择一个上课周次」
     * 却找不出原因。
     */
    fun setEndWeek(
        draft: AddCourseWeekDraft,
        week: Int,
        availableWeeks: List<Int>,
    ): AddCourseWeekDraft = draft.copy(
        endWeek = if (week < draft.startWeek) draft.startWeek else week,
    )

    /**
     * 网格磁贴点选。
     *
     * **保留最后一个已选周**：`isSelected && customWeeks.size > 1` 才允许移除。
     * 否则用户点掉最后一周会看到「一周都没选」，而确认键同时灰掉——像是界面卡住了。
     */
    fun toggleCustomWeek(draft: AddCourseWeekDraft, week: Int): AddCourseWeekDraft {
        val selected = draft.customWeeks
        val next = if (selected.contains(week)) {
            if (selected.size > 1) selected - week else selected
        } else {
            selected + week
        }
        return draft.copy(customWeeks = next)
    }

    /** 全选（按可选周过滤）。 */
    fun selectAllCustom(draft: AddCourseWeekDraft, availableWeeks: List<Int>): AddCourseWeekDraft =
        draft.copy(customWeeks = availableWeeks.toSet())

    /** 只选单周（按可选周过滤）。 */
    fun selectOddCustom(draft: AddCourseWeekDraft, availableWeeks: List<Int>): AddCourseWeekDraft =
        draft.copy(customWeeks = availableWeeks.filter { it % 2 != 0 }.toSet())

    /** 只选双周（按可选周过滤）。 */
    fun selectEvenCustom(draft: AddCourseWeekDraft, availableWeeks: List<Int>): AddCourseWeekDraft =
        draft.copy(customWeeks = availableWeeks.filter { it % 2 == 0 }.toSet())

    /** 草稿的最终周次（与条目同口径）。 */
    fun selectedWeeks(draft: AddCourseWeekDraft): List<Int> =
        if (draft.mode == AddCourseWeekSelectionMode.CUSTOM) {
            draft.customWeeks.sorted()
        } else {
            AddCourseFormLogic.weeksFromRangeSelection(
                draft.startWeek,
                draft.endWeek,
                draft.isOddWeek,
                draft.isEvenWeek,
            )
        }

    /** 确认键是否可用：最终周次非空即可。 */
    fun canConfirm(draft: AddCourseWeekDraft): Boolean = selectedWeeks(draft).isNotEmpty()
}
