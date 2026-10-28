package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.LenientJson

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
 * ## 本刀覆盖的 4 页
 *
 * 通用（`settings-general`）/ 外观（`settings-appearance`）/ 主题管理（`settings-theme`）/
 * 课程卡片（`settings-course-card`）。其余 16 页各自私有 state，未识别 rowId 一律
 * [SettingsDispatch.Ignored]（no-op + 带理由，**不崩**）。
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

    /** 恢复默认的作用域名（`settings_reset.dart:17-23` 里的两个）。 */
    const val SCOPE_APPEARANCE = "appearance"
    const val SCOPE_COURSE_CARD = "courseCard"

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

            else -> {
                // 主题管理页的预设是 RADIO，渲染层不给 target，值只能从 rowId 后缀取。
                if (rowId.startsWith(ROW_THEME_PRESET_PREFIX)) {
                    val presetValue = rowId.removePrefix(ROW_THEME_PRESET_PREFIX)
                    applyThemePreset(model, presetValue)
                        ?: return ignored(kind, target, rowId, "主题预设值不认识：$presetValue")
                } else {
                    return ignored(
                        kind,
                        target,
                        rowId,
                        "未识别的 rowId（本刀只接通用/外观/主题管理/课程卡片 4 页）",
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
