package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme

/**
 * 时间模板管理页的纯逻辑层：列表行、操作菜单、删除拦截、使用情况、分享与编辑器
 * 的全部取值都从这里出，页面只负责把字符串摆上去。
 *
 * ## 为什么把「引用计数」做成入参而不是去查仓库
 *
 * 这一版只落**逻辑 + 单测**，不引入 Compose 页面。引用关系（哪些课表直接绑了这套
 * 模板、哪些课程把它当副时间模板、哪些地点规则按地点匹配到它）来自课表仓库，属于
 * 别人的写作用域，所以这里用一个纯数据的 [TimeSchemeUsageIndex] 接住，由调用方
 * 灌入。好处是删除拦截这类最怕写错的判定可以脱离 Context/数据库直接单测。
 *
 * ## 删除为什么必须拦
 *
 * 删掉一套仍被引用的模板，会让课表和课程的节次时间直接落空（周视图按节次取时间，
 * 取不到就画不出来）。Dart 版在这里做的是「先列清单、再禁掉删除按钮」，这里照搬：
 * [TimeSchemeDeleteCheck.canDelete] 为 false 时，对话框只留「关闭」，不出现「删除」。
 *
 * ## 文案从哪来
 *
 * 一切屏上文字都走 [TimeSchemeManagementStrings]，本文件不出现中文字面量（除了拼名字用的
 * 分隔符，而那个分隔符本身也来自 ARB）。
 */
class TimeSchemeManagementModel(
    /** 模板清单，顺序即展示顺序（仓库给什么顺序就按什么顺序画）。 */
    val schemes: List<TimeScheme> = emptyList(),
    /** 引用关系索引，缺省视为「谁都没用」，因此全都可以删。 */
    val usage: TimeSchemeUsageIndex = TimeSchemeUsageIndex.EMPTY,
    /** 当前课表正在使用的模板 ID；null = 还没有课表在用。 */
    val activeSchemeId: String? = null,
    /** 「地点作息匹配」入口行行尾；等于地点分组条数，0 时不显示（Dart `:385-390`）。 */
    val locationGroupCount: Int = 0,
    /** 「日期作息规则」入口行行尾（Dart `:398-408`）。 */
    val dateRuleCount: Int = 0,
    /** 今天是否落在某条日期规则区间内（为真时行尾换成 [TimeSchemeManagementStrings.scheduleDateRuleActiveToday]）。 */
    val hasActiveDateRule: Boolean = false,
) {

    val isEmpty: Boolean get() = schemes.isEmpty()

    /** 列表页标题栏文案。 */
    val title: String get() = TimeSchemeManagementStrings.timeSchemeTitle.text

    /** 新建按钮的无障碍/长按提示。 */
    val newSchemeTooltip: String get() = TimeSchemeManagementStrings.newSchemeTooltip.text

    /**
     * 「地点作息匹配」入口的副标题。
     *
     * 一条模板都没有时，地点规则无从绑定，入口提示先建模板；这与 Dart 版
     * `locationTimeMatchNeedTimeScheme` 的用法一致。
     */
    val locationEntrySubtitle: String
        get() = if (isEmpty) {
            TimeSchemeManagementStrings.locationTimeMatchNeedTimeScheme.text
        } else {
            TimeSchemeManagementStrings.timeSchemeEntryTitle.text
        }

    /**
     * 「地点作息匹配」入口行的行尾；null = 不显示行尾（Dart `details: 条数 > 0 ? 条数 : null`）。
     *
     * 行尾是**条数**而不是「已启用条数」：这条入口就是把用户送到地点规则页，
     * 停用的规则也在那一页里，藏掉会让「我明明有 3 条，这里怎么没有」变成疑问。
     */
    val locationEntryDetails: String? get() = locationGroupCount.takeIf { it > 0 }?.toString()

    /**
     * 「日期作息规则」入口行的行尾（Dart `:398-408`）。
     *
     * 今天落在某条规则区间内时**换成**「今天在区间内」：那一刻用户最需要知道的是
     * 「今天按哪套作息」，而不是规则总条数。没有规则时不显示行尾。
     */
    val dateRuleEntryDetails: String?
        get() = when {
            dateRuleCount <= 0 -> null
            hasActiveDateRule -> TimeSchemeManagementStrings.scheduleDateRuleActiveToday.text
            else -> dateRuleCount.toString()
        }

    val rows: List<TimeSchemeRow> get() = schemes.map { rowOf(it) }

    fun row(schemeId: String): TimeSchemeRow? = schemes.firstOrNull { it.id == schemeId }?.let { rowOf(it) }

    private fun rowOf(scheme: TimeScheme): TimeSchemeRow {
        val profileCount = usage.directProfiles[scheme.id].orEmpty().size
        val overrideCount = usage.overrideCourses[scheme.id].orEmpty().size
        val courseCount = overrideCount +
            usage.followMainCourses[scheme.id].orEmpty().size +
            usage.locationCourses[scheme.id].orEmpty().size
        val isActive = scheme.id == activeSchemeId
        val firstSection = scheme.sections.firstOrNull()
        return TimeSchemeRow(
            scheme = scheme,
            isActive = isActive,
            sectionCount = scheme.sections.size,
            profileCount = profileCount,
            courseCount = courseCount,
            overrideCourseCount = overrideCount,
            startsAt = scheme.sections.firstOrNull()?.startTime?.takeIf { it.isNotBlank() },
            summary = TimeSchemeManagementStrings.timeSchemeSummary.filled(
                "sections" to scheme.sections.size.toString(),
                "profiles" to profileCount.toString(),
                "courses" to courseCount.toString(),
                "overrideCourses" to overrideCount.toString(),
            ),
            statusLabel = if (isActive) TimeSchemeManagementStrings.usingNow.text else "",
            // 首节起止与「一节都没有」是渲染层的两个不同分支：Dart 在没有任何节次时
            // 画占位 `-`，而不是画一个空的时间段。
            firstSectionText = if (firstSection == null || firstSection.displayText.isBlank()) {
                null
            } else {
                firstSection.displayText
            },
            hasNoSections = scheme.sections.isEmpty(),
        )
    }

    // ────────────────────────── 操作菜单 ──────────────────────────

    /** 这套模板有没有被任何课表 / 课程引用（Dart `_TimeSchemeUsageSummary.isUnused`）。 */
    fun isUnused(schemeId: String): Boolean {
        val profileCount = usage.directProfiles[schemeId].orEmpty().size
        val courseCount = usage.courseReferences(schemeId).size
        return profileCount == 0 && courseCount == 0
    }

    /**
     * 卡片右侧「更多操作」里的菜单项，顺序与 Dart `:306-345` **逐项一致**：
     *
     * ```
     * usage(仅 !isUnused) → apply(仅非当前) → edit → rename → duplicate → share → delete
     * ```
     *
     * 两条守卫都有语义：
     * - **没人用**时不出「查看使用情况」——点进去是一屏空段，纯噪音；
     * - **当前课表已在用它**时不出「应用到当前课表」——点了没有任何效果，摆着只会
     *   让人以为状态没生效。
     */
    fun menu(schemeId: String): List<TimeSchemeMenuItem> {
        if (schemes.none { it.id == schemeId }) return emptyList()
        val isActive = schemeId == activeSchemeId
        return buildList {
            if (!isUnused(schemeId)) add(menuItem(TimeSchemeAction.VIEW_USAGE))
            if (!isActive) add(menuItem(TimeSchemeAction.APPLY_TO_CURRENT))
            add(menuItem(TimeSchemeAction.EDIT_SECTIONS))
            add(menuItem(TimeSchemeAction.RENAME))
            add(menuItem(TimeSchemeAction.DUPLICATE))
            add(menuItem(TimeSchemeAction.SHARE))
            add(menuItem(TimeSchemeAction.DELETE))
        }
    }

    private fun menuItem(action: TimeSchemeAction) = TimeSchemeMenuItem(
        action = action,
        label = when (action) {
            TimeSchemeAction.APPLY_TO_CURRENT -> TimeSchemeManagementStrings.applyToCurrentTimetable.text
            TimeSchemeAction.EDIT_SECTIONS -> TimeSchemeManagementStrings.editSectionsAction.text
            TimeSchemeAction.VIEW_USAGE -> TimeSchemeManagementStrings.viewUsageAction.text
            TimeSchemeAction.RENAME -> TimeSchemeManagementStrings.renameAction.text
            TimeSchemeAction.DUPLICATE -> TimeSchemeManagementStrings.duplicateAction.text
            TimeSchemeAction.SHARE -> TimeSchemeManagementStrings.shareTimeSchemeAction.text
            TimeSchemeAction.DELETE -> TimeSchemeManagementStrings.deleteAction.text
        },
    )

    // ────────────────────────── 新建 / 重命名 ──────────────────────────

    /** 新建弹层：标题、字段、占位、确认按钮一次给全。 */
    val createSheet: TimeSchemeSheet
        get() = TimeSchemeSheet(
            title = TimeSchemeManagementStrings.createTimeSchemeTitle.text,
            nameLabel = TimeSchemeManagementStrings.timeSchemeNameLabel.text,
            nameHint = TimeSchemeManagementStrings.timeSchemeNameHint.text,
            initialName = "",
            confirmLabel = TimeSchemeManagementStrings.createAction.text,
            nameError = TimeSchemeManagementStrings.nameRequired.text,
        )

    fun renameSheet(schemeId: String): TimeSchemeSheet? {
        val scheme = schemes.firstOrNull { it.id == schemeId } ?: return null
        return TimeSchemeSheet(
            title = TimeSchemeManagementStrings.renameTimeSchemeTitle.text,
            nameLabel = TimeSchemeManagementStrings.timeSchemeNameLabel.text,
            nameHint = TimeSchemeManagementStrings.timeSchemeNameHint.text,
            initialName = scheme.name,
            confirmLabel = TimeSchemeManagementStrings.saveAction.text,
            nameError = TimeSchemeManagementStrings.nameRequired.text,
        )
    }

    /** 名称校验：只拦「全是空白」这一种。返回 null = 可以提交。 */
    fun validateName(raw: String): String? =
        if (raw.isBlank()) TimeSchemeManagementStrings.nameRequired.text else null

    /**
     * 复制出来的新名字（**改回 Dart 口径**：`'${source.name} 副本'`，
     * `lib/services/timetable_time_scheme_service.dart:224`）。
     *
     * 旧写法是 `A` → `A 2`（纯数字后缀），那是自创文案；这里改成与 Dart 字面量
     * 完全一致的「副本」后缀。后缀本身不新造字：ARB 里已有同形键
     * `themeDuplicateCopyName`（`{name} 副本`），借来用，见
     * [TimeSchemeManagementStrings.copiedSchemeNameTemplate]。
     *
     * 重名才退化成数字：`A 副本` 已被占用 → `A 副本 2` → `A 副本 3`……
     * （Dart 侧不做去重，允许同名；Kotlin 侧保留去重是既有行为，避免「复制两次得到
     * 两个一模一样的名字」让用户在列表里分不清哪套是哪套。）
     */
    fun copyName(base: String): String {
        val taken = schemes.map { it.name }.toSet()
        val candidate = TimeSchemeManagementStrings.copiedSchemeNameTemplate.filled("name", base)
        if (candidate !in taken) return candidate
        var index = 2
        while ("$candidate $index" in taken) index++
        return "$candidate $index"
    }

    /** 复制成功后的轻提示。 */
    val copiedMessage: String get() = TimeSchemeManagementStrings.copiedTimeSchemeMessage.text

    fun renamedMessage(name: String): String = TimeSchemeManagementStrings.renamedToMessage.filled("name", name)

    fun appliedMessage(schemeId: String): String {
        val name = schemes.firstOrNull { it.id == schemeId }?.name.orEmpty()
        return TimeSchemeManagementStrings.appliedTimeSchemeMessage.filled("name", name)
    }

    fun deletedMessage(name: String): String = TimeSchemeManagementStrings.deletedTimeSchemeMessage.filled("name", name)

    // ────────────────────────── 删除拦截 ──────────────────────────

    /**
     * 删除确认框的完整取值。
     *
     * 被引用时 [TimeSchemeDeleteCheck.blockers] 逐条列出占用方，[TimeSchemeDeleteCheck.canDelete]
     * 为 false，页面据此把「删除」按钮换成唯一的「关闭」。当前课表正在用它时，
     * 额外把 [TimeSchemeInUse] 那一句顶在最前面——它是用户最直接能感知的占用。
     */
    fun deleteCheck(schemeId: String): TimeSchemeDeleteCheck? {
        val scheme = schemes.firstOrNull { it.id == schemeId } ?: return null
        val blockers = blockers(schemeId)
        val inUse = schemeId == activeSchemeId
        return TimeSchemeDeleteCheck(
            schemeId = schemeId,
            title = TimeSchemeManagementStrings.deleteTimeSchemeTitle.text,
            message = TimeSchemeManagementStrings.deleteTimeSchemeMessage.filled("name", scheme.name),
            inUseNote = if (inUse) TimeSchemeManagementStrings.timeSchemeInUseMessage.text else "",
            blockerIntro = if (blockers.isEmpty()) "" else TimeSchemeManagementStrings.timeSchemeDeleteBlockedIntro.text,
            blockers = blockers,
            canDelete = blockers.isEmpty() && !inUse,
            confirmLabel = TimeSchemeManagementStrings.deleteAction.text,
            // 两个删除弹层的取消按钮都是「取消」（Dart :683 与 :793）；「关闭」只属于
            // 使用情况弹层（:1179）。原先这里恒给 closeAction，是把两个弹层的按钮串了。
            cancelLabel = TimeSchemeManagementStrings.cancelAction.text,
        )
    }

    /**
     * 占用清单，顺序固定：课表 → 副模板课程 → 地点匹配课程 → 地点规则 → 日期规则。
     *
     * 顺序固定是为了可测：对话框内容随数据抖动会让人以为删不掉的原因变了。
     */
    fun blockers(schemeId: String): List<String> {
        val separator = TimeSchemeManagementStrings.timeSchemeBlockerListSeparator.text
        val profiles = usage.directProfiles[schemeId].orEmpty()
        val overrideCourses = usage.overrideCourses[schemeId].orEmpty()
        val locationCourses = usage.locationCourses[schemeId].orEmpty()
        val locationGroups = usage.locationGroups[schemeId].orEmpty()
        val dateRules = usage.dateRules[schemeId].orEmpty()
        return buildList {
            if (profiles.isNotEmpty()) {
                add(
                    TimeSchemeManagementStrings.timeSchemeBlockedByProfiles.filled(
                        "names",
                        profiles.joinToString(separator) { it.name },
                    ),
                )
            }
            if (overrideCourses.isNotEmpty()) {
                add(
                    TimeSchemeManagementStrings.timeSchemeBlockedByOverrideCourses.filled(
                        "count",
                        overrideCourses.size.toString(),
                    ),
                )
            }
            if (locationCourses.isNotEmpty()) {
                add(
                    TimeSchemeManagementStrings.timeSchemeBlockedByLocationCourses.filled(
                        "count",
                        locationCourses.size.toString(),
                    ),
                )
            }
            if (locationGroups.isNotEmpty()) {
                add(
                    TimeSchemeManagementStrings.timeSchemeBlockedByLocationGroups.filled(
                        "names",
                        locationGroups.joinToString(separator) { it.name },
                    ),
                )
            }
            if (dateRules.isNotEmpty()) {
                add(
                    TimeSchemeManagementStrings.timeSchemeBlockedByDateRules.filled(
                        "names",
                        dateRules.joinToString(separator) { it.name },
                    ),
                )
            }
        }
    }

    // ────────────────────────── 使用情况 ──────────────────────────

    /**
     * 使用情况页的整页取值。
     *
     * 三段列表对应三种占用方式，各自的副标题与空态都不同：直接绑定（课表级）、
     * 跟随主模板（课程没设副模板，跟着课表走）、副模板覆盖（课程单独指定）。
     * 混成一段会让人无法判断「改这套模板会不会动到那门课」。
     */
    fun usageView(schemeId: String): TimeSchemeUsageView? {
        val scheme = schemes.firstOrNull { it.id == schemeId } ?: return null
        val profiles = usage.directProfiles[schemeId].orEmpty()
        val followCourses = usage.followMainCourses[schemeId].orEmpty()
        val overrideCourses = usage.overrideCourses[schemeId].orEmpty()
        val locationCourses = usage.locationCourses[schemeId].orEmpty()
        val courseCount = followCourses.size + overrideCourses.size + locationCourses.size

        val followLines = followCourses.map {
            line(it, TimeSchemeManagementStrings.mainTimeSchemeLabel.text)
        }
        val overrideLines = overrideCourses.map {
            line(it, TimeSchemeManagementStrings.overrideTimeSchemeShortLabel.text)
        }
        // 地点这一段是「删除前必须先改绑」的占用清单，所以课程与规则条目并在一段里：
        // 用户在这里只关心「还有谁在用」，分不分课程/规则不影响他要做的动作。
        val locationLines = locationCourses.map {
            line(it, TimeSchemeManagementStrings.locationTimeMatchEntryTitle.text)
        } + usage.locationGroups[schemeId].orEmpty().map {
            TimeSchemeLine(title = it.name, summary = "")
        }

        val bottomFirst = (followCourses + overrideCourses + locationCourses).firstOrNull()?.courseName
        val bottomSummary = if (courseCount > 1 && bottomFirst != null) {
            TimeSchemeManagementStrings.timeSchemeBottomUsageMulti.filled(
                "first" to bottomFirst,
                "count" to courseCount.toString(),
            )
        } else {
            ""
        }

        val blockList = blockers(schemeId)
        return TimeSchemeUsageView(
            schemeId = schemeId,
            title = TimeSchemeManagementStrings.timeSchemeUsageTitle.filled("name", scheme.name),
            intro = TimeSchemeManagementStrings.timeSchemeUsageIntro.text,
            profileCountLabel = TimeSchemeManagementStrings.profileCountLabel.text,
            profileCountValue = TimeSchemeManagementStrings.profileCountValue.filled("count", profiles.size.toString()),
            courseCountLabel = TimeSchemeManagementStrings.courseCountLabel.text,
            courseCountValue = TimeSchemeManagementStrings.courseSectionCountValue.filled("count", courseCount.toString()),
            overrideCountLabel = TimeSchemeManagementStrings.overrideTimeSchemeLabel.text,
            overrideCountValue = TimeSchemeManagementStrings.courseSectionCountValue.filled(
                "count",
                overrideCourses.size.toString(),
            ),
            directProfilesTitle = TimeSchemeManagementStrings.directlyBoundProfilesTitle.text,
            directProfilesSubtitle = TimeSchemeManagementStrings.directlyBoundProfilesSubtitle.text,
            directProfilesEmpty = TimeSchemeManagementStrings.directlyBoundProfilesEmpty.text,
            directProfiles = profiles.map { TimeSchemeLine(title = it.name, summary = "") },
            followTitle = TimeSchemeManagementStrings.followMainSchemeCoursesTitle.text,
            followSubtitle = TimeSchemeManagementStrings.followMainSchemeCoursesSubtitle.text,
            followEmpty = TimeSchemeManagementStrings.followMainSchemeCoursesEmpty.text,
            followLines = followLines,
            overrideTitle = TimeSchemeManagementStrings.overrideSchemeCoursesTitle.text,
            overrideSubtitle = TimeSchemeManagementStrings.overrideSchemeCoursesSubtitle.text,
            overrideEmpty = TimeSchemeManagementStrings.overrideSchemeCoursesEmpty.text,
            overrideLines = overrideLines,
            locationTitle = TimeSchemeManagementStrings.locationTimeMatchEntryTitle.text,
            locationSubtitle = TimeSchemeManagementStrings.timeSchemeBlockedLocationGroupsSubtitle.text,
            locationLines = locationLines,
            dateRuleTitle = TimeSchemeManagementStrings.scheduleDateRuleSectionTitle.text,
            dateRuleSubtitle = TimeSchemeManagementStrings.timeSchemeBlockedDateRulesSubtitle.text,
            dateRuleLines = usage.dateRules[schemeId].orEmpty().map {
                TimeSchemeLine(title = it.name, summary = "")
            },
            bottomSummary = bottomSummary,
            canDelete = blockList.isEmpty() && schemeId != activeSchemeId,
            blockers = blockList,
        )
    }

    private fun line(course: TimeSchemeCourseRef, usageType: String): TimeSchemeLine {
        val weekday = TimeSchemeManagementStrings.weekdayShort(course.dayOfWeek)
        return TimeSchemeLine(
            title = formatUsageReference(course, usageType),
            summary = TimeSchemeManagementStrings.weekdaySectionRange.filled(
                "weekday" to weekday,
                "startSection" to course.startSection.toString(),
                "endSection" to course.endSection.toString(),
            ),
        )
    }

    // ────────────────────────── 分享 ──────────────────────────

    /** 分享面板：二维码 / 系统文件两条路，外加随分享带出去的说明文字。 */
    fun shareSheet(schemeId: String): TimeSchemeShareSheet? {
        val scheme = schemes.firstOrNull { it.id == schemeId } ?: return null
        return TimeSchemeShareSheet(
            schemeId = schemeId,
            schemeName = scheme.name,
            title = TimeSchemeManagementStrings.shareTimeSchemeTitle.text,
            viaQrLabel = TimeSchemeManagementStrings.shareTimeSchemeViaQr.text,
            viaSystemLabel = TimeSchemeManagementStrings.shareTimeSchemeViaSystem.text,
            cancelLabel = TimeSchemeManagementStrings.cancelAction.text,
            shareText = TimeSchemeManagementStrings.timeSchemeShareText.filled("name", scheme.name),
            shareSubject = TimeSchemeManagementStrings.timeSchemeShareSubject.text,
        )
    }

    /** 系统分享失败时的提示（带原始错误串）。 */
    fun sendFailedMessage(error: String): String =
        TimeSchemeManagementStrings.sendFailedWithError.filled("error", error)

    /** 二维码中转资源上限的提示。 */
    val qrResourceLimitMessage: String get() = TimeSchemeManagementStrings.qrTransferResourceLimit.text

    // ────────────────────────── 编辑器 ──────────────────────────

    /**
     * 「编辑节次」页取值。
     *
     * [TimeSchemeEditorSheet.impactHint] 按真实引用关系挑一句：既被课表用、又有
     * 课程当副模板时用最长的那句；只有一种占用时说一种；都没有就不提示。含糊地
     * 一律提示「会影响所有课表」会让没人在用的模板也弹出吓人的警告。
     */
    fun editor(schemeId: String): TimeSchemeEditorSheet? {
        val scheme = schemes.firstOrNull { it.id == schemeId } ?: return null
        val isActive = schemeId == activeSchemeId
        val overrideCount = usage.overrideCourses[schemeId].orEmpty().size
        val hint = when {
            isActive && overrideCount > 0 -> TimeSchemeManagementStrings.timeSchemeEditorActiveAndCoursesHint.text
            isActive -> TimeSchemeManagementStrings.timeSchemeEditorActiveHint.text
            overrideCount > 0 -> TimeSchemeManagementStrings.timeSchemeEditorOverrideHint.text
            else -> ""
        }
        return TimeSchemeEditorSheet(
            schemeId = schemeId,
            title = TimeSchemeManagementStrings.editTimeSchemeTitle.text,
            name = scheme.name,
            impactHint = hint,
            sectionTimesTitle = TimeSchemeManagementStrings.sectionTimesTitle.text,
            sectionTimesSubtitle = TimeSchemeManagementStrings.sectionTimesSubtitle.text,
            rows = scheme.sections.mapIndexed { index, section -> sectionRow(index, section) },
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

    /**
     * 单节时间行：序号 + 起止。
     *
     * [TimeSchemeSectionRow.rangeText] 直接取 core 的 [SectionTime.displayText]——
     * 起止时间的拼法是数据层的既有约定，这里再手拼一次只会多出一种格式。
     */
    fun sectionRow(index: Int, section: SectionTime): TimeSchemeSectionRow = TimeSchemeSectionRow(
        index = index,
        label = TimeSchemeManagementStrings.sectionLabel.filled("section", (index + 1).toString()),
        startTime = section.startTime,
        endTime = section.endTime,
        rangeText = section.displayText,
    )
}

/**
 * 一条课程引用的整句描述（Dart `_formatUsageReference`，`:1015-1030`）。
 *
 * 抽出成顶层函数是因为它有**两个**消费方：使用情况页的列表行与编辑器的引用预览
 * （[TimeSchemeEditorModel.header]）。同一句话在两处各拼一遍，早晚出现两种格式。
 */
fun formatUsageReference(course: TimeSchemeCourseRef, usageType: String): String =
    TimeSchemeManagementStrings.timeSchemeUsageReference.filled(
        "profileName" to course.profileName,
        "courseName" to course.courseName,
        "weekday" to TimeSchemeManagementStrings.weekdayShort(course.dayOfWeek),
        "startSection" to course.startSection.toString(),
        "endSection" to course.endSection.toString(),
        "usageType" to usageType,
    )

/** 列表卡片的一行所需的全部取值。 */
data class TimeSchemeRow(
    val scheme: TimeScheme,
    val isActive: Boolean,
    val sectionCount: Int,
    val profileCount: Int,
    val courseCount: Int,
    val overrideCourseCount: Int,
    /** 首节开始时间；null = 这套模板一节都没有。 */
    val startsAt: String?,
    val summary: String,
    /** 「正在使用」标记；非当前模板为空串。 */
    val statusLabel: String,
    /** 首节起止 `08:00-08:45`；null = 这套模板没有任何节次（Dart 渲染成占位 `-`）。 */
    val firstSectionText: String? = null,
    /** 这套模板是不是「一节都没有」，渲染成占位 `-`。 */
    val hasNoSections: Boolean = false,
) {
    val title: String get() = scheme.name

    /**
     * 卡片右上角的次要信息。
     *
     * 正在用的模板显示「正在使用」，其余显示「08:00 起」——一个说状态，一个说
     * 起点，都是扫一眼就能对上自己作息的那个信息。
     */
    val subtitle: String
        get() = when {
            isActive -> TimeSchemeManagementStrings.usingNow.text
            startsAt != null -> TimeSchemeManagementStrings.timeSchemeStartsAt.filled("start", startsAt)
            else -> ""
        }
}

/** 「更多操作」菜单项。 */
data class TimeSchemeMenuItem(val action: TimeSchemeAction, val label: String)

/** 卡片菜单里的动作枚举；顺序由 [TimeSchemeManagementModel.menu] 决定，不依赖枚举序。 */
enum class TimeSchemeAction {
    APPLY_TO_CURRENT,
    EDIT_SECTIONS,
    VIEW_USAGE,
    RENAME,
    DUPLICATE,
    SHARE,
    DELETE,
}

/** 新建 / 重命名共用的表单弹层取值。 */
data class TimeSchemeSheet(
    val title: String,
    val nameLabel: String,
    val nameHint: String,
    val initialName: String,
    val confirmLabel: String,
    val nameError: String,
)

/** 删除确认框取值。 */
data class TimeSchemeDeleteCheck(
    val schemeId: String,
    val title: String,
    val message: String,
    /** 当前课表正在使用时的补一句；否则空串。 */
    val inUseNote: String,
    /** 被占用时的说明抬头；可删时为空串。 */
    val blockerIntro: String,
    val blockers: List<String>,
    val canDelete: Boolean,
    val confirmLabel: String,
    /** 被占用时唯一可点的按钮。 */
    val cancelLabel: String,
)

/** 使用情况页里的一行（课程行或课表行）。 */
data class TimeSchemeLine(val title: String, val summary: String)

/** 使用情况页整页取值。 */
data class TimeSchemeUsageView(
    val schemeId: String,
    val title: String,
    val intro: String,
    val profileCountLabel: String,
    val profileCountValue: String,
    val courseCountLabel: String,
    val courseCountValue: String,
    val overrideCountLabel: String,
    val overrideCountValue: String,
    val directProfilesTitle: String,
    val directProfilesSubtitle: String,
    val directProfilesEmpty: String,
    val directProfiles: List<TimeSchemeLine>,
    val followTitle: String,
    val followSubtitle: String,
    val followEmpty: String,
    val followLines: List<TimeSchemeLine>,
    val overrideTitle: String,
    val overrideSubtitle: String,
    val overrideEmpty: String,
    val overrideLines: List<TimeSchemeLine>,
    /** 按上课地点匹配到这套模板的课程（删除拦截里也算占用）。 */
    val locationTitle: String,
    val locationSubtitle: String,
    val locationLines: List<TimeSchemeLine>,
    /**
     * 「日期作息规则」可选段：只有非空才渲染（与地点段同口径）。
     *
     * 这三项是**契约变更 1**（ts-list 提、Lead 裁定采纳）：日期规则同样会阻止删除，
     * 用户在这页看不到它就会以为「没人用它、为什么删不掉」。三项都有默认值，
     * 既有构造点不受影响。
     */
    val dateRuleTitle: String = "",
    val dateRuleSubtitle: String = "",
    val dateRuleLines: List<TimeSchemeLine> = emptyList(),
    /** 课程多于一条时的「… 等 N 节课程」汇总；否则空串。 */
    val bottomSummary: String,
    val canDelete: Boolean,
    val blockers: List<String>,
)

/** 分享面板取值。 */
data class TimeSchemeShareSheet(
    val schemeId: String,
    /**
     * 被分享模板的名字（Dart 分享弹层正文那句，`:860-866`）。
     *
     * 有默认空串：既有构造点不受影响，渲染层按名字接即可。
     */
    val schemeName: String = "",
    val title: String,
    val viaQrLabel: String,
    val viaSystemLabel: String,
    val cancelLabel: String,
    val shareText: String,
    val shareSubject: String,
)

/** 编辑节次页取值。 */
data class TimeSchemeEditorSheet(
    val schemeId: String,
    val title: String,
    val name: String,
    /** 影响范围提示；无人使用时为空串。 */
    val impactHint: String,
    val sectionTimesTitle: String,
    val sectionTimesSubtitle: String,
    val rows: List<TimeSchemeSectionRow>,
    val quickGenerateLabel: String,
    val addSectionLabel: String,
    val removeLastSectionLabel: String,
    val resetDefaultLabel: String,
    val saveLabel: String,
    val startPickerTitle: String,
    val endPickerTitle: String,
    val crossDayError: String,
)

/** 编辑器里的一节。 */
data class TimeSchemeSectionRow(
    val index: Int,
    val label: String,
    val startTime: String,
    val endTime: String,
    val rangeText: String,
)

/** 课表级引用。 */
data class TimeSchemeProfileRef(val id: String, val name: String)

/** 课程级引用（含它落在一周哪一节的哪一段）。 */
data class TimeSchemeCourseRef(
    val profileId: String,
    val profileName: String,
    val courseId: String,
    val courseName: String,
    /** 1-7，周一到周日。 */
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
)

/** 只有名字就够的引用（地点规则、日期规则）。 */
data class TimeSchemeNameRef(val id: String, val name: String)

/**
 * 引用关系索引：模板 ID → 占用它的东西。
 *
 * 缺键与空表等价（都表示「没人用」），所以调用方可以只填关心的那几个模板。
 */
data class TimeSchemeUsageIndex(
    val directProfiles: Map<String, List<TimeSchemeProfileRef>> = emptyMap(),
    val followMainCourses: Map<String, List<TimeSchemeCourseRef>> = emptyMap(),
    val overrideCourses: Map<String, List<TimeSchemeCourseRef>> = emptyMap(),
    val locationCourses: Map<String, List<TimeSchemeCourseRef>> = emptyMap(),
    val locationGroups: Map<String, List<TimeSchemeNameRef>> = emptyMap(),
    val dateRules: Map<String, List<TimeSchemeNameRef>> = emptyMap(),
    /**
     * 课程级引用，按 Dart 的「档案 → 课程」遍历序（契约变更 5，附加字段）。
     *
     * 三张分类表（follow / override / location）各自有序、但**它们之间的先后关系丢了**；
     * 编辑器头部的引用预览要显示「第一条」，用分类表拼出来的第一条与 Dart 显示的可能
     * 不是同一门课。工厂按 True 的原序额外记一份，预览就走这里。默认空表 ⇒ 既有构造点
     * 与只读分类表的调用方零影响。
     */
    val orderedCourseRefs: Map<String, List<TimeSchemeCourseRef>> = emptyMap(),
) {
    /**
     * 这套模板引用的**全部**课程，按 Dart 遍历序。
     *
     * 缺 [orderedCourseRefs] 时退化成「跟随主模板 + 副模板 + 地点匹配」的拼接序，
     * 保证手工构造索引的调用方与单测仍拿到完整的课程集合。
     */
    fun courseReferences(schemeId: String): List<TimeSchemeCourseRef> {
        orderedCourseRefs[schemeId]?.let { return it }
        return followMainCourses[schemeId].orEmpty() +
            overrideCourses[schemeId].orEmpty() +
            locationCourses[schemeId].orEmpty()
    }

    companion object {
        val EMPTY = TimeSchemeUsageIndex()
    }
}
