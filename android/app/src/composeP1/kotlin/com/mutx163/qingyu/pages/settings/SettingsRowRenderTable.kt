package com.mutx163.qingyu.pages.settings

/**
 * 渲染层与模型层之间的**字段契约表**（纯 Kotlin，不 import Compose）。
 *
 * 模型层（`src/main/.../pages/settings/`）只描述「这一页有哪些行、每行是什么」；
 * 这张表说明「每一类行在渲染层由哪个官方 Miuix 组件承担、渲染它必须有哪些字段」。
 * 由 `SettingsRenderContractTest` 逐项断言，两个方向都钉住：
 *
 * 1. 表里声明的官方组件名，必须在渲染层源码里真的 import 并用到
 *    （防「表里写了、代码没接」）；
 * 2. 三页 spec 里的每一行，都必须满足它那一类的字段要求
 *    （防「模型漏填 switchValue / options 后渲染层静默显示空行」）。
 *
 * ## 为什么 0.8.8 用 `extra.Super*` 而不是 `preference.*`
 *
 * 实测 `top.yukonga.miuix.kmp:miuix-android:0.8.8` 的 AAR 里**没有 preference
 * 包**；设置行整套在 `top.yukonga.miuix.kmp.extra` 的 `Super*` 家族里
 * （`javap` 核过签名）。这是「官方已有组件直接用」，不是自绘；0.9.4 升级后
 * 换成 `miuix-preference` 的同名组件（[MiuixRowComponent.officialPreference]）。
 */
object SettingsRowRenderTable {

    private const val EXTRA = "top.yukonga.miuix.kmp.extra."
    private const val BASIC = "top.yukonga.miuix.kmp.basic."

    /** 渲染某一行时必须成立的模型字段约束。 */
    enum class Requirement {
        /** 标题非空（所有行）。 */
        TITLE,

        /** 开关行必须有当前态（[SettingsRow.switchValue] 非空）。 */
        SWITCH_VALUE,

        /** 滑杆行必须有上下限与档数（[SettingsRow.slider] 非空）。 */
        SLIDER,

        /** 滑杆行必须有当前值（[SettingsRow.sliderValue] 非空）。 */
        SLIDER_VALUE,

        /** 下拉/单选行必须有选项表（[SettingsRow.options] 非空）。 */
        OPTIONS,

        /** 颜色行必须有一个能解析成颜色的取值（[SettingsRow.value]）。 */
        COLOR_VALUE,
    }

    /** 一类行在渲染层的落点。 */
    data class Rendering(
        val component: MiuixRowComponent,
        /** 渲染层源码里必须出现的官方 Miuix 符号（全限定名，import 即算出现）。 */
        val miuixSymbols: List<String>,
        val requires: Set<Requirement>,
    )

    val all: List<Rendering> = listOf(
        Rendering(
            component = MiuixRowComponent.ARROW,
            miuixSymbols = listOf(EXTRA + "SuperArrow"),
            requires = setOf(Requirement.TITLE),
        ),
        Rendering(
            component = MiuixRowComponent.SWITCH,
            miuixSymbols = listOf(EXTRA + "SuperSwitch"),
            requires = setOf(Requirement.TITLE, Requirement.SWITCH_VALUE),
        ),
        Rendering(
            component = MiuixRowComponent.SLIDER,
            miuixSymbols = listOf(BASIC + "BasicComponent", BASIC + "Slider"),
            requires = setOf(Requirement.TITLE, Requirement.SLIDER, Requirement.SLIDER_VALUE),
        ),
        Rendering(
            component = MiuixRowComponent.DROPDOWN,
            miuixSymbols = listOf(EXTRA + "SuperDropdown"),
            requires = setOf(Requirement.TITLE, Requirement.OPTIONS),
        ),
        Rendering(
            component = MiuixRowComponent.RADIO,
            miuixSymbols = listOf(EXTRA + "SuperRadioButton"),
            requires = setOf(Requirement.TITLE, Requirement.OPTIONS),
        ),
        Rendering(
            component = MiuixRowComponent.CHECKBOX,
            miuixSymbols = listOf(EXTRA + "SuperCheckbox"),
            requires = setOf(Requirement.TITLE, Requirement.SWITCH_VALUE),
        ),
        Rendering(
            component = MiuixRowComponent.COLOR_SWATCH,
            miuixSymbols = listOf(EXTRA + "SuperArrow"),
            requires = setOf(Requirement.TITLE, Requirement.COLOR_VALUE),
        ),
    )

    fun rendering(component: MiuixRowComponent): Rendering =
        all.firstOrNull { it.component == component }
            ?: error("渲染层没有为 $component 定义落点——新增组件类型必须同时补这里")

    /**
     * 行尾文本：静态 [SettingsRow.details] 优先，其次动态 [SettingsRow.value]。
     *
     * 两者在 Flutter 侧是同一个槽位（`HyperosNavTile.details` /
     * `HyperosSelectTile` 的取值区），模型为了区分「来自 ARB」与「算出来的」
     * 拆成两个字段，这里合回一个。
     */
    fun trailingText(row: SettingsRow): String? = row.details ?: row.value

    /** 下拉/单选行的当前项名字（找不到就是 null，渲染层按空串处理）。 */
    fun selectedLabel(row: SettingsRow): String? =
        row.options.firstOrNull { it.id == row.selectedOptionId }?.label

    /**
     * `#RRGGBB` / `RRGGBB` → 不透明 ARGB；其余一律 null。
     *
     * 口径逐字抄 `lib/utils/hex_color.dart:3-17` 的 `tryParseHexColor`：
     * 去空白、可带一个 `#`、长度必须 6、按 16 进制解析，alpha 恒为 FF。
     */
    fun tryParseArgb(hex: String?): Int? {
        val normalized = hex?.trim().orEmpty()
        if (normalized.isEmpty()) return null
        val body = if (normalized.startsWith("#")) normalized.substring(1) else normalized
        if (body.length != 6) return null
        val parsed = body.toLongOrNull(16) ?: return null
        return (0xFF000000L or parsed).toInt()
    }

    /** `lib/utils/hex_color.dart:19-21` 的 `parseHexColorOrFallback`。 */
    fun parseArgbOrFallback(hex: String?, fallbackArgb: Int): Int =
        tryParseArgb(hex) ?: fallbackArgb

    /**
     * `settings_shared.dart:128-130` 的 `colorFromHex`：坏串回落品牌蓝 `#2563EB`。
     */
    fun colorFromHex(hex: String?): Int = parseArgbOrFallback(hex, FALLBACK_BLUE_ARGB)

    /** `Color(0xFF2563EB)`（`settings_shared.dart:129`）。 */
    const val FALLBACK_BLUE_ARGB: Int = 0xFF2563EB.toInt()
}
