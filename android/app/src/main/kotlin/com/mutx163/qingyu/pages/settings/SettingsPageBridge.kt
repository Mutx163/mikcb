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

    /**
     * 「最近使用」页的桥接 id。
     *
     * 页面本体（`SettingsRecentWallpaperPage.kt`）把 id 直接写在 `spec()` 的返回值里，
     * 没有导出常量；那边不在本批写作用域内，所以这里先用同一个串，
     * 并由 `AppearanceEditorDataContractTest` 断言它与 `spec(...).id` 逐字一致
     * ——两边谁改了都会红。
     */
    const val RECENT_WALLPAPER_SPEC_ID = "settings-recent-wallpaper"

    /**
     * 外观编辑家族（外观编辑整页 + 两个面板的四个页签）的**桥接页 id**。
     *
     * 这批页面不走 [SettingsHost] 的「列表 + 通用渲染层」：外观编辑是沉浸式整页，
     * 两个面板是底部弹层，宿主分别是 `AppearanceEditorHost` / `MaterialSheetBody` /
     * `WallpaperSheetBody`。但它们**同样需要「模型 → 页面 state」这一层**，否则
     * 面板会退回出厂值。所以它们单独成一张表，[specFor] 认这些 id。
     *
     * ⚠️ 不并进 [SUPPORTED_PAGE_IDS]：那张表与 `SettingsHost` 的 4 页契约一一对应，
     * `app/SettingsActionDispatcherTest` 把它钉成恰好 4 项；本批写作用域不允许改那条测试。
     * 两条表各管各的，调用方按页面宿主选入口。
     */
    val APPEARANCE_PAGE_IDS: List<String> = listOf(
        SettingsAppearanceEditorPage.ID,
        SettingsMaterialGeneralPage.ID,
        SettingsMaterialCourseCardPage.ID,
        SettingsBackdropFlowPage.SELECTION_SPEC_ID,
        RECENT_WALLPAPER_SPEC_ID,
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

    /**
     * 页 id → spec；不认识的 id 返回 `null`（壳据此决定要不要渲染）。
     *
     * 2026-10-30（F06 登记）：原先只认 4 页，其余设置页只能由壳自己
     * `SettingsScreen(XxxPage.spec(SettingsPageState()))` 渲染 —— 传的是**空构造 state**，
     * 于是屏上是默认值、开关点了写不进去。现在把 `b.reset` / `b.glassDockIcon` /
     * `b.live` / `b.liveSelfCheck` 一并登记，让它们能走 `SettingsHost`（真读 + 真写）。
     *
     * ⚠️ 登记 ≠ 接线完成：写路径还取决于 `SettingsActionDispatcher` 是否认这些页的
     * rowId（见各页分支注释与 `claims/F06-settings-components.md`）。
     *
     * `liveData` 只有 `b.live` 用得上：那页的摘要行由 `LivePageData` 决定，`state` 通篇
     * 未使用。**默认值是空构造 = 屏上仍是默认摘要**——真要给 `b.live` 接真值，
     * 调用方必须自己从 `LiveDisplayStore` 读出来后传进来（壳里 `b.live` 走的是
     * `composeP1: app/LiveSettingsPageHost.kt`，不经过这里；本参数是给
     * `SettingsHost` 将来统一托管该页时用的入口）。
     */
    fun specFor(
        pageId: String,
        state: SettingsPageState,
        liveData: LivePageData = LivePageData(),
        /**
         * 外观编辑家族的状态（[APPEARANCE_PAGE_IDS] 用）。
         *
         * 调用方必须从**同一份设置模型**推：
         * `AppearanceEditorBridge.toState(model).material` / `.wallpaper`。
         * 缺省值只是为了让 4 页旧调用点不改签名；给外观家族页传默认值 =
         * 面板回到出厂值（与「传空 state」同一个病，不要这么调）。
         */
        material: MaterialPanelState = MaterialPanelState(),
        backdrop: BackdropFlowState = BackdropFlowState(),
        recent: RecentWallpaperState = RecentWallpaperState(),
    ): SettingsPageSpec? = when (pageId) {
        SettingsGeneralPage.ID -> SettingsGeneralPage.spec(state)
        SettingsAppearancePage.ID -> SettingsAppearancePage.spec(state)
        SettingsThemeManagePage.ID -> SettingsThemeManagePage.spec(state)
        SettingsCourseCardPage.ID -> SettingsCourseCardPage.spec(state)
        // `b.reset`：五个作用域行是 RESET_SCOPE（宿主已有二次确认弹窗 `pendingReset`）。
        SettingsResetPage.ID -> SettingsResetPage.spec(state)
        SettingsGlassDockIconEditorPage.ID -> SettingsGlassDockIconEditorPage.spec(state)
        SettingsLivePage.ID -> SettingsLivePage.spec(state, liveData)
        SettingsLiveSelfCheckPage.ID -> SettingsLiveSelfCheckPage.spec(state)
        // 外观编辑家族（见 [APPEARANCE_PAGE_IDS]）：页面自身数据全部来自
        // [AppearanceEditorBridge] 从同一份设置模型推出的 state。
        SettingsAppearanceEditorPage.ID -> SettingsAppearanceEditorPage.spec(state, material)
        SettingsMaterialGeneralPage.ID -> SettingsMaterialGeneralPage.spec(state, material)
        SettingsMaterialCourseCardPage.ID -> SettingsMaterialCourseCardPage.spec(state, material)
        SettingsBackdropFlowPage.SELECTION_SPEC_ID ->
            SettingsBackdropFlowPage.selectionPage(backdrop)
        RECENT_WALLPAPER_SPEC_ID -> SettingsRecentWallpaperSection.spec(recent)
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
        // 课表页面设置页的三根文字颜色（读的是浅色档，与页面状态同口径）。
        SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY -> model.weekdayBarFontColorLight
        SettingsActionDispatcher.ROW_TP_TEXT_WEEKDAY_ACCENT -> model.weekdayBarAccentColorLight
        SettingsActionDispatcher.ROW_TP_TEXT_TIME_AXIS -> model.timeAxisFontColorLight
        // 深色档三行（2026-11-01 补）：值直接取模型的 Dark 键，与渲染层同一份真源。
        SettingsTimetablePageSettingsPage.ROW_TEXT_WEEKDAY_DARK ->
            model.weekdayBarFontColorDark
        SettingsTimetablePageSettingsPage.ROW_TEXT_WEEKDAY_ACCENT_DARK ->
            model.weekdayBarAccentColorDark
        SettingsTimetablePageSettingsPage.ROW_TEXT_TIME_AXIS_DARK ->
            model.timeAxisFontColorDark
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
     * 设置模型 → 桌面小组件页状态（`SettingsHomeWidgetPage.spec` 的唯一输入）。
     *
     * ## 逐字段直译，不做任何再解释
     *
     * 四个字符串/枚举键原样给**落盘串**（`solid` / `bar_and_text` / `smart` …），
     * 页面自己拿这些串做下拉选中项；10 个字段的行号见 `timetable_settings.dart:786-795`，
     * 读侧口径见同文件 `:1444-1461`（模型层已按 `fromValue` / `lenientXxx` 归好默认值）。
     *
     * ⚠️ `heightAdjustment` 给的是**存储值**（默认 -11 的绝对值），不是滑杆偏移：
     * 页面用 `storedHeightFromOffset` / `heightOffset` 在两种读数之间换算
     * （`settings_home_widget.dart:344-359`）。这里若先减 11，页面的滑杆会停到 -22 的格子上。
     *
     * ## 四个「模型里没有」的输入
     *
     * `widgetInstances` / `profiles` / `partnerProfile` / `exactAlarmGranted` 都来自宿主
     * （桌面卡片绑定表、课表仓储、系统精确闹钟权限），不在 `timetable_settings` 里，
     * 所以由调用方传入：默认空表 / null = 宿主还没接上，页面按「没有卡片」「权限未知」
     * 渲染（`exactAlarmGranted = null` 时权限横幅不出现，避免首帧闪烁，
     * `settings_home_widget.dart:64-66`）。
     */
    fun toHomeWidgetState(
        model: TimetableSettingsModel,
        widgetInstances: List<HomeWidgetInstanceSpec> = emptyList(),
        profiles: List<ProfileSpec> = emptyList(),
        partnerProfile: ProfileSpec? = null,
        exactAlarmGranted: Boolean? = null,
    ): SettingsHomeWidgetState = SettingsHomeWidgetState(
        backgroundStyle = model.widgetBackgroundStyle,
        courseAccentMode = model.widgetCourseAccentMode,
        showLocation = model.widgetShowLocation,
        showCountdown = model.widgetShowCountdown,
        hideCompletedCourses = model.widgetHideCompletedCourses,
        showTomorrowCourses = model.widgetShowTomorrowCourses,
        // 存储值直给（页面自己减 -11 得偏移）。
        heightAdjustment = model.widgetHeightAdjustment,
        cornerRadius = model.widgetCornerRadius,
        countdownLeadMinutes = model.widgetCountdownLeadMinutes,
        countdownTextStyle = model.widgetCountdownTextStyle,
        widgetInstances = widgetInstances,
        profiles = profiles,
        partnerProfile = partnerProfile,
        exactAlarmGranted = exactAlarmGranted,
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
     * 2026-11-01：背景这一组（纯色 / 背景图 / 随周次滑动 / 模糊）原先在桥里**写死默认**，
     * 模型也还没有对应字段 ⇒ 屏上永远显示「未选择 / 关闭 / 0」。现在四个键都进了
     * [TimetableSettingsModel]（`timetable_settings.dart:556-558`、`:1698-1704`），
     * 这里逐键取真值。
     *
     * 背景图的解析口径照 Dart `resolveHomePageBackdropImagePath`
     * （`home_page_background.dart:346-356`）：**新壁纸优先，旧字段只是回退**，
     * 空串按「没有」处理。
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
        pageBackgroundColor = model.timetablePageBackgroundColor,
        imagePath = resolveHomePageBackdropImagePath(model),
        backdropFollowsWeekPager = model.homePageBackdropFollowsWeekPager,
        wallpaperBlurSigma = model.homePageWallpaperBlurSigma,
        weekdayBarColor = model.weekdayBarFontColorLight,
        weekdayBarAccentColor = model.weekdayBarAccentColorLight,
        timeAxisColor = model.timeAxisFontColorLight,
        // 深色档：渲染层 `TimetableWeekdayHeader` / `TimetableTimeColumn` 早就在按
        // `isSystemInDarkTheme()` 读这三个键，本页只是把值显示出来（Dart 两组行同源）。
        weekdayBarColorDark = model.weekdayBarFontColorDark,
        weekdayBarAccentColorDark = model.weekdayBarAccentColorDark,
        timeAxisColorDark = model.timeAxisFontColorDark,
    )

    /**
     * 首页背景图的有效路径（Dart `resolveHomePageBackdropImagePath`，
     * `lib/utils/home_page_background.dart:346-356`）。
     *
     * 顺序不能反：新壁纸 [TimetableSettingsModel.homePageWallpaperPath] 优先，
     * 旧字段 [TimetableSettingsModel.homePageBackgroundImagePath] 只在没有壁纸时兜底。
     * 空串按「没有」处理（Dart 的 `isNotEmpty` 判据）。
     */
    fun resolveHomePageBackdropImagePath(model: TimetableSettingsModel): String? =
        model.homePageWallpaperPath?.takeIf { it.isNotEmpty() }
            ?: model.homePageBackgroundImagePath?.takeIf { it.isNotEmpty() }

    /**
     * 壁纸面板状态 → 壁纸流程块状态（[SettingsBackdropFlowPage] 的输入）。
     *
     * 两个页签（选图 / 设置）共用同一份输入，所以只做一次形状转换。
     * `bingAutoApplyEnabled` **不在这里推**：它的真源是图库台账
     * （`BingWallpaperStore`），不在 `timetable_settings` 里；宿主拿到台账值后自己覆盖，
     * 缺省 false = 「不可用」，不会伪造一个能点的开关。
     */
    fun toBackdropFlowState(wallpaper: WallpaperPanelState): BackdropFlowState = BackdropFlowState(
        imagePath = wallpaper.path,
        history = wallpaper.history.map { it.key },
        followsWeekPager = wallpaper.followsWeekPager,
        blurSigma = wallpaper.blurSigma,
    )

    /**
     * 壁纸面板状态 → 「最近使用」页状态。
     *
     * `armedKey` 是纯 widget 状态（长按后等确认的那一张），模型里没有，默认 null；
     * 删除确认由宿主在交互过程中填。
     */
    fun toRecentWallpaperState(wallpaper: WallpaperPanelState): RecentWallpaperState =
        RecentWallpaperState(
            entries = wallpaper.history.map { it.key },
            selectedKey = wallpaper.path,
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
        // ⚠️ `themeData` 是 **ThemeConfig.toJson 的短键**（`seed` / `ccl` / `cdl` / `wbl` / `wal`，
        // `lib/models/timetable_settings.dart:123-144`），不是设置模型的长键名。
        // 2026-10-29 修（一轮审核）：这里原先按长键（`seedColor` / `courseCardTitleColorLight`…）取，
        // 键名对不上 ⇒ 已存主题行的四个色点**永远是空的**。Dart `previewColors`
        // 读的是 ThemeConfig 的 getter（`timetable_settings.dart:263-278`），本质就是这几个短键。
        return listOfNotNull(
            color("seed"),
            color("ccl"),
            color("cdl"),
            color("wbl"),
            color("wal"),
        ).take(4)
    }
}
