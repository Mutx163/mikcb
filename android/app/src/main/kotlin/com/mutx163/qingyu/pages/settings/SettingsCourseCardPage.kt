package com.mutx163.qingyu.pages.settings

import java.util.Locale
import kotlin.math.roundToInt

/**
 * 课程卡片设置页（`lib/screens/settings/settings_course_card.dart`）结构模型。
 *
 * 本页顶部是固定周预览（占 4 成高）、下面是可调项（6 成），所以
 * [SettingsPageSpec.collapsibleLargeTitle] 为 false（:81 注释：预览不在顶栏下，
 * 不能让编辑区的滚动去折叠大标题）。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | 顶部 `TimetableWeekPreview`（:85-114） | `previewFlex = 4` | 官方无对应物：周视图网格是自绘白名单第 ② 项 |
 * | `HyperosSectionLabel(显示字段)`（:137） | `courseCard.fields.label` | preference category |
 * | 七个 `HyperosSwitchTile`（:138-193） | `courseCard.show.*` | `MiuixSwitchPreference` |
 * | `HyperosListTile(卡片外观)`（:204-214） | `courseCard.surfaceStyle` | `MiuixArrowPreference` |
 * | `HyperosSelectTile<CourseCardVerticalAlign>`（:215-225） | `courseCard.verticalAlign` | `MiuixOverlayDropdownPreference` |
 * | `HyperosSelectTile<CourseCardHorizontalAlign>`（:226-238） | `courseCard.horizontalAlign` | 同上 |
 * | `HyperosSliderTile(课程卡片字号)`（:239-250） | `courseCard.cardFontSize` | `MiuixSliderPreference` |
 * | `HyperosSliderTile(紧凑字号)`（:251-262） | `courseCard.compactFontSize` | `MiuixSliderPreference` |
 * | `HyperosSwitchTile(统一课程卡片颜色)`（:276-285） | `courseCard.unifiedColor` | `MiuixSwitchPreference` |
 * | `HyperosHexColorChipGroup`（:286-299） | `SettingsInline(COLOR_CHIP_GROUP)` | 官方无对应物：八色板胶囊组 |
 * | `HyperosNavTile(课表重新配色)`（:301-305） | `courseCard.recolor` | `MiuixArrowPreference` |
 * | `HyperosSwitchTile(首页显示冲突小胶囊)`（:306-314） | `courseCard.conflictBadge` | `MiuixSwitchPreference` |
 * | `HyperosSliderTile(冲突课程透明度)`（:315-326） | `courseCard.conflictOpacity` | `MiuixSliderPreference` |
 * | `TimetableTextColorSettings(scope: courseCard)`（:331-335） | `courseCard.textColors.*` | 见 [SettingsCourseCardPage.textColorRows] |
 * | `SettingsResetTile(courseCard)`（:336-339） | `courseCard.reset.row` | `MiuixArrowPreference`（危险色） |
 *
 * ## 两条联动（本页最容易写反的地方）
 *
 * 1. 「显示上下课字样」的 `onChanged` 只在「显示时间」开着时非空（:171-177）
 *    → [SettingsRow.enabled]；
 * 2. 「独立设置详情颜色」开关是**取反**的（`value: !linkCourseCardColors`，
 *    timetable_text_color_settings.dart:66），详情色行的可用性也是取反的（:237）。
 *
 * ## 未纳入本模型
 *
 * 1. 顶部预览的 `FrostedAppearanceScope` / `weather` 注入（:91-110）——接线层；
 * 2. 跳去材质面板后的**重读草稿**（`_openMaterialPanel`，:349-363）：返回时必须
 *    用 provider 的真值覆盖 `_draft`，否则下一次改动会把面板里的选择写回旧值；
 * 3. `showCourseRecolorSheet`（:304）的弹层内容在 `lib/widgets/course_recolor_sheet.dart`。
 */
object SettingsCourseCardPage {

    const val ID = "settings-course-card"

    /**
     * 「卡片外观」行的去向：材质面板的课程卡片页签。
     *
     * 命名按 `_TARGET` 后缀、值不带前导 `/`——这是 `SettingsRouteWiringGuardTest` 认的两种形态，
     * 少了任何一个（或改成字面量）它就不扫，删了路由也没人报红。
     */
    const val COURSE_CARD_MATERIAL_TARGET = "materialCourseCard"

    /** 统一课卡色的八色板（`settings_course_card.dart:42-51` 的 `_cardColors`）。 */
    val CARD_COLORS: List<String> = listOf(
        "#2563EB",
        "#7C3AED",
        "#059669",
        "#DC2626",
        "#EA580C",
        "#0891B2",
        "#4F46E5",
        "#DB2777",
    )

    private const val FONT_MIN = 7.0
    private const val FONT_MAX = 12.0
    private const val FONT_DIVISIONS = 10
    private const val OPACITY_MIN = 0.2
    private const val OPACITY_MAX = 1.0
    private const val OPACITY_DIVISIONS = 16

    /** `SettingsResetScope.courseCard`（`settings_reset.dart:17-18`）。 */
    const val RESET_SCOPE_COURSE_CARD = "courseCard"

    fun spec(state: SettingsPageState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 区块 0-1：显示字段
        nodes += SettingsLabel(
            id = "courseCard.fields.label",
            textKey = SettingsStrings.courseCardSectionFields.key,
            text = SettingsStrings.courseCardSectionFields.text,
        )
        nodes += SettingsGroup(
            id = "courseCard.fields",
            children = listOf(
                switchRow("courseCard.show.name", SettingsStrings.showCourseNameTitle, state.courseCardShowName),
                switchRow("courseCard.show.teacher", SettingsStrings.layoutShowTeacherTitle, state.courseCardShowTeacher),
                switchRow("courseCard.show.location", SettingsStrings.layoutShowClassroomTitle, state.courseCardShowLocation),
                switchRow("courseCard.show.time", SettingsStrings.layoutShowTimeTitle, state.courseCardShowTime),
                switchRow(
                    id = "courseCard.show.timeLabels",
                    title = SettingsStrings.layoutShowTimeLabelsTitle,
                    value = state.courseCardShowTimeLabels,
                    // 「显示时间」关掉后这行不给改（:171-177 传 null）
                    enabled = state.courseCardShowTime,
                ),
                switchRow("courseCard.show.weeks", SettingsStrings.layoutShowWeeksTitle, state.courseCardShowWeeks),
                switchRow("courseCard.show.description", SettingsStrings.layoutShowDescriptionTitle, state.courseCardShowDescription),
            ),
        )

        // 区块 2-3：布局
        nodes += SettingsGap("courseCard.gap.layout")
        nodes += SettingsLabel(
            id = "courseCard.layout.label",
            textKey = SettingsStrings.courseCardSectionLayout.key,
            text = SettingsStrings.courseCardSectionLayout.text,
        )
        nodes += SettingsGroup(
            id = "courseCard.layout",
            children = listOf(
                settingsRow(
                    id = "courseCard.surfaceStyle",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.courseCardSurfaceStyleLabel,
                    // 跳转牌不是第二份选择器（2026-09-25 入口收敛，:205-207）
                    details = state.courseCardSurfaceStyle.label,
                    action = SettingsAction.MATERIAL_PANEL,
                    // 2026-11-01 F25：直达「材质面板 · 课程卡片页签」，不再只推到外观编辑页首页
                    // （Dart `settings_appearance_editor.dart:78-88` 的 `initialMaterialPage`）。
                    // 串没有前导 `/`，是页内目标 id；落点见 `shellPageIdForRoute`。
                    actionTarget = COURSE_CARD_MATERIAL_TARGET,
                ),
                settingsRow(
                    id = "courseCard.verticalAlign",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStrings.layoutVerticalAlignLabel,
                    options = CourseCardVerticalAlign.entries.map { option(it.value, it.label) },
                    selectedOptionId = state.courseCardVerticalAlign.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "courseCard.horizontalAlign",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStrings.layoutHorizontalAlignLabel,
                    options = CourseCardHorizontalAlign.entries.map { option(it.value, it.label) },
                    selectedOptionId = state.courseCardHorizontalAlign.value,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "courseCard.cardFontSize",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStrings.layoutCourseCardFontSizeTitle,
                    value = fontSizeLabel(state.courseCardFontSize),
                    slider = SettingsSliderSpec(FONT_MIN, FONT_MAX, FONT_DIVISIONS, 9.0),
                    sliderValue = state.courseCardFontSize,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "courseCard.compactFontSize",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStrings.layoutCompactFontSizeTitle,
                    value = fontSizeLabel(state.compactFontSize),
                    slider = SettingsSliderSpec(FONT_MIN, FONT_MAX, FONT_DIVISIONS, 9.0),
                    sliderValue = state.compactFontSize,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 区块 4-5：颜色
        nodes += SettingsGap("courseCard.gap.color")
        nodes += SettingsLabel(
            id = "courseCard.color.label",
            textKey = SettingsStrings.courseCardSectionColor.key,
            text = SettingsStrings.courseCardSectionColor.text,
        )
        nodes += SettingsGroup(
            id = "courseCard.color",
            children = buildList {
                add(
                    settingsRow(
                        id = "courseCard.unifiedColor",
                        component = MiuixRowComponent.SWITCH,
                        title = SettingsStrings.unifiedCourseCardColorTitle,
                        subtitle = SettingsStrings.unifiedCourseCardColorSubtitle,
                        switchValue = state.timetableUseUnifiedCardColor,
                        action = SettingsAction.WRITE_SETTING,
                    ),
                )
                if (state.timetableUseUnifiedCardColor) {
                    add(
                        SettingsInline(
                            id = "courseCard.colorChips",
                            kind = InlineKind.COLOR_CHIP_GROUP,
                            note = "八色板胶囊组（:286-299）：官方没有色板组控件，" +
                                "色块颜色与选中态由应用画，颜色值来自 _cardColors",
                            colors = CARD_COLORS,
                            selectedColor = state.timetableUnifiedCardColor,
                        ),
                    )
                }
                add(
                    settingsRow(
                        id = "courseCard.recolor",
                        component = MiuixRowComponent.ARROW,
                        title = SettingsStrings.courseRecolorTileTitle,
                        subtitle = SettingsStrings.courseRecolorTileSubtitle,
                        action = SettingsAction.RECOLOR_SHEET,
                    ),
                )
                add(
                    settingsRow(
                        id = "courseCard.conflictBadge",
                        component = MiuixRowComponent.SWITCH,
                        title = SettingsStrings.layoutShowConflictBadgeTitle,
                        switchValue = state.showConflictBadgeOnTimetable,
                        action = SettingsAction.WRITE_SETTING,
                    ),
                )
                add(
                    settingsRow(
                        id = "courseCard.conflictOpacity",
                        component = MiuixRowComponent.SLIDER,
                        title = SettingsStrings.layoutConflictOpacityTitle,
                        value = conflictOpacityLabel(state.timetableConflictCourseOpacity),
                        slider = SettingsSliderSpec(
                            OPACITY_MIN,
                            OPACITY_MAX,
                            OPACITY_DIVISIONS,
                            0.70,
                        ),
                        sliderValue = state.timetableConflictCourseOpacity,
                        action = SettingsAction.WRITE_SETTING,
                    ),
                )
            },
        )

        // 区块 6：文字颜色（自带前导空档；两个 12dp 空档忠实搬运）
        nodes += SettingsGap("courseCard.gap.textColors")
        nodes += SettingsLabel(
            id = "courseCard.textColors.label",
            textKey = SettingsStrings.appearanceTextColorsSectionTitle.key,
            text = SettingsStrings.appearanceTextColorsSectionTitle.text,
        )
        nodes += SettingsGroup(
            id = "courseCard.textColors",
            children = listOf(
                settingsRow(
                    id = "courseCard.textColors.link",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStrings.textColorIndependentDetail,
                    // 取反：开关「独立设置详情颜色」= 不联动（timetable_text_color_settings.dart:66）
                    switchValue = !state.linkCourseCardColors,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )
        nodes += SettingsGap("courseCard.gap.textColors.afterLink")
        nodes += SettingsGap("courseCard.gap.light")
        nodes += SettingsLabel(
            id = "courseCard.textColors.light.label",
            textKey = SettingsStrings.themeModeLight.key,
            text = SettingsStrings.themeModeLight.text,
        )
        nodes += SettingsGroup(
            id = "courseCard.textColors.light",
            children = colorRows(state, dark = false),
        )
        nodes += SettingsGap("courseCard.gap.textColors.afterLight")
        nodes += SettingsGap("courseCard.gap.dark")
        nodes += SettingsLabel(
            id = "courseCard.textColors.dark.label",
            textKey = SettingsStrings.themeModeDark.key,
            text = SettingsStrings.themeModeDark.text,
        )
        nodes += SettingsGroup(
            id = "courseCard.textColors.dark",
            children = colorRows(state, dark = true),
        )

        // 区块 7：恢复默认（SettingsResetTile 自带空档）
        nodes += SettingsGap("courseCard.gap.reset")
        nodes += SettingsGroup(
            id = "courseCard.reset",
            children = listOf(
                settingsRow(
                    id = "courseCard.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.settingsResetDefaultsTitle,
                    // 课卡作用域与页面标题重合，不加作用域说明（settings_reset.dart:226-233）
                    destructive = true,
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = RESET_SCOPE_COURSE_CARD,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStrings.courseCardSettingsTitle.key,
            title = SettingsStrings.courseCardSettingsTitle.text,
            nodes = nodes,
            collapsibleLargeTitle = false,
            previewFlex = 4,
            contentFlex = 6,
        )
    }

    /**
     * 文字颜色四行（`timetable_text_color_settings.dart:224-241`，scope=courseCard）。
     *
     * 详情色行在联动开启时禁用（:237 `enabled: !settings.linkCourseCardColors`）。
     */
    private fun colorRows(state: SettingsPageState, dark: Boolean): List<SettingsNode> {
        val detailEnabled = !state.linkCourseCardColors
        return if (dark) {
            listOf(
                colorRow("courseCard.textColors.dark.title", SettingsStrings.textColorCourseCardTitle, state.courseCardTitleColorDark, true),
                colorRow("courseCard.textColors.dark.detail", SettingsStrings.textColorCourseCardDetail, state.courseCardDetailColorDark, detailEnabled),
            )
        } else {
            listOf(
                colorRow("courseCard.textColors.light.title", SettingsStrings.textColorCourseCardTitle, state.courseCardTitleColor, true),
                colorRow("courseCard.textColors.light.detail", SettingsStrings.textColorCourseCardDetail, state.courseCardDetailColor, detailEnabled),
            )
        }
    }

    private fun colorRow(id: String, title: ArbText, color: String, enabled: Boolean) = settingsRow(
        id = id,
        component = MiuixRowComponent.COLOR_SWATCH,
        title = title,
        value = color,
        enabled = enabled,
        action = SettingsAction.COLOR_PICKER,
    )

    private fun switchRow(
        id: String,
        title: ArbText,
        value: Boolean,
        enabled: Boolean = true,
    ) = settingsRow(
        id = id,
        component = MiuixRowComponent.SWITCH,
        title = title,
        switchValue = value,
        enabled = enabled,
        action = SettingsAction.WRITE_SETTING,
    )

    /**
     * 冲突课程透明度读数（`settings_course_card.dart:320-321`）：
     * `'${(opacity * 100).round()}%'`，四舍五入到整数百分数。
     */
    fun conflictOpacityLabel(opacity: Double): String = "${(opacity * 100).roundToInt()}%"

    /** 字号读数（:245/:257 `toStringAsFixed(1)`）。 */
    fun fontSizeLabel(size: Double): String = "%.1f".format(Locale.ROOT, size)
}
