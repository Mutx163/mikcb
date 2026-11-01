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

    /**
     * 写设置：宿主落盘 [model] 并重组界面。
     *
     * [wallpaperTarget] 非空时**不写设置**（[model] 原样）：它表示「壁纸面板发来的一条
     * 数据动作」，要碰文件 / 网络 / 设备级台账，必须由宿主执行（理由见
     * [SettingsActionDispatcher.wallpaperIntentTarget]）。
     */
    data class Write(
        val model: TimetableSettingsModel,
        val rowId: String,
        val wallpaperTarget: String? = null,
    ) : SettingsDispatch

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

    // ---------------------------------------------------- 桌面小组件（settings-home-widget）
    // rowId 与 `pages/settings/SettingsHomeWidgetPage.kt` 的 spec 逐字一致；传值约定同其它页：
    // 三个下拉传 option id（都是**落盘串**，合法值表见 `TimetableSettingsModel.WIDGET_*`）、
    // 四个开关不带 target（取反），两个滑杆传数字字符串（高度是**相对默认档的偏移**），
    // 倒计时提前量传档位串（"0" = 始终显示，其余见 `WIDGET_COUNTDOWN_LEAD_MINUTES`）。
    const val ROW_HOME_WIDGET_BACKGROUND_STYLE = "homeWidget.backgroundStyle"
    const val ROW_HOME_WIDGET_COURSE_ACCENT = "homeWidget.courseAccent"
    const val ROW_HOME_WIDGET_SHOW_LOCATION = "homeWidget.showLocation"
    const val ROW_HOME_WIDGET_SHOW_COUNTDOWN = "homeWidget.showCountdown"
    const val ROW_HOME_WIDGET_HIDE_COMPLETED = "homeWidget.hideCompleted"
    const val ROW_HOME_WIDGET_SHOW_TOMORROW = "homeWidget.showTomorrow"
    const val ROW_HOME_WIDGET_COUNTDOWN_LEAD = "homeWidget.countdownLead"
    const val ROW_HOME_WIDGET_COUNTDOWN_STYLE = "homeWidget.countdownStyle"
    const val ROW_HOME_WIDGET_HEIGHT_ADJUST = "homeWidget.heightAdjust"
    const val ROW_HOME_WIDGET_CORNER_RADIUS = "homeWidget.cornerRadius"

    /**
     * 「添加到桌面」与「去授权精确闹钟」两个 **RUN_NOW** 动作
     * （`settings_home_widget.dart:405-499` 预览区块的按钮 / `:1036-1065` 的权限引导条）。
     *
     * 它们**不写设置**：真正的 AppWidget 绑定 / 系统授权页跳转由宿主执行。
     * 这里登记常量是为了让宿主与页面共用同一份字面量；万一宿主漏接、页面把它当
     * WRITE_SETTING 发过来，分派器会给出「这是 RUN_NOW 行、不是设置行」的明确
     * Ignored 理由，而不是落到 else 分支变成一句含糊的「未识别 rowId」。
     */
    const val ROW_HOME_WIDGET_PREVIEW_ADD = "homeWidget.preview.add"
    const val ROW_HOME_WIDGET_ALARM_GRANT = "homeWidget.preview.alarmBanner"

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
     * 课表背景色板（`SettingsInline.id`，不是 `SettingsRow`）。
     *
     * 本模型自 2026-11-01 起拥有 `timetablePageBackgroundColor`（Dart `:556`），
     * 点一个色块 = `WRITE_SETTING` + `target = 色值 hex` + 本 rowId。
     *
     * ⚠️ 渲染层 `ColorChipGroup`（composeP1 `SettingsPageRenderers.kt:1142-1148`）目前
     * 对**所有**色板组都回传 `ROW_CARD_COLOR_CHIPS`，所以课表页色板实际仍写到统一课卡色。
     * 分派器这一支是对的，等渲染层改成回传 `node.id` 后即生效（登记给 Lead）。
     */
    const val ROW_TP_BG_CHIPS = "timetablePage.background.colorChips"

    /** 课表页背景随周次滑动（与 [ROW_BACKDROP_FOLLOWS_WEEK_PAGER] 同一个设置，开关，取反）。 */
    const val ROW_TP_BG_FOLLOWS_WEEK = "timetablePage.background.followsWeek"

    /** 课表页壁纸模糊（与 [ROW_BACKDROP_BLUR] 同一个设置，滑杆，0~24 收口）。 */
    const val ROW_TP_BG_BLUR = "timetablePage.background.blur"

    /** 课表页「背景图片」行（SHEET，打开壁纸面板第一页）。 */
    const val ROW_TP_BG_IMAGE = "timetablePage.background.image"

    /** 课表页「最近使用」行（SHEET，打开壁纸面板第一页）。 */
    const val ROW_TP_BG_RECENT = "timetablePage.background.recent"

    /** 课表页三个选色行（`COLOR_PICKER`；写回是本文件 [writeSetting] 的三个 `*.textColors.*` 分支）。 */
    const val ROW_TP_TEXT_WEEKDAY = "timetablePage.textColors.weekday"
    const val ROW_TP_TEXT_WEEKDAY_ACCENT = "timetablePage.textColors.weekdayAccent"
    const val ROW_TP_TEXT_TIME_AXIS = "timetablePage.textColors.timeAxis"

    // 深色模式三条（2026-11-01 F26）。串必须与页面侧
    // `SettingsTimetablePageSettingsPage.ROW_TEXT_*` 逐字一致。
    const val ROW_TP_TEXT_WEEKDAY_DARK = "timetablePage.textColors.dark.weekday"
    const val ROW_TP_TEXT_WEEKDAY_ACCENT_DARK = "timetablePage.textColors.dark.weekdayAccent"
    const val ROW_TP_TEXT_TIME_AXIS_DARK = "timetablePage.textColors.dark.timeAxis"

    /** 恢复默认的作用域名（`settings_reset.dart:17-23` 里的两个）。 */
    const val SCOPE_APPEARANCE = "appearance"
    const val SCOPE_COURSE_CARD = "courseCard"

    /**
     * 课表页面作用域（`settings_reset.dart:74-122`）。
     *
     * 与 `pages/settings/SettingsResetPage.SettingsResetScope.TIMETABLE_PAGE.arg` 逐字一致；
     * 2026-11-01 前分派器**没有这个分支**，用户确认后 `applyResetScope` 返回 null、
     * 宿主什么都不写——看着弹了确认框，实际一个字段都没恢复。
     */
    const val SCOPE_TIMETABLE_PAGE = "timetablePage"

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
     * 「清除图片」行（`settings_home_backdrop_flow.dart:927-933`）。
     *
     * 只清设置里的两条路径，**不删文件**：图可能还在「最近使用」里，删文件由历史淘汰
     * 负责（Dart 同口径）。写回口径见 [writeSetting] 的同名分支。
     */
    const val ROW_BACKDROP_IMAGE_CLEAR = "backdrop.image.clear"

    /**
     * 「每天自动更换」开关（模型行 id `backdrop.bing.autoApply`）。
     *
     * 它的真源是设备级台账（`BingWallpaperStore`），不在设置模型里；渲染层拿到的
     * `onCheckedChange` 又不带新值，所以宿主只能按台账现值取反
     * （Dart `settings_home_backdrop_flow.dart:537-555`）。
     */
    const val ROW_BACKDROP_AUTO_APPLY = "backdrop.bing.autoApply"

    // 壁纸面板「要碰文件 / 网络」的 target 前缀。与 `pages/settings` 的
    // `WallpaperSheetActionTargets` **逐字一致**（有契约测试钉住）；不在本文件写第二份
    // 的行为，只做目标判定（见 [wallpaperIntentTarget]）。
    const val WALLPAPER_PICKED_PREFIX = "backdrop.image.picked:"
    const val WALLPAPER_SELECT_PREFIX = "backdrop.recent.select:"
    const val WALLPAPER_CONFIRM_DELETE_PREFIX = "backdrop.recent.confirmDelete:"
    const val WALLPAPER_UNDO_REMOVE_PREFIX = "backdrop.recent.undoRemove:"

    /**
     * 壁纸面板里需要**宿主**执行的 target：命中返回原串，否则 null。
     *
     * ## 为什么不在这里直接写设置
     *
     * 这四类动作（收图 / 切历史 / 删与撤销 / 自动换开关）要摸文件、网络与设备级台账；
     * 而 `app/` 必须保持纯 Kotlin（`AppLayerPurityTest` 禁止 import `pages.settings`），
     * 也不能 import Compose / Android。所以分派器只把原始 target 装进
     * [SettingsDispatch.Write.wallpaperTarget]，由外观编辑页宿主用
     * `parseWallpaperSheetTarget` 解析后执行。
     *
     * ## 认哪些
     *
     * * 四个前缀：`backdrop.image.picked:` / `backdrop.recent.select:` /
     *   `backdrop.recent.confirmDelete:` / `backdrop.recent.undoRemove:`；
     * * 自动换是精确串 `backdrop.bing.autoApply`：渲染层的开关不带 target，
     *   所以 **rowId 兜底**也认（面板本应先把 target 补出来，这里再兜一层）。
     *
     * 「清除图片」（`backdrop.image.clear`）**不在这里**：它只清设置、不碰文件，
     * 继续走下面按 rowId 的纯写入分支。
     */
    fun wallpaperIntentTarget(target: String?, rowId: String): String? = when {
        target != null && target.startsWith(WALLPAPER_PICKED_PREFIX) -> target
        target != null && target.startsWith(WALLPAPER_SELECT_PREFIX) -> target
        target != null && target.startsWith(WALLPAPER_CONFIRM_DELETE_PREFIX) -> target
        target != null && target.startsWith(WALLPAPER_UNDO_REMOVE_PREFIX) -> target
        target == ROW_BACKDROP_AUTO_APPLY -> target
        rowId == ROW_BACKDROP_AUTO_APPLY -> rowId
        else -> null
    }

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
     * 桌面小组件作用域（`settings_reset.dart` 的 `SettingsResetScope.homeWidget`，
     * 恢复分支 `:175-189`）。
     *
     * 值必须与 `pages/settings/SettingsHomeWidgetPage.RESET_SCOPE_HOME_WIDGET` 逐字一致
     * （那侧同名常量写的是 `"homeWidget"`）。
     */
    const val SCOPE_HOME_WIDGET = "homeWidget"

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
                // 2026-09-22 起材质轴整体从「课表页面」划到「外观」
                // （`settings_reset.dart:128-157`）。三个可空 tuning 必须**清空**
                // （Dart 用 clearXxx 标记，因为 copyWith 对 null 是「不改」语义）；
                // 档位名也要回到标准，否则会出现「旋钮清了、档名停在自定义」。
                liquidGlassTuning = null,
                liquidGlassTuningDark = null,
                courseCardGlassTuning = null,
                courseCardGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD,
                frostedBlurEnabled = true,
                liquidGlassPreset = TimetableSettingsModel.LIQUID_GLASS_PRESET_STANDARD,
                linkLiquidGlassTuning = true,
                darkGlassBoostEnabled = true,
                liquidGlassDockEnabled = true,
                homeBandGlassMaterial = TimetableSettingsModel.DEFAULT_HOME_BAND_GLASS_MATERIAL,
                homePageTimeColumnBlurEnabled = false,
            )

            // 课表页面页（含壁纸与背景区域，`settings_reset.dart:74-122`）。
            // 材质轴 2026-09-22 起不在本作用域（划给外观），两个僵尸开关也不在这里。
            // 壁纸指针必须真的清（Dart 的 clearHomePageWallpaperPath / clearHomePageBackgroundImagePath）：
            // 否则「恢复默认」后背景还在，等于按声明的范围少清了两处。
            SCOPE_TIMETABLE_PAGE -> model.copy(
                timetableAutoFitSectionHeight = false,
                timetableHideWeekends = false,
                timetableShowNonCurrentWeekCourses = false,
                longPressEmptySlotToAddCourseEnabled = false,
                weekGridShowExams = true,
                weekGridShowSchedules = true,
                screenshotSharePromptEnabled = true,
                timetableSectionTimeDisplayMode = SectionTimeDisplayMode.START_AND_END,
                timetableTimeColumnWidthMode = TimetableTimeColumnWidthMode.NARROW,
                sectionHeight = 68.0,
                timetableCourseCardGap = TimetableSettingsModel.DEFAULT_COURSE_CARD_GAP,
                timetableBackToCurrentWeekButtonStyle = BackToCurrentWeekButtonStyle.FLOATING,
                timetableFloatingBackToCurrentWeekButtonOpacity = 0.96,
                timetablePageBackgroundColor =
                TimetableSettingsModel.DEFAULT_TIMETABLE_PAGE_BACKGROUND_COLOR,
                homePageBackdropFollowsWeekPager = false,
                homePageWallpaperBlurSigma = 0.0,
                homePageBackgroundScope =
                TimetableSettingsModel.DEFAULT_HOME_PAGE_BACKGROUND_SCOPE,
                weekdayBarFontColorLight = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_FONT_LIGHT,
                weekdayBarFontColorDark = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_FONT_DARK,
                weekdayBarAccentColorLight = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_ACCENT_LIGHT,
                weekdayBarAccentColorDark = TimetableSettingsModel.DEFAULT_WEEKDAY_BAR_ACCENT_DARK,
                timeAxisFontColorLight = TimetableSettingsModel.DEFAULT_TIME_AXIS_FONT_LIGHT,
                timeAxisFontColorDark = TimetableSettingsModel.DEFAULT_TIME_AXIS_FONT_DARK,
                homePageWallpaperPath = null,
                homePageBackgroundImagePath = null,
            )

            // 与 Dart `settings_reset.dart:162-174` 逐字段对齐。
            // ⚠️ `homeMenuStyle` / `homeGridMenuActions` **不纳入**：Dart 明确排除
            // （`copyWith` 会把空表过一遍 `HomeGridMenu.normalize`，得到一张只有
            // 「课表设置」一格的菜单，而不是出厂那套）；`glassDockShow{Day,Settings,Week}Tab`
            // 是被 `glassDockActions` 取代的旧布尔键，Dart 也已移出任何作用域。
            // 确认框文案只写「底栏与首页标题」，多清这几项就是按声明的范围多清。
            SCOPE_HOME_NAVIGATION -> model.copy(
                homeNavigationForm = HomeNavigationForm.CLASSIC,
                homeTitleStyle = HomeTitleStyle.CLASSIC,
                glassDockActions = emptyList(),
                glassDockShowAddButton = false,
                glassDockButtonEntryId = TimetableSettingsModel.DEFAULT_GLASS_DOCK_BUTTON_ENTRY_ID,
                glassDockButtonIconName = null,
            )

            // 材质面板里那颗「恢复默认」：**只清液态调参**，不动整体材质
            // （`settings_appearance_editor.dart:1058-1085`，按钮旁边那句说明就是它的范围）。
            SCOPE_LIQUID_GLASS -> resetLiquidGlassTuning(model)

            // 桌面小组件：本页 10 个可调项全部回到构造默认（`settings_reset.dart:175-189`）。
            // 逐字段列出、不整体替换——课程数据与别的页设置一个都不能动。
            SCOPE_HOME_WIDGET -> model.copy(
                widgetBackgroundStyle = TimetableSettingsModel.DEFAULT_WIDGET_BACKGROUND_STYLE,
                widgetCourseAccentMode = TimetableSettingsModel.DEFAULT_WIDGET_COURSE_ACCENT_MODE,
                widgetShowLocation = true,
                widgetShowCountdown = true,
                widgetHideCompletedCourses = false,
                widgetShowTomorrowCourses = true,
                widgetCountdownLeadMinutes =
                TimetableSettingsModel.DEFAULT_WIDGET_COUNTDOWN_LEAD_MINUTES,
                widgetCountdownTextStyle = TimetableSettingsModel.DEFAULT_WIDGET_COUNTDOWN_TEXT_STYLE,
                widgetHeightAdjustment = TimetableSettingsModel.DEFAULT_WIDGET_HEIGHT_ADJUSTMENT,
                widgetCornerRadius = TimetableSettingsModel.DEFAULT_WIDGET_CORNER_RADIUS,
            )

            else -> null
        }

    // ------------------------------------------------------------------ 内部

    private fun writeSetting(
        kind: SettingsActionKind,
        target: String?,
        rowId: String,
        model: TimetableSettingsModel,
    ): SettingsDispatch {
        // 壁纸面板的数据动作先认 target：它们不写设置模型，要由宿主碰文件 / 网络 / 台账
        // （判据与理由见 [wallpaperIntentTarget]）。清除图片不在其中，继续往下按 rowId 写。
        wallpaperIntentTarget(target, rowId)?.let { wallpaperTarget ->
            return SettingsDispatch.Write(
                model = model,
                rowId = rowId,
                wallpaperTarget = wallpaperTarget,
            )
        }
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

            // ---------------------------------------------------- 桌面小组件
            // 三个下拉的 option id 就是落盘串（`SettingsHomeWidgetPage.backgroundStyleOptions`
            // 等处逐字用的是 `timetable_settings_extensions.dart` 的 value），所以只做白名单校验。
            ROW_HOME_WIDGET_BACKGROUND_STYLE -> {
                val style = target?.takeIf {
                    it in TimetableSettingsModel.WIDGET_BACKGROUND_STYLES
                } ?: return ignored(kind, target, rowId, "小组件背景样式不认识：$target")
                model.copy(widgetBackgroundStyle = style)
            }

            ROW_HOME_WIDGET_COURSE_ACCENT -> {
                val mode = target?.takeIf {
                    it in TimetableSettingsModel.WIDGET_COURSE_ACCENT_MODES
                } ?: return ignored(kind, target, rowId, "小组件课程颜色档不认识：$target")
                model.copy(widgetCourseAccentMode = mode)
            }

            // 四个开关：渲染层不带新值 ⇒ 取反当前值（与其它开关行同一条约定）。
            ROW_HOME_WIDGET_SHOW_LOCATION ->
                model.copy(widgetShowLocation = !model.widgetShowLocation)

            ROW_HOME_WIDGET_SHOW_COUNTDOWN ->
                model.copy(widgetShowCountdown = !model.widgetShowCountdown)

            ROW_HOME_WIDGET_HIDE_COMPLETED ->
                model.copy(widgetHideCompletedCourses = !model.widgetHideCompletedCourses)

            ROW_HOME_WIDGET_SHOW_TOMORROW ->
                model.copy(widgetShowTomorrowCourses = !model.widgetShowTomorrowCourses)

            // 提前量：`0` = 始终显示，其余必须是九档之一（`settings_home_widget.dart:306-319`）。
            // 不在这十档的值不写盘——Dart 的下拉只可能给出这几项，给出了别的就是接线错了。
            ROW_HOME_WIDGET_COUNTDOWN_LEAD -> {
                val minutes = target?.trim()?.toIntOrNull()
                    ?: return ignored(kind, target, rowId, "倒计时提前量不是整数：$target")
                val known = minutes == 0 ||
                    minutes in TimetableSettingsModel.WIDGET_COUNTDOWN_LEAD_MINUTES
                if (!known) {
                    return ignored(kind, target, rowId, "倒计时提前量不在档位上：$target")
                }
                model.copy(widgetCountdownLeadMinutes = minutes)
            }

            ROW_HOME_WIDGET_COUNTDOWN_STYLE -> {
                val style = target?.takeIf {
                    it in TimetableSettingsModel.WIDGET_COUNTDOWN_TEXT_STYLES
                } ?: return ignored(kind, target, rowId, "倒计时文字样式不认识：$target")
                model.copy(widgetCountdownTextStyle = style)
            }

            // 高度：滑杆读数是**相对默认档（-11）的偏移**（`settings_home_widget.dart:344-359`），
            // 落盘是绝对档位。偏移先夹到 -16~+16（`:352-354`），再加默认档。
            ROW_HOME_WIDGET_HEIGHT_ADJUST -> {
                val offset = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "卡片高度偏移不是数字")
                model.copy(
                    widgetHeightAdjustment = TimetableSettingsModel.DEFAULT_WIDGET_HEIGHT_ADJUSTMENT +
                        offset.coerceIn(
                            TimetableSettingsModel.WIDGET_HEIGHT_OFFSET_MIN,
                            TimetableSettingsModel.WIDGET_HEIGHT_OFFSET_MAX,
                        ),
                )
            }

            // 圆角：滑杆读数是**绝对值**，夹到 8~36（默认 22 ±14，`:368-370`）。
            ROW_HOME_WIDGET_CORNER_RADIUS -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "卡片圆角不是数字")
                model.copy(
                    widgetCornerRadius = value.coerceIn(
                        TimetableSettingsModel.WIDGET_CORNER_RADIUS_MIN,
                        TimetableSettingsModel.WIDGET_CORNER_RADIUS_MAX,
                    ),
                )
            }

            // 两个 RUN_NOW 行（添加到桌面 / 授权精确闹钟）：**不写设置**，动作本身由宿主执行。
            // 这里明确 Ignored 并写清理由，避免宿主漏接时无声失败。
            ROW_HOME_WIDGET_PREVIEW_ADD, ROW_HOME_WIDGET_ALARM_GRANT -> return ignored(
                kind,
                target,
                rowId,
                "该行是 RUN_NOW 动作（添加到桌面 / 授权精确闹钟），由宿主执行，不写设置",
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

            // 「清除图片」：两条路径一起清（新壁纸 + 旧背景图），取景参数保留
            // （Dart `:458-470` 只清路径，历史里的取景还在，切回来时还原）。
            ROW_BACKDROP_IMAGE_CLEAR -> model.copy(
                homePageWallpaperPath = null,
                homePageBackgroundImagePath = null,
            )

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

            // 课表背景色板（Dart `:337-349`）：点一个色块 = 写 `timetablePageBackgroundColor`。
            // 读侧不校验是否在色板内（Dart 同口径），这里只校验色值格式。
            ROW_TP_BG_CHIPS -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "timetable background color is not #RRGGBB: $target")
                model.copy(timetablePageBackgroundColor = hex)
            }

            // 课表页与壁纸面板是**同一个设置的两个入口**（Dart 同一个 builder），
            // 所以写回口径必须与 ROW_BACKDROP_* 逐字一致。
            ROW_TP_BG_FOLLOWS_WEEK -> model.copy(
                homePageBackdropFollowsWeekPager = !model.homePageBackdropFollowsWeekPager,
            )

            ROW_TP_BG_BLUR -> {
                val value = parseDouble(target)
                    ?: return ignored(kind, target, rowId, "wallpaper blur sigma is not a number")
                model.copy(
                    homePageWallpaperBlurSigma =
                    TimetableSettingsModel.clampHomePageWallpaperBlurSigma(value),
                )
            }

            // 两个 SHEET 行（选图 / 最近使用）：弹层与选图由宿主执行，这里不写设置。
            ROW_TP_BG_IMAGE, ROW_TP_BG_RECENT -> return ignored(
                kind,
                target,
                rowId,
                "该行是 SHEET 动作（打开壁纸面板），由宿主执行，不写设置",
            )

            // 课表页三根文字颜色（Dart `settings_timetable_page.dart:341-347` 的
            // `_ColorSettingRow`）：选色器回投 WRITE_SETTING + target = 新色值。
            ROW_TP_TEXT_WEEKDAY -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "weekday bar color is not #RRGGBB: $target")
                model.copy(weekdayBarFontColorLight = hex)
            }

            ROW_TP_TEXT_WEEKDAY_ACCENT -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "weekday bar accent color is not #RRGGBB: $target")
                model.copy(weekdayBarAccentColorLight = hex)
            }

            ROW_TP_TEXT_TIME_AXIS -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "time axis color is not #RRGGBB: $target")
                model.copy(timeAxisFontColorLight = hex)
            }

            ROW_TP_TEXT_WEEKDAY_DARK -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "dark weekday bar color is not #RRGGBB: $target")
                model.copy(weekdayBarFontColorDark = hex)
            }

            ROW_TP_TEXT_WEEKDAY_ACCENT_DARK -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "dark weekday bar accent is not #RRGGBB: $target")
                model.copy(weekdayBarAccentColorDark = hex)
            }

            ROW_TP_TEXT_TIME_AXIS_DARK -> {
                val hex = normalizeHexColor(target)
                    ?: return ignored(kind, target, rowId, "dark time axis color is not #RRGGBB: $target")
                model.copy(timeAxisFontColorDark = hex)
            }

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

    // ================================================== 主题配置：导出 / 导入 / 已存主题
    //
    // 2026-10-29 补口（一轮审核 P0）：主题管理页的「导出主题 / 导入主题 / 保存当前主题 / 已存主题
    // 更多操作」四处**点了没反应**——分派器把动作翻成 `ClipboardExport` / `ShowDialog` / `ShowSheet`
    // 之后没有任何消费者。本段把「一条主题配置长什么样」收敛成唯一一份读写口径，
    // 弹层与剪贴板由 `SettingsHost` 消费（见 `SettingsHost.handleIntent`）。

    /**
     * Dart `ThemeConfig.version` 的默认值（`lib/models/timetable_settings.dart:101` `this.version = 2`）。
     *
     * 导出必须带这个键：Dart 的导入侧 `_importTheme` 用 `config.version == 2` 判「要不要校验两个必填色」
     * （`settings_appearance.dart:842-846`），缺 `v` 会被当成 v1 老格式放行。
     */
    const val THEME_CONFIG_VERSION = 2

    /** 已存主题行的行 id 前缀（[com.mutx163.qingyu.pages.settings.SettingsThemeManagePage] 的 `theme.saved.<id>`）。 */
    const val ROW_SAVED_THEME_PREFIX = "theme.saved."

    /** 已存主题条目的四个键（Dart `SavedTheme.toJson`，`timetable_settings.dart:39-44`）。 */
    const val SAVED_THEME_KEY_ID = "id"
    const val SAVED_THEME_KEY_NAME = "name"
    const val SAVED_THEME_KEY_THEME_DATA = "themeData"
    const val SAVED_THEME_KEY_CREATED_AT = "createdAt"

    /**
     * 当前设置 → 一份主题配置（Dart `ThemeConfig.fromSettings(...).toJson()`，短键）。
     *
     * 与 [applyThemeCheckpoint] / [hasThemeModifications] 共用同一张 [THEME_CHECKPOINT_FIELDS]，
     * 所以「导出的键」与「写回的键」不可能是两套。值为 `null` 的字段**不写键**
     * （Dart `toJson` 的 `if (x != null)` 同口径）。
     */
    fun themeConfigOf(model: TimetableSettingsModel): Map<String, Any?> = buildMap {
        put("v", THEME_CONFIG_VERSION)
        THEME_CHECKPOINT_FIELDS.forEach { field ->
            field.read(model)?.let { put(field.key, it) }
        }
    }

    /** 一份主题配置 → 新设置（导入 / 应用已存主题共用；未识别的键安静忽略）。 */
    fun applyThemeConfig(
        model: TimetableSettingsModel,
        config: Map<String, Any?>,
    ): TimetableSettingsModel = applyThemeCheckpoint(model, config)

    /**
     * Dart `_importTheme` 的结构校验（`settings_appearance.dart:841-847`）。
     *
     * - `v == 2` ⇒ 必须同时有 `seed` 与 `ccl`，否则按「剪贴板内容格式错误」拒绝；
     * - 其余版本（v1 / 缺 `v`）⇒ 放行，靠 [applyThemeConfig] 的宽松读逐键生效。
     */
    fun themeConfigIsUsable(config: Map<String, Any?>): Boolean {
        val version = LenientJson.int(config["v"]) ?: 1L
        if (version != THEME_CONFIG_VERSION.toLong()) return true
        return LenientJson.string(config["seed"]) != null &&
            LenientJson.string(config["ccl"]) != null
    }

    /**
     * 「保存当前主题」（Dart `_themeService.saveTheme`，`timetable_theme_service.dart:69-83`）。
     *
     * @param id `DateTime.now().millisecondsSinceEpoch.toString()`（宿主给，便于测试钉死）。
     * @param createdAtIso `DateTime.now().toIso8601String()`（宿主给）。
     * @return `null` = 名字为空（不写盘、由调用方提示）。
     */
    fun saveTheme(
        model: TimetableSettingsModel,
        name: String,
        id: String,
        createdAtIso: String,
    ): TimetableSettingsModel? {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return null
        val entry = mapOf(
            SAVED_THEME_KEY_ID to id,
            SAVED_THEME_KEY_NAME to trimmed,
            SAVED_THEME_KEY_THEME_DATA to themeConfigOf(model),
            SAVED_THEME_KEY_CREATED_AT to createdAtIso,
        )
        return model.copy(savedThemes = model.savedThemes + entry)
    }

    /**
     * 应用一份已存主题（Dart `_applySavedTheme` → `_applyThemeWithUndo(config, themeName)`）：
     * 18 个字段写回 + 把检查点换成这份主题（名字与快照都换）。
     *
     * @return `null` = 该 id 不在列表里（列表已被别处改掉）。
     */
    fun applySavedTheme(model: TimetableSettingsModel, id: String): TimetableSettingsModel? {
        val entry = model.savedThemes.firstOrNull { it[SAVED_THEME_KEY_ID] == id } ?: return null
        val config = entry[SAVED_THEME_KEY_THEME_DATA] as? Map<*, *> ?: return null
        val normalized = config.entries.mapNotNull { (k, v) -> (k as? String)?.let { it to v } }.toMap()
        val name = entry[SAVED_THEME_KEY_NAME] as? String ?: return null
        return applyThemeCheckpoint(model, normalized).copy(
            themeCheckpointName = name,
            themeCheckpointConfig = normalized,
        )
    }

    /** 重命名（Dart `renameTheme`）：id / 配置 / 创建时间原样保留，只换名字。空名 ⇒ null。 */
    fun renameSavedTheme(
        model: TimetableSettingsModel,
        id: String,
        newName: String,
    ): TimetableSettingsModel? {
        val trimmed = newName.trim()
        if (trimmed.isEmpty()) return null
        if (model.savedThemes.none { it[SAVED_THEME_KEY_ID] == id }) return null
        return model.copy(
            savedThemes = model.savedThemes.map { entry ->
                if (entry[SAVED_THEME_KEY_ID] == id) entry + (SAVED_THEME_KEY_NAME to trimmed) else entry
            },
        )
    }

    /**
     * 复制（Dart `_duplicateTheme`）：把源条目的 `themeData` 再存一份。
     *
     * 名字由调用方给（Dart 取 ARB `themeDuplicateCopyName` = `{name} 副本`），分派器不碰文案。
     * Dart 不做重名去重（同名的副本可以有两条），这里也**不**偷偷加序号。
     */
    fun duplicateSavedTheme(
        model: TimetableSettingsModel,
        sourceId: String,
        newId: String,
        newName: String,
        createdAtIso: String,
    ): TimetableSettingsModel? {
        val source = model.savedThemes.firstOrNull { it[SAVED_THEME_KEY_ID] == sourceId } ?: return null
        val trimmed = newName.trim()
        if (trimmed.isEmpty()) return null
        val copy = mapOf(
            SAVED_THEME_KEY_ID to newId,
            SAVED_THEME_KEY_NAME to trimmed,
            SAVED_THEME_KEY_THEME_DATA to source[SAVED_THEME_KEY_THEME_DATA],
            SAVED_THEME_KEY_CREATED_AT to createdAtIso,
        )
        return model.copy(savedThemes = model.savedThemes + copy)
    }

    /** 删除（Dart `deleteTheme`）：按 id 移除；id 不存在 ⇒ null（调用方据此不提示成功）。 */
    fun deleteSavedTheme(model: TimetableSettingsModel, id: String): TimetableSettingsModel? {
        if (model.savedThemes.none { it[SAVED_THEME_KEY_ID] == id }) return null
        return model.copy(
            savedThemes = model.savedThemes.filterNot { it[SAVED_THEME_KEY_ID] == id },
        )
    }

    /** `theme.saved.<id>` → id；不是这个形态返回 null。 */
    fun savedThemeIdOf(rowId: String): String? =
        rowId.takeIf { it.startsWith(ROW_SAVED_THEME_PREFIX) }
            ?.removePrefix(ROW_SAVED_THEME_PREFIX)
            ?.takeIf { it.isNotBlank() }

    /**
     * 落盘**读回校验**：本次改动过的键，盘上是不是新值。
     *
     * 为什么需要：`TimetableSettingsModelStore.save` 返回 `Unit`，而
     * `KeyValueStore.putString` 把 `SharedPreferences.commit()` 的 `Boolean` 丢了
     * （`platform/PrefsKeyValueStore.kt:90-92`）⇒ 写失败既不抛异常也不返回 false，
     * 宿主原来的「写失败提示」分支永远进不去（一轮审核 P1）。
     *
     * 只比**改动过的键**（前后 patch 相等就跳过）；两侧都取模型自己的 `toJsonPatch()`，
     * **不**拿盘上原始 JSON 直接比类型——JSON 解析会把 `Int` 变 `Long`，整体相等会假红。
     */
    fun persistLanded(
        before: TimetableSettingsModel,
        after: TimetableSettingsModel,
        disk: TimetableSettingsModel,
    ): Boolean {
        val beforePatch = before.toJsonPatch()
        val afterPatch = after.toJsonPatch()
        val diskPatch = disk.toJsonPatch()
        return afterPatch.all { (key, newValue) ->
            beforePatch[key] == newValue || diskPatch[key] == newValue
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
