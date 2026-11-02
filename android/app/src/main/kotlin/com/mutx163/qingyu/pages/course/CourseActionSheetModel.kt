package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.ClassAlarmPlanLogic
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.course.CourseDomain
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.weather.CourseWeatherSummary
import com.mutx163.qingyu.weather.planWeatherLine
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 周视图「课程操作弹层」的**纯模型层**（Dart 判据 `lib/widgets/course_action_sheet.dart`）。
 *
 * 分工：
 * - 本文件：把课程 / 预览条目 / 作业 / 天气 / 日期算成**一份内容描述**
 *   （[CourseActionSheetDetails]），并把用户选择反成 [CourseActionEvent]；
 * - `composeP1/.../pages/course/CourseActionSheet.kt`：只按描述画，不做业务判断；
 * - 宿主（壳）：拿 [CourseActionEvent] 去写库 / 导航，**弹层自身不写库**。
 *
 * ## 为什么模型在 `main/` 而不是和渲染层放一起
 *
 * `scripts/test-kotlin-module.ps1 -Module "pages/course"` 只收 `main/pages/course` +
 * `test/pages/course` + 共享纯 Kotlin 目录，**不收 `composeP1`**。模型放 `main/` 才能进
 * 真 JVM 单测（L0）；也正因如此，本文件一个 `android.*` / `androidx.compose.*` /
 * `top.yukonga.miuix.*` 都不许 import。
 *
 * ## 与 Dart 的落点差异（API 面不变）
 *
 * [CourseDeleteScope] / [CourseSuspendScope] / [CourseRescheduleTarget] 由 F 泳道声明在
 * `main/pages/course/CourseFollowupModel.kt`（同包、纯数据），本文件直接用 —— 同样是因为
 * 「L0 只收 main」：任何被 [CourseActionEvent] 引用的类型必须落在 `main` 里，否则 L0 永远
 * Unresolved。`composeP1` 里只剩四个 `@Composable`。
 *
 * ## 数据口径（只用数据效果对照 Dart）
 *
 * | 项 | 出处 |
 * |---|---|
 * | 冲突课取数 / 排序 / 去重 | `lib/widgets/timetable/timetable_course_action_items.dart:184-203` |
 * | 头部块 | `course_action_sheet.dart:704-757` |
 * | 详情行 | `:759-870` + 行样式 `:963-1048` |
 * | 备注行标题/副题 | `:923-961` |
 * | 说明句周次高亮 | `:1050-1084` |
 * | 时间行副题 | `:1086-1109` |
 * | 天气行判据 | `:558-602` + `lib/widgets/course_weather_display.dart` |
 * | 关联课程面板 | `:210-473` |
 */

// ───────────────────────── 对宿主的事件 ─────────────────────────

/**
 * 用户在弹层里做出的选择。**弹层只抛事件、不写库**。
 *
 * 签名与 `docs/plans/2026-10-29-compose-course-action-sheet-audit.md` §三 的差别只有一处、
 * 且是**必须的**一处：[courseId]。弹层内部允许切到冲突课（Dart `_selectedIndex`），
 * 事件不带课标识的话，宿主只能拿到「最初点开弹层的那门课」，用户先切课再点删除/编辑
 * 就会**对错误的课写库**。所以每个事件都带上「当前选中那条」的课程 id，
 * 发事件一律走 [CourseActionSheetModel.Events]（它从 section 取 id），
 * 宿主侧按 id 回快照里取最新对象，不要复用旧引用。
 */
sealed interface CourseActionEvent {
    /** 事件所属的那门课（= 当前选中 section 的 `courseId`）。 */
    val courseId: String

    /** 「编辑课程」（整宽主按钮）。 */
    data class Edit(override val courseId: String) : CourseActionEvent

    /** 作业行（Dart `:833-839`）→ 打开作业页。 */
    data class AddTask(override val courseId: String) : CourseActionEvent

    /** 删除范围选完、二次确认通过之后的实际删除。 */
    data class Delete(
        override val courseId: String,
        val scope: CourseDeleteScope,
    ) : CourseActionEvent

    /** 停课 / 恢复。 */
    data class Suspend(
        override val courseId: String,
        val scope: CourseSuspendScope,
    ) : CourseActionEvent

    /** 调课（目标周 / 星期 / 起止节次 / 地点）。 */
    data class Reschedule(
        override val courseId: String,
        val target: CourseRescheduleTarget,
    ) : CourseActionEvent

    /** 备注弹层保存：`wholeNote` = 课程简介，`sessionNote` = 本节备注。 */
    data class SaveNotes(
        override val courseId: String,
        val wholeNote: String?,
        val sessionNote: String?,
    ) : CourseActionEvent
}

// ───────────────────────── 预览条目 ─────────────────────────

/**
 * 情侣课表里的角色（Dart `CoupleCourseKind`）。
 *
 * Compose 周视图**还没有**情侣叠加层（见 audit §五），本轮线上拿不到数据；保留定义与文案
 * 路径，是为了叠加层落地时弹层侧不用再改一次。
 */
enum class CourseCoupleKind { TOGETHER, PARTNER, MINE }

/**
 * 弹层要预览的一条（Dart `CourseActionPreviewItem`，`course_action_sheet.dart:24-42`）。
 *
 * 第一条恒为主课，其余是冲突课 / 情侣课；`previewItems.length > 1` 时才有关联课程面板。
 */
data class CourseActionPreviewItem(
    val course: Course,
    /** 对方（TA）课表里的课：只读，动作区整块不渲染。 */
    val isPartnerCourse: Boolean = false,
    /** 与主课同周同节冲突（Dart `isConflict`）。 */
    val isConflict: Boolean = false,
    val coupleKind: CourseCoupleKind? = null,
) {
    /** Dart `isReadOnly => isPartnerCourse`。 */
    val isReadOnly: Boolean get() = isPartnerCourse

    /** Dart `isCoupleRelated`。 */
    val isCoupleRelated: Boolean
        get() = coupleKind == CourseCoupleKind.TOGETHER || coupleKind == CourseCoupleKind.PARTNER
}

// ───────────────────────── 渲染用的枚举（不带图标库依赖）─────────────────────────

/**
 * 行/头部要画的图标**语义**。渲染层负责映射到 `MiuixIcons.*`。
 *
 * 模型层不许 import miuix，所以这里只有语义名，没有 `ImageVector`。
 */
enum class CourseActionIcon {
    /** 课程本体（Dart `Icons.menu_book_rounded`）。 */
    COURSE,

    /** 情侣一起上课（Dart `Icons.favorite_rounded`）。 */
    COUPLE_HEART,

    /** 对方课表的课（Dart `Icons.person_outline_rounded`）。 */
    PARTNER_PERSON,

    /** 时间（Dart `Icons.schedule_outlined`）。 */
    TIME,

    /** 教师（Dart `Icons.person_outline_rounded`）。 */
    TEACHER,

    /** 地点（Dart `Icons.location_on_outlined`）。 */
    LOCATION,

    /** 天气（Dart 按现象取图标）。 */
    WEATHER,

    /** 备注（Dart `Icons.sticky_note_2_outlined`）。 */
    NOTE,

    /** 作业（Dart `Icons.assignment_outlined`）。 */
    TASK,

    /** 单节课闹钟（Dart `Icons.alarm_outlined`）。 */
    ALARM,

    /** 说明行（Dart `Icons.info_outline_rounded`）。 */
    INFO,

    /** 冲突角标（Dart `Icons.warning_amber_rounded`）。 */
    CONFLICT_BADGE,
}

/** 详情行的种类（Dart `:759-870` 的 8 类行）。 */
enum class CourseActionRowKind {
    TIME,
    TEACHER,
    LOCATION,
    WEATHER,
    NOTE,
    TASK,
    ALARM,
    NOTICE,
}

/** 这一行点了之后弹层要做什么（宿主不参与）。 */
enum class CourseActionRowTap {
    /** 打开备注弹层（Dart `:814-829`）。 */
    OPEN_NOTE,

    /** 抛 [CourseActionEvent.AddTask]（Dart `:838`）。 */
    OPEN_TASK,

    /** 打开「这节课闹钟」子弹层（Dart `:840-854` → `onSetAlarm`）。 */
    OPEN_ALARM,
}

/** 一段文字 + 是否用前景色强调（Dart `_CourseActionNoticeText` 的周次高亮）。 */
data class CourseActionTextPiece(val text: String, val emphasized: Boolean = false)

/**
 * 详情行（Dart `_CourseDetailTile`，`:963-1048`）。
 *
 * 渲染层只按这些字段画：18dp 图标 + 主标题 + 可选副标题 + 可选 trailing。
 */
data class CourseActionDetailRow(
    val kind: CourseActionRowKind,
    val icon: CourseActionIcon,
    val title: String,
    val subtitle: String? = null,
    /** 右侧文字（时间行是 `HH:mm-HH:mm`）。 */
    val trailingText: String? = null,
    /** 右侧箭头（备注 / 作业行）。 */
    val showsChevron: Boolean = false,
    val enabled: Boolean = true,
    /** 标题画成次要墨色（天气加载占位用，Dart `mutedTitle`）。 */
    val mutedTitle: Boolean = false,
    val tap: CourseActionRowTap? = null,
    /** 说明句里要用前景色高亮的 token（Dart 高亮的是周次数字）。 */
    val emphasizedToken: String? = null,
) {
    /**
     * 把 [title] 按 [emphasizedToken] 切成若干片（模型侧定好，渲染层只把
     * `emphasized = true` 的片换色）。
     *
     * 只切**第一处**命中，与 Dart `notice.indexOf(weekToken)` + `substring` 同口径；
     * 找不到 token 时原样返回一整片。
     */
    val titlePieces: List<CourseActionTextPiece>
        get() {
            val token = emphasizedToken
            if (token.isNullOrEmpty()) return listOf(CourseActionTextPiece(title))
            val index = title.indexOf(token)
            if (index < 0) return listOf(CourseActionTextPiece(title))
            val pieces = mutableListOf<CourseActionTextPiece>()
            if (index > 0) pieces += CourseActionTextPiece(title.substring(0, index))
            pieces += CourseActionTextPiece(token, emphasized = true)
            val rest = index + token.length
            if (rest < title.length) pieces += CourseActionTextPiece(title.substring(rest))
            return pieces
        }
}

/** 关联课程面板里一条的颜色语义（Dart `_previewItemColor`）。 */
enum class CourseActionEntryColor { CONFLICT, COUPLE, COURSE }

/**
 * 头部块内容（Dart `:704-757`）。
 *
 * `natureText` 为 null = 不画（对方课不显示必修/选修）；`conflictText` / `coupleText`
 * 各自独立，缺席即不画。
 */
data class CourseActionHeader(
    val icon: CourseActionIcon,
    val courseName: String,
    val natureText: String? = null,
    val conflictText: String? = null,
    val coupleText: String? = null,
    /** 第二行：`第N周 · 简介（否则周次描述）`。 */
    val detailLine: String,
)

/**
 * 一门预览课的全部内容描述（Dart `_CourseActionSheetContent.build` 的产物）。
 *
 * 除渲染需要的 [header] / [rows] / 动作开关外，还带上**关联面板与删除确认**要用的
 * 元数据，这样切换选中课、组装删除确认文案都不用再回查课程对象。
 */
data class CourseActionSection(
    val courseId: String,
    val header: CourseActionHeader,
    val rows: List<CourseActionDetailRow>,
    /** Dart `:871`：只读课整块动作区不渲染。 */
    val showActions: Boolean,
    /** 调课按钮是否可点（Dart `canReschedule = !isReadOnly && course.isInWeek(week)`）。 */
    val canReschedule: Boolean,
    /** 本周是否已停课（Dart `isSuspended`，决定按钮写「停课」还是「恢复」）。 */
    val isSuspendedThisWeek: Boolean,
    val isReadOnly: Boolean,
    // ── 关联面板 / 删除确认要用的元数据 ──
    val isConflict: Boolean,
    val coupleKind: CourseCoupleKind?,
    /** 课程色（hex，渲染层解析成 Color 并压低 alpha）。 */
    val colorHex: String,
    /** `周X · 第A-B节 · HH:mm-HH:mm`（关联课一条的排课行）。 */
    val scheduleLine: String,
    /** 地点，空串 = 不画（Dart `course.location.trim().isNotEmpty()`）。 */
    val location: String,
    /** 星期文字（`周三`），删除确认文案用。 */
    val weekdayText: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String,
    /** `第 1～16 周` 这类周次描述（Dart `course.weekDescription`）。 */
    val weekDescription: String,
    /** 删除范围里「删除这节课」是否可用（Dart `canDeleteOccurrence = course.isInWeek(week)`）。 */
    val canDeleteOccurrence: Boolean,
    /** 是否有任何一周被停过（Dart `hasAnySuspended = suspendedWeeks?.isNotEmpty ?? false`）。 */
    val hasAnySuspended: Boolean,
    // ── 这节课闹钟（Dart `_isAlarmAvailable` / `_addSystemAlarm` 要用的原始料）──
    /**
     * 生效作息下这一节的开始钟点 `HH:mm`（Dart `resolvedCourseStartTime`：
     * `sections[startSection-1].startTime`，越界 = null）。null ⇒ 闹钟入口不出现。
     */
    val alarmResolvedStart: String? = null,
    /** 这节课在本周的真实日期（学期开始日推算；没设 = null）。 */
    val alarmDate: LocalDate? = null,
    /** 入口判据的结论（[ClassAlarmPlanLogic.isAvailable]）；false ⇒ 渲染层不画这一行。 */
    val alarmAvailable: Boolean = false,
)

/** 关联面板里的一条（Dart `_RelatedCourseCompactRow`，`:375-472`）。 */
data class CourseActionRelatedEntry(
    /** 在 `previewItems` / [CourseActionSheetDetails.sections] 里的下标（切换选中课用）。 */
    val previewIndex: Int,
    val courseName: String,
    /** 角标：冲突 / 一起上课 / TA的课 / 我的课；null = 不画。 */
    val badgeText: String?,
    val scheduleLine: String,
    val location: String?,
    val switchLabel: String,
    val color: CourseActionEntryColor,
    val colorHex: String,
)

/** 关联课程折叠面板（Dart `_RelatedCoursesPanel`，`:210-345`）。 */
data class CourseActionRelatedPanel(
    val title: String,
    /** 折叠时那一行：课名预览（`A · B…`），没有课名时用展开提示。 */
    val subtitle: String,
    /** 展开后那一行：收起提示。 */
    val expandedSubtitle: String,
    val icon: CourseActionIcon,
    val accent: CourseActionEntryColor,
    val entries: List<CourseActionRelatedEntry>,
)

// ───────────────────────── 天气（壳注入的数据契约）─────────────────────────

/**
 * 天气行的四个设置开关（`app/TimetableSettingsModel.kt:121-124`）。
 *
 * 由壳按用户设置构造注入；默认值 = 设置页的出厂值。
 */
data class CourseSheetWeatherPrefs(
    val showOnSheet: Boolean = true,
    val showPhenomenon: Boolean = true,
    val showTemperature: Boolean = true,
    val showProbability: Boolean = false,
)

/**
 * 一节课的天气数据（壳注入）。
 *
 * 判据照 Dart `course_action_sheet.dart:567-602`：
 * - [date] 为 null（学期开始日没设）→ 整行不画；
 * - [summary] 为 null 且 [awaiting] 为 false → 整行不画；
 * - [awaiting] 为 true → 画「天气加载中…」占位（标题次要色），数据到了原地换内容。
 */
data class CourseSheetWeatherInfo(
    /** 该节课的日期；学期开始日未设 = null。 */
    val date: LocalDate? = null,
    /** 该节课时段内的天气摘要（`weather/WeatherLogic.kt:summarizeCourseWeather` 的产物）。 */
    val summary: CourseWeatherSummary? = null,
    /** 数据还没到 → 画占位行。 */
    val awaiting: Boolean = false,
)

// ───────────────────────── 弹层整体描述 ─────────────────────────

/**
 * 弹层的完整内容描述。
 *
 * [sections] 与传进 [CourseActionSheet] 的 `previewItems` **同序**：弹层内部切换选中课时
 * 直接按同一下标取，不需要回查课程。
 */
data class CourseActionSheetDetails(
    val sections: List<CourseActionSection> = emptyList(),
    /** 调课弹层的周次上限（Dart `settings.weekCount`）。 */
    val weekCount: Int = CourseActionSheetModel.DEFAULT_WEEK_COUNT,
    /** 调课弹层的星期标签，默认取 ARB `weekdayMon..Sun`。 */
    val weekdayLabels: List<String> = CourseActionSheetStrings.weekdayLabels,
    /** 调课弹层的节次时刻表（壳按课程解析后的节次表注入）。 */
    val sectionTimes: List<SectionTime> = emptyList(),
) {
    /** 没有任何 section = 数据没备好，弹层画个空的也不能崩。 */
    val isReady: Boolean get() = sections.isNotEmpty()

    fun sectionAt(index: Int): CourseActionSection? = sections.getOrNull(index)

    fun sectionFor(courseId: String): CourseActionSection? =
        sections.firstOrNull { it.courseId == courseId }

    /**
     * 关联课程折叠面板（Dart `_RelatedCoursesPanel` `:210-345` 的模型对位件）。
     *
     * 判据：
     * - `previewItems.length > 1` 才有面板，否则 null；
     * - `others` = 除选中项之外的全部条目（**顺序 = 预览顺序**）；
     * - `conflictCount` = others 里 `isConflict` 的条数；
     * - `coupleCount` = others 里 `coupleKind != null` 的条数；
     * - 标题：只有情侣 → `courseActionCoupleRelatedCount`；只有冲突 → `conflictCountLabel`；
     *   其余（含两者都有 / 都没有）→ `courseActionMixedRelatedCount`。
     *
     * ⚠️ **与 Dart 故意不同的一处（修的是 Dart 的 bug）**：Dart `:236` 写的是
     * `coupleCount = otherIndexes.length - conflictCount`，即「非冲突的都算情侣」。
     * 于是切到某门冲突课之后，主课（`isConflict = false`）会被算成情侣课，面板标题
     * 当场变成「还有 1 节情侣课表课程」——每次切课都说一句错话，而屏幕上根本没有情侣数据。
     * 这里按**真实语义**数（`coupleKind != null` 才算），切到冲突课后标题落回「相关课程」，
     * 不再出现「情侣课」。单测 `切到冲突课之后面板标题不再出现情侣课字样` 钉着新口径。
     */
    fun relatedPanel(selectedIndex: Int): CourseActionRelatedPanel? {
        if (sections.size <= 1) return null
        val others = sections.withIndex().filter { it.index != selectedIndex }
        if (others.isEmpty()) return null
        val conflictCount = others.count { it.value.isConflict }
        val coupleCount = others.count { it.value.coupleKind != null }
        val coupleOnly = coupleCount > 0 && conflictCount == 0
        val title = when {
            coupleOnly -> CourseActionSheetStrings.coupleRelatedCount(coupleCount)
            conflictCount > 0 && coupleCount == 0 ->
                CourseActionSheetStrings.conflictCount(conflictCount)
            else -> CourseActionSheetStrings.mixedRelatedCount(others.size)
        }
        val names = others
            .map { it.value.header.courseName.trim() }
            .filter { it.isNotEmpty() }
        val previewLine = conflictPreviewLine(names)
        return CourseActionRelatedPanel(
            title = title,
            subtitle = previewLine
                ?: if (coupleOnly) {
                    CourseActionSheetStrings.courseActionCoupleExpandHint.zh
                } else {
                    CourseActionSheetStrings.courseActionConflictExpandHint.zh
                },
            expandedSubtitle = if (coupleOnly) {
                CourseActionSheetStrings.courseActionCoupleCollapseHint.zh
            } else {
                CourseActionSheetStrings.courseActionConflictCollapseHint.zh
            },
            icon = if (coupleOnly) CourseActionIcon.COUPLE_HEART else CourseActionIcon.CONFLICT_BADGE,
            accent = if (coupleOnly) CourseActionEntryColor.COUPLE else CourseActionEntryColor.CONFLICT,
            entries = others.map { (index, section) ->
                CourseActionRelatedEntry(
                    previewIndex = index,
                    courseName = section.header.courseName,
                    badgeText = if (section.isConflict) {
                        CourseActionSheetStrings.conflictLabel.zh
                    } else {
                        CourseActionSheetModel.coupleLabel(section.coupleKind)
                    },
                    scheduleLine = section.scheduleLine,
                    location = section.location.takeIf { it.isNotEmpty() },
                    switchLabel = CourseActionSheetStrings.courseActionConflictSwitchAction.zh,
                    color = when {
                        section.coupleKind != null -> CourseActionEntryColor.COUPLE
                        section.isConflict -> CourseActionEntryColor.CONFLICT
                        else -> CourseActionEntryColor.COURSE
                    },
                    colorHex = section.colorHex,
                )
            },
        )
    }

    companion object {
        /**
         * 课名预览（Dart `_conflictPreviewLine`，`:362-373`）：1 条直出，2 条用 ` · ` 连，
         * 3 条以上只显示前两条 + `…`。
         *
         * 分隔符是 Dart 里硬写的 `' · '`（没有对应 ARB 键，不是句子），原样保留。
         */
        fun conflictPreviewLine(names: List<String>): String? = when {
            names.isEmpty() -> null
            names.size == 1 -> names.first()
            names.size == 2 -> "${names[0]}$PREVIEW_NAME_SEPARATOR${names[1]}"
            else -> "${names[0]}$PREVIEW_NAME_SEPARATOR${names[1]}…"
        }

        /** 关联预览课名的连接符（Dart `_conflictPreviewLine` 里硬写的 `' · '`）。 */
        const val PREVIEW_NAME_SEPARATOR: String = " · "
    }
}

// ───────────────────────── 模型构建 ─────────────────────────

/**
 * 把数据算成 [CourseActionSheetDetails] 的纯函数集合。**无副作用、无平台依赖**。
 *
 * 调用方（壳）负责提供三样外部数据：
 * 1. [build] 的 `tasks`：作业仓储里与该课关联的条目（`repository.tasks`）；
 * 2. `dateOf`：`repository.dateForCourseOccurrence(course, week)`；
 * 3. `weatherOf`：`WeatherProvider.summaryForCourse(date, start, end)` 的包装。
 */
object CourseActionSheetModel {

    /** 默认周次上限（Dart `TimetableSettings.weekCount` 的出厂值 16）。 */
    const val DEFAULT_WEEK_COUNT: Int = 16

    /**
     * 点课卡那一刻的预览条目（Dart `buildTimetableCourseActionPreviewItems` 的**冲突课那一半**，
     * `lib/widgets/timetable/timetable_course_action_items.dart:22-113` + `:184-203`）。
     *
     * 第 0 条恒为 [primary] 本身；其余是**同周**冲突课，口径逐条照 Dart：
     * 1. 冲突索引取整周口径的 `CourseDomain.buildConflictMap(courses, week = week)`；
     * 2. 去掉自己（`id == primary.id`）与重复 id（Dart `seenIds`）；
     * 3. 排序：`dayOfWeek` → `startSection` → `id`（Dart `:194-201`）。
     *
     * ## 情侣课为什么先不产出
     *
     * Dart 的另外两半（`coupleKind` / `isPartnerCourse`）依赖**情侣叠加层**：
     * `partnerCourses` + `partnerWeekOffset` + `CoupleTimetableLogic`。
     * Compose 周视图目前没有这一层（audit §五），弹层不伪造数据。
     * 所以这里对 [coupleOverlayActive] 取 `require` 而不是静默返回半成品 ——
     * 真要接的时候必须实现 together / partner / mine 三个分支，不能被一个默认 false 蒙过去。
     *
     * @param courses 当前课表快照（`snapshot.courses`）。
     * @param primary 被点的那门课。
     * @param week 当前浏览周次（冲突判据按这一周算）。
     * @param partnerCourses 对方课表（本轮恒空）。
     * @param coupleOverlayActive 情侣覆盖层是否开启（本轮恒 false）。
     */
    fun buildPreviewItems(
        courses: List<Course>,
        primary: Course,
        week: Int,
        partnerCourses: List<Course> = emptyList(),
        coupleOverlayActive: Boolean = false,
    ): List<CourseActionPreviewItem> {
        require(!coupleOverlayActive) {
            "couple overlay preview items are not implemented yet " +
                "(partnerCourses=${partnerCourses.size}, week=$week)"
        }
        val items = mutableListOf(CourseActionPreviewItem(course = primary))
        // 主课理论上就在快照里；万一是「刚加进来还没进列表」的实例，也得能算出冲突
        // （`buildConflictMap` 只在传入的列表里两两判，主课缺席就一条冲突都拿不到）。
        val pool = if (courses.any { it.id == primary.id }) courses else courses + primary
        val conflictMap = CourseDomain.buildConflictMap(pool, week = week)
        val seenIds = mutableSetOf(primary.id)
        val conflicts = (conflictMap[primary.id] ?: emptyList())
            .filter { it.id != primary.id && seenIds.add(it.id) }
            .sortedWith(
                compareBy({ it.dayOfWeek }, { it.startSection }, { it.id }),
            )
        conflicts.forEach { items += CourseActionPreviewItem(course = it, isConflict = true) }
        return items
    }

    /**
     * 构建整份描述。
     *
     * @param previewItems 预览条目，第 0 条是主课（与传给 [CourseActionSheet] 的同一个列表）。
     * @param week 当前浏览周次（occurrence 级判据全用它）。
     * @param tasks 作业仓储快照；只读第一条 `sourceWeek == null || == week` 的。
     * @param weatherPrefs 天气四开关。
     * @param dateOf 该课在 [week] 的日期；学期开始日没设时返回 null。
     * @param weatherOf 该课的天气（含日期与等待标记）。
     * @param weekdayLabels 星期标签（默认 ARB）。
     * @param weekCount 调课弹层的周次上限。
     * @param sectionTimes 调课弹层的节次时刻表。
     */
    fun build(
        previewItems: List<CourseActionPreviewItem>,
        week: Int,
        tasks: List<CourseTask> = emptyList(),
        weatherPrefs: CourseSheetWeatherPrefs = CourseSheetWeatherPrefs(),
        dateOf: (Course) -> LocalDate? = { null },
        weatherOf: (Course) -> CourseSheetWeatherInfo = { CourseSheetWeatherInfo() },
        weekdayLabels: List<String> = CourseActionSheetStrings.weekdayLabels,
        weekCount: Int = DEFAULT_WEEK_COUNT,
        sectionTimes: List<SectionTime> = emptyList(),
        now: LocalDateTime = LocalDateTime.now(),
    ): CourseActionSheetDetails = CourseActionSheetDetails(
        sections = previewItems.map { item ->
            buildSection(
                item = item,
                week = week,
                tasks = tasks,
                weatherPrefs = weatherPrefs,
                dateOf = dateOf,
                weatherOf = weatherOf,
                weekdayLabels = weekdayLabels,
                sectionTimes = sectionTimes,
                now = now,
            )
        },
        weekCount = weekCount,
        weekdayLabels = weekdayLabels,
        sectionTimes = sectionTimes,
    )

    /** 单条预览课的内容描述（[build] 的逐条实现，可单独测）。 */
    fun buildSection(
        item: CourseActionPreviewItem,
        week: Int,
        tasks: List<CourseTask> = emptyList(),
        weatherPrefs: CourseSheetWeatherPrefs = CourseSheetWeatherPrefs(),
        dateOf: (Course) -> LocalDate? = { null },
        weatherOf: (Course) -> CourseSheetWeatherInfo = { CourseSheetWeatherInfo() },
        weekdayLabels: List<String> = CourseActionSheetStrings.weekdayLabels,
        sectionTimes: List<SectionTime> = emptyList(),
        now: LocalDateTime = LocalDateTime.now(),
    ): CourseActionSection {
        val course = item.course
        val teacher = course.teacher.trim()
        val location = course.location.trim()
        val description = course.description?.trim().orEmpty()
        val legacyNote = course.note?.trim().orEmpty()
        // Dart `:633-638`：课程简介（description）优先，回落 legacy note。
        val introText = when {
            description.isNotEmpty() -> description
            legacyNote.isNotEmpty() -> legacyNote
            else -> null
        }
        val sessionNoteText = course.sessionNoteForWeek(week)
            ?.trimmedText
            ?.takeIf { it.isNotEmpty() }
        val weekDescription = CourseActionSheetStrings.weekDescription(course)
        val weekdayText = weekdayLabelOf(weekdayLabels, course.dayOfWeek)
        val sectionLine = "$weekdayText · ${CourseActionSheetStrings.sectionRange(course.startSection, course.endSection)}"
        val shortName = course.shortName?.trim().orEmpty()

        // ── C7 这节课闹钟的原始料（Dart `resolvedCourseStartTime` + `_isAlarmAvailable`）──
        // 生效作息表 = 调课弹层用的同一份（壳按主课解析；冲突课同作息的已知差异
        // 与调课弹层共有一条诚实清单）。
        val alarmResolvedStart = sectionTimes.getOrNull(course.startSection - 1)?.startTime
        val alarmDate = dateOf(course)
        val alarmAvailable = !item.isReadOnly && ClassAlarmPlanLogic.isAvailable(
            courseDate = alarmDate,
            startMinutes = alarmResolvedStart?.let { ClassAlarmPlanLogic.parseClockMinutes(it) },
            now = now,
        )

        val natureText = when {
            // Dart `:732`：对方课不显示性质。
            item.isPartnerCourse -> null
            course.courseNature == CourseNature.ELECTIVE -> CourseActionSheetStrings.courseNatureElective.zh
            else -> CourseActionSheetStrings.courseNatureRequired.zh
        }
        val headerIcon = when {
            item.coupleKind == CourseCoupleKind.TOGETHER -> CourseActionIcon.COUPLE_HEART
            item.isPartnerCourse -> CourseActionIcon.PARTNER_PERSON
            else -> CourseActionIcon.COURSE
        }
        val header = CourseActionHeader(
            icon = headerIcon,
            courseName = course.name,
            natureText = natureText,
            conflictText = if (item.isConflict) CourseActionSheetStrings.conflictLabel.zh else null,
            // Dart 这里复用 `_previewItemBadgeLabel`，对冲突课会把「冲突」再画一遍
            // （一次红字、一次课程色）。那是重复，不是设计：这里只留情侣角标。
            coupleText = coupleLabel(item.coupleKind),
            detailLine = "${CourseActionSheetStrings.weekLabel(week)} · ${introText ?: weekDescription}",
        )

        val rows = mutableListOf<CourseActionDetailRow>()
        // C1 时间行（Dart `:759-764`）
        rows += CourseActionDetailRow(
            kind = CourseActionRowKind.TIME,
            icon = CourseActionIcon.TIME,
            title = sectionLine,
            subtitle = timeTileSubtitle(course, week, dateOf(course)),
            trailingText = "${course.startTime}-${course.endTime}",
        )
        // C2 教师行（Dart `:766-770`）
        rows += CourseActionDetailRow(
            kind = CourseActionRowKind.TEACHER,
            icon = CourseActionIcon.TEACHER,
            title = teacher.ifEmpty { com.mutx163.qingyu.app.CourseActionStrings.unknownTeacher.zh },
            subtitle = when {
                introText != null -> weekDescription
                shortName.isNotEmpty() -> CourseActionSheetStrings.shortName(shortName)
                else -> weekDescription
            },
        )
        // C3 地点行（Dart `:772-776`）
        rows += CourseActionDetailRow(
            kind = CourseActionRowKind.LOCATION,
            icon = CourseActionIcon.LOCATION,
            title = location.ifEmpty { com.mutx163.qingyu.app.CourseActionStrings.unknownLocation.zh },
            subtitle = if (shortName.isNotEmpty() && introText != null) {
                CourseActionSheetStrings.shortName(shortName)
            } else {
                weekDescription
            },
        )
        // C4 天气行（Dart `:777-795`）
        buildWeatherRow(
            item = item,
            week = week,
            weatherPrefs = weatherPrefs,
            weather = weatherOf(course),
        )?.let { rows += it }

        // C5 备注行（Dart `:797-830`）
        rows += CourseActionDetailRow(
            kind = CourseActionRowKind.NOTE,
            icon = CourseActionIcon.NOTE,
            title = resolveNoteTitle(introText, sessionNoteText),
            subtitle = resolveNoteSubtitle(introText, sessionNoteText),
            showsChevron = true,
            tap = CourseActionRowTap.OPEN_NOTE,
        )

        if (!item.isReadOnly) {
            // C6 作业行（Dart `:831-839`）
            val linkedTask = tasks.firstOrNull {
                it.courseId == course.id && (it.sourceWeek == null || it.sourceWeek == week.toLong())
            }
            val taskTitle = when {
                linkedTask == null -> CourseActionSheetStrings.taskAddFromCourse.zh
                linkedTask.title.trim().isEmpty() -> CourseActionSheetStrings.taskHomeworkDefaultTitle.zh
                else -> linkedTask.title.trim()
            }
            val taskSubtitle = when {
                linkedTask == null -> CourseActionSheetStrings.taskListTitle.zh
                linkedTask.isCompleted -> CourseActionSheetStrings.taskCompletedSection.zh
                else -> CourseActionSheetStrings.taskListTitle.zh
            }
            rows += CourseActionDetailRow(
                kind = CourseActionRowKind.TASK,
                icon = CourseActionIcon.TASK,
                title = taskTitle,
                subtitle = taskSubtitle,
                showsChevron = true,
                tap = CourseActionRowTap.OPEN_TASK,
            )
            // C7 这节课闹钟（Dart `:840-854`）：只在 `alarmAvailable` 时出现——
            // 入口判据见 [ClassAlarmPlanLogic.isAvailable]（未来课可设、当天开课前可设、
            // 过去课 / 没开学日 / 解析不出钟点不出现）。写入走系统时钟
            //（`AlarmClock.ACTION_SET_ALARM`），不是应用内调度器。
            if (alarmAvailable) {
                rows += CourseActionDetailRow(
                    kind = CourseActionRowKind.ALARM,
                    icon = CourseActionIcon.ALARM,
                    title = com.mutx163.qingyu.app.CourseActionStrings.classAlarmActionLabel.zh,
                    showsChevron = true,
                    tap = CourseActionRowTap.OPEN_ALARM,
                )
            }
        }

        // C8 说明行（Dart `:856-870`）
        rows += if (item.isReadOnly) {
            CourseActionDetailRow(
                kind = CourseActionRowKind.NOTICE,
                icon = CourseActionIcon.INFO,
                title = com.mutx163.qingyu.app.CourseActionStrings.courseActionPartnerReadOnlyNotice.zh,
            )
        } else {
            CourseActionDetailRow(
                kind = CourseActionRowKind.NOTICE,
                icon = CourseActionIcon.INFO,
                title = com.mutx163.qingyu.app.CourseActionStrings.notice(week),
                emphasizedToken = week.toString(),
            )
        }

        return CourseActionSection(
            courseId = course.id,
            header = header,
            rows = rows,
            showActions = !item.isReadOnly,
            canReschedule = !item.isReadOnly && course.isInWeek(week),
            isSuspendedThisWeek = course.isSuspendedInWeek(week),
            isReadOnly = item.isReadOnly,
            isConflict = item.isConflict,
            coupleKind = item.coupleKind,
            colorHex = course.color,
            scheduleLine = "$sectionLine · ${course.startTime}-${course.endTime}",
            location = location,
            weekdayText = weekdayText,
            dayOfWeek = course.dayOfWeek,
            startSection = course.startSection,
            endSection = course.endSection,
            startTime = course.startTime,
            endTime = course.endTime,
            weekDescription = weekDescription,
            canDeleteOccurrence = course.isInWeek(week),
            hasAnySuspended = !course.suspendedWeeks.isNullOrEmpty(),
            alarmResolvedStart = alarmResolvedStart,
            alarmDate = alarmDate,
            alarmAvailable = alarmAvailable,
        )
    }

    /**
     * 时间行副题（Dart `_formatTimeTileSubtitle`，`:1086-1109`）：
     * `10月29日 第 9 周 单周`——日期缺席（学期开始日没设）时从「第 N 周」开始。
     */
    fun timeTileSubtitle(course: Course, week: Int, date: LocalDate?): String {
        val parts = mutableListOf<String>()
        if (date != null) parts += CourseActionSheetStrings.dateLabel(date.monthValue, date.dayOfMonth)
        parts += CourseActionSheetStrings.weekLabel(week)
        when {
            course.isOddWeek -> parts += CourseActionSheetStrings.courseActionOddWeekShort.zh
            course.isEvenWeek -> parts += CourseActionSheetStrings.courseActionEvenWeekShort.zh
        }
        return parts.joinToString(" ")
    }

    /**
     * 备注行标题（Dart `_resolveNoteTileTitle`，`:928-940`）：本周备注 → 课程简介 → 「备注」。
     */
    fun resolveNoteTitle(introText: String?, sessionNoteText: String?): String = when {
        !sessionNoteText.isNullOrEmpty() -> sessionNoteText
        !introText.isNullOrEmpty() -> introText
        else -> CourseActionSheetStrings.courseNoteAction.zh
    }

    /**
     * 备注行副题（Dart `_resolveNoteTileSubtitle`，`:942-961`）四态：
     * 都有 / 只有本节 / 只有简介 / 都没有。
     */
    fun resolveNoteSubtitle(introText: String?, sessionNoteText: String?): String {
        val hasSession = !sessionNoteText.isNullOrEmpty()
        val hasWhole = !introText.isNullOrEmpty()
        return when {
            hasSession && hasWhole -> CourseActionSheetStrings.courseNoteTileSubtitleBoth.zh
            hasSession -> CourseActionSheetStrings.courseNoteTileSubtitleSession.zh
            hasWhole -> CourseActionSheetStrings.courseNoteTileSubtitleWhole.zh
            else -> CourseActionSheetStrings.courseNoteTileSubtitleEmpty.zh
        }
    }

    /**
     * 天气行（Dart `_weatherDisplay`，`:567-602`）。
     *
     * 四种「整行不出现」：开关关掉 / 对方课 / 这一周不上这门课 / 没有日期。
     * 有摘要 → 按三项开关画一句话；摘要还没到但 `awaiting` → 画占位。
     */
    fun buildWeatherRow(
        item: CourseActionPreviewItem,
        week: Int,
        weatherPrefs: CourseSheetWeatherPrefs,
        weather: CourseSheetWeatherInfo,
    ): CourseActionDetailRow? {
        if (!weatherPrefs.showOnSheet) return null
        if (item.isPartnerCourse) return null
        if (!item.course.isActiveInWeek(week)) return null
        if (weather.date == null) return null
        val plan = planWeatherLine(
            summary = weather.summary,
            showPhenomenon = weatherPrefs.showPhenomenon,
            showTemperature = weatherPrefs.showTemperature,
            showProbability = weatherPrefs.showProbability,
        )
        if (plan != null) {
            return CourseActionDetailRow(
                kind = CourseActionRowKind.WEATHER,
                icon = CourseActionIcon.WEATHER,
                title = CourseActionSheetStrings.weatherLineText(plan),
                subtitle = CourseActionSheetStrings.weatherCourseTileSubtitle.zh,
            )
        }
        if (!weather.awaiting) return null
        return CourseActionDetailRow(
            kind = CourseActionRowKind.WEATHER,
            icon = CourseActionIcon.WEATHER,
            title = CourseActionSheetStrings.weatherLoadingPlaceholder.zh,
            subtitle = CourseActionSheetStrings.weatherCourseTileSubtitle.zh,
            mutedTitle = true,
        )
    }

    // ── 删除确认文案（`CourseDeleteConfirmSheet` 的 title / message 由本泳道组装）──

    /** 「删除整门课」确认的标题（Dart `l10n.deleteScheduleTitle`）。 */
    fun deleteWholeCourseTitle(): String = CourseActionSheetStrings.deleteScheduleTitle.zh

    /** 「删除整门课」确认的正文（Dart `_confirmDeleteCourse` 的 `deleteScheduleConfirmMessage`）。 */
    fun deleteWholeCourseMessage(section: CourseActionSection): String =
        CourseActionSheetStrings.deleteScheduleConfirmMessage.filled(
            "name" to section.header.courseName,
            "detail" to CourseActionSheetStrings.courseWeekdaySectionSummary.filled(
                "weekDescription" to section.weekDescription,
                "weekday" to section.weekdayText,
                "startSection" to section.startSection.toString(),
                "endSection" to section.endSection.toString(),
            ),
        )

    /** 「删除本周这节课」确认的标题（Dart `l10n.deleteLessonTitle`）。 */
    fun deleteOccurrenceTitle(): String = CourseActionSheetStrings.deleteLessonTitle.zh

    /** 「删除本周这节课」确认的正文（Dart `_confirmDeleteOccurrence` 的 `deleteOccurrenceConfirmMessage`）。 */
    fun deleteOccurrenceMessage(section: CourseActionSection, week: Int): String =
        CourseActionSheetStrings.deleteOccurrenceConfirmMessage.filled(
            "name" to section.header.courseName,
            "week" to week.toString(),
            "detail" to CourseActionSheetStrings.weekdaySectionTimeSummary.filled(
                "weekday" to section.weekdayText,
                "startSection" to section.startSection.toString(),
                "endSection" to section.endSection.toString(),
                "startTime" to section.startTime,
                "endTime" to section.endTime,
            ),
        )

    /** 星期文字；越界退化成数字（与 Dart `_weekdayLabel` 同口径）。 */
    fun weekdayLabelOf(labels: List<String>, dayOfWeek: Int): String =
        labels.getOrNull(dayOfWeek - 1) ?: dayOfWeek.toString()

    /** 情侣课角标文字（Dart `_previewItemBadgeLabel` 去掉冲突那一支）。 */
    fun coupleLabel(kind: CourseCoupleKind?): String? = when (kind) {
        CourseCoupleKind.TOGETHER -> CourseActionSheetStrings.coupleTimetableLegendTogether.zh
        CourseCoupleKind.PARTNER -> CourseActionSheetStrings.coupleTimetableLegendPartner.zh
        CourseCoupleKind.MINE -> CourseActionSheetStrings.coupleTimetableLegendMine.zh
        null -> null
    }

    /**
     * 事件工厂。**每一个都从「当前选中的那条 section」取 `courseId`**。
     *
     * 弹层内部允许切到冲突课，如果渲染层拿 `details.sections.first()` 或最初点开的
     * 那门课去发事件，用户切课后再点删除/编辑就会对**错误的课**写库。
     * 把「取哪个 id」收到这里，单测就能直接钉住
     * 「切到第 2 条之后，事件里是第 2 条的 id」（[CourseActionSheetModelTest]）。
     */
    object Events {
        fun edit(section: CourseActionSection): CourseActionEvent =
            CourseActionEvent.Edit(section.courseId)

        fun addTask(section: CourseActionSection): CourseActionEvent =
            CourseActionEvent.AddTask(section.courseId)

        fun delete(section: CourseActionSection, scope: CourseDeleteScope): CourseActionEvent =
            CourseActionEvent.Delete(section.courseId, scope)

        fun suspend(section: CourseActionSection, scope: CourseSuspendScope): CourseActionEvent =
            CourseActionEvent.Suspend(section.courseId, scope)

        fun reschedule(section: CourseActionSection, target: CourseRescheduleTarget): CourseActionEvent =
            CourseActionEvent.Reschedule(section.courseId, target)

        fun saveNotes(
            section: CourseActionSection,
            wholeNote: String?,
            sessionNote: String?,
        ): CourseActionEvent = CourseActionEvent.SaveNotes(
            courseId = section.courseId,
            wholeNote = wholeNote,
            sessionNote = sessionNote,
        )
    }
}
