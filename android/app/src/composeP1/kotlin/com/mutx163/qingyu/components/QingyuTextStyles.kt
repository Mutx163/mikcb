package com.mutx163.qingyu.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
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
 * 「系统粗体」的增量（`Configuration.fontWeightAdjustment`，API 31+）走**减法**：
 * Android 平台本身已经会把该增量加到文字上（Compose 的 `TextStyle` 解析时），
 * 这里若再加一次就是双倍。Dart 侧同样是减法（`designWeight - systemFontWeightDelta`），
 * 照抄同一口径。
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
    // 系统粗体增量。API 31 以下该字段不存在，`fontWeightAdjustment` 会返回
    // FONT_WEIGHT_ADJUSTMENT_UNDEFINED（Int.MAX_VALUE）；Compose 把它暴露成
    // 普通 Int，这里必须显式判掉，否则字重会被钳到 100、全站变极细。
    val config = LocalConfiguration.current
    // `Configuration.fontWeightAdjustment` 是 API 31+ 的 Int 字段；未设置时值是
    // `FONT_WEIGHT_ADJUSTMENT_UNDEFINED` = Int.MAX_VALUE。本工程 minSdk 33，
    // 所以这个字段一定存在，不需要版本判断，但要判掉那个哨兵值。
    val raw = config.fontWeightAdjustment
    val systemDelta = if (raw == Int.MAX_VALUE) 0 else raw

    return remember(userFontWeight, fontFamily, systemDelta) {
        buildQingyuTextStyles(
            userFontWeight = userFontWeight,
            fontFamily = fontFamily,
            systemWeightDelta = systemDelta,
        )
    }
}

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
        // 平移：设计字重 + (用户字重 - 400)，再减掉系统已经加过的那一份。
        // `fontWeight` 为 null 时按 Compose 的默认 w400 处理（与平台一致）。
        val design = (fontWeight?.weight ?: 400)
        val shifted = design + (userFontWeight - QingyuTypography.WEIGHT_DEFAULT) - systemWeightDelta
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
