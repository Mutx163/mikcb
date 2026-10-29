package com.mutx163.qingyu.pages.settings

// ⚠️ 下面这一行是**跨域的反向依赖**（设置域 → `app/` 的分派器镜像枚举），有意为之：
// 分派器必须待在 `app/`（它被每一次 L0 无条件收录，不能 import `pages.settings`），
// 而映射函数必须待在 `pages/settings/`（它要 import 本包的页面词汇；放 `app/` 会让
// **所有模块**的 L0 报 Unresolved）。两边各只依赖对方的一个枚举，方向单一、无环。
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
// 设置模型（`app/` 下的完整显示模型）。同样是「设置域 → app」方向，理由同上。
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.SectionTimeDisplayMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableTimeColumnWidthMode
import com.mutx163.qingyu.pages.settings.AppFontMode
import com.mutx163.qingyu.pages.settings.AppThemeMode
import com.mutx163.qingyu.pages.settings.CourseCardHorizontalAlign
import com.mutx163.qingyu.pages.settings.CourseCardSurfaceStyle
import com.mutx163.qingyu.pages.settings.CourseCardVerticalAlign
import com.mutx163.qingyu.pages.settings.ForuiTheme
import com.mutx163.qingyu.pages.settings.SavedThemeRow
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsAppearancePage
import com.mutx163.qingyu.pages.settings.SettingsCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsPageSpec
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsThemeManagePage
import java.time.LocalDateTime

/**
 * 设置族的**桥**：页面词汇（`pages/settings`）↔ 宿主词汇（`app/`）。
 *
 * ## 为什么这个文件在 composeP1 而不在 `main/.../app/`
 *
 * 它必须 import `pages.settings.*`，而 `pages/settings` **不在** L0 脚本的
 * `sharedModelDirs` 名单里：一旦放进 `main/.../app/`，所有泳道的 L0 都会因为
 * 「`app/` 收了这个文件、但 `pages/settings` 没被收」而报 Unresolved。
 * 放这里则两边都安全：L1 照常编译；本泳道跑 L0 时用 `-ExtraSources` 把它显式带上
 * （它是**纯 Kotlin，没有一行 Compose**，所以能被 kotlinc 直接编）。
 *
 * ## 三个映射
 *
 * 1. [toKind]：页面 `SettingsAction` → 宿主的 [SettingsActionKind]（11 个值逐个映射，
 *    有测试钉住不漂）；
 * 2. [toSettingsPageState]：设置模型 → 页面状态（spec 的唯一输入）；
 * 3. [specFor]：页 id → 本刀 4 页的 spec。
 */
object SettingsPageBridge {

    /** 本刀接的 4 个页 id（页面对象自己的常量，不在这里另抄一份）。 */
    val SUPPORTED_PAGE_IDS: List<String> = listOf(
        SettingsGeneralPage.ID,
        SettingsAppearancePage.ID,
        SettingsThemeManagePage.ID,
        SettingsCourseCardPage.ID,
    )

    /** 页面动作 → 宿主动作（一一对应，未知值返回 null）。 */
    fun toKind(action: SettingsAction): SettingsActionKind = when (action) {
        SettingsAction.NAVIGATE -> SettingsActionKind.NAVIGATE
        SettingsAction.SHEET -> SettingsActionKind.SHEET
        SettingsAction.DIALOG -> SettingsActionKind.DIALOG
        SettingsAction.WRITE_SETTING -> SettingsActionKind.WRITE_SETTING
        SettingsAction.RESET_SCOPE -> SettingsActionKind.RESET_SCOPE
        SettingsAction.CLIPBOARD_EXPORT -> SettingsActionKind.CLIPBOARD_EXPORT
        SettingsAction.CLIPBOARD_IMPORT -> SettingsActionKind.CLIPBOARD_IMPORT
        SettingsAction.RUN_NOW -> SettingsActionKind.RUN_NOW
        SettingsAction.COLOR_PICKER -> SettingsActionKind.COLOR_PICKER
        SettingsAction.MATERIAL_PANEL -> SettingsActionKind.MATERIAL_PANEL
        SettingsAction.RECOLOR_SHEET -> SettingsActionKind.RECOLOR_SHEET
    }

    /** 页 id → spec；不在本刀的 4 页里返回 null（壳据此决定要不要渲染）。 */
    fun specFor(pageId: String, state: SettingsPageState): SettingsPageSpec? = when (pageId) {
        SettingsGeneralPage.ID -> SettingsGeneralPage.spec(state)
        SettingsAppearancePage.ID -> SettingsAppearancePage.spec(state)
        SettingsThemeManagePage.ID -> SettingsThemeManagePage.spec(state)
        SettingsCourseCardPage.ID -> SettingsCourseCardPage.spec(state)
        else -> null
    }

    /**
     * 选色行的**当前色**（选色器要初值）。
     *
     * @return null 表示这个 rowId 不是本刀支持的选色行（宿主据此记 Ignored，不弹）。
     */
    fun currentColorHex(model: TimetableSettingsModel, rowId: String): String? = when (rowId) {
        SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE -> model.courseCardTitleColorLight
        SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_DETAIL -> model.courseCardDetailColorLight
        SettingsActionDispatcher.ROW_CARD_TEXT_DARK_TITLE -> model.courseCardTitleColorDark
        SettingsActionDispatcher.ROW_CARD_TEXT_DARK_DETAIL -> model.courseCardDetailColorDark
        else -> null
    }

    // ------------------------------------------------- 首页与导航 / 两个编辑器

    /**
     * 设置模型 → 首页与导航页状态（`SettingsHomeNavigationPage.spec` 的唯一输入）。
     *
     * ## 空表语义（三处 list 都**原样**给，不做 resolve）
     *
     * `dockActionIds` / `gridMenuActions` 直接给模型里的**原始** list——即使用户曾把底栏删空、
     * 存成空表，这里也照实给空表。**空表回退默认值由渲染前的 resolve 负责**：
     * [SettingsHomeNavigationPage.resolveDockActionIds] / [resolveGridEntryIds]
     * （底栏编辑器另有 [SettingsGlassDockEditorPage.sanitize]）。宿主如果直接把
     * 状态喂给 spec 而跳过 resolve，空表会显示成「一个按钮都没有」——这是宿主的接线责任，
     * 不是本函数偷偷塞默认值能替代的（偷偷塞默认值会让「用户真的清空了」这件事无法表达）。
     *
     * ## 导航形态的**词汇翻译**（这里最容易写错）
     *
     * 页面把两档叫 `"classic"` / `"glassDock"`（下拉 option id 与 `isGlassDock` 判断都认这两个串），
     * 而模型的磁盘值是 `"classic"` / `"glass_dock"`。所以 [navigationFormToken] 必须做翻译，
     * **不能**直接写 `model.homeNavigationForm.value`——那样玻璃坞形态的底栏区块永远不渲染
     * （`"glass_dock" != "glassDock"`）。其余三项（menuStyle / titleStyle）页面词汇与磁盘值恰好
     * 逐字一致（`list`/`grid`、`classic`/`brand`），直接用 `.value` 即可。
     */
    fun toHomeNavigationState(model: TimetableSettingsModel): SettingsHomeNavigationState =
        SettingsHomeNavigationState(
            navigationForm = navigationFormToken(model.homeNavigationForm),
            showAddButton = model.glassDockShowAddButton,
            dockActionIds = model.glassDockActions,
            dockButtonEntryId = model.glassDockButtonEntryId,
            dockButtonIconName = model.glassDockButtonIconName,
            menuStyle = model.homeMenuStyle.value,
            gridMenuActions = model.homeGridMenuActions,
            titleStyle = model.homeTitleStyle.value,
            diagnosticsBuild = false,
        )

    /**
     * 设置模型 → 玻璃坞底栏编辑器状态（`SettingsGlassDockEditorPage.spec` 的输入）。
     *
     * `enabledIds` 给模型里的**原始** `glassDockActions`；编辑器渲染前的「去脏 id / 去不可见」
     * 由 [SettingsGlassDockEditorPage.sanitize] 负责，本函数不预先过滤（见 [toHomeNavigationState]
     * 关于空表语义的说明）。
     */
    fun toGlassDockEditorState(
        model: TimetableSettingsModel,
        debugBuild: Boolean = false,
    ): GlassDockEditorState = GlassDockEditorState(
        enabledIds = model.glassDockActions,
        debugBuild = debugBuild,
    )

    /**
     * 设置模型 → 八宫格菜单编辑器状态（`SettingsHomeMenuEditorPage.spec` 的输入）。
     *
     * `enabledIds` 给模型里的**原始** `homeGridMenuActions`；编辑器渲染前的种子清洗
     * （`sanitizeSeed`）与 resolve 由页面/宿主负责，本函数不预过滤。
     */
    fun toHomeMenuEditorState(
        model: TimetableSettingsModel,
        debugBuild: Boolean = false,
    ): SettingsHomeMenuEditorState = SettingsHomeMenuEditorState(
        enabledIds = model.homeGridMenuActions,
        // 参数叫 debugBuild（与另两个映射一致），状态字段叫 diagnosticsBuild——
        // 同一件事（调试/性能构建可见调试条目），语义相同、名字不同。
        diagnosticsBuild = debugBuild,
    )

    /**
     * 导航形态：模型枚举 → 页面词汇（`"classic"` / `"glassDock"`）。
     *
     * ⚠️ 磁盘值 `glass_dock` → 页面词 `glassDock` 的翻译就在这一处，别在别处再写一遍。
     */
    private fun navigationFormToken(form: HomeNavigationForm): String = when (form) {
        HomeNavigationForm.CLASSIC -> "classic"
        HomeNavigationForm.GLASS_DOCK -> "glassDock"
    }

    /**
     * 设置模型 → 页面状态。
     *
     * ## 两个**填不满**的字段（诚实清单）
     *
     * - `autoRefresh`：课程自动更新的档位/时刻/上次成功时间**不在** `timetable_settings`
     *   里（Dart 侧是独立的调度存储），本模型也没有。这里恒为 `null` ⇒ 通用页的
     *   「课表自动更新」整块不渲染（模型层 KDoc 写明 null = 尚未加载完，整块不渲染）。
     * - `savedThemes` 的 `selected`：Dart 判据是
     *   `themeCheckpointName == theme.name && !hasThemeModifications`
     *   （`theme_manage_sheets.dart:315-318`）——两个条件都实现了（`hasThemeModifications`
     *   见 [SettingsActionDispatcher.hasThemeModifications]，task-16 补齐）。
     *
     * `themeHasModifications` 走 [SettingsActionDispatcher.hasThemeModifications]
     * （口径与 Dart `timetable_settings.dart:2482-2513` 逐条对齐，含「只比检查点里非 null
     * 的字段」这条）。它决定主题管理页控制卡那两个按钮**渲染不渲染**。
     */
    fun toSettingsPageState(
        model: TimetableSettingsModel,
        /**
         * 通用页「课表自动更新」整块的状态；`null` = 宿主还没接上那份本地存储
         * （此时整块不渲染，与 Phase 3.5 第一刀的行为一致）。
         *
         * ⚠️ 它**不来自** [model]：自动更新的开关/时机存在另一个 prefs 键里
         * （Dart `lib/services/course_auto_refresh_store.dart:35`），理由见那边的类注释
         * （台账必须跟随本机、不能跟着课表备份走）。所以只能由宿主读盘后传进来，
         * 见 [toAutoRefreshState]。
         */
        autoRefresh: AutoRefreshState? = null,
    ): SettingsPageState {
        val defaults = SettingsPageState()
        val themeHasModifications = SettingsActionDispatcher.hasThemeModifications(model)
        return SettingsPageState(
            // ---- 通用 ----
            appLocaleTag = model.appLocaleTag,
            pageTransitionSpeed = model.pageTransitionSpeed,
            enableHaptics = model.enableHaptics,
            homePullQuickImportEnabled = model.homePullQuickImportEnabled,
            autoRefresh = autoRefresh,
            // ---- 外观与主题 ----
            appThemeMode = pick(
                AppThemeMode.entries,
                { it.value },
                model.appThemeMode.value,
                defaults.appThemeMode,
            ),
            appFontMode = pick(
                AppFontMode.entries,
                { it.value },
                model.appFontMode.value,
                defaults.appFontMode,
            ),
            appFontWeight = model.appFontWeight,
            appTextScale = model.appTextScale,
            foruiTheme = pick(
                ForuiTheme.entries,
                { it.value },
                model.foruiTheme.value,
                defaults.foruiTheme,
            ),
            themeSeedColor = model.themeSeedColor,
            themeCheckpointName = model.themeCheckpointName,
            themeHasModifications = themeHasModifications,
            savedThemes = mapSavedThemes(model, themeHasModifications),
            // ---- 课程卡片 ----
            courseCardShowName = model.courseCardShowName,
            courseCardShowTeacher = model.courseCardShowTeacher,
            courseCardShowLocation = model.courseCardShowLocation,
            courseCardShowTime = model.courseCardShowTime,
            courseCardShowTimeLabels = model.courseCardShowTimeLabels,
            courseCardShowWeeks = model.courseCardShowWeeks,
            courseCardShowDescription = model.courseCardShowDescription,
            courseCardSurfaceStyle = pick(
                CourseCardSurfaceStyle.entries,
                { it.value },
                model.courseCardSurfaceStyle.value,
                defaults.courseCardSurfaceStyle,
            ),
            courseCardVerticalAlign = pick(
                CourseCardVerticalAlign.entries,
                { it.value },
                model.courseCardVerticalAlign.value,
                defaults.courseCardVerticalAlign,
            ),
            courseCardHorizontalAlign = pick(
                CourseCardHorizontalAlign.entries,
                { it.value },
                model.courseCardHorizontalAlign.value,
                defaults.courseCardHorizontalAlign,
            ),
            courseCardFontSize = model.courseCardFontSize,
            compactFontSize = model.compactFontSize,
            timetableUseUnifiedCardColor = model.timetableUseUnifiedCardColor,
            timetableUnifiedCardColor = model.timetableUnifiedCardColor,
            showConflictBadgeOnTimetable = model.showConflictBadgeOnTimetable,
            timetableConflictCourseOpacity = model.timetableConflictCourseOpacity,
            linkCourseCardColors = model.linkCourseCardColors,
            courseCardTitleColor = model.courseCardTitleColorLight,
            courseCardDetailColor = model.courseCardDetailColorLight,
            courseCardTitleColorDark = model.courseCardTitleColorDark,
            courseCardDetailColorDark = model.courseCardDetailColorDark,
        )
    }

    /**
     * 「课表自动更新」的本地存储 → 通用页那一整块的状态（[SettingsGeneralPage.spec] 的
     * `general.autoRefresh.*` 节点）。
     *
     * 期望值来源全部是 Dart：
     * - 字段含义与默认值：`lib/widgets/course_auto_refresh_settings.dart:100-165`；
     * - 「上次 X / 下次约 Y」两段文案的拼法：同文件 `:226-240`（`_summaryText`）；
     * - 时刻的短格式：同文件 `:246-252`（月不补零、日补零、24 小时制）。
     *
     * ## 为什么收基本类型、不收 `pages/import` 的配置对象
     *
     * 那对象（`CourseAutoRefreshSchedule`）与它的档位枚举在 `pages/import/` 下，
     * 而本桥只在 `pages/settings` 的 L0 里被 `-ExtraSources` 单独拉进编译；
     * 一旦这里 import 了 `pages/import`，**所有照抄那条 L0 命令的泳道都会 Unresolved**。
     * 收 `modeValue` 字符串既避开了这条跨域依赖，口径也更直接：Dart 往盘上写的就是
     * `everyLaunch` / `intervalHours` / `dailyAt` 这三个短串。
     *
     * @param modeValue 磁盘上的档位短串；认不出（或空）按 `everyLaunch` 处理——与 Dart
     *   `CourseAutoRefreshMode.fromName` 的容错口径一致。
     * @param lastSuccess 上一次**成功**更新的时刻；null = 从没成功过。
     * @param nextRun 下一次预计运行的时刻；null = 功能关着（或没有下次）。
     */
    fun toAutoRefreshState(
        enabled: Boolean,
        modeValue: String,
        intervalHours: Int,
        dailyMinuteOfDay: Int,
        lastSuccess: LocalDateTime?,
        nextRun: LocalDateTime?,
    ): AutoRefreshState = AutoRefreshState(
        enabled = enabled,
        mode = CourseAutoRefreshMode.entries.firstOrNull { it.value == modeValue }
            ?: CourseAutoRefreshMode.EVERY_LAUNCH,
        intervalHours = intervalHours,
        dailyMinuteOfDay = dailyMinuteOfDay,
        lastSuccessLabel = lastSuccess?.let { shortDateTime(it) },
        nextRunLabel = nextRun?.let { shortDateTime(it) },
    )

    /**
     * 时刻 → 「9-21 07:30」。逐字照 Dart `_shortDateTime`
     * （`course_auto_refresh_settings.dart:246-252`）：**月不补零**、日补零。
     */
    private fun shortDateTime(value: LocalDateTime): String = SettingsGeneralPage.shortDateTime(
        month = value.monthValue,
        day = value.dayOfMonth,
        hour = value.hour,
        minute = value.minute,
    )

    /**
     * 设置模型 → 「课表页面设置」页状态（`SettingsTimetablePageSettingsPage.spec` 的输入）。
     *
     * 本页的状态有一批字段**本模型还不拥有**（背景色/壁纸/模糊/背景随周滑动、
     * 以及单值的星期栏与时间轴字色——模型存的是明暗两套）。这些字段用页面默认值，
     * 对应行也还没接写回（宿主会 Ignore，等背景/材质那一刀扩模型）。**已拥有的密度与
     * 浮钮不透明度全部按模型真值喂**，所以这一片是真能存住的。
     *
     * @param screenshotShareSupported 设备能力（Android 14 截屏回调）；默认 false =
     *   该行整行不出现，是保守口径（Dart 也是不支持就不显示）。
     */
    fun toTimetablePageState(
        model: TimetableSettingsModel,
        screenshotShareSupported: Boolean = false,
    ): TimetablePageSettingsState = TimetablePageSettingsState(
        autoFitSectionHeight = model.timetableAutoFitSectionHeight,
        hideWeekends = model.timetableHideWeekends,
        showNonCurrentWeekCourses = model.timetableShowNonCurrentWeekCourses,
        longPressEmptySlotToAddCourse = model.longPressEmptySlotToAddCourseEnabled,
        weekGridShowExams = model.weekGridShowExams,
        weekGridShowSchedules = model.weekGridShowSchedules,
        screenshotSharePromptEnabled = model.screenshotSharePromptEnabled,
        screenshotShareSupported = screenshotShareSupported,
        sectionTimeDisplayMode = when (model.timetableSectionTimeDisplayMode) {
            SectionTimeDisplayMode.HIDDEN -> PageSectionTimeDisplayMode.HIDDEN
            SectionTimeDisplayMode.START_ONLY -> PageSectionTimeDisplayMode.START_ONLY
            SectionTimeDisplayMode.START_AND_END -> PageSectionTimeDisplayMode.START_AND_END
        },
        timeColumnWidthMode = when (model.timetableTimeColumnWidthMode) {
            TimetableTimeColumnWidthMode.NARROW -> PageTimeColumnWidthMode.NARROW
            TimetableTimeColumnWidthMode.WIDE -> PageTimeColumnWidthMode.WIDE
        },
        sectionHeight = model.sectionHeight,
        courseCardGap = model.timetableCourseCardGap,
        backToCurrentWeekOpacity = model.timetableFloatingBackToCurrentWeekButtonOpacity,
        // 以下八项本模型未拥有：给页面默认值（不会写回，宿主 Ignore）。
        pageBackgroundColor = "#F8FAFC",
        imagePath = null,
        backdropFollowsWeekPager = false,
        wallpaperBlurSigma = 0.0,
        weekdayBarColor = model.weekdayBarFontColorLight,
        weekdayBarAccentColor = model.weekdayBarAccentColorLight,
        timeAxisColor = model.timeAxisFontColorLight,
    )

    // ------------------------------------------------------------------ 内部

    private fun <T> pick(
        candidates: List<T>,
        value: (T) -> String,
        appValue: String,
        fallback: T,
    ): T = candidates.firstOrNull { value(it) == appValue } ?: fallback

    /**
     * 已存主题 → 页面行。
     *
     * 逐条宽容（Dart `SavedTheme.fromJson`：id/name 缺失的条目丢弃，不让一条坏数据炸整块），
     * 预览色取 `themeData` 的前 4 个（Dart `TimetableSettings.previewColors`，
     * `timetable_settings.dart:264-278`）。
     *
     * `selected` 判据逐字照 Dart `isSavedThemeSelected`（`theme_manage_sheets.dart:315-318`）：
     * `themeCheckpointName == theme.name && !hasThemeModifications`
     * —— 名字对上了但用户已经改过主题，就不算「选中」。
     */
    private fun mapSavedThemes(
        model: TimetableSettingsModel,
        themeHasModifications: Boolean,
    ): List<SavedThemeRow> =
        model.savedThemes.mapNotNull { raw ->
            val id = raw["id"] as? String ?: return@mapNotNull null
            val name = raw["name"] as? String ?: return@mapNotNull null
            SavedThemeRow(
                id = id,
                name = name,
                selected = model.themeCheckpointName == name && !themeHasModifications,
                previewColors = previewColorsOf(raw),
            )
        }

    private fun previewColorsOf(raw: Map<String, Any?>): List<String> {
        val themeData = raw["themeData"] as? Map<*, *> ?: return emptyList()
        fun color(key: String): String? =
            (themeData[key] as? String)?.takeIf { it.isNotBlank() }
        return listOfNotNull(
            color("seedColor"),
            color("courseCardTitleColorLight"),
            color("courseCardDetailColorLight"),
            color("weekdayBarFontColorLight"),
            color("weekdayBarAccentColorLight"),
        ).take(4)
    }
}
