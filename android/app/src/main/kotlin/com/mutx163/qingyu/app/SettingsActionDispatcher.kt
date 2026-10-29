package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.LenientJson
import kotlin.math.roundToInt

/**
 * 设置族动作分派器（Phase 3.5 · 设置族竖切第一刀）。
 *
 * ## 它解决什么
 *
 * `SettingsPageScreen` 的渲染层只把每行的 `action` 原样转出来：
 * `onAction(action, target, rowId)`（`SettingsPageRenderers.kt:89-94`）。
 * **「这个动作到底改哪个字段、跳哪个页」是宿主的活**——本文件就是那个宿主逻辑，
 * 但它**不碰 Android / Compose / 导航**：只把动作翻译成「新的设置模型」或一个
 * 界面意图（[SettingsDispatch]），由壳决定怎么弹、怎么跳、怎么存。
 *
 * ## 为什么参数是「镜像枚举」而不是直接收 `pages.settings.SettingsAction`
 *
 * `main/.../app/` 会被 `scripts/test-kotlin-module.ps1` **无条件收进每一次 L0 编译**
 * （`sharedModelDirs` 里有 `app`），而 `pages/settings` 不在那个名单里。一旦本文件
 * import `pages.settings.*`，**所有泳道的 L0 都会报 Unresolved**。所以这里用
 * [SettingsActionKind] 镜像枚举，映射函数放在
 * `main/.../pages/settings/SettingsPageBridge.kt`（纯 Kotlin，无 Compose）。
 * **它必须放在 `pages/settings/` 而不是 `app/`**：它要 import `pages.settings.*`，
 * 而 `app/` 被每一次 L0 无条件收录——放 `app/` 会让**所有模块**的 L0 报 Unresolved；
 * 放 `pages/settings/` 则只在 `-Module pages/settings` 时被收，边界正好对上。
 * 由一条「11 个值逐个映射」的测试钉住两边不漂。
 *
 * ## 值的传递约定（照渲染层实际行为，不是猜的）
 *
 * | 行类型 | 渲染层怎么传 | 分派器怎么读 |
 * |---|---|---|
 * | SWITCH / CHECKBOX | `onAction(action, row.actionTarget, row.id)` —— **不带新值** | `target == null` ⇒ 把该行当前布尔值**取反** |
 * | DROPDOWN | `onAction(action, option.id, row.id)` | `target` = 选中项 id |
 * | SLIDER | `onAction(WRITE_SETTING, changed.toString(), row.id)` | `target` = 数字字符串 |
 * | RADIO | `onAction(action, row.actionTarget, row.id)` | `target` 通常为 null ⇒ **从 rowId 后缀取值** |
 * | ARROW / COLOR_SWATCH | `onAction(action, row.actionTarget, row.id)` | `target` = 路由 / 作用域 |
 *
 * ## 本刀覆盖的页面
 *
 * 通用（`settings-general`）/ 外观（`settings-appearance`）/ 主题管理（`settings-theme`）/
 * 课程卡片（`settings-course-card`）/ 首页与导航（`settings-home-navigation`，含底栏编辑器与
 * 八宫格编辑器那批 add / remove / move / reset 增量动作）。2026-10-29 起还覆盖**外观编辑页的
 * 材质面板与壁纸弹层**（`material.general.*` / `material.courseCard.*` / `backdrop.*`，
 * 见 [ROW_MATERIAL_GLASS_MODE] 那一节）。其余页各自私有 state，
 * 未识别 rowId 一律 [SettingsDispatch.Ignored]（no-op + 带理由，**不崩**）。
 *
 * ## 判据出处（Dart 只读参照，逐条核过）
 *
 * - 主题预设：`settings_appearance.dart:352-353`（下拉）与 `:721-722`（主题管理单选）
 *   —— 选一档**同时**写 `foruiTheme` 与 `themeSeedColor = preset.seedHex`；
 * - 文字颜色联动：`timetable_text_color_settings.dart:67-81`（开关）与 `:101-111`（浅色标题色）
 *   —— 联动为真时详情色**跟随**标题色；
 * - 恢复默认：`settings_reset.dart:50-73`（courseCard 20 字段）/ `:128-157`（appearance）。
 */
enum class SettingsActionKind {
    NAVIGATE,
    SHEET,
    DIALOG,
    WRITE_SETTING,
    RESET_SCOPE,
    CLIPBOARD_EXPORT,
    CLIPBOARD_IMPORT,
    RUN_NOW,
    COLOR_PICKER,
    MATERIAL_PANEL,
    RECOLOR_SHEET,
}

/** 分派结果：要么是「新的设置状态」，要么是一个界面意图（由壳执行）。 */
sealed interface SettingsDispatch {

    /** 写设置：宿主落盘 [model] 并重组界面。 */
    data class Write(val model: TimetableSettingsModel, val rowId: String) : SettingsDispatch

    /** 推一个新页（路由见 [route]，取自行的 `actionTarget`）。 */
    data class Navigate(val route: String, val rowId: String) : SettingsDispatch

    /** 弹 BottomSheet（[target] 为行自己的 `actionTarget`，可能为 null）。 */
    data class ShowSheet(val target: String?, val rowId: String) : SettingsDispatch

    /** 弹 OverlayDialog。 */
    data class ShowDialog(val target: String?, val rowId: String) : SettingsDispatch

    /** 弹选色器；选完由宿主回投一条 `WRITE_SETTING`（target = 新色值 hex）。 */
    data class ShowColorPicker(val rowId: String) : SettingsDispatch

    /** 进外观编辑页的材质面板。 */
    data class ShowMaterialPanel(val route: String, val rowId: String) : SettingsDispatch

    /** 弹课表重新配色弹层。 */
    data class ShowRecolorSheet(val rowId: String) : SettingsDispatch

    /** 恢复默认：**先确认**（模型层 KDoc 写明「写入前须二次确认」），确认后宿主调 [SettingsActionDispatcher.applyResetScope]。 */
    data class ConfirmReset(val scope: String, val rowId: String) : SettingsDispatch

    data class ClipboardExport(val rowId: String) : SettingsDispatch

    data class ClipboardImport(val rowId: String) : SettingsDispatch

    /** 立刻跑一次（课程自动更新）。 */
    data class RunNow(val rowId: String) : SettingsDispatch

    /**
     * 未接的组合：未知 rowId、该行不该写、值解析不出来、缺必需 target。
     * **no-op + 带理由**，宿主可以记一条日志；绝不让界面崩。
     */
    data class Ignored(
        val kind: SettingsActionKind,
        val target: String?,
        val rowId: String,
        val reason: String,
    ) : SettingsDispatch
}

object SettingsActionDispatcher {

    // ---------------------------------------------------------------- rowId 常量
    // 与 pages/settings 的 spec 逐字一致（本文件不能 import 那个包，见类注释）。

    const val ROW_LOCALE = "general.language"
    const val ROW_TRANSITION_SPEED = "general.transitionSpeed"
    const val ROW_HAPTICS = "general.haptics"
    const val ROW_HOME_PULL_IMPORT = "general.homePullImport"

    /**
     * 节假日标记总开关（`settings_holiday.dart:508-516` 的 `HyperosSwitchTile`）。
     *
     * 这一行不属上面四页的 45 个字段，是 2026-10-29 接节假日页时补进来的：
     * `TimetableSettingsModel` 从第一批起就带 `enableHolidayMarking`（模型层要喂
     * 月视图与超级岛），但**分派器没有对应分支** ⇒ 开关点了界面不会变、盘上也不会变。
     */
    const val ROW_HOLIDAY_ENABLE = "holiday.enable"

    const val ROW_THEME_MODE = "appearance.themeMode"
    const val ROW_FONT_MODE = "appearance.fontMode"
    const val ROW_FONT_WEIGHT = "appearance.fontWeight"
    const val ROW_FONT_SIZE = "appearance.fontSize"
    const val ROW_THEME_PRESET = "appearance.themePreset"

    /** 主题管理页的预设单选行前缀（`theme.preset.<foruiTheme.value>`）。 */
    const val ROW_THEME_PRESET_PREFIX = "theme.preset."

    const val ROW_CARD_SHOW_NAME = "courseCard.show.name"
    const val ROW_CARD_SHOW_TEACHER = "courseCard.show.teacher"
    const val ROW_CARD_SHOW_LOCATION = "courseCard.show.location"
    const val ROW_CARD_SHOW_TIME = "courseCard.show.time"
    const val ROW_CARD_SHOW_TIME_LABELS = "courseCard.show.timeLabels"
    const val ROW_CARD_SHOW_WEEKS = "courseCard.show.weeks"
    const val ROW_CARD_SHOW_DESCRIPTION = "courseCard.show.description"
    const val ROW_CARD_VERTICAL_ALIGN = "courseCard.verticalAlign"
    const val ROW_CARD_HORIZONTAL_ALIGN = "courseCard.horizontalAlign"
    const val ROW_CARD_FONT_SIZE = "courseCard.cardFontSize"
    const val ROW_CARD_COMPACT_FONT_SIZE = "courseCard.compactFontSize"
    const val ROW_CARD_UNIFIED_COLOR = "courseCard.unifiedColor"
    const val ROW_CARD_CONFLICT_BADGE = "courseCard.conflictBadge"
    const val ROW_CARD_CONFLICT_OPACITY = "courseCard.conflictOpacity"
    const val ROW_CARD_TEXT_LINK = "courseCard.textColors.link"
    const val ROW_CARD_TEXT_LIGHT_TITLE = "courseCard.textColors.light.title"
    const val ROW_CARD_TEXT_LIGHT_DETAIL = "courseCard.textColors.light.detail"
    const val ROW_CARD_TEXT_DARK_TITLE = "courseCard.textColors.dark.title"
    const val ROW_CARD_TEXT_DARK_DETAIL = "courseCard.textColors.dark.detail"

    /**
     * 统一课卡色的**八色板**（`SettingsInline.id`，不是 `SettingsRow`）。
     *
     * 渲染层以前这里没有 `clickable`，色板点了没反应（2026-10-28 task-15 修）。
     * 现在点一个色块走的就是其它行同一条通路：`WRITE_SETTING` + `target = 该色值 hex`
     * + 本 rowId（**不需要后缀**——一次点击只可能选中一个色值，值从 `target` 来）。
     */
    const val ROW_CARD_COLOR_CHIPS = "courseCard.colorChips"

    // ---------------------------------------------------- 首页与导航（settings-home-navigation）
    // 渲染层实际传来的 target：形态/样式走下拉 option id（form 是 "classic"/"glassDock"，
    // 注意**不是**磁盘值 "glass_dock"），开关不带 target，底栏/菜单的增删移走 target=入口 id
    // 或 "from:to"，reset 不带 target。

    const val ROW_HOME_NAV_FORM = "homeNavigation.form"
    const val ROW_HOME_NAV_MENU_STYLE = "homeNavigation.menuStyle"
    const val ROW_HOME_NAV_HOME_TITLE_STYLE = "homeNavigation.homeTitleStyle"
    const val ROW_HOME_NAV_SHOW_ADD_BUTTON = "homeNavigation.showAddButton"
    const val ROW_HOME_NAV_DOCK_BUTTON_ENTRY = "homeNavigation.dockButtonEntry"

    /** 玻璃坞底栏编辑器：添加 / 移除 / 排序 / 恢复默认（target=入口 id 或 "from:to"）。 */
    const val ROW_DOCK_ADD = "dock.add"
    const val ROW_DOCK_REMOVE = "dock.remove"
    const val ROW_DOCK_MOVE = "dock.move"
    const val ROW_DOCK_RESET = "dock.reset"

    /** 八宫格菜单编辑器：添加 / 移除 / 排序 / 恢复默认。 */
    const val ROW_MENU_ADD = "menu.add"
    const val ROW_MENU_REMOVE = "menu.remove"
    const val ROW_MENU_MOVE = "menu.move"
    const val ROW_MENU_RESET = "menu.reset"

    /** 主题管理页控制卡（`SettingsInline.id`）与它两个按钮的行 id。 */
    const val ROW_THEME_CURRENT = "theme.current"

    /**
     * 「重置为预设」：把 `themeCheckpointConfig` 那份主题快照写回设置。
     * 出处 `settings_appearance.dart:487-496`（`_applyThemeWithUndo(…, themeCheckpointConfig!)`）。
     */
    const val ROW_THEME_CURRENT_RESET = "theme.current.resetToPreset"

    /**
     * 「保存当前主题」：弹保存对话框（`settings_appearance.dart:497-501` 的
     * `_showSaveThemeDialog`）。走 `DIALOG` 意图，对话框本体属宿主/页面层。
     */
    const val ROW_THEME_CURRENT_SAVE = "theme.current.saveCurrent"

    // ---------------------------------------------------- 课表页面设置（settings-timetable-page）
    // 渲染层实际传来的 target：开关不带 target；两个下拉走 option id（页面词汇
    // `hidden/startOnly/startAndEnd` 与 `narrow/wide`）；滑杆是数字字符串。
    // 背景色板见下方 [ROW_TP_BG_CHIPS]。
    const val ROW_TP_AUTO_FIT = "timetablePage.autoFit"
    const val ROW_TP_HIDE_WEEKENDS = "timetablePage.hideWeekends"
    const val ROW_TP_SHOW_OTHER_WEEKS = "timetablePage.showOtherWeeks"
    const val ROW_TP_LONG_PRESS = "timetablePage.longPressEmptySlot"
    const val ROW_TP_WEEK_EXAMS = "timetablePage.weekGridExams"
    const val ROW_TP_WEEK_SCHEDULES = "timetablePage.weekGridSchedules"
    const val ROW_TP_SCREENSHOT = "timetablePage.screenshotShare"
    const val ROW_TP_TIME_DISPLAY = "timetablePage.timeColumnDisplay"
    const val ROW_TP_TIME_WIDTH = "timetablePage.timeColumnWidth"
    const val ROW_TP_SECTION_HEIGHT = "timetablePage.sectionHeight"
    const val ROW_TP_CARD_GAP = "timetablePage.courseCardGap"
    const val ROW_TP_BACK_WEEK_OPACITY = "timetablePage.backToWeek.opacity"

    /**
     * 课表背景色板。渲染层的 `ColorChipGroup` 复用了课卡色板的 rowId（历史原因），
     * 本页宿主会把它拦成本常量；本模型**不拥有** `timetablePageBackgroundColor`，
     * 所以写它只能 Ignored（等背景/材质那一刀扩模型后再接）。
     */
    const val ROW_TP_BG_CHIPS = "timetablePage.background.colorChips"

    /** 恢复默认的作用域名（`settings_reset.dart:17-23` 里的两个）。 */
    const val SCOPE_APPEARANCE = "appearance"
    const val SCOPE_COURSE_CARD = "courseCard"

    // ------------------------------------------------ 外观编辑页：材质（settings-material-*）
    // rowId 与 `pages/settings/SettingsMaterialPanels.kt` 逐字一致；传值约定同其它页：
    // SWITCH 不带 target（取反当前值），RADIO 传 option id（**形状是「跟随 / 实体 / 液态」
    // 与「实体 / 高斯 / 液态」，值见各行的 `options`），SLIDER 传数字字符串。
    const val ROW_MATERIAL_GLASS_MODE = "material.general.glassMode.row"
    const val ROW_MATERIAL_HOME_BAND = "material.general.homeBand.row"
    const val ROW_MATERIAL_PRESET = "material.general.preset"

    /** 浅色档八根旋钮的前缀（后缀 = 参数名，见 [withTuningField]）。 */
    const val ROW_MATERIAL_TUNING_PREFIX = "material.general.tuning."

    /** 深色档八根旋钮的前缀。 */
    const val ROW_MATERIAL_DARK_TUNING_PREFIX = "material.general.darkTuning."

    /** 面板里那颗「恢复默认」（只清液态调参，不动整体材质，`settings_appearance_editor.dart:1058-1085`）。 */
    const val ROW_MATERIAL_RESET = "material.general.reset"
    const val ROW_MATERIAL_DARK_BOOST = "material.general.darkBoost"

    /** ⚠️ 开关语义是「独立设置深色档」，字段存的是「是否跟随」→ 写回要**取反**（`:1106-1118`）。 */
    const val ROW_MATERIAL_DARK_INDEPENDENT = "material.general.darkIndependent"
    const val ROW_MATERIAL_SCOPE_DOCK = "material.general.scopeDock"
    const val ROW_MATERIAL_CARD_SURFACE_STYLE = "material.courseCard.surfaceStyle.row"
    const val ROW_MATERIAL_CARD_PRESET = "material.courseCard.preset"

    /** 卡片档八根旋钮的前缀。 */
    const val ROW_MATERIAL_CARD_TUNING_PREFIX = "material.courseCard.tuning."

    // ------------------------------------------------ 外观编辑页：壁纸（backdrop.*）
    /** 背景随周次翻页滑动（`settings_home_backdrop_flow.dart:780-788`，开关，取反）。 */
    const val ROW_BACKDROP_FOLLOWS_WEEK_PAGER = "backdrop.followsWeekPager"

    /** 壁纸高斯模糊 sigma（`widgets/wallpaper_blur_tile.dart:56-74`，滑杆，0~24 收口）。 */
    const val ROW_BACKDROP_BLUR = "backdrop.blur"

    /**
     * 液态玻璃的「恢复默认」作用域名
     * （`pages/settings/SettingsMaterialPanels.kt` 的 `RESET_SCOPE_LIQUID_GLASS` 逐字一致）。
     *
     * 它**不是** `SettingsResetScope` 的一员（Dart 那颗按钮不走撤销栈，就是一次
     * `copyWith(preset: standard, tuning: defaults)`，`settings_appearance_editor.dart:1062-1070`）。
     */
    const val SCOPE_LIQUID_GLASS = "liquidGlass"

    /** 首页与导航作用域（`settings_reset.dart:29-30` 的 `homeNavigation`）。 */
    const val SCOPE_HOME_NAVIGATION = "homeNavigation"

    /**
     * Dart `TimetableSettings` 的**构造**默认种子色（`timetable_settings.dart:889`）。
     * ⚠️ 与本模型的**读侧**缺键默认 `#2563EB` 不是一个值：恢复默认要回到构造默认。
     */
    const val RESET_THEME_SEED_COLOR = "#3482FF"

    /** 外观作用域恢复默认时写入的 `foruiTheme`（Dart `d.foruiTheme` = miui）。 */
    const val RESET_FORUI_THEME_VALUE = "miui"

    /**
     * 分派一个动作。
     *
     * @param kind 动作类型（页面 `SettingsAction` 的镜像）。
     * @param target 渲染层给出的目标/新值，语义见表见类注释；开关类行为 null。
     * @param rowId 行 id（`SettingsRow.id`），写设置时靠它认字段。
     * @param model 当前设置模型。
     */
    fun dispatch(
        kind: SettingsActionKind,
        target: String?,
        rowId: String,
        model: TimetableSettingsModel,
    ): SettingsDispatch = when (kind) {
        SettingsActionKind.NAVIGATE ->
            target?.let { SettingsDispatch.Navigate(it, rowId) }
                ?: ignored(kind, target, rowId, "NAVIGATE 缺少路由（行的 actionTarget 为空）")

        SettingsActionKind.SHEET -> SettingsDispatch.ShowSheet(target, rowId)

        SettingsActionKind.DIALOG -> SettingsDispatch.ShowDialog(target, rowId)

        SettingsActionKind.COLOR_PICKER -> SettingsDispatch.ShowColorPicker(rowId)

        SettingsActionKind.MATERIAL_PANEL ->
            target?.let { SettingsDispatch.ShowMaterialPanel(it, rowId) }
                ?: ignored(kind, target, rowId, "MATERIAL_PANEL 缺少面板路由")

        SettingsActionKind.RECOLOR_SHEET -> SettingsDispatch.ShowRecolorSheet(rowId)

        SettingsActionKind.RESET_SCOPE ->
            target?.let { SettingsDispatch.ConfirmReset(it, rowId) }
                ?: ignored(kind, target, rowId, "RESET_SCOPE 缺少作用域")

        SettingsActionKind.CLIPBOARD_EXPORT -> SettingsDispatch.ClipboardExport(rowId)

        SettingsActionKind.CLIPBOARD_IMPORT -> SettingsDispatch.ClipboardImport(rowId)

        SettingsActionKind.RUN_NOW -> SettingsDispatch.RunNow(rowId)

        SettingsActionKind.WRITE_SETTING -> writeSetting(kind, target, rowId, model)
    }

    /**
     * 恢复默认：把 [scope] 涉及字段拨回 Dart 的**构造**默认值。
     *
     * 逐字段显式列出（对齐 `settings_reset.dart:50-73` / `:128-157` 的写法），
     * 不用反射、不整体替换——避免顺手把课程数据或别的页的设置一起清掉。
     *
     * @return 新模型；**未知作用域返回 null**（调用方据此什么都不做）。
     */
    fun applyResetScope(model: TimetableSettingsModel, scope: String): TimetableSettingsModel? =
        when (scope) {
            SCOPE_COURSE_CARD -> model.copy(
                // `courseCardSurfaceStyle` 刻意不在本作用域：Dart `settings_reset.dart:51-52`
                // 写明它是材质，2026-09-22 起归「外观」作用域。
                courseCardShowName = true,
                courseCardShowTeacher = true,
                courseCardShowLocation = true,
                courseCardShowTime = false,
                courseCardShowTimeLabels = true,
                courseCardShowWeeks = false,
                courseCardShowDescription = false,
                courseCardVerticalAlign = CourseCardVerticalAlign.CENTER,
                courseCardHorizontalAlign = CourseCardHorizontalAlign.CENTER,
                courseCardFontSize = 9.0,
                compactFontSize = 9.0,
                timetableUseUnifiedCardColor = false,
                timetableUnifiedCardColor = TimetableSettingsModel.DEFAULT_UNIFIED_CARD_COLOR,
                showConflictBadgeOnTimetable = true,
                timetableConflictCourseOpacity = 0.70,
                linkCourseCardColors = true,
                courseCardTitleColorLight = TimetableSettingsModel.DEFAULT_CARD_TITLE_COLOR,
                courseCardTitleColorDark = TimetableSettingsModel.DEFAULT_CARD_TITLE_COLOR,
                courseCardDetailColorLight = TimetableSettingsModel.DEFAULT_CARD_DETAIL_COLOR,
                courseCardDetailColorDark = TimetableSettingsModel.DEFAULT_CARD_DETAIL_COLOR,
            )

            SCOPE_APPEARANCE -> model.copy(
                appThemeMode = AppThemeMode.SYSTEM,
                appFontMode = AppFontMode.SYSTEM,
                appFontWeight = TimetableSettingsModel.APP_FONT_WEIGHT_DEFAULT,
                appTextScale = TimetableSettingsModel.APP_TEXT_SCALE_DEFAULT,
                foruiTheme = ForuiTheme.MIUI,
                // 注意用**构造**默认，不是读侧缺键默认（见 [RESET_THEME_SEED_COLOR]）。
                themeSeedColor = RESET_THEME_SEED_COLOR,
                // 材质那一档（`courseCardSurfaceStyle`）归本作用域（Dart `:154`）。
                courseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
            )

            SCOPE_HOME_NAVIGATION -> model.copy(
                homeNavigationForm = HomeNavigationForm.CLASSIC,
                homeMenuStyle = HomeMenuStyle.LIST,
                homeTitleStyle = HomeTitleStyle.CLASSIC,
                glassDockActions = emptyList(),
                glassDockShowAddButton = false,
                glassDockButtonEntryId = TimetableSettingsModel.DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID,
                glassDockButtonIconName = null,
                glassDockShowDayTab = true,
                glassDockShowSettingsTab = true,
                glassDockShowWeekTab = true,
                homeGridMenuActions = emptyList(),
            )

            // 材质面板里那颗「恢复默认」：**只清液态调参**，不动整体材质
            // （`settings_appearance_editor.dart:1058-1085`，按钮旁边那句说明就是它的范围）。
            SCOPE_LIQUID_GLASS -> resetLiquidGlassTuning(model)

            else -> null
        }

    // ------------------------------------------------------------------ 内部

    private fun writeSetting(
        kind: SettingsActionKind,
        target: String?,
        rowId: String,
        model: TimetableSettingsModel,
    ): SettingsDispatch {
        val next: TimetableSettingsModel = when (rowId) {
            ROW_LOCALE -> model.copy(
                appLocaleTag = TimetableSettingsModel.normalizeAppLocaleTag(target),
            )

            ROW_TRANSITION_SPEED -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "滑杆值不是数字")
                model.copy(
                    pageTransitionSpeed = value.coerceIn(
                        TimetableSettingsModel.MIN_PAGE_TRANSITION_SPEED,
                        TimetableSettingsModel.MAX_PAGE_TRANSITION_SPEED,
                    ),
                )
            }

            ROW_HAPTICS -> model.copy(enableHaptics = !model.enableHaptics)

            ROW_HOLIDAY_ENABLE ->
                model.copy(enableHolidayMarking = !model.enableHolidayMarking)

            ROW_HOME_PULL_IMPORT ->
                model.copy(homePullQuickImportEnabled = !model.homePullQuickImportEnabled)

            ROW_THEME_MODE -> model.copy(appThemeMode = AppThemeMode.fromValue(target))

            ROW_FONT_MODE -> model.copy(appFontMode = AppFontMode.fromValue(target))

            ROW_FONT_WEIGHT -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "字重不是数字")
                model.copy(appFontWeight = TimetableSettingsModel.normalizeAppFontWeight(value))
            }

            ROW_FONT_SIZE -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "字号缩放不是数字")
                model.copy(appTextScale = TimetableSettingsModel.normalizeAppTextScale(value))
            }

            ROW_THEME_PRESET -> applyThemePreset(model, target)
                ?: return ignored(kind, target, rowId, "主题预设值不认识：$target")

            ROW_CARD_SHOW_NAME -> model.copy(courseCardShowName = !model.courseCardShowName)
            ROW_CARD_SHOW_TEACHER -> model.copy(courseCardShowTeacher = !model.courseCardShowTeacher)
            ROW_CARD_SHOW_LOCATION ->
                model.copy(courseCardShowLocation = !model.courseCardShowLocation)
            ROW_CARD_SHOW_TIME -> model.copy(courseCardShowTime = !model.courseCardShowTime)
            ROW_CARD_SHOW_TIME_LABELS ->
                model.copy(courseCardShowTimeLabels = !model.courseCardShowTimeLabels)
            ROW_CARD_SHOW_WEEKS -> model.copy(courseCardShowWeeks = !model.courseCardShowWeeks)
            ROW_CARD_SHOW_DESCRIPTION ->
                model.copy(courseCardShowDescription = !model.courseCardShowDescription)

            ROW_CARD_VERTICAL_ALIGN ->
                model.copy(courseCardVerticalAlign = CourseCardVerticalAlign.fromValue(target))

            ROW_CARD_HORIZONTAL_ALIGN ->
                model.copy(courseCardHorizontalAlign = CourseCardHorizontalAlign.fromValue(target))

            ROW_CARD_FONT_SIZE -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "课卡字号不是数字")
                model.copy(courseCardFontSize = value.coerceIn(FONT_SIZE_MIN, FONT_SIZE_MAX))
            }

            ROW_CARD_COMPACT_FONT_SIZE -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "紧凑字号不是数字")
                model.copy(compactFontSize = value.coerceIn(FONT_SIZE_MIN, FONT_SIZE_MAX))
            }

            ROW_CARD_UNIFIED_COLOR ->
                model.copy(timetableUseUnifiedCardColor = !model.timetableUseUnifiedCardColor)

            ROW_CARD_CONFLICT_BADGE ->
                model.copy(showConflictBadgeOnTimetable = !model.showConflictBadgeOnTimetable)

            ROW_CARD_CONFLICT_OPACITY -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "透明度不是数字")
                model.copy(timetableConflictCourseOpacity = value.coerceIn(0.2, 1.0))
            }

            // 开关显示的是「独立设置详情颜色」= 不联动，所以取反后才是 link 的真值。
            ROW_CARD_TEXT_LINK -> applyTextColorLink(model, link = model.linkCourseCardColors.not())

            ROW_CARD_TEXT_LIGHT_TITLE -> applyTitleColor(model, target, dark = false)
                ?: return ignored(kind, target, rowId, "色值不是 #RRGGBB：$target")

            ROW_CARD_TEXT_LIGHT_DETAIL -> applyDetailColor(model, target, dark = false)
                ?: return ignored(kind, target, rowId, "色值不是 #RRGGBB：$target")

            ROW_CARD_TEXT_DARK_TITLE -> applyTitleColor(model, target, dark = true)
                ?: return ignored(kind, target, rowId, "色值不是 #RRGGBB：$target")

            ROW_CARD_TEXT_DARK_DETAIL -> applyDetailColor(model, target, dark = true)
                ?: return ignored(kind, target, rowId, "色值不是 #RRGGBB：$target")

            // 八色板点一个色块：新值就是那个 hex（task-15 接上的死控件）。
            ROW_CARD_COLOR_CHIPS -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "色板色值不是 #RRGGBB：$target")
                model.copy(timetableUnifiedCardColor = hex)
            }

            // 「重置为预设」：把存档里的主题快照写回去（Dart :487-496）。
            ROW_THEME_CURRENT_RESET -> {
                val config = model.themeCheckpointConfig
                    ?: return ignored(
                        kind,
                        target,
                        rowId,
                        "没有主题存档（themeCheckpointConfig 为空），Dart 同一分支什么都不做",
                    )
                applyThemeCheckpoint(model, config)
            }

            // ---------------------------------------------------- 首页与导航
            ROW_HOME_NAV_FORM -> {
                // 页面下拉的 option id 是 "glassDock"，而枚举磁盘值是 "glass_dock"（见枚举 KDoc），
                // 两个都收，避免「选了玻璃坞却回落经典」。未知值按本刀约定 Ignored（不猜）。
                val form = when (target) {
                    "classic" -> HomeNavigationForm.CLASSIC
                    "glassDock", "glass_dock" -> HomeNavigationForm.GLASS_DOCK
                    else -> return ignored(kind, target, rowId, "首页导航形态不认识：$target")
                }
                model.copy(homeNavigationForm = form)
            }

            ROW_HOME_NAV_MENU_STYLE -> {
                val style = when (target) {
                    "list" -> HomeMenuStyle.LIST
                    "grid" -> HomeMenuStyle.GRID
                    else -> return ignored(kind, target, rowId, "菜单形态不认识：$target")
                }
                model.copy(homeMenuStyle = style)
            }

            ROW_HOME_NAV_HOME_TITLE_STYLE -> {
                val style = when (target) {
                    "classic" -> HomeTitleStyle.CLASSIC
                    "brand" -> HomeTitleStyle.BRAND
                    else -> return ignored(kind, target, rowId, "首页标题样式不认识：$target")
                }
                model.copy(homeTitleStyle = style)
            }

            ROW_HOME_NAV_SHOW_ADD_BUTTON -> model.copy(
                glassDockShowAddButton = !model.glassDockShowAddButton,
            )

            ROW_HOME_NAV_DOCK_BUTTON_ENTRY -> model.copy(
                // 缺省/空串回落 addCourse（Dart `_effectiveGlassDockButtonEntryId` 同口径）。
                glassDockButtonEntryId = target?.takeIf { it.isNotBlank() }
                    ?: TimetableSettingsModel.DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID,
            )

            ROW_DOCK_ADD -> {
                val id = target?.takeIf { it.isNotBlank() }
                    ?: return ignored(kind, target, rowId, "底栏添加缺少入口 id")
                if (model.glassDockActions.size >= TimetableSettingsModel.HOME_DOCK_MENU_MAX_SLOTS ||
                    id in model.glassDockActions
                ) {
                    model
                } else {
                    model.copy(glassDockActions = model.glassDockActions + id)
                }
            }

            ROW_DOCK_REMOVE -> {
                val id = target?.takeIf { it.isNotBlank() }
                    ?: return ignored(kind, target, rowId, "底栏移除缺少入口 id")
                if (model.glassDockActions.size <= 1 || id !in model.glassDockActions) {
                    model
                } else {
                    model.copy(glassDockActions = model.glassDockActions.filter { it != id })
                }
            }

            ROW_DOCK_MOVE -> {
                val (from, to) = parseMoveTarget(target)
                    ?: return ignored(kind, target, rowId, "底栏排序不是 from:to 两个整数：$target")
                val ids = model.glassDockActions
                if (from !in ids.indices || to !in ids.indices) {
                    return ignored(kind, target, rowId, "底栏排序越界：$target")
                }
                val moved = ids.toMutableList()
                moved.add(to, moved.removeAt(from))
                model.copy(glassDockActions = moved)
            }

            ROW_DOCK_RESET -> model.copy(
                glassDockActions = listOf("day", "week", "tasks"),
            )

            ROW_MENU_ADD -> {
                val id = target?.takeIf { it.isNotBlank() }
                    ?: return ignored(kind, target, rowId, "菜单添加缺少入口 id")
                if (model.homeGridMenuActions.size >= TimetableSettingsModel.HOME_GRID_MENU_MAX_SLOTS ||
                    id in model.homeGridMenuActions
                ) {
                    model
                } else {
                    model.copy(
                        homeGridMenuActions = TimetableSettingsModel.normalizeHomeGridMenuActions(
                            model.homeGridMenuActions + id,
                        ),
                    )
                }
            }

            ROW_MENU_REMOVE -> {
                val id = target?.takeIf { it.isNotBlank() }
                    ?: return ignored(kind, target, rowId, "菜单移除缺少入口 id")
                val pinned = TimetableSettingsModel.HOME_GRID_MENU_PINNED_ACTION_ID
                if (id == pinned || id !in model.homeGridMenuActions ||
                    model.homeGridMenuActions.size <= 1
                ) {
                    model
                } else {
                    model.copy(
                        homeGridMenuActions = model.homeGridMenuActions.filter { it != id },
                    )
                }
            }

            ROW_MENU_MOVE -> {
                val (from, to) = parseMoveTarget(target)
                    ?: return ignored(kind, target, rowId, "菜单排序不是 from:to 两个整数：$target")
                val ids = model.homeGridMenuActions
                if (from !in ids.indices || to !in ids.indices) {
                    return ignored(kind, target, rowId, "菜单排序越界：$target")
                }
                val moved = ids.toMutableList()
                moved.add(to, moved.removeAt(from))
                model.copy(homeGridMenuActions = moved)
            }

            ROW_MENU_RESET -> model.copy(
                homeGridMenuActions = listOf(
                    "overview", "statistics", "addCourse", "exams",
                    "tasks", "importCourses", "settings", "support",
                ),
            )

            // ---------------------------------------------------- 外观编辑页：材质（通用页）
            // 总闸两档（`glass_mode_choice.dart:22-40` 的 `applyGlassModeChoice`）：
            // 实体 = 关模糊；液态 = 开模糊**且**顺手打开玻璃坞那把唯一的例外开关。
            // 页面 option id 是 `GlassModeChoice.value`；老渲染层（单行 SuperRadioButton）
            // 不带 target，此时按「两档互切」处理。
            ROW_MATERIAL_GLASS_MODE -> when (target) {
                "solid" -> model.copy(frostedBlurEnabled = false)
                "liquidGlass" -> model.copy(
                    frostedBlurEnabled = true,
                    liquidGlassDockEnabled = true,
                )
                null -> if (model.frostedBlurEnabled) {
                    model.copy(frostedBlurEnabled = false)
                } else {
                    model.copy(frostedBlurEnabled = true, liquidGlassDockEnabled = true)
                }
                else -> return ignored(kind, target, rowId, "默认材质档不认识：$target")
            }

            // 顶栏玻璃带三档（`glass_mode_choice.dart:44-58` 的 `applyHomeBandGlassMaterial`）：
            // 写入口一律过 sanitize，本模型里就是同一份判据（`timetable_settings.dart:339-343`）。
            ROW_MATERIAL_HOME_BAND -> {
                val material = when (target) {
                    TimetableSettingsModel.HOME_BAND_FOLLOW,
                    TimetableSettingsModel.HOME_BAND_SOLID,
                    TimetableSettingsModel.HOME_BAND_LIQUID,
                    -> target
                    else -> return ignored(kind, target, rowId, "顶栏玻璃材质不认识：$target")
                }
                model.copy(
                    homeBandGlassMaterial =
                    TimetableSettingsModel.sanitizeHomeBandGlassMaterial(material),
                )
            }

            // 档位滑杆（10 格）：选一格 = **档位名 + 那档的推荐参数一起写**
            // （`settings_appearance_editor.dart:1026-1042`）。只写档位名会让面板与渲染对不上。
            ROW_MATERIAL_PRESET -> {
                val step = parseStep(target)
                    ?: return ignored(kind, target, rowId, "液态档位不是 1~10 的数字：$target")
                val preset = LiquidGlassTuningModel.fromStep(step)
                model.copy(
                    liquidGlassPreset = preset,
                    liquidGlassTuning = LiquidGlassTuningModel.tuningOfPreset(preset),
                )
            }

            // 面板那颗「恢复默认」（本行 action 是 RESET_SCOPE，正常走确认弹窗后由宿主调
            // [applyResetScope]；这里再兜一条 WRITE_SETTING，两个入口同一份结果）。
            ROW_MATERIAL_RESET -> resetLiquidGlassTuning(model)

            ROW_MATERIAL_DARK_BOOST ->
                model.copy(darkGlassBoostEnabled = !model.darkGlassBoostEnabled)

            // ⚠️ 取反：开关显示的是「独立设置深色档」，字段存的是「是否跟随」
            // （`settings_appearance_editor.dart:1106-1118`）。
            ROW_MATERIAL_DARK_INDEPENDENT -> applyDarkIndependent(model)

            ROW_MATERIAL_SCOPE_DOCK ->
                model.copy(liquidGlassDockEnabled = !model.liquidGlassDockEnabled)

            // ---------------------------------------------------- 外观编辑页：材质（课程卡片页）
            ROW_MATERIAL_CARD_SURFACE_STYLE -> {
                // 页面 option id 就是磁盘值（`SettingsMaterialPanels.kt` 的
                // `CourseCardSurfaceStyle.entries.map { option(it.value, …) }`）。
                val style = CourseCardSurfaceStyle.entries
                    .firstOrNull { it.value == target }
                    ?: return ignored(kind, target, rowId, "课程卡片外观档不认识：$target")
                model.copy(courseCardSurfaceStyle = style)
            }

            ROW_MATERIAL_CARD_PRESET -> {
                val step = parseStep(target)
                    ?: return ignored(kind, target, rowId, "卡片档位不是 1~10 的数字：$target")
                val preset = LiquidGlassTuningModel.fromStep(step)
                model.copy(
                    courseCardGlassPreset = preset,
                    // 卡片那 10 格与全局同值（`course_glass_tuning.dart:73-124` 直接引用全局常量）。
                    courseCardGlassTuning = LiquidGlassTuningModel.tuningOfPreset(preset),
                )
            }

            // ---------------------------------------------------- 外观编辑页：壁纸
            ROW_BACKDROP_FOLLOWS_WEEK_PAGER -> model.copy(
                homePageBackdropFollowsWeekPager = !model.homePageBackdropFollowsWeekPager,
            )

            ROW_BACKDROP_BLUR -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "壁纸模糊量不是数字")
                // 与 Dart `copyWith` 同一道收口（`timetable_settings.dart:2385-2387`）。
                model.copy(
                    homePageWallpaperBlurSigma =
                    TimetableSettingsModel.clampHomePageWallpaperBlurSigma(value),
                )
            }

            // ---------------------------------------------------- 课表页面设置
            ROW_TP_AUTO_FIT -> model.copy(
                timetableAutoFitSectionHeight = !model.timetableAutoFitSectionHeight,
            )

            ROW_TP_HIDE_WEEKENDS -> model.copy(
                timetableHideWeekends = !model.timetableHideWeekends,
            )

            ROW_TP_SHOW_OTHER_WEEKS -> model.copy(
                timetableShowNonCurrentWeekCourses = !model.timetableShowNonCurrentWeekCourses,
            )

            ROW_TP_LONG_PRESS -> model.copy(
                longPressEmptySlotToAddCourseEnabled =
                !model.longPressEmptySlotToAddCourseEnabled,
            )

            ROW_TP_WEEK_EXAMS -> model.copy(weekGridShowExams = !model.weekGridShowExams)

            ROW_TP_WEEK_SCHEDULES -> model.copy(
                weekGridShowSchedules = !model.weekGridShowSchedules,
            )

            ROW_TP_SCREENSHOT -> model.copy(
                screenshotSharePromptEnabled = !model.screenshotSharePromptEnabled,
            )

            ROW_TP_TIME_DISPLAY -> {
                val mode = when (target) {
                    "hidden" -> SectionTimeDisplayMode.HIDDEN
                    "startOnly" -> SectionTimeDisplayMode.START_ONLY
                    "startAndEnd" -> SectionTimeDisplayMode.START_AND_END
                    else -> return ignored(kind, target, rowId, "节次时间显示方式不认识：$target")
                }
                model.copy(timetableSectionTimeDisplayMode = mode)
            }

            ROW_TP_TIME_WIDTH -> {
                val width = when (target) {
                    "narrow" -> TimetableTimeColumnWidthMode.NARROW
                    "wide" -> TimetableTimeColumnWidthMode.WIDE
                    else -> return ignored(kind, target, rowId, "时间栏宽度不认识：$target")
                }
                model.copy(timetableTimeColumnWidthMode = width)
            }

            ROW_TP_SECTION_HEIGHT -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "节次高度不是数字")
                model.copy(sectionHeight = value.coerceIn(48.0, 92.0))
            }

            ROW_TP_CARD_GAP -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "课程卡间距不是数字")
                model.copy(timetableCourseCardGap = value.coerceIn(0.0, 3.0))
            }

            ROW_TP_BACK_WEEK_OPACITY -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "浮钮不透明度不是数字")
                model.copy(
                    timetableFloatingBackToCurrentWeekButtonOpacity = value.coerceIn(0.55, 1.0),
                )
            }

            // 模型不拥有课表页背景色：明确 Ignored，别让它落到课卡字段上。
            ROW_TP_BG_CHIPS -> return ignored(
                kind,
                target,
                rowId,
                "课表背景色不在本模型覆盖范围（背景/材质批次再补）",
            )

            else -> {
                // 主题管理页的预设是 RADIO，渲染层不给 target，值只能从 rowId 后缀取。
                if (rowId.startsWith(ROW_THEME_PRESET_PREFIX)) {
                    val presetValue = rowId.removePrefix(ROW_THEME_PRESET_PREFIX)
                    applyThemePreset(model, presetValue)
                        ?: return ignored(kind, target, rowId, "主题预设值不认识：$presetValue")
                } else {
                    // 材质面板的三组八根旋钮走**前缀**（后缀 = 参数名），`when (rowId)` 的
                    // 等值分支写不了前缀，所以留在这里认。
                    return applyMaterialTuningRow(model, target, rowId)
                        ?: ignored(
                            kind,
                            target,
                            rowId,
                            "未识别的 rowId（本刀只接通用/外观/主题管理/课程卡片/首页与导航/材质/壁纸）",
                        )
                }
            }
        }
        return SettingsDispatch.Write(next, rowId)
    }

    /**
     * 把主题快照（`themeCheckpointConfig`，Dart `ThemeConfig.toJson` 的**短键**）写回模型。
     *
     * 键名逐字对照 `lib/models/timetable_settings.dart:123-144`：
     * `seed` / `uc` / `ucOn` / `mode` / `ccl` / `ccd` / `cdl` / `cdd` /
     * `wbl` / `wbd` / `wal` / `wad` / `tal` / `tad` / `link` / `hideWeekend` /
     * `spacing` / `timeDisplay`。
     *
     * **只认本模型拥有的键**：快照里还可能有材质/玻璃调参（`bg` 等）不在本模型覆盖范围，
     * 原样忽略——本方法不会碰它们，也不会因此崩（Dart 侧那些键由材质那一刀负责）。
     * 值缺失 / 类型不符 / 色值非法一律**保持原值**（宽松读，与 Dart `ThemeConfig.fromJson` 同口径）。
     */
    private fun applyThemeCheckpoint(
        model: TimetableSettingsModel,
        config: Map<String, Any?>,
    ): TimetableSettingsModel =
        THEME_CHECKPOINT_FIELDS.fold(model) { acc, field ->
            if (!config.containsKey(field.key)) {
                acc
            } else {
                field.apply(acc, config[field.key]) ?: acc
            }
        }

    /**
     * 当前主题设置是否**偏离了存档里的检查点**（Dart `hasThemeModifications`，
     * `lib/models/timetable_settings.dart:2482-2493`）。
     *
     * ## 口径（逐条对齐 Dart，行号可查）
     *
     * - `themeCheckpointConfig == null` ⇒ `false`（`:2483`）；
     * - **只比较检查点里「有值」的字段**：`getter(checkpoint) == null` 就跳过（`:2488-2492`）——
     *   检查点没记过的字段，用户怎么改都不算「基于该主题的改动」；
     * - 比较用**原始值**：颜色按字符串逐字比（**不做大小写归一**）、
     *   布尔按 `.toString()` 比（`:2497` `useUnifiedCardColor?.toString()` / `:2509` / `:2510`）、
     *   枚举/文本按字符串比（`:2498` `themeMode`、`:2511` `spacingMode`、`:2512` `timeDisplayMode`）。
     *   所以本方法**不**复用 [applyThemeCheckpoint] 的写回归一化（那会把颜色转成大写、把未知枚举
     *   回落默认值），而是与快照原始值直接比——两者只有「键表」这一份是共用的。
     * - 快照值的类型按 Dart `ThemeConfig.fromJson` 的宽松读解析（字符串 / 布尔）；
     *   解析不出（例如该键是数字）⇒ 与 Dart 一样视为「这个字段没记过」，跳过。
     *
     * ## 与 Dart 的**已知差异**（都是「本模型覆盖范围」的边界，不是口径选择）
     *
     * - `backgroundColor`（短键 `bg`）在 Dart 的 19 项里（`:2495`），但**不在本模型的 61 键里**
     *   （课表页背景色属材质/背景那一刀）⇒ 只差 `bg` 时这里返回 `false`，Dart 会返回 `true`；
     * - 快照里颜色写成小写（`#ffffff`）而当前值是大写时：Dart 逐字比 ⇒ `true`，
     *   本方法同样逐字比 ⇒ 也是 `true`（一致；写回路径才会归一成大写）。
     */
    fun hasThemeModifications(model: TimetableSettingsModel): Boolean {
        val config = model.themeCheckpointConfig ?: return false
        return THEME_CHECKPOINT_FIELDS.any { field ->
            val raw = config[field.key] ?: return@any false
            val checkpointValue = field.lenientValue(raw) ?: return@any false
            field.read(model).toString() != checkpointValue.toString()
        }
    }

    /**
     * 主题快照的**唯一一张键表**：写回（[applyThemeCheckpoint]）与「是否有改动」
     * （[hasThemeModifications]）共用，别在别处再抄一份。
     *
     * 键名逐字对照 Dart `ThemeConfig.toJson`（`lib/models/timetable_settings.dart:123-144`）。
     * Dart `hasThemeModifications` 的比较清单见 `:2494-2512`——顺序一致，只少一个 `bg`
     * （见 [hasThemeModifications] 的差异说明）。
     */
    private val THEME_CHECKPOINT_FIELDS: List<ThemeCheckpointField> = listOf(
        ThemeCheckpointField("seed", ThemeCheckpointKind.COLOR, { it.themeSeedColor }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(themeSeedColor = it) }
        },
        ThemeCheckpointField("uc", ThemeCheckpointKind.COLOR, { it.timetableUnifiedCardColor }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(timetableUnifiedCardColor = it) }
        },
        ThemeCheckpointField(
            "ucOn",
            ThemeCheckpointKind.BOOL,
            { it.timetableUseUnifiedCardColor },
        ) { m, v -> LenientJson.bool(v)?.let { m.copy(timetableUseUnifiedCardColor = it) } },
        ThemeCheckpointField("mode", ThemeCheckpointKind.TEXT, { it.appThemeMode.value }) { m, v ->
            (v as? String)?.takeIf { it.isNotBlank() }
                ?.let { m.copy(appThemeMode = AppThemeMode.fromValue(it)) }
        },
        ThemeCheckpointField("ccl", ThemeCheckpointKind.COLOR, { it.courseCardTitleColorLight }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(courseCardTitleColorLight = it) }
        },
        ThemeCheckpointField("ccd", ThemeCheckpointKind.COLOR, { it.courseCardTitleColorDark }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(courseCardTitleColorDark = it) }
        },
        ThemeCheckpointField("cdl", ThemeCheckpointKind.COLOR, { it.courseCardDetailColorLight }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(courseCardDetailColorLight = it) }
        },
        ThemeCheckpointField("cdd", ThemeCheckpointKind.COLOR, { it.courseCardDetailColorDark }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(courseCardDetailColorDark = it) }
        },
        ThemeCheckpointField("wbl", ThemeCheckpointKind.COLOR, { it.weekdayBarFontColorLight }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(weekdayBarFontColorLight = it) }
        },
        ThemeCheckpointField("wbd", ThemeCheckpointKind.COLOR, { it.weekdayBarFontColorDark }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(weekdayBarFontColorDark = it) }
        },
        ThemeCheckpointField("wal", ThemeCheckpointKind.COLOR, { it.weekdayBarAccentColorLight }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(weekdayBarAccentColorLight = it) }
        },
        ThemeCheckpointField("wad", ThemeCheckpointKind.COLOR, { it.weekdayBarAccentColorDark }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(weekdayBarAccentColorDark = it) }
        },
        ThemeCheckpointField("tal", ThemeCheckpointKind.COLOR, { it.timeAxisFontColorLight }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(timeAxisFontColorLight = it) }
        },
        ThemeCheckpointField("tad", ThemeCheckpointKind.COLOR, { it.timeAxisFontColorDark }) { m, v ->
            normalizeHexColor(v as? String)?.let { m.copy(timeAxisFontColorDark = it) }
        },
        ThemeCheckpointField("link", ThemeCheckpointKind.BOOL, { it.linkCourseCardColors }) { m, v ->
            LenientJson.bool(v)?.let { m.copy(linkCourseCardColors = it) }
        },
        ThemeCheckpointField("hideWeekend", ThemeCheckpointKind.BOOL, { it.timetableHideWeekends }) { m, v ->
            LenientJson.bool(v)?.let { m.copy(timetableHideWeekends = it) }
        },
        ThemeCheckpointField(
            "spacing",
            ThemeCheckpointKind.TEXT,
            { it.timetableCourseSpacingMode.value },
        ) { m, v ->
            (v as? String)?.takeIf { it.isNotBlank() }
                ?.let { m.copy(timetableCourseSpacingMode = TimetableCourseSpacingMode.fromValue(it)) }
        },
        ThemeCheckpointField(
            "timeDisplay",
            ThemeCheckpointKind.TEXT,
            { it.timetableSectionTimeDisplayMode.value },
        ) { m, v ->
            (v as? String)?.takeIf { it.isNotBlank() }
                ?.let { m.copy(timetableSectionTimeDisplayMode = SectionTimeDisplayMode.fromValue(it)) }
        },
    )

    /**
     * 选主题预设：**同时**写 `foruiTheme` 与 `themeSeedColor = preset.seedHex`。
     *
     * 出处：`settings_appearance.dart:352-353`（外观页下拉）与 `:721-722`（主题管理页单选）。
     * 只写 foruiTheme 会让预览卡的主色停在旧种子色——那是 Dart 明写的联动。
     *
     * @return null 表示 [presetValue] 不是已知预设（调用方记 Ignored）。
     */
    private fun applyThemePreset(
        model: TimetableSettingsModel,
        presetValue: String?,
    ): TimetableSettingsModel? {
        if (presetValue == null) return null
        val preset = ForuiTheme.entries.firstOrNull { it.value == presetValue } ?: return null
        return model.copy(foruiTheme = preset, themeSeedColor = preset.seedHex)
    }

    /**
     * 文字颜色联动开关（`timetable_text_color_settings.dart:67-81`）。
     *
     * - 打开联动（`link = true`）：详情色**跟随**标题色（两套都写）；
     * - 关掉联动（`link = false`）：只改开关，详情色保持用户自己的值。
     */
    private fun applyTextColorLink(
        model: TimetableSettingsModel,
        link: Boolean,
    ): TimetableSettingsModel = if (link) {
        model.copy(
            linkCourseCardColors = true,
            courseCardDetailColorLight = model.courseCardTitleColorLight,
            courseCardDetailColorDark = model.courseCardTitleColorDark,
        )
    } else {
        model.copy(linkCourseCardColors = false)
    }

    /**
     * 标题色：联动为真时**详情色跟着走**（`timetable_text_color_settings.dart:101-111`
     * 浅色；深色同口径）。
     *
     * @return null 表示色值非法（调用方记 Ignored）。
     */
    private fun applyTitleColor(
        model: TimetableSettingsModel,
        color: String?,
        dark: Boolean,
    ): TimetableSettingsModel? {
        val hex = normalizeHexColor(color) ?: return null
        return if (dark) {
            model.copy(
                courseCardTitleColorDark = hex,
                courseCardDetailColorDark = if (model.linkCourseCardColors) {
                    hex
                } else {
                    model.courseCardDetailColorDark
                },
            )
        } else {
            model.copy(
                courseCardTitleColorLight = hex,
                courseCardDetailColorLight = if (model.linkCourseCardColors) {
                    hex
                } else {
                    model.courseCardDetailColorLight
                },
            )
        }
    }

    /** 详情色：独立设置时才会走到这里（联动时那一行是禁用态）。 */
    private fun applyDetailColor(
        model: TimetableSettingsModel,
        color: String?,
        dark: Boolean,
    ): TimetableSettingsModel? {
        val hex = normalizeHexColor(color) ?: return null
        return if (dark) {
            model.copy(courseCardDetailColorDark = hex)
        } else {
            model.copy(courseCardDetailColorLight = hex)
        }
    }

    // ------------------------------------------------------- 外观编辑页：材质与壁纸

    /**
     * 材质面板那三组八根旋钮（`material.general.tuning.*` / `material.general.darkTuning.*`
     * / `material.courseCard.tuning.*`）。不在任何分支里的 rowId 返回 null，由调用方记 Ignored。
     *
     * 三组的**写法不一样**，逐条照 Dart：
     * - 浅色档：写参数 + 档位打成 `custom`（`settings_appearance_editor.dart:1355-1370`）；
     * - 深色档：只写参数，**不动档位**——深色那套没有独立档名（`:1373-1384`）；
     * - 卡片档：写参数 + 卡片档位打成 `custom`（`:1395-1401`）。
     */
    private fun applyMaterialTuningRow(
        model: TimetableSettingsModel,
        target: String?,
        rowId: String,
    ): SettingsDispatch? {
        val (prefix, family) = when {
            rowId.startsWith(ROW_MATERIAL_DARK_TUNING_PREFIX) ->
                ROW_MATERIAL_DARK_TUNING_PREFIX to TuningFamily.DARK

            rowId.startsWith(ROW_MATERIAL_TUNING_PREFIX) ->
                ROW_MATERIAL_TUNING_PREFIX to TuningFamily.LIGHT

            rowId.startsWith(ROW_MATERIAL_CARD_TUNING_PREFIX) ->
                ROW_MATERIAL_CARD_TUNING_PREFIX to TuningFamily.CARD

            else -> return null
        }
        val field = rowId.removePrefix(prefix)
        val value = parseDouble(target)
            ?: return ignored(
                SettingsActionKind.WRITE_SETTING,
                target,
                rowId,
                "液态玻璃滑杆值不是数字",
            )
        val base = when (family) {
            TuningFamily.LIGHT -> model.liquidGlassTuning ?: LiquidGlassTuningModel.DEFAULTS
            // 回落链必须与面板读的那条一致（深色档 ?? 浅色档 ?? 默认），否则拖杆会从另一档初值开始跳。
            TuningFamily.DARK -> model.liquidGlassTuningDark
                ?: model.liquidGlassTuning
                ?: LiquidGlassTuningModel.DEFAULTS

            TuningFamily.CARD -> model.courseCardGlassTuning ?: LiquidGlassTuningModel.DEFAULTS
        }
        val updated = withTuningField(base, field, value)
            ?: return ignored(
                SettingsActionKind.WRITE_SETTING,
                target,
                rowId,
                "不认识的液态玻璃参数：$field",
            )
        val next = when (family) {
            TuningFamily.LIGHT -> model.copy(
                liquidGlassTuning = updated,
                liquidGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM,
            )

            TuningFamily.DARK -> model.copy(liquidGlassTuningDark = updated)

            TuningFamily.CARD -> model.copy(
                courseCardGlassTuning = updated,
                courseCardGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_CUSTOM,
            )
        }
        return SettingsDispatch.Write(next, rowId)
    }

    /**
     * 改一个参数并**按滑杆区间收口**（`liquid_glass_tuning.dart:522-539` 的 `clamped()`）。
     *
     * 后缀名就是面板行 id 的后缀（`SettingsMaterialPanels.kt` 的 `$idPrefix.<name>`）；
     * 染色那一根面板写作 `tint`，Dart 字段叫 `tintAlpha`，两个都收。
     *
     * @return null 表示后缀不认识（调用方记 Ignored，不猜）。
     */
    private fun withTuningField(
        tuning: LiquidGlassTuningModel,
        field: String,
        value: Double,
    ): LiquidGlassTuningModel? = when (field) {
        "refraction" -> tuning.copy(
            refraction = value.coerceIn(
                LiquidGlassTuningModel.MIN_REFRACTION,
                LiquidGlassTuningModel.MAX_REFRACTION,
            ),
        )

        "refractionBand" -> tuning.copy(
            refractionBand = value.coerceIn(
                LiquidGlassTuningModel.MIN_REFRACTION_BAND,
                LiquidGlassTuningModel.MAX_REFRACTION_BAND,
            ),
        )

        "edgePow" -> tuning.copy(
            refractionEdgePow = value.coerceIn(
                LiquidGlassTuningModel.MIN_REFRACTION_EDGE_POW,
                LiquidGlassTuningModel.MAX_REFRACTION_EDGE_POW,
            ),
        )

        "dispersion" -> tuning.copy(
            dispersion = value.coerceIn(
                LiquidGlassTuningModel.MIN_DISPERSION,
                LiquidGlassTuningModel.MAX_DISPERSION,
            ),
        )

        "rimStrength" -> tuning.copy(
            rimStrength = value.coerceIn(
                LiquidGlassTuningModel.MIN_RIM_STRENGTH,
                LiquidGlassTuningModel.MAX_RIM_STRENGTH,
            ),
        )

        "rimWidth" -> tuning.copy(
            rimWidth = value.coerceIn(
                LiquidGlassTuningModel.MIN_RIM_WIDTH,
                LiquidGlassTuningModel.MAX_RIM_WIDTH,
            ),
        )

        "blurSigma" -> tuning.copy(
            blurSigma = value.coerceIn(
                LiquidGlassTuningModel.MIN_BLUR_SIGMA,
                LiquidGlassTuningModel.MAX_BLUR_SIGMA,
            ),
        )

        "tint", "tintAlpha" -> tuning.copy(
            tintAlpha = value.coerceIn(
                LiquidGlassTuningModel.MIN_TINT_ALPHA,
                LiquidGlassTuningModel.MAX_TINT_ALPHA,
            ),
        )

        else -> null
    }

    /**
     * 液态调参恢复默认（`settings_appearance_editor.dart:1062-1070`）：档位回 `standard`、
     * 参数回出厂档。**不动**深色档与其它材质开关 —— 那颗按钮旁边那句说明就是它的范围。
     */
    private fun resetLiquidGlassTuning(
        model: TimetableSettingsModel,
    ): TimetableSettingsModel = model.copy(
        liquidGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD,
        liquidGlassTuning = LiquidGlassTuningModel.DEFAULTS,
    )

    /**
     * 「独立设置深色档」开关（`settings_appearance_editor.dart:1106-1118`）。
     *
     * 开关显示的是**独立**、字段存的是**是否跟随**，所以取反后再写：
     * - 打开独立（`link` 变 false）：从没设过深色档时**以浅色档为起点**，这一按不会让画面跳；
     * - 关掉独立（`link` 变 true）：**保留**深色那套 —— Dart 的 `copyWith` 对可空字段是 `??`
     *   语义、清不掉它，注释写明「关掉只是不使用，再打开要拿回原来那套」（`:679-682`）。
     */
    private fun applyDarkIndependent(
        model: TimetableSettingsModel,
    ): TimetableSettingsModel = if (model.linkLiquidGlassTuning) {
        model.copy(
            linkLiquidGlassTuning = false,
            liquidGlassTuningDark = model.liquidGlassTuningDark
                ?: model.liquidGlassTuning
                ?: LiquidGlassTuningModel.DEFAULTS,
        )
    } else {
        model.copy(linkLiquidGlassTuning = true)
    }

    /** 10 格档位滑杆 → 第几格：Dart 那边是 `value.round()` 再 `fromStep`（`:1449`）。 */
    private fun parseStep(raw: String?): Int? = raw?.trim()?.toDoubleOrNull()?.roundToInt()

    /**
     * 色值归一：只收 `#RRGGBB` / `#AARRGGBB`（大小写不敏感，统一大写）。
     * 别的一律 null ⇒ Ignored——宁可不动，也不要把脏字符串写进存档。
     */
    private fun normalizeHexColor(raw: String?): String? {
        val text = raw?.trim().orEmpty()
        if (text.length != 7 && text.length != 9) return null
        if (!text.startsWith("#")) return null
        if (!text.drop(1).all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) return null
        return "#" + text.drop(1).uppercase()
    }

    private fun parseDouble(raw: String?): Double? = raw?.trim()?.toDoubleOrNull()

    /**
     * 解析底栏/菜单排序的 `"from:to"`（两个整数，冒号分隔）。
     * 段数不对、非整数一律 null ⇒ 调用方记 Ignored（不猜、不动列表）。
     */
    private fun parseMoveTarget(raw: String?): Pair<Int, Int>? {
        val parts = raw?.split(":") ?: return null
        if (parts.size != 2) return null
        val from = parts[0].trim().toIntOrNull() ?: return null
        val to = parts[1].trim().toIntOrNull() ?: return null
        return from to to
    }

    private fun ignored(
        kind: SettingsActionKind,
        target: String?,
        rowId: String,
        reason: String,
    ): SettingsDispatch = SettingsDispatch.Ignored(kind, target, rowId, reason)

    /** 课卡字号滑杆的上下限（`SettingsCourseCardPage.kt:63-64`：7.0~12.0）。 */
    private const val FONT_SIZE_MIN = 7.0
    private const val FONT_SIZE_MAX = 12.0
}

/** 主题快照字段的取值口径（决定宽松解析方式）。 */
private enum class ThemeCheckpointKind {
    /** 颜色：字符串 + `#RRGGBB` 校验。 */
    COLOR,

    /** 布尔。 */
    BOOL,

    /** 文本 / 枚举值字符串。 */
    TEXT,
}

/**
 * 主题快照里的一个字段（[SettingsActionDispatcher] 的 `THEME_CHECKPOINT_FIELDS` 用）。
 *
 * 一张表同时服务两件事：写回（[SettingsActionDispatcher.applyThemeCheckpoint]）与
 * 「是否有改动」（[SettingsActionDispatcher.hasThemeModifications]）——**别在别处再抄一份**。
 *
 * @param key Dart `ThemeConfig.toJson` 的短键（`timetable_settings.dart:123-144`）。
 * @param kind 宽松解析口径。
 * @param read 当前值（比较时按 Dart 口径 `.toString()`；颜色返回原样字符串，**不归一大小写**）。
 * @param apply 写回；返回 `null` 表示这个快照值本模型用不了（保持原值）。
 */
private class ThemeCheckpointField(
    val key: String,
    val kind: ThemeCheckpointKind,
    val read: (TimetableSettingsModel) -> Any?,
    val apply: (TimetableSettingsModel, Any?) -> TimetableSettingsModel?,
) {
    /**
     * Dart `ThemeConfig.fromJson` 的宽松读：解析不出（类型不符）⇒ `null`。
     * 在 [SettingsActionDispatcher.hasThemeModifications] 里 `null` 等价于
     * 「检查点没记过这个字段」，跳过不比较（`:2488-2492`）。
     */
    fun lenientValue(raw: Any?): Any? = when (kind) {
        ThemeCheckpointKind.COLOR, ThemeCheckpointKind.TEXT -> LenientJson.string(raw)
        ThemeCheckpointKind.BOOL -> LenientJson.bool(raw)
    }
}

/** 材质面板三组八根旋钮各自写哪：浅色档 / 深色档 / 课程卡片档（见 `applyMaterialTuningRow`）。 */
private enum class TuningFamily {
    LIGHT,
    DARK,
    CARD,
}
