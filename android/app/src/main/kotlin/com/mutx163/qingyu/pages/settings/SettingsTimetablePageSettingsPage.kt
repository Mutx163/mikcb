package com.mutx163.qingyu.pages.settings

import java.util.Locale

/**
 * 「课表页面设置」页（`lib/screens/settings/settings_timetable_page.dart`，494 行）结构模型。
 *
 * ## 为什么这一页是补上来的（2026-10-28）
 *
 * 台账原记 P3-B「20 页全迁」，但这一页**从来没有落点**：入口行
 * `timetable.pageSettings`（[SettingsTimetablePage] 里 id 就是这个）把
 * `actionTarget` 指向 `/settings/timetable-page`，而设置族里没有任何 spec 接这个路由。
 * `l4-recon` 逐页核对时发现，Lead 复验属实——根因是设置族 20 页共用
 * `SettingsPageScreen(spec)` 一个渲染函数，「没写页面函数」与「没写页面」在人工登记里
 * 长得一模一样。本文件补上落点，并已登记进 [SettingsBatchCoverageTest]。
 *
 * ## 页面形状
 *
 * 与课程卡片页同构：上方 4 成是课表微缩预览、下方 6 成是可调项
 * （Dart `:105-153` 的 `Expanded(flex: 4/6)`），所以
 * `collapsibleLargeTitle = false` + `previewFlex = 4` / `contentFlex = 6`。
 *
 * ## 逐区对照
 *
 * | Dart 段 | 行 | 本模型 |
 * |---|---|---|
 * | `HyperosSectionLabel(密度)` | :167 | `timetablePage.label.density` |
 * | 密度组 11 行 | :168-291 | `timetablePage.density` |
 * | `HyperosSectionLabel(回到当前周)` | :298 | `timetablePage.label.backToWeek` |
 * | 浮钮不透明度滑杆 | :303-316 | `timetablePage.backToWeek.opacity` |
 * | `HyperosSectionLabel(背景)` | :327 | `timetablePage.label.background` |
 * | 背景色板 + 壁纸 + 最近 + 随周滑动 + 模糊 | :328-385 | `timetablePage.background` |
 * | `HyperosSettingsBlock(玻璃材质)` | :418-444 | `timetablePage.glass` |
 * | `TimetableTextColorSettings(scope: page)` | :394-398 | `timetablePage.textColors.light` + `.dark` |
 * | `SettingsResetTile(scope: timetablePage)` | :399-402 | `timetablePage.reset` |
 *
 * ## 本页**不**管的两件事（都在别处）
 *
 * 1. 课卡的字色跟课卡走，在课程卡片页（Dart :393 的注释就写着这句）；
 * 2. 材质轴（质感方案 / 玻璃档位 / 各表面材质图）2026-09-19 起整体划给「外观编辑」页，
 *    本页只留一条保证一键可达的入口行（Dart :407-413）。
 */
object SettingsTimetablePageSettingsPage {

    /** spec id：与入口行的 `actionTarget`（`/settings/timetable-page`）一一对应。 */
    const val ID = "settings-timetable-page"

    /** 恢复默认的作用域参数（`SettingsResetPage` 的 `TIMETABLE_PAGE.arg`）。 */
    const val RESET_SCOPE_TIMETABLE_PAGE = "timetablePage"

    /**
     * 深色档三行的 rowId（`weekdayBarFontColorDark` / `weekdayBarAccentColorDark` /
     * `timeAxisFontColorDark`，`timetable_settings.dart:1758 / :1764 / :1770`）。
     *
     * 浅色三行的 rowId 在 `SettingsActionDispatcher.ROW_TP_TEXT_*` 里；深色三行本轮
     * 只补了页面与状态（写回分支在 Lead 独占的 `SettingsActionDispatcher.kt`，
     * 见 F25 交付说明）。常量放这里，等分派器接上时直接引用，不要再抄一遍字面量。
     */
    const val ROW_TEXT_WEEKDAY_DARK = "timetablePage.textColors.dark.weekday"
    const val ROW_TEXT_WEEKDAY_ACCENT_DARK = "timetablePage.textColors.dark.weekdayAccent"
    const val ROW_TEXT_TIME_AXIS_DARK = "timetablePage.textColors.dark.timeAxis"

    /** 背景色板（Dart `_backgroundColors`，:53-60）。 */
    val BACKGROUND_COLORS: List<String> = listOf(
        "#F8FAFC",
        "#F7F7F5",
        "#FDF6EC",
        "#F2F7FF",
        "#F5F3FF",
        "#ECFDF5",
    )

    /** 节次高度滑杆（Dart :264-278 `min: 48, max: 92, divisions: 11`）。 */
    const val SECTION_HEIGHT_MIN = 48.0
    const val SECTION_HEIGHT_MAX = 92.0
    const val SECTION_HEIGHT_DIVISIONS = 11

    /** 课程卡间距滑杆（Dart :279-289 `max: 3, divisions: 12`，下界默认 0）。 */
    const val CARD_GAP_MIN = 0.0
    const val CARD_GAP_MAX = 3.0
    const val CARD_GAP_DIVISIONS = 12

    /** 浮钮不透明度滑杆（Dart :303-316 `min: 0.55, divisions: 9`）。 */
    const val BACK_TO_WEEK_OPACITY_MIN = 0.55
    const val BACK_TO_WEEK_OPACITY_MAX = 1.0
    const val BACK_TO_WEEK_OPACITY_DIVISIONS = 9

    /** 壁纸模糊滑杆（与 `SettingsBackdropFlowPage` 同口径：0..24，每格 1）。 */
    const val BLUR_MIN = 0.0
    const val BLUR_MAX = 24.0

    fun spec(state: TimetablePageSettingsState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 区块 1：密度
        nodes += SettingsLabel(
            id = "timetablePage.label.density",
            textKey = SettingsStringsExt5.timetablePageSectionDensity.key,
            text = SettingsStringsExt5.timetablePageSectionDensity.zh,
        )
        nodes += SettingsGroup(
            id = "timetablePage.density",
            children = densityRows(state),
        )

        // 区块 2：回到当前周（自带前导空档）
        nodes += SettingsGap("timetablePage.gap.backToWeek")
        nodes += SettingsLabel(
            id = "timetablePage.label.backToWeek",
            textKey = SettingsStringsExt5.timetablePageSectionBackToWeek.key,
            text = SettingsStringsExt5.timetablePageSectionBackToWeek.zh,
        )
        nodes += SettingsGroup(
            id = "timetablePage.backToWeek",
            children = listOf(
                settingsRow(
                    id = "timetablePage.backToWeek.opacity",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStringsExt5.layoutBackToCurrentWeekButtonOpacityTitle,
                    value = opacityPercentLabel(state.backToCurrentWeekOpacity),
                    slider = SettingsSliderSpec(
                        min = BACK_TO_WEEK_OPACITY_MIN,
                        max = BACK_TO_WEEK_OPACITY_MAX,
                        divisions = BACK_TO_WEEK_OPACITY_DIVISIONS,
                        defaultValue = BACK_TO_WEEK_OPACITY_MAX,
                    ),
                    sliderValue = state.backToCurrentWeekOpacity,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 区块 3：背景
        nodes += SettingsGap("timetablePage.gap.background")
        nodes += SettingsLabel(
            id = "timetablePage.label.background",
            textKey = SettingsStringsExt5.timetablePageSectionBackground.key,
            text = SettingsStringsExt5.timetablePageSectionBackground.zh,
        )
        nodes += SettingsGroup(
            id = "timetablePage.background",
            children = backgroundRows(state),
        )

        // 区块 4：玻璃材质（只有一条入口行）
        nodes += SettingsGap("timetablePage.gap.glass")
        nodes += SettingsLabel(
            id = "timetablePage.label.glass",
            textKey = SettingsStrings.frostedSheetSectionTitle.key,
            text = SettingsStrings.frostedSheetSectionTitle.zh,
        )
        nodes += SettingsGroup(
            id = "timetablePage.glass",
            children = listOf(
                settingsRow(
                    id = "timetablePage.glass.appearanceEditor",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.appearanceEditorTitle,
                    subtitle = SettingsStringsExt5.appearanceEditorEntrySubtitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = SettingsAppearancePage.ROUTE_APPEARANCE_EDITOR,
                ),
            ),
        )

        // 区块 5：文字颜色（scope = page：星期栏两色 + 时间轴一色，Dart :243-265）
        //
        // Dart 的 `TimetableTextColorSettings`（`timetable_text_color_settings.dart:120-280`）
        // 分**两组**渲染同一批行：浅色档 + 深色档，各三行（page 作用域）。
        // 2026-11-01 之前这里只有浅色那三行，深色档的值在模型里、渲染层也早就在读
        // （`TimetableWeekdayHeader` / `TimetableTimeColumn` 按 `isSystemInDarkTheme()`
        // 取 Dark 键），但设置页没有任何入口 —— 用户切到深色模式后无法调整这三色。
        nodes += SettingsGap("timetablePage.gap.textColors")
        nodes += SettingsLabel(
            id = "timetablePage.textColors.light.label",
            textKey = SettingsStrings.themeModeLight.key,
            text = SettingsStrings.themeModeLight.zh,
        )
        nodes += SettingsGroup(
            id = "timetablePage.textColors.light",
            children = listOf(
                colorRow(
                    id = "timetablePage.textColors.weekday",
                    title = SettingsStringsExt5.textColorWeekdayBar,
                    color = state.weekdayBarColor,
                ),
                colorRow(
                    id = "timetablePage.textColors.weekdayAccent",
                    title = SettingsStringsExt5.textColorWeekdayBarAccent,
                    color = state.weekdayBarAccentColor,
                ),
                colorRow(
                    id = "timetablePage.textColors.timeAxis",
                    title = SettingsStringsExt5.textColorTimeAxis,
                    color = state.timeAxisColor,
                ),
            ),
        )

        // 深色档：键名与模型字段逐字对齐 ——
        // `weekdayBarFontColorDark` / `weekdayBarAccentColorDark` / `timeAxisFontColorDark`
        // （`timetable_settings.dart:1758 / :1764 / :1770`）。
        nodes += SettingsGap("timetablePage.gap.textColors.afterLight")
        nodes += SettingsGap("timetablePage.gap.textColors.dark")
        nodes += SettingsLabel(
            id = "timetablePage.textColors.dark.label",
            textKey = SettingsStrings.themeModeDark.key,
            text = SettingsStrings.themeModeDark.zh,
        )
        nodes += SettingsGroup(
            id = "timetablePage.textColors.dark",
            children = listOf(
                colorRow(
                    id = ROW_TEXT_WEEKDAY_DARK,
                    title = SettingsStringsExt5.textColorWeekdayBar,
                    color = state.weekdayBarColorDark,
                ),
                colorRow(
                    id = ROW_TEXT_WEEKDAY_ACCENT_DARK,
                    title = SettingsStringsExt5.textColorWeekdayBarAccent,
                    color = state.weekdayBarAccentColorDark,
                ),
                colorRow(
                    id = ROW_TEXT_TIME_AXIS_DARK,
                    title = SettingsStringsExt5.textColorTimeAxis,
                    color = state.timeAxisColorDark,
                ),
            ),
        )

        // 区块 6：恢复默认（`SettingsResetTile` 自带空档）
        nodes += SettingsGap("timetablePage.gap.reset")
        nodes += SettingsGroup(
            id = "timetablePage.reset",
            children = listOf(
                settingsRow(
                    id = "timetablePage.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.settingsResetDefaultsTitle,
                    destructive = true,
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = RESET_SCOPE_TIMETABLE_PAGE,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt2.timetablePageSettingsTitle.key,
            title = SettingsStringsExt2.timetablePageSettingsTitle.zh,
            nodes = nodes,
            collapsibleLargeTitle = false,
            previewFlex = 4,
            contentFlex = 6,
        )
    }

    // ------------------------------------------------------------------ 密度组

    private fun densityRows(state: TimetablePageSettingsState): List<SettingsNode> {
        val rows = mutableListOf<SettingsNode>()
        fun switch(id: String, title: ArbText, subtitle: ArbText?, value: Boolean) {
            rows += settingsRow(
                id = id,
                component = MiuixRowComponent.SWITCH,
                title = title,
                subtitle = subtitle,
                switchValue = value,
                action = SettingsAction.WRITE_SETTING,
            )
        }

        switch(
            "timetablePage.autoFit",
            SettingsStringsExt5.layoutAutoFitHeightTitle,
            null,
            state.autoFitSectionHeight,
        )
        switch(
            "timetablePage.hideWeekends",
            SettingsStringsExt5.layoutHideWeekendsTitle,
            null,
            state.hideWeekends,
        )
        switch(
            "timetablePage.showOtherWeeks",
            SettingsStringsExt5.layoutShowOtherWeeksTitle,
            SettingsStringsExt5.layoutShowOtherWeeksSubtitle,
            state.showNonCurrentWeekCourses,
        )
        switch(
            "timetablePage.longPressEmptySlot",
            SettingsStringsExt5.longPressEmptySlotToAddTitle,
            SettingsStringsExt5.longPressEmptySlotToAddSubtitle,
            state.longPressEmptySlotToAddCourse,
        )
        switch(
            "timetablePage.weekGridExams",
            SettingsStringsExt5.weekGridShowExamsTitle,
            SettingsStringsExt5.weekGridShowExamsSubtitle,
            state.weekGridShowExams,
        )
        switch(
            "timetablePage.weekGridSchedules",
            SettingsStringsExt5.weekGridShowSchedulesTitle,
            SettingsStringsExt5.weekGridShowSchedulesSubtitle,
            state.weekGridShowSchedules,
        )
        // 截屏提示依赖 Android 14 的官方回调；不支持的平台**整行不出现**
        // （Dart :227 `if (_screenshotShareSupported)`），不是禁用态。
        if (state.screenshotShareSupported) {
            switch(
                "timetablePage.screenshotShare",
                SettingsStringsExt5.settingsScreenshotShareTitle,
                SettingsStringsExt5.settingsScreenshotShareSubtitle,
                state.screenshotSharePromptEnabled,
            )
        }

        rows += settingsRow(
            id = "timetablePage.timeColumnDisplay",
            component = MiuixRowComponent.DROPDOWN,
            title = SettingsStringsExt5.layoutTimeColumnDisplayLabel,
            options = PageSectionTimeDisplayMode.entries.map { option(it.value, it.label) },
            selectedOptionId = state.sectionTimeDisplayMode.value,
            action = SettingsAction.WRITE_SETTING,
        )
        rows += settingsRow(
            id = "timetablePage.timeColumnWidth",
            component = MiuixRowComponent.DROPDOWN,
            title = SettingsStringsExt5.layoutTimeColumnWidthLabel,
            options = PageTimeColumnWidthMode.entries.map { option(it.value, it.label) },
            selectedOptionId = state.timeColumnWidthMode.value,
            action = SettingsAction.WRITE_SETTING,
        )
        rows += settingsRow(
            id = "timetablePage.sectionHeight",
            component = MiuixRowComponent.SLIDER,
            title = SettingsStringsExt5.layoutSectionHeightTitle,
            value = sectionHeightLabel(state.sectionHeight),
            // 自动充满高度开着时这一行是**禁用**态，不是隐藏（Dart :270）
            enabled = sectionHeightSliderEnabled(state.autoFitSectionHeight),
            slider = SettingsSliderSpec(
                min = SECTION_HEIGHT_MIN,
                max = SECTION_HEIGHT_MAX,
                divisions = SECTION_HEIGHT_DIVISIONS,
                defaultValue = 64.0,
            ),
            sliderValue = state.sectionHeight,
            action = SettingsAction.WRITE_SETTING,
        )
        rows += settingsRow(
            id = "timetablePage.courseCardGap",
            component = MiuixRowComponent.SLIDER,
            title = SettingsStringsExt5.layoutCourseCardGapTitle,
            value = cardGapLabel(state.courseCardGap),
            slider = SettingsSliderSpec(
                min = CARD_GAP_MIN,
                max = CARD_GAP_MAX,
                divisions = CARD_GAP_DIVISIONS,
                defaultValue = 1.0,
            ),
            sliderValue = state.courseCardGap,
            action = SettingsAction.WRITE_SETTING,
        )
        return rows
    }

    // ------------------------------------------------------------------ 背景组

    private fun backgroundRows(state: TimetablePageSettingsState): List<SettingsNode> {
        val rows = mutableListOf<SettingsNode>()

        // 背景色板：`HyperosHexColorChipGroup`（Dart :337-349）——官方 preference 没有
        // 「色板组」这种控件，所以走内联块（与课程卡片页的统一课卡色板同一条路）。
        rows += SettingsInline(
            id = "timetablePage.background.colorChips",
            kind = InlineKind.COLOR_CHIP_GROUP,
            note = "课表背景色六色板（:337-349）：官方没有色板组控件，色块与选中态由应用画",
            labelKey = SettingsStringsExt5.timetableBackgroundColorSectionTitle.key,
            label = SettingsStringsExt5.timetableBackgroundColorSectionTitle.zh,
            colors = BACKGROUND_COLORS,
            selectedColor = state.pageBackgroundColor,
        )

        // 壁纸（Dart :350-375 `buildHomePageImageTile`）：行尾是文件名，没选时留空。
        rows += settingsRow(
            id = "timetablePage.background.image",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt1.homePageWallpaperTitle,
            valueKey = if (state.imagePath.isNullOrEmpty()) {
                null
            } else {
                NON_ARB_TEXT
            },
            value = SettingsBackdropFlowPage.fileNameOf(state.imagePath),
            action = SettingsAction.SHEET,
        )

        // 最近使用的壁纸（Dart :376 `buildRecentWallpaperTile`）。
        rows += settingsRow(
            id = "timetablePage.background.recent",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt1.homePageWallpaperRecentTitle,
            action = SettingsAction.SHEET,
        )

        // 背景随周次滑动（Dart :379）：与壁纸弹窗里那颗是**同一个开关、同一份设置**。
        rows += settingsRow(
            id = "timetablePage.background.followsWeek",
            component = MiuixRowComponent.SWITCH,
            title = SettingsStringsExt1.homePageBackdropFollowsWeekPagerTitle,
            subtitle = SettingsStringsExt1.homePageBackdropFollowsWeekPagerSubtitle,
            switchValue = state.backdropFollowsWeekPager,
            action = SettingsAction.WRITE_SETTING,
        )

        // 壁纸模糊强度（Dart :381）：0 档显示「关闭」而不是「0」。
        val blur = state.wallpaperBlurSigma.coerceIn(BLUR_MIN, BLUR_MAX)
        val blurOff = blur <= BLUR_MIN
        rows += settingsRow(
            id = "timetablePage.background.blur",
            component = MiuixRowComponent.SLIDER,
            title = SettingsStringsExt1.homePageWallpaperBlurTitle,
            valueKey = if (blurOff) SettingsStringsExt1.homePageWallpaperBlurOff.key else null,
            value = if (blurOff) {
                SettingsStringsExt1.homePageWallpaperBlurOff.zh
            } else {
                blur.toInt().toString()
            },
            slider = SettingsSliderSpec(
                min = BLUR_MIN,
                max = BLUR_MAX,
                divisions = BLUR_MAX.toInt(),
                defaultValue = BLUR_MIN,
            ),
            sliderValue = blur,
            action = SettingsAction.WRITE_SETTING,
        )
        return rows
    }

    // ------------------------------------------------------------------ 共用行

    /**
     * 文字颜色行（Dart `_ColorSettingRow`，`timetable_text_color_settings.dart:277-300`）。
     *
     * 行尾是 36dp 色块（[MiuixRowComponent.COLOR_SWATCH]），选色走官方 `ColorPicker`。
     * page 作用域的三行**都不带** enabled 判据——联动开关只管课卡那两行。
     */
    private fun colorRow(id: String, title: ArbText, color: String) = settingsRow(
        id = id,
        component = MiuixRowComponent.COLOR_SWATCH,
        title = title,
        value = color,
        action = SettingsAction.COLOR_PICKER,
    )

    // ------------------------------------------------------------------ 纯逻辑（人推期望值，见对应测试）

    /** 节次高度滑杆是否可用：自动充满高度开着时禁用（Dart :270 `enabled: !autoFit`）。 */
    fun sectionHeightSliderEnabled(autoFitSectionHeight: Boolean): Boolean = !autoFitSectionHeight

    /** 节次高度读数（Dart :271 `toStringAsFixed(0)`）。 */
    fun sectionHeightLabel(value: Double): String =
        "%.0f".format(Locale.ROOT, value)

    /** 课程卡间距读数（Dart :284 `toStringAsFixed(1)`）。 */
    fun cardGapLabel(value: Double): String = "%.1f".format(Locale.ROOT, value)

    /** 浮钮不透明度读数（Dart :309 `'${(opacity * 100).round()}%'`）。 */
    fun opacityPercentLabel(opacity: Double): String =
        "${Math.round(opacity * 100)}%"

    /**
     * 当前背景色是否落在色板里。
     *
     * 存量值可能是旧存档 / 手改 JSON 里的任意色（Dart 侧 `HyperosHexColorChipGroup`
     * 找不到匹配就一个都不选中）。宿主用它决定「要不要在色板外补一个当前色」——
     * 这里只提供判据，不替宿主决定。
     */
    fun isPaletteColor(hex: String, palette: List<String> = BACKGROUND_COLORS): Boolean =
        palette.any { it.equals(hex, ignoreCase = true) }

    /**
     * 密度组里应当出现的行 id 顺序（含条件行）。
     *
     * 抽出来是为了让测试能钉「截屏提示那一行只在支持时出现」，而不是靠人读 if。
     */
    fun densityRowIds(state: TimetablePageSettingsState): List<String> {
        val ids = mutableListOf(
            "timetablePage.autoFit",
            "timetablePage.hideWeekends",
            "timetablePage.showOtherWeeks",
            "timetablePage.longPressEmptySlot",
            "timetablePage.weekGridExams",
            "timetablePage.weekGridSchedules",
        )
        if (state.screenshotShareSupported) {
            ids += "timetablePage.screenshotShare"
        }
        ids += listOf(
            "timetablePage.timeColumnDisplay",
            "timetablePage.timeColumnWidth",
            "timetablePage.sectionHeight",
            "timetablePage.courseCardGap",
        )
        return ids
    }
}

/** 首页时间列显示方式（Dart `SectionTimeDisplayMode`，`timetable_settings_enums.dart:240`）。 */
enum class PageSectionTimeDisplayMode(val value: String, val label: ArbText) {
    HIDDEN("hidden", SettingsStringsExt5.sectionTimeDisplayHidden),
    START_ONLY("startOnly", SettingsStringsExt5.sectionTimeDisplayStartOnly),
    START_AND_END("startAndEnd", SettingsStringsExt5.sectionTimeDisplayStartAndEnd),
}

/** 时间栏宽度（Dart `TimetableTimeColumnWidthMode`，`timetable_settings_extensions.dart:387`）。 */
enum class PageTimeColumnWidthMode(val value: String, val label: ArbText) {
    NARROW("narrow", SettingsStringsExt5.timetableTimeColumnWidthNarrow),
    WIDE("wide", SettingsStringsExt5.timetableTimeColumnWidthWide),
}

/**
 * 本页的输入状态（页面私有，不进 [SettingsPageState]）。
 *
 * 默认值逐条抄 `lib/models/timetable_settings.dart` 的声明默认值；字段名与
 * `SettingsResetPage.TIMETABLE_PAGE.fields` 对齐，便于双向核对「这一页到底管哪些设置」。
 *
 * [screenshotShareSupported] 与 [imagePath] 不是设置字段：前者是设备能力探测结果
 * （`ScreenCaptureService.ensureSupported()`），后者是当前背景图路径，都由接线层填。
 */
data class TimetablePageSettingsState(
    val autoFitSectionHeight: Boolean = false,
    val hideWeekends: Boolean = false,
    val showNonCurrentWeekCourses: Boolean = true,
    val longPressEmptySlotToAddCourse: Boolean = false,
    val weekGridShowExams: Boolean = true,
    val weekGridShowSchedules: Boolean = true,
    val screenshotSharePromptEnabled: Boolean = false,
    /** 设备是否支持截屏回调；false 时那一行整行不出现。 */
    val screenshotShareSupported: Boolean = false,
    val sectionTimeDisplayMode: PageSectionTimeDisplayMode = PageSectionTimeDisplayMode.START_AND_END,
    val timeColumnWidthMode: PageTimeColumnWidthMode = PageTimeColumnWidthMode.NARROW,
    val sectionHeight: Double = 64.0,
    val courseCardGap: Double = 1.0,
    val backToCurrentWeekOpacity: Double = 1.0,
    val pageBackgroundColor: String = "#F8FAFC",
    val imagePath: String? = null,
    val backdropFollowsWeekPager: Boolean = false,
    val wallpaperBlurSigma: Double = 0.0,
    val weekdayBarColor: String = "#FFFFFF",
    val weekdayBarAccentColor: String = "#2563EB",
    val timeAxisColor: String = "#64748B",
    /**
     * 深色档三色（Dart `timetable_settings.dart:1758 / :1764 / :1770` 的读侧默认）。
     *
     * 渲染层已经在用它们（`TimetableWeekdayHeader` / `TimetableTimeColumn` 按
     * `isSystemInDarkTheme()` 取 Dark 键）；本页 2026-11-01 之前缺这三行入口。
     */
    val weekdayBarColorDark: String = "#FFFFFF",
    val weekdayBarAccentColorDark: String = "#93C5FD",
    val timeAxisColorDark: String = "#FFFFFF",
)
