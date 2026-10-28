package com.mutx163.qingyu.app

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
