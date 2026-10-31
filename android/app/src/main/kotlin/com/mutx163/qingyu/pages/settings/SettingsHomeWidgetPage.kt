package com.mutx163.qingyu.pages.settings

import java.util.Locale
import kotlin.math.roundToInt

/**
 * 桌面小组件设置页（`lib/screens/settings/settings_home_widget.dart`，1154 行）
 * 结构模型。
 *
 * ## 逐项对照（Flutter → 本模型）
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSubpage(title: homeWidgetSettingsTitle)`（:197-204） | `titleKey/title` | `basic.TopAppBar` |
 * | `_buildPreviewSection`（:405-499） | `SettingsInline(WIDGET_PREVIEW)` | 官方无对应物：原生渲染的卡片位图 |
 * | `HyperosHintBanner`（精确闹钟，:1036-1065） | `SettingsInline(CONTROL_CARD)` | 官方无对应物：引导条 |
 * | `HyperosSectionLabel(今日课程组件)`（:229） | `homeWidget.todayCourse.label` | preference category |
 * | `HyperosSelectTile<WidgetBackgroundStyle>`（:232-241） | `homeWidget.backgroundStyle` | `MiuixOverlayDropdownPreference` |
 * | `HyperosSelectTile<WidgetCourseAccentMode>`（:248-258） | `homeWidget.courseAccent` | 同上 |
 * | `HyperosSwitchTile`×4（:259-294） | `homeWidget.showLocation` 等 | `MiuixSwitchPreference` |
 * | `HyperosSectionLabel(倒计时提前量)`（:303） | `homeWidget.countdown.label` | preference category |
 * | `HyperosSelectTile<int>`（:306-319） | `homeWidget.countdownLead` | `MiuixOverlayDropdownPreference` |
 * | `HyperosSelectTile<LiveCountdownTextStyle>`（:320-332） | `homeWidget.countdownStyle` | 同上 |
 * | `HyperosSectionLabel(卡片外观)`（:341） | `homeWidget.appearance.label` | preference category |
 * | `HyperosSliderTile(卡片高度)`（:347-363） | `homeWidget.heightAdjust` | `MiuixSliderPreference` |
 * | `HyperosSliderTile(卡片圆角)`（:364-375） | `homeWidget.cornerRadius` | `MiuixSliderPreference` |
 * | `HyperosSectionLabel(各卡片绑定管理)`（:838） | `homeWidget.binding.label` | preference category |
 * | 每张卡片一个 `HyperosSelectTile<String>`（:841-863） | `homeWidget.binding.<appWidgetId>` | `MiuixOverlayDropdownPreference` |
 * | 空态 `Text(homeWidgetBindingEmpty)`（:813-822） | `SettingsDescription` | 整宽说明 |
 * | `SettingsResetTile(homeWidget)`（:381-384） | `homeWidget.reset.row` | `MiuixArrowPreference`（危险色） |
 *
 * ## 三条「本页独有的错位」，每一条都容易写反
 *
 * 1. **倒计时区块是可选的**：`_homeWidgetSectionCount => (_draft.widgetShowCountdown ? 4 : 3) + 2`
 *    （:214），且 `if (!_draft.widgetShowCountdown && section >= 2) section += 1`（:219-221）
 *    ——关掉「显示倒计时」后，倒计时提前量与倒计时样式**两行一起消失**；
 * 2. **卡片高度是相对档**：存储值 `-11` 是默认，滑杆读数是「相对 -11 的偏移」
 *    （:344-352），所以 `sliderValue = widgetHeightAdjustment + 11`，
 *    而落盘时 `widgetHeightAdjustment = -11 + offset`；
 * 3. **绑定下拉的「跟随当前课表」用空串占位**：语义是 `null`（未登记），但
 *    `HyperosSelectTile` 对 null 值不渲染值标签（:49-52），所以模型里也用空串。
 *
 * ## 未纳入本模型的三件事（都在别的层）
 *
 * 1. 预览位图的渲染管线（`HomeWidgetService.renderPreview` + 代次作废 + 8 秒超时，
 *    :736-800）—— 渲染层/接线层的事，模型只给出「有哪十张卡片、尺寸读数怎么拼」；
 * 2. 落盘的防抖与串行队列（`_enqueuePersist` / `_drainPersistQueue`，:924-958）；
 * 3. 「润色后的草稿被 provider 拒绝时拉回真值」（`reportSettingsPersistRejected`，:960-988）。
 */
object SettingsHomeWidgetPage {

    const val ID = "settings-home-widget"

    /** `_defaultWidgetHeightAdjustment`（:46）：卡片高度的默认档存储值。 */
    const val DEFAULT_HEIGHT_ADJUSTMENT = -11.0

    /** `_defaultWidgetCornerRadius`（:47）。 */
    const val DEFAULT_CORNER_RADIUS = 22.0

    /** 高度滑杆相对默认档的偏移范围（:352-354：-16~16、32 档）。 */
    const val HEIGHT_OFFSET_MIN = -16.0
    const val HEIGHT_OFFSET_MAX = 16.0
    const val HEIGHT_OFFSET_DIVISIONS = 32

    /** 圆角滑杆范围（:368-370：默认 ±14、28 档）。 */
    const val CORNER_RADIUS_MIN = DEFAULT_CORNER_RADIUS - 14.0
    const val CORNER_RADIUS_MAX = DEFAULT_CORNER_RADIUS + 14.0
    const val CORNER_RADIUS_DIVISIONS = 28

    /** 「跟随当前课表」的占位值（`_followActiveValue`，:52）。 */
    const val FOLLOW_ACTIVE_VALUE = ""

    /** `kHomeWidgetCoupleMergedBindingId`（`home_widget_binding_service.dart:19`）。 */
    const val COUPLE_MERGED_BINDING_ID = "couple-merged"

    /** `SettingsResetScope.homeWidget`（`settings_reset.dart:31-32`）。 */
    const val RESET_SCOPE_HOME_WIDGET = "homeWidget"

    /** 路由（Dart 侧 `RouteSettings(name: ...)` 常量）。 */
    const val ROUTE_GLASS_DOCK_ICON = "/settings/glass-dock-icon"

    /** 倒计时提前量的九档分钟（:310 `const [1, 5, 10, 15, 20, 30, 40, 50, 60]`）。 */
    val COUNTDOWN_LEAD_MINUTES: List<Int> = listOf(1, 5, 10, 15, 20, 30, 40, 50, 60)

    /**
     * 预览轮播的十张卡片，顺序与 `buildHomeWidgetPreviewSpecs`
     * （`home_widget_service.dart:115-126`）**逐项一致**：今日课程系 → 统计系 → 考试卡。
     */
    val PREVIEW_TARGETS: List<WidgetTarget> = listOf(
        WidgetTarget("compact", SettingsStringsExt2.homeWidgetTargetCompact22),
        WidgetTarget("mini_list", SettingsStringsExt2.homeWidgetTargetMiniList22),
        WidgetTarget("medium", SettingsStringsExt2.homeWidgetTargetMedium24),
        WidgetTarget("large", SettingsStringsExt2.homeWidgetTargetLarge44),
        WidgetTarget("today_strip", SettingsStringsExt2.homeWidgetTargetTodayStrip41),
        WidgetTarget("today_wide", SettingsStringsExt2.homeWidgetTargetTodayWide42),
        WidgetTarget("stats_compact", SettingsStringsExt2.homeWidgetTargetStats22),
        WidgetTarget("stats_medium", SettingsStringsExt2.homeWidgetTargetStats24),
        WidgetTarget("stats_strip", SettingsStringsExt2.homeWidgetTargetStatsStrip41),
        WidgetTarget("exam_card", SettingsStringsExt2.homeWidgetTargetExamCard22),
    )

    /** 一张预览卡片：`HomeWidgetPinTarget.value` + 它的 ARB 名称。 */
    data class WidgetTarget(val id: String, val label: ArbText)

    fun spec(state: SettingsHomeWidgetState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 区块 0：效果预览（无前导空档，_PreviewKeepAlive 保活）
        nodes += previewNodes(state)

        // 区块 1：今日课程组件
        nodes += SettingsGap("homeWidget.gap.todayCourse")
        nodes += SettingsLabel(
            id = "homeWidget.todayCourse.label",
            textKey = SettingsStringsExt2.homeWidgetTodayCourseTitle.key,
            text = SettingsStringsExt2.homeWidgetTodayCourseTitle.zh,
        )
        nodes += SettingsGroup(
            id = "homeWidget.todayCourse",
            children = listOf(
                settingsRow(
                    id = "homeWidget.backgroundStyle",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStringsExt2.homeWidgetBackgroundStyleLabel,
                    options = backgroundStyleOptions(),
                    selectedOptionId = state.backgroundStyle,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeWidget.courseAccent",
                    component = MiuixRowComponent.DROPDOWN,
                    title = SettingsStringsExt2.homeWidgetCourseAccentTitle,
                    // 不挂副标题：三档选项名已各自说清（:245-247）
                    options = courseAccentOptions(),
                    selectedOptionId = state.courseAccentMode,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeWidget.showLocation",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt2.homeWidgetShowLocationTitle,
                    subtitle = SettingsStringsExt2.homeWidgetShowLocationSubtitle,
                    switchValue = state.showLocation,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeWidget.showCountdown",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt2.homeWidgetShowCountdownTitle,
                    subtitle = SettingsStringsExt2.homeWidgetShowCountdownSubtitle,
                    switchValue = state.showCountdown,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeWidget.hideCompleted",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt2.homeWidgetHideCompletedTitle,
                    subtitle = SettingsStringsExt2.homeWidgetHideCompletedSubtitle,
                    switchValue = state.hideCompletedCourses,
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeWidget.showTomorrow",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt2.homeWidgetShowTomorrowTitle,
                    subtitle = SettingsStringsExt2.homeWidgetShowTomorrowSubtitle,
                    switchValue = state.showTomorrowCourses,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 区块 2：倒计时（「显示倒计时」关掉时整块不存在，:214/:219-221）
        if (state.showCountdown) {
            nodes += SettingsGap("homeWidget.gap.countdown")
            nodes += SettingsLabel(
                id = "homeWidget.countdown.label",
                textKey = SettingsStringsExt2.homeWidgetCountdownLeadTitle.key,
                text = SettingsStringsExt2.homeWidgetCountdownLeadTitle.zh,
            )
            nodes += SettingsGroup(
                id = "homeWidget.countdown",
                children = listOf(
                    settingsRow(
                        id = "homeWidget.countdownLead",
                        component = MiuixRowComponent.DROPDOWN,
                        // 行标题复用区标题（Dart :307 label: homeWidgetCountdownLeadTitle）
                        title = SettingsStringsExt2.homeWidgetCountdownLeadTitle,
                        options = countdownLeadOptions(),
                        selectedOptionId = state.countdownLeadMinutes.toString(),
                        action = SettingsAction.WRITE_SETTING,
                    ),
                    settingsRow(
                        id = "homeWidget.countdownStyle",
                        component = MiuixRowComponent.DROPDOWN,
                        title = SettingsStringsExt2.widgetCountdownStyleTitle,
                        options = countdownStyleOptions(),
                        selectedOptionId = state.countdownTextStyle,
                        action = SettingsAction.WRITE_SETTING,
                    ),
                ),
            )
        }

        // 区块 3：卡片外观
        nodes += SettingsGap("homeWidget.gap.appearance")
        nodes += SettingsLabel(
            id = "homeWidget.appearance.label",
            textKey = SettingsStringsExt2.homeWidgetAppearanceTitle.key,
            text = SettingsStringsExt2.homeWidgetAppearanceTitle.zh,
        )
        nodes += SettingsGroup(
            id = "homeWidget.appearance",
            children = listOf(
                settingsRow(
                    id = "homeWidget.heightAdjust",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStringsExt2.homeWidgetHeightAdjustTitle,
                    valueKey = heightAdjustmentValueKey(state.heightAdjustment),
                    value = heightAdjustmentLabel(state.heightAdjustment),
                    slider = SettingsSliderSpec(
                        min = HEIGHT_OFFSET_MIN,
                        max = HEIGHT_OFFSET_MAX,
                        divisions = HEIGHT_OFFSET_DIVISIONS,
                        defaultValue = 0.0,
                        // 只有「卡片高度」这一根滑杆能点开数值输入框（Dart :355
                        // `dialogHelper: l10n.homeWidgetHeightAdjustHint`）；圆角那根
                        // 原版没给 helper，也就没有弹框，保持不填。
                        dialogHelperKey = SettingsStringsExt2.homeWidgetHeightAdjustHint.key,
                        dialogHelper = SettingsStringsExt2.homeWidgetHeightAdjustHint.zh,
                    ),
                    sliderValue = heightOffset(state.heightAdjustment),
                    action = SettingsAction.WRITE_SETTING,
                ),
                settingsRow(
                    id = "homeWidget.cornerRadius",
                    component = MiuixRowComponent.SLIDER,
                    title = SettingsStringsExt2.homeWidgetCornerRadiusTitle,
                    value = cornerRadiusLabel(state.cornerRadius),
                    slider = SettingsSliderSpec(
                        min = CORNER_RADIUS_MIN,
                        max = CORNER_RADIUS_MAX,
                        divisions = CORNER_RADIUS_DIVISIONS,
                        defaultValue = DEFAULT_CORNER_RADIUS,
                    ),
                    sliderValue = state.cornerRadius,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        // 区块 4：各卡片绑定管理
        nodes += SettingsGap("homeWidget.gap.binding")
        nodes += SettingsLabel(
            id = "homeWidget.binding.label",
            textKey = SettingsStringsExt2.homeWidgetBindingSectionTitle.key,
            text = SettingsStringsExt2.homeWidgetBindingSectionTitle.zh,
        )
        nodes += bindingBlock(state)

        // 区块 5：恢复默认（外层 gap + SettingsResetTile 自带 gap，忠实搬运两个空档）
        nodes += SettingsGap("homeWidget.gap.resetOuter")
        nodes += SettingsGap("homeWidget.gap.reset")
        nodes += SettingsGroup(
            id = "homeWidget.reset",
            children = listOf(
                settingsRow(
                    id = "homeWidget.reset.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStrings.settingsResetDefaultsTitle,
                    // 本页作用域与页面标题不重合，但 settings_reset.dart:226-233
                    // 只给 appearance / timetablePage 两句说明，homeWidget 不加
                    destructive = true,
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = RESET_SCOPE_HOME_WIDGET,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt2.homeWidgetSettingsTitle.key,
            title = SettingsStringsExt2.homeWidgetSettingsTitle.zh,
            nodes = nodes,
        )
    }

    // ------------------------------------------------------------------ 预览区

    /**
     * 效果预览区（:405-499）。
     *
     * 预览图是**原生把真实卡片的 RemoteViews 渲染成 PNG** 传回来的，不是 Compose
     * 重画（:401-403），所以整块交给渲染层的 `preview` 槽位；模型只负责：
     * 区块标题、轮播里有哪些卡片（[PREVIEW_TARGETS]）、以及「添加到桌面」按钮。
     *
     * 精确闹钟引导条（:493-496）挂在**这个区块的末尾**——2026-10-21 用户要求从
     * 页面顶部挪到这里：先看效果、再添加、最后才看到「添了但不刷新」的原因。
     */
    private fun previewNodes(state: SettingsHomeWidgetState): List<SettingsNode> {
        val carousel = SettingsInline(
            id = "homeWidget.preview",
            kind = InlineKind.WIDGET_PREVIEW,
            note = "效果预览轮播（:405-499）：官方没有「原生小组件位图预览」控件，" +
                "十张卡片按 ${PREVIEW_TARGETS.size} 个格位由原生渲染后回传 PNG，" +
                "渲染层见 HomeWidgetPreviewCarousel.kt",
            labelKey = SettingsStringsExt2.homeWidgetPreviewTitle.key,
            label = SettingsStringsExt2.homeWidgetPreviewTitle.zh,
            texts = listOf(
                SettingsInlineText(
                    SettingsStringsExt2.homeWidgetPreviewAddAction.key,
                    SettingsStringsExt2.homeWidgetPreviewAddAction.zh,
                ),
            ),
        )
        if (state.exactAlarmGranted != false) return listOf(carousel)
        // 精确闹钟未授权：紧跟在「添加到桌面」下面（:493-496），单独一个内联块
        val banner = SettingsInline(
            id = "homeWidget.preview.alarmBanner",
            kind = InlineKind.CONTROL_CARD,
            note = "精确闹钟权限引导（:1036-1065）：官方没有「图标 + 标题 + 正文 + 按钮」的提示条，" +
                "用 Card 组出来（HyperosHintBanner 的对应物）",
            labelKey = SettingsStringsExt2.homeWidgetExactAlarmBannerTitle.key,
            label = SettingsStringsExt2.homeWidgetExactAlarmBannerTitle.zh,
            valueKey = SettingsStringsExt2.homeWidgetExactAlarmBannerText.key,
            value = SettingsStringsExt2.homeWidgetExactAlarmBannerText.zh,
            texts = listOf(
                SettingsInlineText(
                    SettingsStringsExt2.homeWidgetExactAlarmGrantAction.key,
                    SettingsStringsExt2.homeWidgetExactAlarmGrantAction.zh,
                ),
            ),
        )
        return listOf(carousel, banner)
    }

    // --------------------------------------------------------------- 绑定管理

    /**
     * 各卡片绑定管理（:804-868）。
     *
     * 空态：整组只有一句说明（:805-827）。有卡片时每张卡片一行下拉，
     * 选项 = 跟随当前课表 → 普通课表 → 情侣课表 → TA 课表。
     */
    private fun bindingBlock(state: SettingsHomeWidgetState): SettingsNode {
        if (state.widgetInstances.isEmpty()) {
            return SettingsDescription(
                id = "homeWidget.binding.empty",
                textKey = SettingsStringsExt2.homeWidgetBindingEmpty.key,
                text = SettingsStringsExt2.homeWidgetBindingEmpty.zh,
            )
        }
        return SettingsGroup(
            id = "homeWidget.binding",
            children = state.widgetInstances.map { instance ->
                settingsRow(
                    id = "homeWidget.binding.${instance.appWidgetId}",
                    component = MiuixRowComponent.DROPDOWN,
                    // 行标题是卡片类型名，不是「卡片 1/2/3」（:843-846）
                    title = targetLabelFor(pinTargetForType(instance.widgetTypeValue)),
                    options = bindingOptions(state),
                    selectedOptionId = instance.boundProfileId ?: FOLLOW_ACTIVE_VALUE,
                    action = SettingsAction.WRITE_SETTING,
                    actionTarget = instance.appWidgetId.toString(),
                )
            },
        )
    }

    /**
     * 绑定下拉的选项表（:847-857）。
     *
     * 顺序：跟随当前课表 → 普通课表（`!isPartnerImported`）→ 情侣课表（合并视图）
     * → TA 课表。情侣课表排在 TA 课表**前面**：它是情侣功能的主视图（:850-851）。
     */
    fun bindingOptions(state: SettingsHomeWidgetState): List<SettingsOption> {
        val out = mutableListOf(
            option(FOLLOW_ACTIVE_VALUE, SettingsStringsExt2.homeWidgetBindingFollowActive),
        )
        state.profiles.filterNot { it.isPartnerImported }.forEach { profile ->
            // 课表名是用户数据，不来自 ARB（NON_ARB_TEXT）
            out += nativeOption(profile.id, profile.name)
        }
        state.partnerProfile?.let { partner ->
            out += option(COUPLE_MERGED_BINDING_ID, SettingsStringsExt2.homeWidgetBindingCoupleMerged)
            out += nativeOption(partner.id, partner.name)
        }
        return out
    }

    // -------------------------------------------------------------- 选项表构造

    /** 背景样式三档（`WidgetBackgroundStyle`，`timetable_settings_extensions.dart:31-36`）。 */
    fun backgroundStyleOptions(): List<SettingsOption> = listOf(
        option("glass", SettingsStringsExt2.widgetBackgroundStyleGlass),
        option("solid", SettingsStringsExt2.widgetBackgroundStyleSolid),
        option("gradient", SettingsStringsExt2.widgetBackgroundStyleGradient),
    )

    /** 课程颜色三档（`WidgetCourseAccentMode`，`widget_course_accent.dart:23-30`）。 */
    fun courseAccentOptions(): List<SettingsOption> = listOf(
        option("off", SettingsStringsExt2.widgetCourseAccentModeOff),
        option("bar", SettingsStringsExt2.widgetCourseAccentModeBar),
        option("bar_and_text", SettingsStringsExt2.widgetCourseAccentModeBarAndText),
    )

    /**
     * 倒计时提前量十档（:308-313）：0 = 始终显示，其余走 `beforeClassMinutesOption`
     * 的模板（`{minutes} 分钟`）。
     */
    fun countdownLeadOptions(): List<SettingsOption> = buildList {
        add(option("0", SettingsStringsExt2.homeWidgetCountdownLeadAlways))
        COUNTDOWN_LEAD_MINUTES.forEach { minutes ->
            add(
                option(
                    minutes.toString(),
                    ArbText(
                        SettingsStringsExt2.beforeClassMinutesOption.key,
                        SettingsStringsExt2.beforeClassMinutesOption.zh.replace("{minutes}", minutes.toString()),
                    ),
                ),
            )
        }
    }

    /**
     * 倒计时样式十二档（`LiveCountdownTextStyle`，`timetable_settings_enums.dart:244-257`；
     * 落盘串见 `timetable_settings_extensions.dart:153-167`）。
     */
    fun countdownStyleOptions(): List<SettingsOption> = listOf(
        option("smart", SettingsStringsExt2.liveCountdownTextStyleSmart),
        option("smart_min_s", SettingsStringsExt2.liveCountdownTextStyleSmartMinS),
        option("minute_second_cn", SettingsStringsExt2.liveCountdownTextStyleMinuteSecondCn),
        option("minute_second_colon", SettingsStringsExt2.liveCountdownTextStyleMinuteSecondColon),
        option("minute_second_min_s", SettingsStringsExt2.liveCountdownTextStyleMinuteSecondMinS),
        option("minute_second_min_slash_s", SettingsStringsExt2.liveCountdownTextStyleMinuteSecondMinSlashS),
        option("minute_only_cn", SettingsStringsExt2.liveCountdownTextStyleMinuteOnlyCn),
        option("minute_only_min", SettingsStringsExt2.liveCountdownTextStyleMinuteOnlyMin),
        option("minute_only_slash", SettingsStringsExt2.liveCountdownTextStyleMinuteOnlySlash),
        option("second_only_cn", SettingsStringsExt2.liveCountdownTextStyleSecondOnlyCn),
        option("second_only_short", SettingsStringsExt2.liveCountdownTextStyleSecondOnlyShort),
        option("second_only_slash", SettingsStringsExt2.liveCountdownTextStyleSecondOnlySlash),
    )

    // ------------------------------------------------------------- 纯函数行为

    /** 卡片高度滑杆读数 = 存储值相对默认档（-11）的偏移（:344-352）。 */
    fun heightOffset(stored: Double): Double = stored - DEFAULT_HEIGHT_ADJUSTMENT

    /** 滑杆读数 → 存储值（`_defaultWidgetHeightAdjustment + offset`，:358-359）。 */
    fun storedHeightFromOffset(offset: Double): Double = DEFAULT_HEIGHT_ADJUSTMENT + offset

    /**
     * 「卡片高度」的值标签（:914-922）。
     *
     * `offset == 0` → 「默认」；正负分别用 `higherByValue` / `lowerByValue`，
     * `dp` 数取 `toStringAsFixed(0)`（四舍五入，`Locale.ROOT` 定点）。
     */
    fun heightAdjustmentLabel(stored: Double): String {
        val offset = heightOffset(stored)
        if (offset == 0.0) return SettingsStringsExt2.defaultLabel.zh
        val dpText = "${fixed0(kotlin.math.abs(offset))}dp"
        return if (offset > 0) {
            SettingsStringsExt2.higherByValue.filled("value", dpText)
        } else {
            SettingsStringsExt2.lowerByValue.filled("value", dpText)
        }
    }

    /** 值标签对应的 ARB 键（null = 不是整句 ARB 模板）。 */
    fun heightAdjustmentValueKey(stored: Double): String? {
        val offset = heightOffset(stored)
        return when {
            offset == 0.0 -> SettingsStringsExt2.defaultLabel.key
            offset > 0 -> SettingsStringsExt2.higherByValue.key
            else -> SettingsStringsExt2.lowerByValue.key
        }
    }

    /** 「卡片圆角」读数（:366 `'${widgetCornerRadius.toStringAsFixed(0)}dp'`）。 */
    fun cornerRadiusLabel(cornerRadius: Double): String = "${fixed0(cornerRadius)}dp"

    /**
     * 预览图尺寸读数（`home_widget_service.dart:86`
     * `'${widthDp.round()} × ${heightDp.round()} dp'`）。注意乘号两侧各一个空格。
     */
    fun sizeLabel(widthDp: Double, heightDp: Double): String =
        "${widthDp.roundToInt()} × ${heightDp.roundToInt()} dp"

    /**
     * `HomeWidgetType` → `HomeWidgetPinTarget`（:870-880）。
     *
     * null（未知类型）一律回落 `compact`——与 Dart 的 switch 默认分支一致。
     */
    fun pinTargetForType(typeValue: String?): String = when (typeValue) {
        "mini_list" -> "mini_list"
        "medium" -> "medium"
        "large" -> "large"
        "today_strip" -> "today_strip"
        "today_wide" -> "today_wide"
        else -> "compact"
    }

    /** 预览格位 id → ARB 名称（:17-34 的 `_homeWidgetTargetLabel`）。 */
    fun targetLabelFor(targetId: String): ArbText =
        PREVIEW_TARGETS.firstOrNull { it.id == targetId }?.label
            ?: SettingsStringsExt2.homeWidgetTargetCompact22

    /** Dart `toStringAsFixed(0)`：四舍五入到整数，`Locale.ROOT` 定点。 */
    private fun fixed0(value: Double): String = "%.0f".format(Locale.ROOT, value)
}
