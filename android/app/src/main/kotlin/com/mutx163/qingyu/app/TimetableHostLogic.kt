package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.course.TimetableCoursePort
import com.mutx163.qingyu.course.TimetableCourseService
import com.mutx163.qingyu.pages.timetable.WeekCardHorizontalAlign
import com.mutx163.qingyu.pages.timetable.WeekCardSurface
import com.mutx163.qingyu.pages.timetable.WeekCardVerticalAlign
import com.mutx163.qingyu.pages.timetable.WeekSectionTimeMode
import com.mutx163.qingyu.pages.timetable.WeekViewStyle

/**
 * 课表宿主的显示偏好。
 *
 * ## 值的来源（2026-10-28 S1 起）：**用户存档**
 *
 * 这四个值的真实来源是完整设置模型 [TimetableSettingsModel]，用
 * [fromSettings] 从存档推导出来；壳接线层只需把 `settingsModel.load()` 交给
 * `TimetableHost`，**不再传「假默认」**。
 *
 * 本类型保留两个用途：
 * 1. **注入点**——测试或将来要覆盖时可以直接给一份（`TimetableHost(display = …)`）；
 * 2. 把「渲染层要的四个值」与「设置模型那 75 个键」解耦，渲染层不用认识设置模型。
 *
 * ⚠️ 历史：S1 之前这里写的是「`core.TimetableSettings` 没有这四个键，所以只能由壳注入」
 * （task-8 的临时做法，注释里留了「待办：设置族并入时对齐」）。设置族并入后该待办已消。
 *
 * 默认值全部取 **Dart 默认**，不取渲染层签名默认：Dart `sectionHeight` 默认 68
 * （`models/timetable_settings.dart:754`），而 `TimetableWeekPage` 的签名默认是 64
 * ——后者只是「没人传时的占位」，不是产品默认值。
 *
 * 放在纯 Kotlin 侧（而不是 Compose 文件里）是为了让这些默认值能被 JVM 测试钉住；
 * 渲染层只负责把 [sectionHeightDp] 包成 `Dp`。
 */
data class TimetableHostDisplayPrefs(
    val hideWeekends: Boolean = false,
    val wideTimeColumn: Boolean = false,
    val sectionHeightDp: Float = TimetableHostLogic.DEFAULT_SECTION_HEIGHT_DP,
    val longPressEmptySlotToAddCourseEnabled: Boolean = false,
) {
    companion object {

        /**
         * 从**用户存档**（完整设置模型）推导宿主显示偏好（S1）。
         *
         * 四个键的类型与缺省**逐条去 Dart 核过**（`lib/models/timetable_settings.dart`）：
         *
         * | 本字段 | 设置模型的键 | Dart 类型 / 构造默认 | Dart 读侧缺省 | 行号 |
         * |---|---|---|---|---|
         * | [hideWeekends] | `timetableHideWeekends` | `bool` / `false` | `lenientBool(...) ?? false` | `:819` / `:1531` |
         * | [wideTimeColumn] | `timetableTimeColumnWidthMode` | 枚举 `narrow`/`wide` / 见下 | `fromValue(...)`，**未知值回落 `narrow`** | `:1433` + `extensions.dart:387-399` |
         * | [sectionHeightDp] | `sectionHeight` | `double` / `68` | `lenientDouble(...) ?? 68` | `:754` / `:1385` |
         * | [longPressEmptySlotToAddCourseEnabled] | `longPressEmptySlotToAddCourseEnabled` | `bool` / `false` | `lenientBool(...) ?? false` | `:824` / `:1541` |
         *
         * **「读侧缺省」与「构造默认」这四个键是一致的**（本仓有过三个反例：主题种子色
         * `#2563EB` vs `#3482FF`、`timetableCourseCardGap` 按另一个键推导、
         * `SectionTimeDisplayMode` 未知值回落不是第一项——所以这里逐条核了，没有照抄直觉）。
         *
         * 唯一一处 `sectionHeight` 的 clamp 在 `lib/widgets/timetable_export_document.dart:137`
         * （导出文档专用），**课表视图侧没有 clamp** ⇒ 这里原样透传，不做归一。
         */
        fun fromSettings(model: TimetableSettingsModel): TimetableHostDisplayPrefs =
            TimetableHostDisplayPrefs(
                hideWeekends = model.timetableHideWeekends,
                wideTimeColumn =
                    model.timetableTimeColumnWidthMode == TimetableTimeColumnWidthMode.WIDE,
                sectionHeightDp = model.sectionHeight.toFloat(),
                longPressEmptySlotToAddCourseEnabled =
                    model.longPressEmptySlotToAddCourseEnabled,
            )
    }
}

/**
 * Phase 3.5 · L4 宿主层的**纯逻辑**（无 `android.*`、无 Compose）。
 *
 * 为什么单独放这里：`scripts/test-kotlin-module.ps1` 的「纯 Kotlin」判定是**整目录**的
 * ——`app/` 里只要出现一个 `import android.*`，整个目录会被静默跳过，全队 JVM 测试立刻
 * Unresolved。宿主层真正碰 Android / Compose 的部分在
 * `composeP1/.../app/TimetableHost.kt`，本文件只放能在 JVM 上断言的部分。
 *
 * 每条判据都能在 Dart 侧找到出处（见各函数注释），**期望值是人推的**，不从实现抄。
 */
object TimetableHostLogic {

    /** 首次启动兜底档案名（`storage_service.dart:1645` 的 `name: '默认课表'`）。 */
    const val DEFAULT_PROFILE_NAME = "默认课表"

    /** 时间列窄档宽度（`domain/timetable_layout.dart:12-17`）。 */
    const val NARROW_TIME_COLUMN_WIDTH_DP = 34f

    /** 时间列宽档宽度（同上）。 */
    const val WIDE_TIME_COLUMN_WIDTH_DP = 40f

    /** 节次行高默认值（`models/timetable_settings.dart:754` 的 `sectionHeight = 68`）。 */
    const val DEFAULT_SECTION_HEIGHT_DP = 68f

    /**
     * 可见星期几（Dart `visibleDayNumbers`，`domain/timetable_layout.dart:6-10`）：
     * 隐藏周末 → 周一到周五；否则周一到周日。
     *
     * 期望值：`false` → `[1,2,3,4,5,6,7]`；`true` → `[1,2,3,4,5]`。
     */
    fun visibleDayNumbers(hideWeekends: Boolean): List<Int> =
        if (hideWeekends) listOf(1, 2, 3, 4, 5) else listOf(1, 2, 3, 4, 5, 6, 7)

    /**
     * 时间列宽度（Dart `timeColumnWidth`，`domain/timetable_layout.dart:12-17`）：
     * 宽档 40、窄档 34。**单位是 dp 的数值**，Dp 包装留给渲染层（本文件不许 import Compose）。
     */
    fun timeColumnWidthDp(wide: Boolean): Float =
        if (wide) WIDE_TIME_COLUMN_WIDTH_DP else NARROW_TIME_COLUMN_WIDTH_DP

    /**
     * 空档加课是否放行（Dart `timetable_empty_slot_layer.dart:46`：
     * `if (!settings.longPressEmptySlotToAddCourseEnabled || span <= 0)` 就整个隐藏标记格）。
     *
     * 两个条件都要成立才允许：开关打开**且**这一格真有可用跨度。
     * 期望值（手推）：
     * - `(enabled=true,  span=1)`  -> true（开关开着、单格跨度 1）
     * - `(enabled=true,  span=0)`  -> false（没有可落课的空档，开关开着也不放行）
     * - `(enabled=false, span=1)`  -> false（开关关着）
     * - `(enabled=false, span=0)`  -> false
     * - `(enabled=true,  span=-1)` -> false（负跨度同样不算空档）
     */
    fun shouldAllowEmptySlotAdd(longPressToAddCourseEnabled: Boolean, span: Int): Boolean =
        longPressToAddCourseEnabled && span > 0

    /**
     * 顶部标题显示的档案名。
     *
     * 口径（人推）：
     * 1. `activeProfileId` 命中某档 → 用该档的 `name`；名字是空白 → [TimetableProfile.UNNAMED]
     *    （Dart `timetable_profile.dart` 的解析兜底名「未命名课表」）；
     * 2. 没命中（id 为 null 或指向不存在的档）→ 退到**第一份**档，同样按空白兜底；
     * 3. 一份档都没有 → [DEFAULT_PROFILE_NAME]（首启种子档名，`storage_service.dart:1645`）。
     */
    fun resolveProfileName(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
    ): String {
        val active = profiles.firstOrNull { it.id == activeProfileId } ?: profiles.firstOrNull()
        if (active == null) return DEFAULT_PROFILE_NAME
        return active.name.takeIf { it.isNotBlank() } ?: TimetableProfile.UNNAMED
    }

    /**
     * 生效的作息模板（Dart 侧 `settings.activeTimeSchemeId` 的路由口径）：
     * 命中 [activeTimeSchemeId] 用它；id 为 null 或指向不存在的档 → 退到第一份；
     * 一份都没有 → `null`（此时页面自己回落到 `settings.sections`，
     * 见 `TimetableWeekPage.kt:126-127`，宿主不要自己造节次表）。
     */
    fun resolveActiveTimeScheme(
        schemes: List<TimeScheme>,
        activeTimeSchemeId: String?,
    ): TimeScheme? =
        schemes.firstOrNull { it.id == activeTimeSchemeId } ?: schemes.firstOrNull()

    /**
     * 从**用户存档**推导周视图渲染风格（设置 → 渲染层的唯一映射点）。
     *
     * 未映射前，渲染层自造了一套值：卡面字段全开、字号 13sp（`footnote2`）、
     * 星期标签「一/二」、今天用蓝胶囊……设置里改哪一项都没反应。这里逐键对上：
     *
     * | 设置键（`lib/models/timetable_settings.dart`） | 本函数去处 |
     * |---|---|
     * | `courseCardShowName/Teacher/Location/Time/TimeLabels/Weeks/Description` | 同名字段 |
     * | `courseCardFontSize`（默认 9）/ `compactFontSize`（9） | `cardTitleFontSize` / `compactFontSize` |
     * | `courseCardVerticalAlign` / `HorizontalAlign` | 同名枚举（页面本地枚举） |
     * | `courseCardSurfaceStyle`：`solid`/`gaussian`/`refraction` | `SOLID`/`GAUSSIAN`/`TRANSLUCENT`（无壁纸时折射档在 Dart 也退化成半透明） |
     * | `timetableUseUnifiedCardColor` + `timetableUnifiedCardColor` | `unifiedCardColorHex`（未开 = null） |
     * | `showConflictBadgeOnTimetable` / `timetableConflictCourseOpacity` | `showConflictBadge` / `conflictCourseOpacity` |
     * | `timetableSectionTimeDisplayMode` | `sectionTimeMode`（**未知值回落 `startAndEnd`**，不是第一项） |
     * | `sectionHeight` / `timetableAutoFitSectionHeight` | `sectionHeightDp` / `autoFitSectionHeight` |
     * | `timetableTimeColumnWidthMode` | `timeColumnWidthDp`（宽 40 / 窄 34） |
     * | `timetableCourseCardGap`（默认 1.25，clamp 0..3） | `cardInsetDp`（Dart `courseCardInset`） |
     * | `timetableShowNonCurrentWeekCourses` / `weekGridShowExams` / `weekGridShowSchedules` | 同名字段 |
     * | `longPressEmptySlotToAddCourseEnabled` / `enableHolidayMarking` | 同名字段 |
     * | `weekdayBarFontColor*` / `weekdayBarAccentColor*` / `timeAxisFontColor*` | 同名字段 |
     * | `courseCardTitleColor*` / `courseCardDetailColor*` | 同名字段 |
     * | `timetableBackToCurrentWeekButtonStyle` | `showBackToCurrentWeek`（读侧恒 `floating`，见枚举 KDoc） |
     * | `timetableFloatingBackToCurrentWeekButtonOpacity` | `backToCurrentWeekOpacity` |
     * | `weatherShowOnWeekCard` | `showWeatherOnCard`（本批未接线，仅保留口径） |
     */
    fun weekViewStyle(model: TimetableSettingsModel): WeekViewStyle = WeekViewStyle(
        showName = model.courseCardShowName,
        showTeacher = model.courseCardShowTeacher,
        showLocation = model.courseCardShowLocation,
        showTime = model.courseCardShowTime,
        showTimeLabels = model.courseCardShowTimeLabels,
        showWeeks = model.courseCardShowWeeks,
        showDescription = model.courseCardShowDescription,
        cardTitleFontSize = model.courseCardFontSize.toFloat(),
        compactFontSize = model.compactFontSize.toFloat(),
        verticalAlign = when (model.courseCardVerticalAlign) {
            CourseCardVerticalAlign.TOP -> WeekCardVerticalAlign.TOP
            CourseCardVerticalAlign.CENTER -> WeekCardVerticalAlign.CENTER
            CourseCardVerticalAlign.BOTTOM -> WeekCardVerticalAlign.BOTTOM
            CourseCardVerticalAlign.SPACE_EVENLY -> WeekCardVerticalAlign.SPACE_EVENLY
        },
        horizontalAlign = when (model.courseCardHorizontalAlign) {
            CourseCardHorizontalAlign.LEFT -> WeekCardHorizontalAlign.LEFT
            CourseCardHorizontalAlign.CENTER -> WeekCardHorizontalAlign.CENTER
            CourseCardHorizontalAlign.RIGHT -> WeekCardHorizontalAlign.RIGHT
        },
        surfaceStyle = when (model.courseCardSurfaceStyle) {
            CourseCardSurfaceStyle.SOLID -> WeekCardSurface.SOLID
            CourseCardSurfaceStyle.GAUSSIAN -> WeekCardSurface.GAUSSIAN
            // 无壁纸/无模糊管线时 Dart 的折射档同样退化成半透明实体。
            CourseCardSurfaceStyle.LIQUID_GLASS -> WeekCardSurface.TRANSLUCENT
        },
        unifiedCardColorHex =
            if (model.timetableUseUnifiedCardColor) model.timetableUnifiedCardColor else null,
        cardTitleColorLight = model.courseCardTitleColorLight,
        cardTitleColorDark = model.courseCardTitleColorDark,
        cardDetailColorLight = model.courseCardDetailColorLight,
        cardDetailColorDark = model.courseCardDetailColorDark,
        showConflictBadge = model.showConflictBadgeOnTimetable,
        conflictCourseOpacity = model.timetableConflictCourseOpacity.toFloat(),
        sectionTimeMode = when (model.timetableSectionTimeDisplayMode) {
            SectionTimeDisplayMode.HIDDEN -> WeekSectionTimeMode.HIDDEN
            SectionTimeDisplayMode.START_ONLY -> WeekSectionTimeMode.START_ONLY
            SectionTimeDisplayMode.START_AND_END -> WeekSectionTimeMode.START_AND_END
        },
        sectionHeightDp = model.sectionHeight.toFloat(),
        autoFitSectionHeight = model.timetableAutoFitSectionHeight,
        timeColumnWidthDp = timeColumnWidthDp(
            model.timetableTimeColumnWidthMode == TimetableTimeColumnWidthMode.WIDE,
        ),
        // Dart `courseCardInset`：`timetableCourseCardGap.clamp(0, 3)`。
        cardInsetDp = model.timetableCourseCardGap.toFloat().coerceIn(0f, 3f),
        showNonCurrentWeekCourses = model.timetableShowNonCurrentWeekCourses,
        showWeekGridExams = model.weekGridShowExams,
        showWeekGridSchedules = model.weekGridShowSchedules,
        longPressEmptySlotToAddCourse = model.longPressEmptySlotToAddCourseEnabled,
        holidayMarkingEnabled = model.enableHolidayMarking,
        weekdayFontColorLight = model.weekdayBarFontColorLight,
        weekdayFontColorDark = model.weekdayBarFontColorDark,
        weekdayAccentColorLight = model.weekdayBarAccentColorLight,
        weekdayAccentColorDark = model.weekdayBarAccentColorDark,
        timeAxisColorLight = model.timeAxisFontColorLight,
        timeAxisColorDark = model.timeAxisFontColorDark,
        showBackToCurrentWeek =
            model.timetableBackToCurrentWeekButtonStyle == BackToCurrentWeekButtonStyle.FLOATING,
        backToCurrentWeekOpacity =
            model.timetableFloatingBackToCurrentWeekButtonOpacity.toFloat(),
        showWeatherOnCard = model.weatherShowOnWeekCard,
    )
}

/** 删除目标（Dart `add_course_screen.dart` 两条删除分支）。 */
sealed interface TimetableDeleteTarget {

    /**
     * 整组删除（Dart `:1406-1425`，组编辑态）：按**原始组名**摘掉整组课次，
     * 连带挂在这组课上的考试与作业（服务侧 `deleteGroup` 已实现）。
     */
    data class WholeGroup(val originalGroupName: String) : TimetableDeleteTarget

    /** 单条课次删除（Dart `:448-473`，单课编辑态）：只摘这一条，同组其它课次留着。 */
    data class SingleCourse(val courseId: String) : TimetableDeleteTarget
}

/**
 * 加课页的保存/删除载荷 → 仓储的分派（**宿主职责**）。
 *
 * 为什么在宿主层：`AddCoursePage` 的 KDoc 写着「保存载荷交给壳层落盘，由壳层按 mode 分派」，
 * 也就是说页面只产载荷，落到哪个仓储方法是宿主的事。
 *
 * ## 保存：Dart 是「三分支」，其中**编辑走整组替换**（`add_course_screen.dart:2044-2064`）
 *
 * ```dart
 * if (widget.courseGroup != null)      await provider.updateCourseGroup(widget.courseGroup!.name, courses);
 * else if (widget.course != null)      await provider.updateCourseGroup(widget.course!.name, courses);
 * else                                 for (final c in courses) await provider.addCourse(c);
 * ```
 *
 * ⚠️ **单课编辑也走整组替换**，Dart 原注释写明理由：走 delete+add 的话，
 * 同名兄弟课次会活过 delete，随后 `addCourse` 的共享字段广播又把它们的旧
 * 颜色/名字/性质盖回用户刚改的内容——「保存成功提示照弹，界面却没变」。
 *
 * ⚠️ 壳里原来的实现是**逐课 `updateCourse`**：那是「组里被删掉的课次不会被移除」的洞
 * ——编辑后把 3 门课删成 2 门，第 3 门会**留在盘上**。
 *
 * ## 参数口径：用 `originalGroupName` 而不是 mode 枚举
 *
 * 页面模型 `AddCourseFormLogic.resolveSaveTarget` 的契约是
 * 「编辑既有课/组 → `UPDATE_GROUP` 且 `targetGroupName != null`；新建 → `ADD` 且 null」，
 * 两者等价。所以这里直接收 `targetGroupName`（壳一行传参即可），并有一条契约测试
 * 钉住这个等价关系（`TimetableHostLogicTest`）。
 *
 * @param originalGroupName 编辑态的**原始**组名（改名前的那个名字）；新建传 null。
 * @param courses 保存后应当存在的**完整**课次列表（整组替换的语义就在这里）。
 */
object TimetableSaveDispatcher {

    /** 保存：编辑既有课/组 → 整组替换；新建 → 逐条新增（与 Dart 分支逐条一致）。 */
    fun applySave(
        port: TimetableCoursePort,
        originalGroupName: String?,
        courses: List<Course>,
    ) {
        if (originalGroupName == null) {
            // Dart `:2059-2063`：新建是逐条 addCourse（不是 addGroup）。
            courses.forEach { TimetableCourseService.add(port, it) }
        } else {
            // Dart `:2047` / `:2058`：整组替换。服务侧对空集合是 no-op（挡在摘除旧课次之前）。
            TimetableCourseService.updateGroup(port, originalGroupName, courses)
        }
    }

    /**
     * 删除目标判定（Dart 的两条分支 + 新建态没有删除入口）。
     *
     * 期望值（手推）：
     * - 组编辑（`originalGroupName != null`）→ [TimetableDeleteTarget.WholeGroup]（组名优先，即使 course 也在场）
     * - 单课编辑（只有 `initialCourse`）→ [TimetableDeleteTarget.SingleCourse]（只删这一条）
     * - 新建（两者都 null）→ `null`（没有可删的东西，调用方应当什么都不做）
     */
    fun resolveDeleteTarget(
        originalGroupName: String?,
        initialCourse: Course?,
    ): TimetableDeleteTarget? = when {
        originalGroupName != null -> TimetableDeleteTarget.WholeGroup(originalGroupName)
        initialCourse != null -> TimetableDeleteTarget.SingleCourse(initialCourse.id)
        else -> null
    }

    /** 删除：整组走 `deleteGroup`（连带摘考试/作业），单条走 `delete`。 */
    fun applyDelete(port: TimetableCoursePort, target: TimetableDeleteTarget) {
        when (target) {
            is TimetableDeleteTarget.WholeGroup ->
                TimetableCourseService.deleteGroup(port, target.originalGroupName)
            is TimetableDeleteTarget.SingleCourse ->
                TimetableCourseService.delete(port, target.courseId)
        }
    }
}
