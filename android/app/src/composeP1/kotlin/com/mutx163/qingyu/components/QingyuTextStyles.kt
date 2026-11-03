package com.mutx163.qingyu.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.mutx163.qingyu.theme.QingyuTypography
import top.yukonga.miuix.kmp.theme.TextStyles
import top.yukonga.miuix.kmp.theme.defaultTextStyles

/**
 * 把「用户字重 / 系统粗体 / 字族」挂到官方字阶上，供 [QingyuPageTheme] 注入。
 *
 * ## 为什么必须做这件事（不是一个可有可无的优化）
 *
 * miuix 的 Compose 侧 **0.9.4 没有任何 `fontWeightAdjustment` 支持**
 * （六个模块的 sources 全搜过，0 命中；Flutter 的 fork 有，是它自己补的 1.1.0 特性）。
 * 这意味着：
 *
 * 1. 系统「粗体文字」（`Settings > 无障碍 > 粗体`）在 Compose 侧**完全不生效**；
 * 2. 本仓自己的「应用字重」设置（`TimetableSettings.appFontWeight`，Dart 侧
 *    `lib/ui/app_fonts.dart` 那套 25ms/2dp 的字重 scope）也挂不上；
 * 3. 字族（自定义字体）同理。
 *
 * 唯一能把这三样送进官方组件的口子就是 `MiuixTheme(textStyles = …)`——
 * 官方 `Text` 默认 `style = MiuixTheme.textStyles.main`，所以只要在字阶里
 * 把 `fontWeight` / `fontFamily` 填好，全站文字自动跟随。
 *
 * ## 为什么是「平移」而不是「覆盖」
 *
 * 与 Dart 侧 `AppFontScope.resolveShiftedWeight` 同一口径：
 * 层级本身靠字重表达的文本（标题 w600 / 正文 w400），绝对覆盖会把两者压成同一档，
 * 卡片就失去主次。所以用户字重以 **`设计字重 + (用户字重 - 400)`** 施加，
 * 保留差值；结果钳在 [QingyuTypography.WEIGHT_MIN]..[WEIGHT_MAX]。
 *
 * 「系统粗体」的增量（`Configuration.fontWeightAdjustment`，API 31+）只在
 * **用户未改字重**时抵扣：Android 平台本身已经会把该增量加到文字上（Compose 的
 * `TextStyle` 解析时），这里若再加一次就是双倍。Dart 侧同样是两分支
 * （`lib/ui/app_fonts.dart:105-116`）：用户设了非默认字重 → `设计 + (用户 - 400)`、
 * 不抵扣系统增量；用户未改 → `设计 - 系统增量`。这里直接委托
 * [QingyuTypography.resolveShiftedWeight]，不再自己拼一份公式。
 *
 * ## 默认值等于官方，所以「没配 = 不变」是可证的
 *
 * [QingyuTypography] 的字号与官方 `defaultTextStyles` 逐条相同（已对 0.9.4 源码核过），
 * 所以本函数在「用户字重 = 400、无自定义字族、系统未开粗体」时**产出与官方完全一致的字阶**——
 * 这条由 `QingyuTextStylesTest` 钉住，杜绝「注入了一份看起来差不多但实际跑偏的副本」。
 *
 * @param userFontWeight 用户在设置里选的字重（100..900），默认 [QingyuTypography.WEIGHT_DEFAULT]。
 * @param fontFamily 用户选的字体；`null` 表示跟随系统默认（不覆写）。
 */
@Composable
fun rememberQingyuTextStyles(
    userFontWeight: Int = QingyuTypography.WEIGHT_DEFAULT,
    fontFamily: FontFamily? = null,
): TextStyles {
    // 系统粗体增量。`Configuration.fontWeightAdjustment` 是 API 31+ 的 Int 字段，
    // 未设置时值是 `FONT_WEIGHT_ADJUSTMENT_UNDEFINED` = Int.MAX_VALUE。
    // 本工程 minSdk 33，所以字段一定存在，不需要版本判断，但**必须判掉哨兵值** ——
    // 不判的话字重会被钳到 w100、全站变极细（见 normalizeSystemWeightDelta 的测试）。
    val systemDelta = normalizeSystemWeightDelta(LocalConfiguration.current.fontWeightAdjustment)

    return remember(userFontWeight, fontFamily, systemDelta) {
        buildQingyuTextStyles(
            userFontWeight = userFontWeight,
            fontFamily = fontFamily,
            systemWeightDelta = systemDelta,
        )
    }
}

/**
 * 把 `Configuration.fontWeightAdjustment` 的原始值规整成可用的增量。
 *
 * ## 为什么单独抽一个函数（2026-10-27 咬合探针查出的缺口）
 *
 * 这段判据原先内联在 [rememberQingyuTextStyles] 里 —— 那是个 `@Composable`，
 * 普通 JVM 单测调不了，于是它**没有任何测试覆盖**。
 *
 * 实证：把 `if (raw == Int.MAX_VALUE) 0 else raw` 改成 `raw`（正是要防的那个错误），
 * 8 例测试**全绿** —— 说明探针打不响、这条判据当时是裸奔的。
 * 抽成纯函数后 `QingyuTextStylesTest` 直接钉它，同样改坏立即变红。
 *
 * @param raw 平台原值。`Int.MAX_VALUE` = `FONT_WEIGHT_ADJUSTMENT_UNDEFINED`（未设置）。
 * @return 可用的字重增量；未设置时返回 0（= 不偏移）。
 */
internal fun normalizeSystemWeightDelta(raw: Int): Int =
    if (raw == Int.MAX_VALUE) 0 else raw

/**
 * [rememberQingyuTextStyles] 的纯函数内核——**故意不帶 @Composable**。
 *
 * 抽出来是为了能在 JVM 单测里直接调（Compose 的 `@Composable` 函数在
 * 普通单测里调不了，而「字重怎么算」正是最容易算错、又最该被钉住的地方）。
 */
internal fun buildQingyuTextStyles(
    userFontWeight: Int = QingyuTypography.WEIGHT_DEFAULT,
    fontFamily: FontFamily? = null,
    systemWeightDelta: Int = 0,
): TextStyles {
    // ⚠️ 这里必须先把字族存成局部变量再进扩展函数。
    //
    // `TextStyle` **自己就有 `fontFamily` 属性**，而扩展函数是「先接收者后外层」解析的
    // ——若在 `shaped()` 里直接写 `fontFamily ?: …`，拿到的是 `this.fontFamily`，
    // 参数被完全遮蔽，结果就是「字族永远挂不上，而且不报任何错」。
    // 这是本项目最容易踩的一类静默失败，所以单独提出来并改名叫 `familyOverride`。
    val familyOverride = fontFamily

    fun TextStyle.shaped(): TextStyle {
        // 平移：用户改过字重 → 设计字重 + (用户字重 - 400)；用户未改 → 设计字重
        // 减掉系统已经加过的那一份。两分支由 [QingyuTypography.resolveShiftedWeight] 拥有，
        // 与 Dart `AppFontScope.resolveShiftedWeight`（`lib/ui/app_fonts.dart:105-116`）逐行同口径。
        // `fontWeight` 为 null 时按 Compose 的默认 w400 处理（与平台一致）。
        val design = (fontWeight?.weight ?: 400)
        val shifted = QingyuTypography.resolveShiftedWeight(
            userWeight = userFontWeight,
            designWeight = design,
            systemDelta = systemWeightDelta,
        )
        return copy(
            fontWeight = FontWeight(shifted.coerceIn(
                QingyuTypography.WEIGHT_MIN,
                QingyuTypography.WEIGHT_MAX,
            )),
            fontFamily = familyOverride ?: this.fontFamily,
        )
    }

    val base = defaultTextStyles()
    return defaultTextStyles(
        main = base.main.shaped(),
        paragraph = base.paragraph.shaped(),
        body1 = base.body1.shaped(),
        body2 = base.body2.shaped(),
        button = base.button.shaped(),
        footnote1 = base.footnote1.shaped(),
        footnote2 = base.footnote2.shaped(),
        headline1 = base.headline1.shaped(),
        headline2 = base.headline2.shaped(),
        // ⚠️ subtitle 是官方唯一带 Bold 的槽位（`TextStyles.kt:201-206`）。
        // 早期转录版 `QingyuTypography.SUBTITLE` 漏了这个字重，从而把
        // 「副标题比正文粗」这条层级抹平了；这里直接取官方的，不再自己拼。
        subtitle = base.subtitle.shaped(),
        title1 = base.title1.shaped(),
        title2 = base.title2.shaped(),
        title3 = base.title3.shaped(),
        title4 = base.title4.shaped(),
    )
}

/**
 * 页面强调用的**设计字重增量**。数值 = 设计字重 - 正文 400。
 *
 * 页面只需要说明「比正文重几档」，不要写死绝对字重（那会盖掉用户字重与系统粗体，
 * 见 [shiftWeight]）。
 */
object QingyuWeightDelta {
    /** 设计 w300（比正文细一档）。 */
    const val LIGHT = -100

    /** 设计 w500。 */
    const val MEDIUM = 100

    /** 设计 w600。 */
    const val SEMIBOLD = 200

    /** 设计 w700。 */
    const val BOLD = 300

    /** 设计 w800。 */
    const val EXTRABOLD = 400
}

/**
 * 在**主题已注入的字阶**上按设计增量加/减字重，而不是写死绝对字重。
 *
 * ## 为什么必须走这里（这不是审美偏好，是一个真实缺陷）
 *
 * [buildQingyuTextStyles] 已经把每个官方字阶槽位平移过：
 * `设计字重 + (用户字重 - 400) - 系统粗体增量`。页面里再写
 * `fontWeight = FontWeight.SemiBold` 是**绝对覆盖**，平移结果会被整个盖掉 ——
 * 用户在设置里调「应用字重」时，凡是写了 `fontWeight` 的地方都不跟着变。
 * 2026-11-01 全仓页面仍有 311 处这种写法（台账 §9.5 记的未做项）。
 *
 * 这里的增量和 Dart 侧 `AppFontScope.resolveShiftedWeight` 同口径：
 * 在当前（已平移的）字重上加回设计差值，结果钳在 [QingyuTypography.WEIGHT_MIN]
 * ..[QingyuTypography.WEIGHT_MAX]。默认设置（用户 400、系统未开粗体）下，
 * `body1.shiftWeight(QingyuWeightDelta.SEMIBOLD)` 正好等于 w600，**与旧的写死值逐像素一致**；
 * 开了系统粗体或改了用户字重时，才会按设计意图跟着平移。
 *
 * ## 用法
 *
 * ```kotlin
 * Text(
 *     text = "标题",
 *     style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
 * )
 * ```
 *
 * ⚠️ 只对来自 `MiuixTheme.textStyles.*` 的样式用。它假定当前字重是「设计字重平移后」
 * 的结果；若对任意 [TextStyle] 调用，就只是相对加重，不保证与主题一致。
 *
 * @param delta 设计增量，优先取 [QingyuWeightDelta] 的具名常量。
 */
fun TextStyle.shiftWeight(delta: Int): TextStyle =
    if (delta == 0) this else copy(fontWeight = shiftedWeight(fontWeight, delta))

/**
 * [shiftWeight] 的 [SpanStyle] 版本（`buildAnnotatedString` 里给局部文字加重）。
 *
 * ⚠️ 与 [TextStyle] 版一样，**不要**用它去「清除」字重：`null` 在这里按 w400 处理，
 * 写回去会让原本继承主题字重的片段变成显式 w400。只想保留原样就别调用（delta = 0 时直接返回 this）。
 */
fun SpanStyle.shiftWeight(delta: Int): SpanStyle =
    if (delta == 0) this else copy(fontWeight = shiftedWeight(fontWeight, delta))

/** [TextStyle.shiftWeight] / [SpanStyle.shiftWeight] 的共同内核（纯函数，可单测）。 */
private fun shiftedWeight(current: FontWeight?, delta: Int): FontWeight = FontWeight(
    ((current?.weight ?: QingyuTypography.WEIGHT_DEFAULT) + delta)
        .coerceIn(QingyuTypography.WEIGHT_MIN, QingyuTypography.WEIGHT_MAX),
)
