package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.BreakOverrideRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.buildQuickSectionTimes
import com.mutx163.qingyu.core.isSectionTimeSpanValid
import com.mutx163.qingyu.core.validateSectionTimes

/**
 * 「编辑时间模板」页的不可变状态机（口径来源：`lib/screens/time_scheme_management_screen.dart`
 * 的 `_TimeSchemeEditorPageState`，1888 行那份文件的编辑器一半）。
 *
 * ## 为什么是「不可变 + 返回新状态」而不是可变 List
 *
 * 页面每敲一下加号/改一节时间都要重画，宿主侧用 Compose 的 `mutableStateOf(model)`
 * 持有本对象即可；本类不持有任何 Android/Compose 引用，因此整条改动链（追加节次、
 * 改时间、恢复默认、快捷生成）都能在 JVM 单测里逐条钉住。
 *
 * ## 判据必须与 Dart 同源（不是「看起来差不多」）
 *
 * 三处最容易被重新发明的判据，本文件末尾**逐条照搬** Dart 同名实现：
 * - [canAppendSection]：`_screens/time_scheme_management_screen.dart:1855-1881`；
 * - [nextSection]：同文件 `_buildNextSection:1826-1834`；
 * - [resolveSectionEndTimeEdit]：同文件 `:1814-1824`。
 *
 * 三者是一组**互相咬合**的判据：`canAppendSection` 判的是 `nextSection` 的实际跨度
 * （末节结束 +10 分钟开始、+45 分钟结束，共需 55 分钟余量），而 `nextSection`
 * 用的又是**不带** `allowEndOfDay` 的宽松解析。任何一处单独改动都会造出
 * 「点一下添加、整张作息从此存不下」的幽灵节次（Dart 侧 2026-10-08 的报障原样）。
 *
 * ## 文案从哪来
 *
 * 一切屏上文字走 [TimeSchemeManagementStrings] / [TimeSchemeServiceMessages]，
 * 本文件不出现中文字面量。
 */
data class TimeSchemeEditorModel(
    val schemeId: String,
    val name: String,
    val sections: List<SectionTime>,
    val isActive: Boolean,
    val schemes: List<TimeScheme>,
    val activeSchemeId: String?,
    val usage: TimeSchemeUsageIndex = TimeSchemeUsageIndex.EMPTY,
    val lastQuickGeneratePreset: TimeSchemeQuickGeneratePreset = TimeSchemeQuickGeneratePreset.DEFAULT,
) {

    companion object {
        /**
         * 从仓储当前状态装配编辑器；[schemeId] 不在 [schemes] 里 → null。
         *
         * 返回 null 而不是抛错：宿主可能在「模板被另一个入口删掉」之后才切到编辑器
         * （Dart 侧同一路径会拿到 null 并 `Navigator.pop`）。页面据此回退，不崩。
         */
        fun from(
            schemes: List<TimeScheme>,
            activeSchemeId: String?,
            usage: TimeSchemeUsageIndex,
            schemeId: String,
        ): TimeSchemeEditorModel? {
            val scheme = schemes.firstOrNull { it.id == schemeId } ?: return null
            return TimeSchemeEditorModel(
                schemeId = schemeId,
                name = scheme.name,
                sections = scheme.sections,
                isActive = schemeId == activeSchemeId,
                schemes = schemes,
                activeSchemeId = activeSchemeId,
                usage = usage,
            )
        }
    }

    // ────────────────────────── 页面取值 ──────────────────────────

    /**
     * 编辑器页的静态文案（标题、各按钮、两个选择器标题）。
     *
     * 复用 [TimeSchemeManagementModel.editor] 这一份口径，避免同类文案出现第二种拼法；
     * `rows` 用**当前**节次表覆盖，宿主拿 [rows] 渲染，拿 [sheet] 取文案就够了。
     */
    val sheet: TimeSchemeEditorSheet by lazy {
        val base = TimeSchemeManagementModel(
            schemes = schemes,
            usage = usage,
            activeSchemeId = activeSchemeId,
        ).editor(schemeId)
        base?.copy(rows = rows) ?: TimeSchemeEditorSheet(
            schemeId = schemeId,
            title = TimeSchemeManagementStrings.editTimeSchemeTitle.text,
            name = name,
            impactHint = "",
            sectionTimesTitle = TimeSchemeManagementStrings.sectionTimesTitle.text,
            sectionTimesSubtitle = TimeSchemeManagementStrings.sectionTimesSubtitle.text,
            rows = rows,
            quickGenerateLabel = TimeSchemeManagementStrings.quickGenerateAction.text,
            addSectionLabel = TimeSchemeManagementStrings.addSectionAction.text,
            removeLastSectionLabel = TimeSchemeManagementStrings.removeLastSectionAction.text,
            resetDefaultLabel = TimeSchemeManagementStrings.resetDefaultAction.text,
            saveLabel = TimeSchemeManagementStrings.saveAction.text,
            startPickerTitle = TimeSchemeManagementStrings.selectStartTimeTitle.text,
            endPickerTitle = TimeSchemeManagementStrings.selectEndTimeTitle.text,
            crossDayError = TimeSchemeManagementStrings.timeRangeValidationNoCrossDay.text,
        )
    }

    /** 一节一行（序号 + 起止）；序号从 1 开始，与 Dart `第 N 节` 一致。 */
    val rows: List<TimeSchemeSectionRow>
        get() = sections.mapIndexed { index, section -> sectionRow(index, section) }

    /**
     * 顶部信息区（状态徽标 + 三个计数 chip + 影响提示 + 引用预览）。
     *
     * 逐条对 Dart `:1300-1340`：徽标只在「当前课表在用」时出现；三个 chip 是
     * 课表数 / 课程数 / 副模板课程数；影响提示按「在用 + 有课引用」挑最长的那句；
     * 预览有引用才显示（一条直接显示，多条拼 `{first} 等 {count} 节课程`）。
     */
    val header: TimeSchemeEditorHeader
        get() {
            val profileCount = usage.directProfiles[schemeId].orEmpty().size
            val overrideCount = usage.overrideCourses[schemeId].orEmpty().size
            val courseRefs = usage.courseReferences(schemeId)
            val courseCount = courseRefs.size
            val hint = when {
                isActive && courseCount > 0 -> TimeSchemeManagementStrings.timeSchemeEditorActiveAndCoursesHint.text
                isActive -> TimeSchemeManagementStrings.timeSchemeEditorActiveHint.text
                courseCount > 0 -> TimeSchemeManagementStrings.timeSchemeEditorOverrideHint.text
                else -> ""
            }
            return TimeSchemeEditorHeader(
                showInUseBadge = isActive,
                inUseBadgeText = if (isActive) TimeSchemeManagementStrings.currentInUse.text else "",
                chips = listOf(
                    TimeSchemeChip(
                        label = TimeSchemeManagementStrings.profileCountLabel.text,
                        value = TimeSchemeManagementStrings.profileCountValue.filled(
                            "count" to profileCount.toString(),
                        ),
                    ),
                    TimeSchemeChip(
                        label = TimeSchemeManagementStrings.courseCountLabel.text,
                        value = TimeSchemeManagementStrings.courseSectionCountValue.filled(
                            "count" to courseCount.toString(),
                        ),
                    ),
                    TimeSchemeChip(
                        label = TimeSchemeManagementStrings.overrideTimeSchemeLabel.text,
                        value = TimeSchemeManagementStrings.courseSectionCountValue.filled(
                            "count" to overrideCount.toString(),
                        ),
                    ),
                ),
                impactHint = hint,
                previewText = usagePreview(schemeId, courseRefs),
            )
        }

    /** 还能不能再追加一节（与「新增一节」按钮的置灰条件同源）。 */
    val canAdd: Boolean get() = canAppendSection(sections)

    /** 至少留一节：Dart 侧按钮在只剩一节时置灰。 */
    val canRemove: Boolean get() = sections.size > 1

    /** 「恢复默认」恒可点（Dart 侧没有置灰条件）。 */
    val canReset: Boolean get() = true

    // ────────────────────────── 状态迁移 ──────────────────────────

    fun withName(value: String): TimeSchemeEditorModel = copy(name = value)

    /**
     * 只换「引用关系 / 当前是否生效」这些**派生输入**，不动 name 与 sections
     * （契约变更 2）。
     *
     * 为什么需要它：Dart 编辑页把 name/sections 存在 State 里，把 usage 每次 build
     * 从 provider 现算；Kotlin 侧整个状态机是一个不可变对象，宿主在仓储变更时
     * 只能刷新后者。若用 `from(...)` 重建，用户正在编辑的节次会被盘上那份冲掉
     * （打了一半的节次凭空回退），所以刷新走这个方法。
     */
    fun withUsage(
        usage: TimeSchemeUsageIndex,
        schemes: List<TimeScheme>,
        activeSchemeId: String?,
    ): TimeSchemeEditorModel = copy(
        usage = usage,
        schemes = schemes,
        activeSchemeId = activeSchemeId,
        isActive = schemeId == activeSchemeId,
    )

    /**
     * 改第 [index] 节的时间。
     *
     * ## 2026-11-10 口径变更（用户指令）：编辑期允许乱序/重叠
     *
     * 原先这里跑 `validateSectionTimes(新表)`，不通过就**整表拒绝**——用户想先把「下午
     * 提到上午」这类结构调整到一半，会被即时拦回来。现在：
     *
     * 1. **只保留**「单节结束必须晚于开始」这条硬规则（跨天表达不了，`24:00` 除外）——
     *    失败时原样返回 + 提示，与之前一致；
     * 2. 顺序/重叠**不再拒绝编辑**：新表照常落地，[TimeSchemeEditOutcome.message] 换成
     *    非阻塞提示（[overlapHint]），由页面内联展示；
     * 3. 硬校验留给 [validateForSave]——重叠的节次表保存时仍会被拒（服务消息逐条不变）。
     *
     * 结束时间这一跳额外过一遍 [resolveSectionEndTimeEdit]：时间选择器的小时上限是 23，
     * 表达不了 `24:00`，把「原本是 24:00 且选回 00:00」认回 `24:00`，否则只想改开始
     * 时间的那次编辑会把末节改坏。这一段在 Dart 里就在调用点上，搬到本方法内是
     * 为了宿主不可能漏掉。
     */
    fun withSectionTime(index: Int, start: String, end: String): TimeSchemeEditOutcome {
        if (index !in sections.indices) return TimeSchemeEditOutcome(this, null)
        val editedEnd = resolveSectionEndTimeEdit(
            storedEndTime = sections[index].endTime,
            pickedEndTime = end,
        )
        if (!isSectionTimeSpanValid(start, editedEnd)) {
            return TimeSchemeEditOutcome(
                model = this,
                message = TimeSchemeManagementStrings.timeRangeValidationNoCrossDay.text,
            )
        }
        val next = sections.toMutableList()
        next[index] = SectionTime(start, editedEnd)
        return TimeSchemeEditOutcome(copy(sections = next), overlapHint(next))
    }

    /**
     * 编辑期的**非阻塞**重叠提示：第 n 节的开始早于上一节的结束就算重叠。
     *
     * 只服务编辑器页那行提示（`TimeSchemeServiceMessages.sectionTimeOverlap`，六语），
     * **不是**保存判据——保存仍走 [validateForSave] → `validateSectionTimes`。
     *
     * 逐条跳过「两格都空」的补位行（那是本仓认可的占位形状，不参与排序判定）；
     * 解析不出来的坏值也跳过（畸形存量值不在提示层猜语义）。
     */
    fun overlapHint(sections: List<SectionTime> = this.sections): String? {
        var previousEnd = -1
        for ((index, section) in sections.withIndex()) {
            if (section.startTime.trim().isEmpty() && section.endTime.trim().isEmpty()) continue
            val start = tryParseClockMinutes(section.startTime, allowEndOfDay = true) ?: continue
            val end = tryParseClockMinutes(section.endTime, allowEndOfDay = true) ?: continue
            if (previousEnd >= 0 && start < previousEnd) {
                return TimeSchemeServiceMessages.sectionTimeOverlap.filled(
                    "sectionNumber",
                    (index + 1).toString(),
                )
            }
            previousEnd = end
        }
        return null
    }

    /** 追加一节（末节不可追加时**原样返回**，不造幽灵节次）。 */
    fun addSection(): TimeSchemeEditorModel {
        if (!canAdd) return this
        return copy(sections = sections + nextSection(sections.last()))
    }

    /** 删除末节（只剩一节时原样返回）。 */
    fun removeLastSection(): TimeSchemeEditorModel {
        if (!canRemove) return this
        return copy(sections = sections.dropLast(1))
    }

    /** 恢复内置默认节次表（`TimetableSettings.defaults().sections`）。 */
    fun resetSections(): TimeSchemeEditorModel =
        copy(sections = TimetableSettings.defaults().sections)

    /**
     * 整表替换（快捷生成结果落地）。
     *
     * **不做校验**：快速生成自己会在 [TimeSchemeQuickGeneratePreset.toSections] 里
     * 抛 `DartFormatException`，重复校验只会让两处判据有机会漂移。
     */
    fun withSections(sections: List<SectionTime>): TimeSchemeEditorModel =
        copy(sections = sections)

    /** 记住上一次快捷生成的参数（下次打开弹层预填，Dart `_lastQuickGeneratePreset`）。 */
    fun withQuickGeneratePreset(preset: TimeSchemeQuickGeneratePreset): TimeSchemeEditorModel =
        copy(lastQuickGeneratePreset = preset)

    /**
     * 保存前的**快速反馈**校验：null = 可以提交，否则是**已本地化**的提示文案。
     *
     * 口径说明（已与 Lead 对齐）：Dart `_save` 本身没有前置校验，节次数 vs 已用最大
     * 节次、落盘失败这类判定全在 service 层。这里只做两件同一真源的事：
     * 名称必填（[TimeSchemeManagementStrings.nameRequired]）与
     * [validateSectionTimes]（与仓储同一函数）。**不**重复实现「已用最大节次」那段，
     * 否则同一判据会有两份，改一处就会漂移。
     */
    fun validateForSave(): String? {
        if (name.isBlank()) return TimeSchemeManagementStrings.nameRequired.text
        return validateSectionTimes(sections)?.let { TimeSchemeServiceMessages.localize(it) }
    }

    // ────────────────────────── 内部 ──────────────────────────

    private fun sectionRow(index: Int, section: SectionTime): TimeSchemeSectionRow =
        TimeSchemeSectionRow(
            index = index,
            label = TimeSchemeManagementStrings.sectionLabel.filled("section", (index + 1).toString()),
            startTime = section.startTime,
            endTime = section.endTime,
            rangeText = section.displayText,
        )

    /**
     * 编辑器里的「引用预览」一句话（Dart `_buildUsageSummary` 的 `previewText`）。
     *
     * 多条时用 `{first} 等 {count} 节课程`；一条时直接展开那条引用。引用的第一条
     * 取 [TimeSchemeUsageIndex.courseReferences] 的顺序（工厂按 Dart 的
     * 「档案 → 课程」遍历序填），所以显示的是真·第一条，不是某种重排后的第一条。
     */
    private fun usagePreview(
        schemeId: String,
        refs: List<TimeSchemeCourseRef>,
    ): String? {
        val first = refs.firstOrNull() ?: return null
        // ref 本身不带「占用方式」，按 courseId 是否落在 override 段判定 ——
        // 这正是 Dart `reference.usesOverride` 的等价信息（工厂按同一分类填的）。
        val overrideCourseIds = usage.overrideCourses[schemeId].orEmpty().map { it.courseId }.toSet()
        val usageType = if (first.courseId in overrideCourseIds) {
            TimeSchemeManagementStrings.overrideTimeSchemeShortLabel.text
        } else {
            TimeSchemeManagementStrings.mainTimeSchemeLabel.text
        }
        val summary = formatUsageReference(first, usageType)
        return if (refs.size == 1) {
            summary
        } else {
            TimeSchemeManagementStrings.timeSchemeBottomUsageMulti.filled(
                "first" to summary,
                "count" to refs.size.toString(),
            )
        }
    }
}

/** 顶部信息区的取值（见 [TimeSchemeEditorModel.header]）。 */
data class TimeSchemeEditorHeader(
    val showInUseBadge: Boolean,
    val inUseBadgeText: String,
    val chips: List<TimeSchemeChip>,
    /** 影响提示；空串 = 不显示。 */
    val impactHint: String,
    /** 引用预览；null = 不显示。 */
    val previewText: String?,
)

/** 一个计数 chip（左标签 + 右取值）。 */
data class TimeSchemeChip(val label: String, val value: String)

/** 改一节时间的结果：新状态 + 要弹的提示（null = 静默成功）。 */
/**
 * 快捷生成弹层的**实时预览**一行（2026-11-10 重做新增）。
 *
 * 「共 N 节 · 最后一节 HH:MM 结束」——用户改节数/起始时间/时长时直接看到结果，
 * 不必先点「生成」再回来看节次表。参数非法时返回 null（预览行整行不画，
 * 字段级校验提示照常显示），**不抛异常**。
 */
fun TimeSchemeQuickGeneratePreset.previewSummary(): String? = runCatching { toSections() }
    .getOrNull()
    ?.takeIf { it.isNotEmpty() }
    ?.let { sections ->
        TimeSchemeManagementStrings.quickGeneratePreviewSummary.filled(
            "sections" to sections.size.toString(),
            "endTime" to sections.last().endTime,
        )
    }

/**
 * 一次编辑的结果。
 *
 * [message] 现在是**非阻塞提示**（2026-11-10 起可能是「时间重叠」那句）：页面把它渲染成
 * 内联提示行，而不是 toast 之后拦下编辑。真正会拦住保存的判据在
 * [TimeSchemeEditorModel.validateForSave]。
 */
data class TimeSchemeEditOutcome(
    val model: TimeSchemeEditorModel,
    val message: String?,
)

/**
 * 快捷生成的参数（字段与 Dart `TimeSchemeQuickGeneratePreset` 逐字一致，
 * `lib/widgets/time_scheme_quick_generate_sheet.dart:14-56`）。
 */
data class TimeSchemeQuickGeneratePreset(
    val morningCount: Int,
    val afternoonCount: Int,
    val eveningCount: Int,
    val morningStartTime: String?,
    val afternoonStartTime: String?,
    val eveningStartTime: String?,
    val classDurationMinutes: Int,
    val breakDurationMinutes: Int,
    val breakOverrideRules: List<BreakOverrideRule>,
) {
    /**
     * 生成节次表；参数非法时**原样上抛** [com.mutx163.qingyu.core.DartFormatException]。
     *
     * 上抛而不是在这里接住并本地化：`DartFormatException.message` 是 service message
     * payload（`code|k=v`），本地化是调用方（宿主）用 [TimeSchemeServiceMessages.localize]
     * 的事。这里私自本地化会把「谁负责给用户看字」这条边界搅浑。
     */
    fun toSections(): List<SectionTime> = buildQuickSectionTimes(
        morningCount = morningCount,
        afternoonCount = afternoonCount,
        eveningCount = eveningCount,
        morningStartTime = morningStartTime,
        afternoonStartTime = afternoonStartTime,
        eveningStartTime = eveningStartTime,
        classDurationMinutes = classDurationMinutes,
        breakDurationMinutes = breakDurationMinutes,
        breakOverrideRules = breakOverrideRules,
    )

    companion object {
        /** Dart `kDefaultTimeSchemeQuickGeneratePreset`（同文件 `:36-49`）逐字一致。 */
        val DEFAULT = TimeSchemeQuickGeneratePreset(
            morningCount = 4,
            afternoonCount = 4,
            eveningCount = 2,
            morningStartTime = "08:00",
            afternoonStartTime = "14:00",
            eveningStartTime = "19:00",
            classDurationMinutes = 45,
            breakDurationMinutes = 10,
            breakOverrideRules = listOf(BreakOverrideRule(afterSection = 2, breakDurationMinutes = 20)),
        )
    }
}

/**
 * 单节时间编辑的宿主入口（契约变更 3）。
 *
 * 单独一个对象而不是散落的顶层函数：宿主在「点了第几节 → 两次时间选择器」这条链上
 * 只需要 import 这一个名字，判定口径也只能有这一份。
 */
object TimeSchemeSectionEdit {
    /**
     * 把「结束时间选择器返回的值」折叠回这一节实际要存的 endTime。
     *
     * 选择器小时上限是 23，表达不了本仓认可的 `24:00`；`stored` 是 `24:00` 且
     * `picked` 是 `00:00` 时返回 `stored` 原值，否则返回 `picked`。不这样，
     * 用户「只想改开始时间」时第二跳直接确认也会把 `24:00` 改成 `00:00`。
     *
     * 注意 [TimeSchemeEditorModel.withSectionTime] 内部**已经**做了这一跳，
     * 宿主走状态机时不必重复调；这个对象是给「不经过状态机、自己拼 SectionTime」
     * 的调用点（例如将来的批量改时间）用的同一份判据。
     */
    fun resolveEndTimeEdit(storedEndTime: String, pickedEndTime: String): String =
        resolveSectionEndTimeEdit(storedEndTime, pickedEndTime)
}

// ───────────────────────── 与 Dart 同源的三个判据 ─────────────────────────

/**
 * 还能不能再追加一节（逐条照搬 `time_scheme_management_screen.dart:1855-1881`）。
 *
 * 三条判据缺一不可：
 * 1. 数量上限（默认 20 节）与「一节都没有」；
 * 2. 末节结束时间必须**能解析**（带 `allowEndOfDay`，即放行 `24:00`）——
 *    畸形末节一律不追加：`nextSection` 会拿同一个宽松解析把畸形串兜底成 `00:00`，
 *    照样凭空造出一节 00:10-00:55 的幽灵课，而这张作息本来就已经存不下了；
 * 3. **时间余量**：末节结束 + 10 分钟开始 + 45 分钟结束 ≤ 24:00，即需要 55 分钟余量，
 *    不是「当天还没用完」。只判 `lastEnd < 1440` 会让 23:06~23:59 这一段的模板构造出
 *    23:16-00:01 这种**结束早于开始**的畸形节次（`%1440` 回绕）。
 *
 * 处置是**置灰**而不是弹错：仓库里没有「没有余地追加」这类文案，
 * 与「已满 20 节」共用同一条既有语义（Dart 注释原话）。
 */
fun canAppendSection(sections: List<SectionTime>, maxSections: Int = 20): Boolean {
    if (sections.size >= maxSections || sections.isEmpty()) {
        return false
    }
    val lastEnd = tryParseClockMinutes(sections.last().endTime, allowEndOfDay = true) ?: return false
    val nextSectionStartGapMinutes = 10
    val nextSectionSpanMinutes = 45
    return lastEnd + nextSectionStartGapMinutes + nextSectionSpanMinutes <= 24 * 60
}

/**
 * 追加出来的那一节（逐条照搬 Dart `_buildNextSection:1826-1834`）。
 *
 * 注意末尾的 `%1440` 回绕与 `minutesToClock` 的 `24:00` 语义**不同**：
 * Dart 这里就是 `_minutesToTime`（不带 24:00 特例），照搬即可 ——
 * 能不能走到这里由 [canAppendSection] 把关，余量足够时不会触发回绕。
 */
fun nextSection(last: SectionTime): SectionTime {
    val endMinutes = tryParseClockMinutes(last.endTime, allowEndOfDay = false) ?: 0
    val startMinutes = endMinutes + 10
    val finishMinutes = startMinutes + 45
    return SectionTime(
        startTime = minutesToWallClock(startMinutes),
        endTime = minutesToWallClock(finishMinutes),
    )
}

/**
 * 时间选择器返回的结束时间 → 这一节实际要存的结束时间
 * （逐条照搬 Dart `resolveSectionEndTimeEdit:1814-1824`）。
 *
 * 选择器小时上限是 23，表达不了本仓认可的 `24:00`；于是「原本就是 24:00 且这次选回
 * 00:00」解释成「结束时间没改」，保留 `24:00`。用户显式选别的值照常生效 ——
 * 而 `00:00` 当结束时间本来就是非法输入，会被 [isSectionTimeSpanValid] 拒掉，
 * 所以这个哨兵没有真实语义损失。
 */
fun resolveSectionEndTimeEdit(storedEndTime: String, pickedEndTime: String): String {
    val stored = tryParseClockMinutes(storedEndTime, allowEndOfDay = true)
    val isEndOfDay = stored != null && stored == 24 * 60
    if (isEndOfDay && pickedEndTime == "00:00") return storedEndTime
    return pickedEndTime
}

/**
 * 容错解析 `HH:mm`（Dart `ClockTime.tryParse` 的等价物，`lib/utils/clock_time.dart:30-52`）。
 *
 * 与 core 的 [com.mutx163.qingyu.core.clockMinutes] 的区别只有一处：后者**抛**
 * `DartFormatException`，这里返回 null。UI 侧全部需要「坏值就置灰/兜底」，
 * 用抛异常的版本会逼每个调用点写 try/catch。
 */
fun tryParseClockMinutes(value: String?, allowEndOfDay: Boolean = false): Int? {
    val text = value?.trim().orEmpty()
    if (text.isEmpty()) return null
    val parts = text.split(":")
    if (parts.size != 2) return null
    val hour = parts[0].trim().toIntOrNull() ?: return null
    val minute = parts[1].trim().toIntOrNull() ?: return null
    if (minute < 0 || minute > 59) return null
    if (allowEndOfDay && hour == 24 && minute == 0) return 24 * 60
    if (hour < 0 || hour > 23) return null
    return hour * 60 + minute
}

/** Dart `_minutesToTime`：`%1440` 回绕，**不**输出 `24:00`（与 `minutesToClock` 刻意不同）。 */
private fun minutesToWallClock(minutes: Int): String {
    val normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
    return "%02d:%02d".format(normalized / 60, normalized % 60)
}
