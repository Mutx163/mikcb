package com.mutx163.qingyu.pages.settings

import java.util.Locale

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
 * **2026-11-02 起又走共享件 `components.QingyuSliderPreference`**：官方 `Slider`
 * 只挂 `draggable`、纯点击不回调，官方行没把内层滑杆的 `modifier` 开放出来，
 * 只能复制一份官方行、把内层换成补了点击跳转的 `QingyuSlider`（见
 * `components/QingyuSlider.kt`；例外登记在 `docs/reference/miuix-component-first-standard.md`）。
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
        // 官方 `SliderPreference` 的逐字副本 + 内层点击跳转（官方 `Slider` 不认
        // 「点轨道」）。官方补上 tap-to-jump 后换回 `preference.SliderPreference`。
        composeP1Component = "components.QingyuSliderPreference",
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
    /**
     * 是否在轨道上画「建议点位」（`HyperosSliderTile.showKeyPoints`）。
     *
     * 材质面板那几根旋钮有推荐档位（预设档、卡片四根旋钮的建议值），Dart 侧把它们画成
     * 轨道上的小刻点、拖到附近会被吸附（`settings_appearance_editor.dart:1441-1444` 等）。
     * 官方 `preference.SliderPreference` 原生支持 `showKeyPoints` / `keyPoints`，
     * 模型这里只负责把值带过去，不自己画点。
     */
    val showKeyPoints: Boolean = false,
    /** 建议点位的刻度值（与 [min]/[max] 同一坐标系）；null = 不画点。 */
    val keyPoints: List<Double>? = null,
    /**
     * 点开数值输入框时显示的提示语 ARB 键（Dart `HyperosSliderTile.dialogHelper`）。
     *
     * null = **整行没有「点开输入」这回事**：渲染层不给官方 `SliderPreference` 传 `onClick`，
     * 于是行尾不出现箭头、点行也没有反应——与加这两个字段之前完全一样。所以默认值
     * 保证了其它页面的滑杆行为零变化。
     *
     * 出处：`lib/ui/hyperos/hyperos_controls.dart:491-660`（`tapToEdit` 默认 true，
     * 点行/数值 → `showHyperosSliderValueDialog`，确认后 `onChanged(result)`）。
     */
    val dialogHelperKey: String? = null,
    /** 提示语的渲染值（模板语言 zh），与 [dialogHelperKey] 成对。 */
    val dialogHelper: String? = null,
)

/**
 * 滑杆数值输入框的**读数口径**（逐行搬运 Dart `_hyperosSliderInputText` /
 * `_hyperosSliderPrecision` / `_hyperosNormalizeSliderValue`，
 * `lib/ui/hyperos/hyperos_controls.dart:281-337`）。
 *
 * 为什么放在模型层（这里）而不是渲染层：这三段是**纯数值逻辑**，与 Compose 无关，
 * 放在 main 源集才能被 JVM 单测直接覆盖；渲染层只负责把结果画出来。
 *
 * `divisions` 表示「把 min..max 等分成几档」，与官方 `SliderPreference(steps = divisions-1)`
 * 同一口径——输入框里的值必须吸附到与拖动完全相同的档位上，否则「拖到 32、输入 32.4
 * 显示 32.4」会当场对不上。
 */
object SettingsSliderValueLogic {

    /** 没有 divisions 时的显示精度（Dart `_hyperosSliderPrecision` 的 `return 2`）。 */
    const val FALLBACK_PRECISION = 2

    /**
     * 显示/吸附精度：把一档的步长写成小数，取它有效的小数位数（上限 4）。
     *
     * `divisions <= 0` 或区间非法时回落到 [FALLBACK_PRECISION]（Dart 同）。
     */
    fun precision(min: Double, max: Double, divisions: Int): Int {
        if (divisions <= 0 || max <= min) return FALLBACK_PRECISION
        val step = (max - min) / divisions
        val stepText = fixed(step, 6)
        val dot = stepText.indexOf('.')
        if (dot < 0) return 0
        // 去掉尾部的 0 之后还剩几位小数（Dart 用 `replaceFirst(RegExp(r'0+$'))`）。
        val digits = stepText.trimEnd('0').length - dot - 1
        return digits.coerceIn(0, 4)
    }

    /** 输入框里的初始文案（Dart `_hyperosSliderInputText`）：整数就不带小数点，也不会出现二进制尾巴。 */
    fun inputText(value: Double, min: Double, max: Double, divisions: Int): String {
        val precision = precision(min, max, divisions)
        if (precision <= 0 || value == roundDouble(value)) return roundToLong(value).toString()
        val fixedText = fixed(value, precision)
        if (!fixedText.contains('.')) return fixedText
        return fixedText.trimEnd('0').trimEnd('.')
    }

    /**
     * 用户输入 → 真正落盘的值：先按档位吸附，再夹进 [min]..[max]。
     *
     * Dart `_hyperosNormalizeSliderValue` 的顺序是「先 clamp 再吸附再按精度取整再 clamp」，
     * 这里照抄同一顺序——先钳后吸附与先吸附后钳在正常区间内结果相同，但在边界上
     * 能避免出现 `max + step/2` 这种越界值。
     */
    fun normalize(raw: Double, min: Double, max: Double, divisions: Int): Double {
        val lo = minOf(min, max)
        val hi = maxOf(min, max)
        val clamped = raw.coerceIn(lo, hi)
        if (divisions <= 0 || hi <= lo) {
            return roundToPrecision(clamped, precision(lo, hi, 0))
        }
        val step = (hi - lo) / divisions
        val snapped = roundToLong((clamped - lo) / step) * step + lo
        return roundToPrecision(snapped, precision(lo, hi, divisions)).coerceIn(lo, hi)
    }

    /** 定点格式化（Dart `toStringAsFixed`）；`Locale.ROOT` 保证小数点不随系统语言变。 */
    private fun fixed(value: Double, precision: Int): String =
        "%.${precision}f".format(Locale.ROOT, value)

    private fun roundToPrecision(value: Double, precision: Int): Double =
        fixed(value, precision).toDouble()

    private fun roundToLong(value: Double): Long = kotlin.math.round(value).toLong()

    private fun roundDouble(value: Double): Double = roundToLong(value).toDouble()
}

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
     * 整行降到 55% 透明度（Flutter `Opacity(0.55)`，`settings_holiday.dart:613-614`：
     * 已经过去的法定节假日**变淡但仍显示**）。
     *
     * 与 [enabled] 不同：禁用行是「不可交互」的语义（官方组件自己会调灰），
     * 而 dim 是「可读但次要」的视觉层级，渲染层用 `Modifier.alpha(0.55f)` 包整行，
     * 不改组件的禁用态、不改文案颜色。两者可以叠加。
     */
    val dimmed: Boolean = false,
    /**
     * 长按动作（Flutter `HyperosNavTile(onLongPress:)`，`settings_holiday.dart:568-570`：
     * 长按自定义假期行 = 删除确认）。
     *
     * 官方 `ArrowPreference` 没有长按回调，渲染层会在 `BasicComponent` 外挂
     * `Modifier.combinedClickable`（薄封装、不改 miuix 行为）。
     * null = 不响应长按（绝大多数行）。
     */
    val longPressAction: SettingsAction? = null,
    /** 长按动作的 target（与 [actionTarget] 同义，长按通常不需要，留作扩展）。 */
    val longPressTarget: String? = null,
    /**
     * 上下两行左对齐渲染（Flutter 高级页的日志条目：时刻一行 + 正文一行，`settings_holiday.dart:750-781`）。
     *
     * 语义固定为「[title] 在上、用次要色小字；[subtitle] 在下、用主要色正文」
     * ——与 Dart 的日志条目逐字对齐（时刻是 `listDetail` + tabular 数字，正文是
     * `listDetail` + `primaryText` 色）。由渲染层用 `BasicComponent` 的 content 槽实现
     * （仍是官方组件，不手绘行）。
     */
    val stacked: Boolean = false,
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

    /**
     * 桌面小组件的**原生位图轮播**（`settings_home_widget.dart:405-499`）。
     *
     * 与 [PREVIEW_CARD] 的区别：那张卡是 Compose 重画的微缩预览；这一块是十张
     * **真实卡片**的位图（原生 inflate 同一份 RemoteViews 后出 PNG），带分页、
     * 指示点、卡片名、尺寸读数与「添加到桌面」（`HomeWidgetPreviewCarousel.kt`）。
     * 单独一个 kind 而不是复用 PREVIEW_CARD：两者渲染管线完全不同，
     * 混用会让「预览卡」这一处改动同时影响两个页面。
     */
    WIDGET_PREVIEW,
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
    /**
     * 卡内按钮正在执行（Flutter `HyperosButton(loading: true)`，`settings_holiday.dart:806`：
     * 「检查更新」请求期间按钮转圈并不可点）。
     *
     * 渲染层据此把按钮画成 loading 态并吞掉点击——**文案不变**（Dart 的 label 是写死的
     * 「检查更新」，只换 spinner），所以这里只给一个布尔，不给另一套文案。
     */
    val busy: Boolean = false,
    /**
     * 内联文字块的**就地字号倍率**（`1.0` = 与页面其余文字同一档）。
     *
     * 只给 [InlineKind.FONT_PREVIEW] 用：外观页把这句样张的字号交给它（`appTextScale`），
     * 于是拖字号滑杆时**这句样张**当场变大 / 变小，与发布版
     * `lib/screens/settings/settings_appearance.dart:297-318`（`fontSize: 16 * _draft.appTextScale`）
     * 同一口径。整页的全局字号不跟着逐帧重排（理由见 `SettingsHost.commitWrite` 里
     * 拖动闸门那段：拖动中换 `LocalDensity` 会把滑杆自己的拖动会话打断）。
     */
    val textScaleFactor: Double = 1.0,
    /**
     * 内联文字块的**草稿字重**（`null` = 跟随已生效的应用字重）。
     *
     * 与 [textScaleFactor] 同一件事的两半：外观页把 `appFontWeight` 交进来，于是拖字重滑杆时
     * 这句样张当场变粗 / 变细。整页文字的字重仍只在松手后换（同一条拖动闸门，见
     * `SettingsHost.commitWrite`）：拖动中换全局字阶会重排整棵树、打断滑杆的拖动会话。
     */
    val textWeight: Int? = null,
) : SettingsNode

/**
 * 顶栏右侧的单图标动作（Flutter `HyperosSubpage(suffixes: [FHeaderAction(...)])`）。
 *
 * 目前只有一处在用：节假日标记页右上角的齿轮，点它去「节假日数据更新」页
 * （`settings_holiday.dart:466-478`）。渲染层把它塞进 `QingyuPageScaffold(actions = …)`，
 * 点击等价于一次 `NAVIGATE`（路由取 [route]）。
 */
data class SettingsTopAction(
    /** 与行上的 `actionTarget` 同一套路由串（壳的 `shellPageIdForRoute` 负责翻译）。 */
    val route: String,
    /** 无障碍朗读文案（Flutter `semanticsLabel`），不是屏上可见文字。 */
    val semanticsLabel: String,
)

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
    /**
     * 固定底栏节点：**不随列表滚动**，钉在页面底部（Flutter 高级页的「检查更新」按钮，
     * `settings_holiday.dart:792-812` 就是 `Column` 的最后一个子项）。
     *
     * 渲染层把它交给 `QingyuPageScaffold(bottomBar = …)`，因此**不要**同时把它放进 [nodes]。
     */
    val footerNode: SettingsNode? = null,
    /** 顶栏右侧动作；null = 没有（绝大多数页）。 */
    val topBarAction: SettingsTopAction? = null,
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

/**
 * 摊平节点树，只收**行控件**（分组内的行按屏上顺序）。
 *
 * 分派器/宿主关心「哪些行是拖动类」时用它，不要按 id 手写名单。
 */
fun List<SettingsNode>.flattenedSettingsRows(): List<SettingsRow> {
    val out = ArrayList<SettingsRow>()
    fun visit(node: SettingsNode) {
        when (node) {
            is SettingsRow -> out.add(node)
            is SettingsGroup -> node.children.forEach { visit(it) }
            else -> Unit
        }
    }
    forEach { visit(it) }
    return out
}

/**
 * 拖动类（滑杆）行的 id 集合：**落盘防抖的唯一判据**（设置主宿主与外观编辑宿主共用）。
 *
 * 判据是「这一行的组件是 [MiuixRowComponent.SLIDER]」，不是手写 id 名单：
 * 2026-11-05 的手写名单（`material.*` + `.tuning.` / `.darkTuning.` + `backdrop.blur`）漏了
 * `material.general.preset` / `material.courseCard.preset` 两根档位滑杆，于是它们拖动时
 * 每帧走一次 `persistNow()`（同步 `commit()` 写盘 + 整份读回校验），全压在主线程上。
 */
fun debouncedSliderRowIds(nodes: List<SettingsNode>): Set<String> =
    nodes.flattenedSettingsRows()
        .filter { it.component == MiuixRowComponent.SLIDER }
        .map { it.id }
        .toSet()

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
    dimmed: Boolean = false,
    longPressAction: SettingsAction? = null,
    longPressTarget: String? = null,
    stacked: Boolean = false,
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
    dimmed = dimmed,
    longPressAction = longPressAction,
    longPressTarget = longPressTarget,
    stacked = stacked,
)
