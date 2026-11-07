package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.transfer.IcsExportEventKind
import java.time.LocalDate

/**
 * ICS 导出页模型层（移植自 `lib/screens/ics_export_screen.dart` 的纯逻辑部分）。
 *
 * **移植边界**：这里只管「选什么、日期怎么顶、什么时候拦下、摘要显示什么、文件名怎么拼」。
 * 真实的事件收集与序列化在 `transfer/IcsModel.kt` + `transfer/IcsSerializer.kt`（Phase 2 已迁）；
 * 日历权限、FilePicker、分享面板是平台能力，留在渲染层注入的回调里。
 *
 * 全部纯 Kotlin（无 Compose / Android 依赖），JVM 单测可直接跑。
 */

/** 导出页只需要用到的课表字段（`TimetableProfile` 的超集裁剪）。 */
data class IcsExportProfile(
    val id: String,
    val name: String,
    val semesterStartDate: LocalDate? = null,
    val semesterWeekCount: Int = 20,
)

/** 导出选项（对应 Dart 的 `_fromDate` / `_toDate` / `_eventKinds` / `_skipHolidayCourses`）。 */
data class IcsExportOptions(
    val fromDate: LocalDate,
    val toDate: LocalDate,
    val eventKinds: Set<IcsExportEventKind> = IcsExportLogic.defaultEventKinds,
    /**
     * 落在节假日上的**课程**是否跳过（默认开启）。
     *
     * 只有勾了课程才有意义：考试与自定义日程照常导出（Dart 决策，2026-09-19）。
     */
    val skipHolidayCourses: Boolean = true,
)

/** 起止区间（Dart 用 `(DateTime, DateTime)` record，Kotlin 侧用具名类型便于断言）。 */
data class IcsExportRange(val from: LocalDate, val to: LocalDate)

/** 导出/同步的前置拦截原因（Dart 侧是三条 toast 分支）。 */
enum class IcsExportBlocker {
    /** 一份课表都没有。 */
    NO_PROFILES,

    /** 一种日历内容都没勾。 */
    NO_SELECTION,

    /** 勾了课程但没设学期开始日期（算不出上课日期）。 */
    SEMESTER_START_REQUIRED,
}

/** 摘要里的一行：正常行用次级文本色，[isError] 的行用错误色。 */
data class IcsExportSummaryLine(val text: String, val isError: Boolean = false)

/** 摘要卡片内容：标题是课表名，下面是「标签: 值」若干行。 */
data class IcsExportSummary(
    val title: String,
    val lines: List<IcsExportSummaryLine>,
)

/**
 * 导出页视图状态（渲染层只读它，不做业务计算）。
 *
 * 课表下拉标签、摘要、节假日开关可见性都是纯函数结果，放在这里让渲染层
 * 一句 `viewState.summary` 就能画，避免把逻辑漏进 Compose。
 */
data class IcsExportViewState(
    val profiles: List<IcsExportProfile> = emptyList(),
    val selectedProfileId: String? = null,
    val options: IcsExportOptions,
    val isExporting: Boolean = false,
    val isSyncing: Boolean = false,
    val isRemoving: Boolean = false,
    /** 导出成功后的「分享 / 保存」二选一菜单是否展开（Dart `_exportActionMenuVisible`）。 */
    val exportActionMenuVisible: Boolean = false,
    /** 生成结果里的事件数（菜单展开时提示用）。 */
    val pendingEventCount: Int = 0,
) {
    /** 当前选中的课表；id 不在列表里时退回 null（由调用方决定回落口径）。 */
    val selectedProfile: IcsExportProfile?
        get() = profiles.firstOrNull { it.id == selectedProfileId }

    /** 下拉项：显示名 → 课表 id。 */
    val profileItems: LinkedHashMap<String, String>
        get() = IcsExportLogic.profileItems(profiles, ExportStrings.icsExportProfileLabel.text)

    val summary: IcsExportSummary
        get() = IcsExportLogic.summary(selectedProfile, options)

    val showSkipHolidayCourses: Boolean
        get() = IcsExportLogic.skipHolidayCoursesVisible(options.eventKinds)

    val blocker: IcsExportBlocker?
        get() = IcsExportLogic.validate(selectedProfile, options)
}

object IcsExportLogic {

    /** Dart `IcsExportEventKind.all`（顺序即界面与摘要里的出现顺序）。 */
    val defaultEventKinds: Set<IcsExportEventKind> = linkedSetOf(
        IcsExportEventKind.COURSE,
        IcsExportEventKind.EXAM,
        IcsExportEventKind.SCHEDULE_ITEM,
    )

    /** 周一对齐（Dart `_mondayOf`：ics_export_screen.dart:863-866）。 */
    fun mondayOf(date: LocalDate): LocalDate = date.minusDays((date.dayOfWeek.value - 1).toLong())

    /**
     * 默认导出区间（Dart `_defaultRangeFor`：318-330）。
     *
     * - 设了学期开始日期：从该日所在周的周一，到第 `weeks` 周的周日（`weeks*7-1` 天）；
     *   周数小于 1 时按 1 周算。
     * - 没设：今天到 30 天后。
     */
    fun defaultRangeFor(profile: IcsExportProfile?, today: LocalDate): IcsExportRange {
        val semesterStart = profile?.semesterStartDate
        if (semesterStart != null) {
            val from = mondayOf(semesterStart)
            val weeks = if (profile.semesterWeekCount < 1) 1 else profile.semesterWeekCount
            return IcsExportRange(from = from, to = from.plusDays(weeks * 7L - 1))
        }
        return IcsExportRange(from = today, to = today.plusDays(30))
    }

    /**
     * 课表下拉项：显示名 → 课表 id（Dart `_profileItems`：296-316）。
     *
     * 重名课表追加序号 `名字 (2)`；序号本身撞上了就继续往后找（`A (2)` 已被占用时，
     * 第二个 `A` 落 `A (3)`），保证每个 id 都有唯一可点的标签。空名课表用
     * [blankFallbackLabel]（ARB `icsExportProfileLabel` = "课表"）当基名。
     */
    fun profileItems(
        profiles: List<IcsExportProfile>,
        blankFallbackLabel: String,
    ): LinkedHashMap<String, String> {
        val items = LinkedHashMap<String, String>()
        val nameCounts = HashMap<String, Int>()
        for (profile in profiles) {
            val trimmed = profile.name.trim()
            val baseName = if (trimmed.isEmpty()) blankFallbackLabel else trimmed
            var count = (nameCounts[baseName] ?: 0) + 1
            nameCounts[baseName] = count
            var label = if (count == 1) baseName else "$baseName ($count)"
            while (items.containsKey(label)) {
                count += 1
                nameCounts[baseName] = count
                label = "$baseName ($count)"
            }
            items[label] = profile.id
        }
        return items
    }

    /** 开始日期变更（Dart `_handleFromDateChanged`：420-428）：结束日期不早于开始日期。 */
    fun onFromDateChanged(options: IcsExportOptions, from: LocalDate): IcsExportOptions {
        val to = if (options.toDate.isBefore(from)) from else options.toDate
        return options.copy(fromDate = from, toDate = to)
    }

    /** 结束日期变更（Dart `_handleToDateChanged`：430-435）：早于开始日期时顶回开始日期。 */
    fun onToDateChanged(options: IcsExportOptions, to: LocalDate): IcsExportOptions {
        val clamped = if (to.isBefore(options.fromDate)) options.fromDate else to
        return options.copy(toDate = clamped)
    }

    /**
     * 「跳过节假日课程」开关是否出现（Dart 219-221）：
     * 只有勾了课程才展示 —— 否则是个改了不生效的开关。
     */
    fun skipHolidayCoursesVisible(eventKinds: Set<IcsExportEventKind>): Boolean =
        eventKinds.contains(IcsExportEventKind.COURSE)

    /**
     * 导出/同步前置校验（Dart `_export`：442-466 与 `_syncToSystemCalendar`：588-612 两条链路同源）。
     * 返回 null 表示可以继续。
     */
    fun validate(profile: IcsExportProfile?, options: IcsExportOptions): IcsExportBlocker? {
        if (profile == null) return IcsExportBlocker.NO_PROFILES
        if (options.eventKinds.isEmpty()) return IcsExportBlocker.NO_SELECTION
        if (options.eventKinds.contains(IcsExportEventKind.COURSE) &&
            profile.semesterStartDate == null
        ) {
            return IcsExportBlocker.SEMESTER_START_REQUIRED
        }
        return null
    }

    /** 摘要内容行「日历内容: 课程, 考试」的值部分；一种都没勾时是短横。 */
    fun selectedTypesLabel(eventKinds: Set<IcsExportEventKind>): String {
        val labels = buildList {
            if (eventKinds.contains(IcsExportEventKind.COURSE)) add(ExportStrings.icsExportCourses.text)
            if (eventKinds.contains(IcsExportEventKind.EXAM)) add(ExportStrings.icsExportExams.text)
            if (eventKinds.contains(IcsExportEventKind.SCHEDULE_ITEM)) {
                add(ExportStrings.icsExportSchedules.text)
            }
        }
        return if (labels.isEmpty()) "-" else labels.joinToString(", ")
    }

    /**
     * 摘要卡片（Dart `_buildSummary`：353-404）。
     *
     * 标题 = 课表名（没有课表时是占位文案），随后固定三行「标签: 值」，
     * 再按需追加「已跳过节假日课程」（普通行）与「请先设置学期开始日期」（错误行）。
     */
    fun summary(profile: IcsExportProfile?, options: IcsExportOptions): IcsExportSummary {
        val title = profile?.name ?: ExportStrings.icsExportNoProfiles.text
        val lines = mutableListOf(
            IcsExportSummaryLine(
                "${ExportStrings.icsExportStartDate.text}: ${formatDate(options.fromDate)}",
            ),
            IcsExportSummaryLine(
                "${ExportStrings.icsExportEndDate.text}: ${formatDate(options.toDate)}",
            ),
            IcsExportSummaryLine(
                "${ExportStrings.icsExportTypesTitle.text}: ${selectedTypesLabel(options.eventKinds)}",
            ),
        )
        if (options.skipHolidayCourses && options.eventKinds.contains(IcsExportEventKind.COURSE)) {
            lines += IcsExportSummaryLine(ExportStrings.icsExportSkipHolidayCoursesOn.text)
        }
        if (options.eventKinds.contains(IcsExportEventKind.COURSE) &&
            profile?.semesterStartDate == null
        ) {
            lines += IcsExportSummaryLine(
                ExportStrings.icsExportSemesterStartRequired.text,
                isError = true,
            )
        }
        return IcsExportSummary(title = title, lines = lines)
    }

    /**
     * 日期显示（Dart 用 `DateFormat.yMMMd(localeName)`，zh 下即「2026年3月2日」）。
     * 与 `pages/task` 的到期日格式同口径。
     */
    fun formatDate(date: LocalDate): String =
        "${date.year}年${date.monthValue}月${date.dayOfMonth}日"

    /**
     * 导出文件名（Dart `IcsExportService.buildFileName`：ics_export_service.dart:272-281）。
     *
     * 课表名清洗规则照抄 `_sanitizeFileNameSegment`（726-740）：空白折成 `_`、
     * 控制字符与 `<>:"/\|?*` 换成 `_`、连续 `_` 压成一个、去掉首尾 ` ._`；
     * 洗完为空时退回 `timetable`。日期是 `yyyyMMdd`。
     */
    fun buildFileName(profileName: String, from: LocalDate, to: LocalDate): String {
        val safeProfile = sanitizeFileNameSegment(profileName)
        return "$safeProfile-${compactDate(from)}-${compactDate(to)}.ics"
    }

    /** 系统日历里的日历名（ARB `icsExportSyncCalendarName` = "轻屿课表·{profileName}"）。 */
    fun syncCalendarName(profileName: String): String =
        ExportStrings.icsExportSyncCalendarName.filled("profileName", profileName)

    /**
     * 同步成功提示（Dart `_syncToSystemCalendar`：702-712）：跳过假期课程时追加一行。
     */
    fun syncSuccessMessage(eventCount: Int, skippedHolidayCourses: Int): String {
        val base = ExportStrings.icsExportSyncCalendarSuccess
            .filled("count", eventCount.toString())
        if (skippedHolidayCourses <= 0) return base
        val skipped = ExportStrings.icsExportSyncCalendarSkipped
            .filled("count", skippedHolidayCourses.toString())
        return "$base\n$skipped"
    }

    /** Dart `_formatCompactCalendarDate`：ics_export_service.dart:651-655。 */
    private fun compactDate(date: LocalDate): String {
        val year = date.year.toString().padStart(4, '0')
        val month = date.monthValue.toString().padStart(2, '0')
        val day = date.dayOfMonth.toString().padStart(2, '0')
        return "$year$month$day"
    }

    /**
     * Dart `_sanitizeFileNameSegment`：ics_export_service.dart:726-740。
     *
     * `:751-754` 还有一段**按 rune（codePoint）**的 80 上限截断：Dart 走
     * `safe.runes.take(80)`，避免把 emoji 这类代理对从中间截开留下孤立代理项。
     * 这里用 `codePoints()` 同口径；ASCII/BMP 与 `String.length` 结果一致。
     */
    private fun sanitizeFileNameSegment(value: String): String {
        val normalized = value.trim().replace(Regex("""\s+"""), "_")
        val buffer = StringBuilder()
        for (ch in normalized) {
            val code = ch.code
            val isControl = code < 0x20
            val isUnsafe = ch in "<>:\"/\\|?*"
            buffer.append(if (isControl || isUnsafe) '_' else ch)
        }
        var safe = buffer.toString().replace(Regex("_+"), "_")
        safe = safe.replace(Regex("""^[ ._]+"""), "")
        safe = safe.replace(Regex("""[ ._]+$"""), "")
        if (safe.isEmpty()) return "timetable"
        val codePoints = safe.codePoints().toArray()
        if (codePoints.size > 80) {
            val truncated = StringBuilder(80)
            for (index in 0 until 80) truncated.appendCodePoint(codePoints[index])
            return truncated.toString()
        }
        return safe
    }
}
