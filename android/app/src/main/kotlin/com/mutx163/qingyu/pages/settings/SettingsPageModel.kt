package com.mutx163.qingyu.pages.settings

/**
 * 设置族页面结构模型的**词汇表**（纯 Kotlin，不 import Compose / Miuix）。
 *
 * ## 为什么是「模型」而不是 Composable
 *
 * `android/app/src/main` 是**全变体**源集（Flutter 的 prod 包也编它），而官方
 * Miuix 只挂在 `composeP1` / `composeUi` 的 classpath 上（`android/app/build.gradle`）。
 * 在 main 里 import `top.yukonga.miuix.kmp.*` 会让 `:app:compileProdDebugKotlin`
 * 当场挂——所以模型层只描述「这一页有哪些行、每行是什么、文案是什么、什么时候
 * 可见/可用」，由 `src/composeP1/kotlin/.../pages/settings/` 的渲染层喂给官方组件。
 * 与 `theme/` 泳道同一套先例（`QingyuTheme` 只定语义槽位，不 import Compose）。
 *
 * ## 与 Flutter 版的对应关系
 *
 * 每个 [SettingsNode] 都对应 Flutter 侧一个具名控件，且每行都指明它对应的
 * **官方 Miuix 组件**（见 [MiuixRowComponent]）：规格验收第 5 条要求「官方已有的
 * 组件直接 import 使用、自绘须说明官方没有对应物」，这里把这件事写进模型，
 * 评审时逐行可查、测试里逐项可断言。
 *
 * ## 数据来源纪律
 *
 * 文案只来自 `lib/l10n/app_zh.arb`（模板语言 zh，见 `l10n.yaml`），键与值一并
 * 存在（`*Key` + 文案本体），由 `SettingsArbParityTest` 机械比对——不允许在
 * Kotlin 侧「顺手改写」一句界面文字。
 */

/**
 * 一行设置对应的官方 Miuix 组件。
 *
 * **2026-10-27 升级到 0.9.4 后，[composeP1Component] 已经是官方 preference 系列本体。**
 * 0.8.8 时代整套设置行在 `top.yukonga.miuix.kmp.extra` 的 `Super*` 家族里，
 * 0.9.4 模块化后 `extra` 包**整个消失**，官方改为独立的 `miuix-preference` 模块，
 * 类名为 `top.yukonga.miuix.kmp.preference.{Arrow,Switch,Slider,OverlayDropdown,
 * RadioButton,Checkbox}Preference`（`javap` 逐个核过签名，见渲染层
 * `SettingsPageRenderers.kt` 的 `SettingsRowView`）。
 *
 * - [officialPreference]：升级前对照的**目标组件名**，保留它是因为评审要能一眼看出
 *   「这一行对应官方哪个组件」。0.9.4 落地后两列已基本一致，不再有「靶子」之说；
 * - [composeP1Component]：**实际 import 的包路径与符号**，改渲染层时以这列为准；
 * - [selfDrawn]：非空表示这一行有一部分官方确实没有对应物（评审白名单），
 *   必须在评审里说明理由。
 *
 * 滑杆行（[SLIDER]）的历史：0.8.8 没有官方滑杆行，当时用
 * `basic.BasicComponent` + `basic.Slider` 包了一层；0.9.4 的
 * `preference.SliderPreference` 到位后已改用官方组件，自绘那层删掉了。
 */
enum class MiuixRowComponent(
    val officialPreference: String,
    val composeP1Component: String,
    val selfDrawn: String? = null,
) {
    ARROW(
        officialPreference = "MiuixArrowPreference",
        composeP1Component = "preference.ArrowPreference",
    ),
    SWITCH(
        officialPreference = "MiuixSwitchPreference",
        composeP1Component = "preference.SwitchPreference",
    ),
    SLIDER(
        officialPreference = "MiuixSliderPreference",
        composeP1Component = "preference.SliderPreference",
    ),
    DROPDOWN(
        officialPreference = "MiuixOverlayDropdownPreference",
        composeP1Component = "preference.OverlayDropdownPreference",
    ),
    RADIO(
        officialPreference = "MiuixRadioButtonPreference",
        composeP1Component = "preference.RadioButtonPreference",
    ),
    CHECKBOX(
        officialPreference = "MiuixCheckboxPreference",
        composeP1Component = "preference.CheckboxPreference",
    ),

    /**
     * 文字颜色行：官方**没有**「承载任意色值的偏好行」。行体用官方
     * `preference.ArrowPreference`，行尾那个 36dp 色块是应用画的值展示，选色弹窗用官方
     * `basic.ColorPicker`（Flutter 侧同样用 `MiuixColorPicker`，
     * `lib/widgets/timetable_text_color_settings.dart:358`）。
     */
    COLOR_SWATCH(
        officialPreference = "（官方 preference 无颜色行）",
        composeP1Component = "preference.ArrowPreference + basic.ColorPicker（选色弹窗）",
        selfDrawn = "行内 36dp 色块：官方无承载任意色值的偏好行，色块只做值展示",
    ),
}

/** 行/块的点击语义（渲染层据此接线，不含业务逻辑）。 */
enum class SettingsAction {
    /** 推一个新页；目标见 [SettingsRow.actionTarget]。 */
    NAVIGATE,

    /** 弹官方 BottomSheet。 */
    SHEET,

    /** 弹官方 OverlayDialog。 */
    DIALOG,

    /** 写回设置（设置页的「改一下就存」入口）。 */
    WRITE_SETTING,

    /** 按作用域恢复默认（目标见 [SettingsRow.actionTarget]），写入前须二次确认。 */
    RESET_SCOPE,

    /** 导出到剪贴板。 */
    CLIPBOARD_EXPORT,

    /** 从剪贴板导入。 */
    CLIPBOARD_IMPORT,

    /** 立刻跑一次。 */
    RUN_NOW,

    /** 弹选色器（官方 ColorPicker）。 */
    COLOR_PICKER,

    /** 进外观编辑页的材质面板（课程卡片页）。 */
    MATERIAL_PANEL,

    /** 弹课表重新配色弹层。 */
    RECOLOR_SHEET,
}

/**
 * 下拉/单选的一项。
 *
 * [labelKey] 为 null 表示**这一项的名字不来自 ARB**——目前只有语言下拉里
 * 各语言的自称（`lib/utils/locale_utils.dart:11-31` 的 `nativeNameFor`，
 * 硬编码在 Dart 里），ARB 对照测试对这类项跳过。
 */
data class SettingsOption(
    val id: String,
    val labelKey: String?,
    val label: String,
    /** 主题预设/色点的代表色（`ForuiTheme.seedHex`）。 */
    val seedHex: String? = null,
)

/** 滑杆的上下限与档数（`HyperosSliderTile` 的 min/max/divisions）。 */
data class SettingsSliderSpec(
    val min: Double,
    val max: Double,
    val divisions: Int,
    val defaultValue: Double,
)

/** 页面结构树的节点。 */
sealed interface SettingsNode {
    val id: String
}

/** 行首彩色图标徽章（Flutter `settingsIconBadge(icon, color)` 的对应物）。 */
data class SettingsRowIcon(
    /** Miuix 图标名（渲染层按名取 `MiuixIcons` 扩展：`pin` / `location` / `refresh` …）。 */
    val name: String,
    /** 徽章底色（`#RRGGBB`）；null = 主题主色。 */
    val tintHex: String? = null,
)

/**
 * 一行设置控件。
 *
 * 每个 `*Key` 都配一个同名的渲染值（`titleKey`/`title`、`subtitleKey`/`subtitle`…）：
 * 键给渲染层取资源，值给对照测试逐字比对。带占位符的模板（如 `themeBasedOnModified`）
 * 的渲染值已替换占位符，比对时按「模板片段按序出现」判定。
 */
data class SettingsRow(
    override val id: String,
    val component: MiuixRowComponent,
    val titleKey: String,
    val title: String,
    val subtitleKey: String? = null,
    val subtitle: String? = null,
    /**
     * 行尾**静态**文案（如「导出、导入和切换主题」、当前卡片外观档名）。
     * 渲染层取 `details ?: value` 当行尾文本。
     */
    val detailsKey: String? = null,
    val details: String? = null,
    /**
     * 行尾**动态**取值（滑杆读数、当前色值、当前定时时刻）；
     * [valueKey] 非空表示这个值本身就是一句 ARB 文案（如字号的「默认」）。
     */
    val valueKey: String? = null,
    val value: String? = null,
    /** 开关行的当前态（`HyperosSwitchTile.value`）。 */
    val switchValue: Boolean? = null,
    /** false = 行禁用（Flutter 侧 `onChanged: null`）。 */
    val enabled: Boolean = true,
    /** 行首图标徽章；null = 无图标。 */
    val icon: SettingsRowIcon? = null,
    /** 危险操作行（恢复默认），渲染层按 `QingyuFixedTokens.DESTRUCTIVE` 上色。 */
    val destructive: Boolean = false,
    val options: List<SettingsOption> = emptyList(),
    val selectedOptionId: String? = null,
    val slider: SettingsSliderSpec? = null,
    /** 滑杆当前值（[value] 是给人看的读数，这个给组件定位滑块）。 */
    val sliderValue: Double? = null,
    val action: SettingsAction? = null,
    val actionTarget: String? = null,
    /** 行尾附加按钮的文案（目前只有「更多操作」的 tooltip）。 */
    val trailingActionKey: String? = null,
    val trailingAction: String? = null,
    val trailingActionKind: SettingsAction? = null,
    /** 行内色点预览（已存主题的 `previewColors`）。 */
    val previewColors: List<String> = emptyList(),
    /**
     * 以**独立摘要卡**渲染（`HyperosSummaryCard`）：设置首页顶部的学期摘要。
     * 与普通行不同，它不套在分组卡里，自己就是一张白卡（16dp 内边距、可点、带右箭头）。
     */
    val standaloneSummaryCard: Boolean = false,
    /** 摘要卡左侧显示应用图标（`HyperosSummaryCard.leading` 用的是启动图，44dp / 圆角 12）。 */
    val leadingAppIcon: Boolean = false,
) : SettingsNode

/** 一个白卡分组（`HyperosListGroup` / `HyperosControlCard`）。 */
data class SettingsGroup(
    override val id: String,
    val children: List<SettingsNode>,
) : SettingsNode

/** 分组小标题（`HyperosSectionLabel`，Miuix preference category）。 */
data class SettingsLabel(
    override val id: String,
    val textKey: String,
    val text: String,
) : SettingsNode

/** 整宽段说明（`HyperosSectionDescription`），**不受**单行 11/17 口径约束。 */
data class SettingsDescription(
    override val id: String,
    val textKey: String,
    val text: String,
) : SettingsNode

/** 区块间空档（`HyperosSectionGap` = `SizedBox(height: 12)`，`HyperosTokens.sectionGap`）。 */
data class SettingsGap(
    override val id: String,
    val heightDp: Double = SECTION_GAP_DP,
) : SettingsNode

/** 内联块里的一处文案。 */
data class SettingsInlineText(val key: String, val text: String)

/** 官方 preference 系列没有对应物的内联块（预览卡 / 色板 / 控制卡头）。 */
enum class InlineKind {
    /** 外观页顶部的主题预览卡（Flutter 侧是自绘的微缩预览）。 */
    PREVIEW_CARD,

    /** 字号实时预览条。 */
    FONT_PREVIEW,

    /** 统一课卡色的八色板（`HyperosHexColorChipGroup`）。 */
    COLOR_CHIP_GROUP,

    /** 带标题/副标题/按钮的控制卡（`HyperosControlCard`）。 */
    CONTROL_CARD,
}

/**
 * 内联块。
 *
 * [note] 说明它为什么不是一行 Preference、以及官方有没有对应物（评审用）。
 */
data class SettingsInline(
    override val id: String,
    val kind: InlineKind,
    val note: String,
    val labelKey: String? = null,
    val label: String? = null,
    val valueKey: String? = null,
    val value: String? = null,
    val texts: List<SettingsInlineText> = emptyList(),
    val colors: List<String> = emptyList(),
    val selectedColor: String? = null,
) : SettingsNode

/** 一页的完整结构。 */
data class SettingsPageSpec(
    val id: String,
    val titleKey: String,
    val title: String,
    val nodes: List<SettingsNode>,
    /** 顶栏大标题是否随滚动折叠（课程卡片页因预览区不在顶栏下而为 false）。 */
    val collapsibleLargeTitle: Boolean = true,
    /** 预览区与可调项的高度权重（课程卡片页 4:6），null 表示本页无预览区。 */
    val previewFlex: Int? = null,
    val contentFlex: Int? = null,
)

/** `HyperosTokens.sectionGap`（`lib/ui/hyperos/hyperos_tokens.dart`，与 theme/ 桥一致）。 */
const val SECTION_GAP_DP = 12.0

/**
 * 「这段文案不来自 ARB」的键值。
 *
 * 目前只有主题管理页「我的主题」的行标题（用户自己起的主题名）。
 * `SettingsArbParityTest` 跳过空键，其余每一处文案都必须能在 `app_zh.arb` 里找到。
 */
const val NON_ARB_TEXT = ""

// ------------------------------------------------------------------ 构造助手

/** ARB 文案：键 + 模板语言（zh）的逐字值。 */
data class ArbText(val key: String, val zh: String) {

    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)
}

fun option(id: String, label: ArbText, seedHex: String? = null): SettingsOption =
    SettingsOption(id = id, labelKey = label.key, label = label.zh, seedHex = seedHex)

/** 名字不来自 ARB 的选项（语言下拉里的语言自称）。 */
fun nativeOption(id: String, label: String): SettingsOption =
    SettingsOption(id = id, labelKey = null, label = label)

@Suppress("LongParameterList")
fun settingsRow(
    id: String,
    component: MiuixRowComponent,
    title: ArbText,
    subtitle: ArbText? = null,
    details: ArbText? = null,
    valueKey: String? = null,
    value: String? = null,
    switchValue: Boolean? = null,
    enabled: Boolean = true,
    destructive: Boolean = false,
    icon: SettingsRowIcon? = null,
    options: List<SettingsOption> = emptyList(),
    selectedOptionId: String? = null,
    slider: SettingsSliderSpec? = null,
    sliderValue: Double? = null,
    action: SettingsAction? = null,
    actionTarget: String? = null,
    trailingActionKey: String? = null,
    trailingAction: String? = null,
    trailingActionKind: SettingsAction? = null,
    previewColors: List<String> = emptyList(),
    standaloneSummaryCard: Boolean = false,
    leadingAppIcon: Boolean = false,
): SettingsRow = SettingsRow(
    id = id,
    component = component,
    titleKey = title.key,
    title = title.zh,
    subtitleKey = subtitle?.key,
    subtitle = subtitle?.zh,
    detailsKey = details?.key,
    details = details?.zh,
    valueKey = valueKey,
    value = value,
    switchValue = switchValue,
    enabled = enabled,
    destructive = destructive,
    icon = icon,
    options = options,
    selectedOptionId = selectedOptionId,
    slider = slider,
    sliderValue = sliderValue,
    action = action,
    actionTarget = actionTarget,
    trailingActionKey = trailingActionKey,
    trailingAction = trailingAction,
    trailingActionKind = trailingActionKind,
    previewColors = previewColors,
    standaloneSummaryCard = standaloneSummaryCard,
    leadingAppIcon = leadingAppIcon,
)
