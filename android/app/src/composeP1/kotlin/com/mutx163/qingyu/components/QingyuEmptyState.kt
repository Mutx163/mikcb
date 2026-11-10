package com.mutx163.qingyu.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.shell.EmptyStateInk
import com.mutx163.qingyu.pages.shell.resolveEmptyStateColorsArgb
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 页面级空态：发布版 `HyperosEmptyState` 的逐字几何。
 *
 * ## 几何（一个像素都不开放）
 *
 * 全部取自 `v2.1.4.1:lib/ui/hyperos/hyperos_empty_state.dart`：
 *
 * | 项 | 值 | 发布版行 |
 * |---|---|---|
 * | 外边距 | 横向 32 / 纵向 48 | :27 |
 * | 图标 | 48dp，summary 灰 | :31 |
 * | 图标→标题 | 16dp | :32 |
 * | 标题 | `HyperosTypography.title`＝17sp w400 ⇒ `headline1` | :34-38 |
 * | 标题→说明 | 8dp | :39 |
 * | 说明 | `body2`＝14sp，summary 灰 | :44 |
 * | 说明→动作 | 20dp | :49 |
 * | 卡片壳 | **没有**（不是 Card，四边留白） | 全文件 |
 *
 * 只有两个发布版自己就不一样的页允许改 [iconSize] / [iconTitleGap]：
 * 课程总览 56/12（`course_overview_screen.dart:171-197`）。其余调用点一律走默认值——
 * 这个组件存在的意义就是「别再各写各的 40/48/56 和 16 Medium」。
 *
 * ## 判墨
 *
 * 默认 [EmptyStateInk.Theme]：主题墨（`QingyuTheme.primaryText/secondaryText`）。
 * 压在壁纸或自定义页底上的空态传 [EmptyStateInk.OverBackdrop]，走首页那套
 * `HomeBackgroundModel.inkOverWallpaperArgb`（与日视图 `DayViewEmptyState.kt:69-74` 同一条）；
 * 副标题永远是标题墨压淡一档（`mutedInkOverWallpaperArgb`），两行不会一冷一暖。
 *
 * @param icon 图标；发布版是 `onSurfaceVariantSummary` 色的 48dp 字形
 * @param title 主标题（17sp 常规字重；不进一行口径，允许长句折行）。
 *   **只有发布版课程总览**（`course_overview_screen.dart:171-197`）传 null：
 *   那一页本来就无标题，只有一行 14sp 的说明；其余页面级空态必须有标题
 * @param description 说明（14sp，可选；null 时不占那 8dp）
 * @param action 动作槽（可选；调用方给官方 `Button`，空态不自己造按钮）
 * @param ink 墨色来源，见 [EmptyStateInk]
 * @param iconSize 仅课程总览传 56
 * @param iconTitleGap 仅课程总览传 12
 * @param iconTint 覆盖图标色（错误态可传 error；默认取说明墨）
 */
@Composable
fun QingyuEmptyState(
    icon: ImageVector,
    title: String? = null,
    modifier: Modifier = Modifier,
    description: String? = null,
    action: (@Composable () -> Unit)? = null,
    ink: EmptyStateInk = EmptyStateInk.Theme,
    iconSize: Dp = EmptyStateSpec.IconSize,
    iconTitleGap: Dp = EmptyStateSpec.IconTitleGap,
    iconTint: Color? = null,
) {
    val colors = emptyStateColors(ink)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                horizontal = EmptyStateSpec.ContentPaddingHorizontal,
                vertical = EmptyStateSpec.ContentPaddingVertical,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint ?: colors.body,
            modifier = Modifier.size(iconSize),
        )
        Spacer(modifier = Modifier.height(iconTitleGap))
        if (title != null) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.headline1,
                color = colors.title,
                textAlign = TextAlign.Center,
            )
            if (description != null) {
                Spacer(modifier = Modifier.height(EmptyStateSpec.TitleDescriptionGap))
            }
        }
        if (description != null) {
            Text(
                text = description,
                style = MiuixTheme.textStyles.body2,
                color = colors.body,
                textAlign = TextAlign.Center,
            )
        }
        if (action != null) {
            Spacer(modifier = Modifier.height(EmptyStateSpec.DescriptionActionGap))
            action()
        }
    }
}

/**
 * 行内 / 卡内空态：一句（可选两句）说明，**不带图标、不带外边距**。
 *
 * 卡内边距归卡片（`QingyuCard` 的 `insideMargin`），位置归调用方；本组件只统一
 * 「13/14 两档字阶 + 次级墨」——这类提示以前是 footnote1/body1/body2 混着写。
 *
 * 为什么不做成 [QingyuEmptyState] 的一个参数：页面级空态有 32/48 留白与 48dp 图标，
 * 卡内提示一旦吃到那套留白，卡片会被撑成一块空板（`SupportCreatorPage.kt:650` 的鸣谢卡
 * 就是卡内一行，硬套页面级会破坏三段结构）。
 *
 * @param text 提示正文
 * @param description 第二行说明（可选）
 * @param emphasis 字阶：[EmptyStateHintEmphasis.Caption]＝footnote1(13)，
 *   [EmptyStateHintEmphasis.Body]＝body2(14)
 * @param ink 墨色来源，见 [EmptyStateInk]
 * @param textAlign 默认左对齐（卡内说明随卡片轴线）；弹层里的居中提示传 `Center`
 */
@Composable
fun QingyuEmptyHint(
    text: String,
    modifier: Modifier = Modifier,
    description: String? = null,
    emphasis: EmptyStateHintEmphasis = EmptyStateHintEmphasis.Caption,
    ink: EmptyStateInk = EmptyStateInk.Theme,
    textAlign: TextAlign = TextAlign.Start,
) {
    val colors = emptyStateColors(ink)
    val style = when (emphasis) {
        EmptyStateHintEmphasis.Caption -> MiuixTheme.textStyles.footnote1
        EmptyStateHintEmphasis.Body -> MiuixTheme.textStyles.body2
    }
    Column(modifier = modifier) {
        Text(
            text = text,
            style = style,
            color = colors.body,
            textAlign = textAlign,
        )
        if (description != null) {
            Spacer(modifier = Modifier.height(EmptyStateSpec.TitleDescriptionGap))
            Text(
                text = description,
                style = MiuixTheme.textStyles.footnote1,
                color = colors.body,
                textAlign = textAlign,
            )
        }
    }
}

/** 行内空态的强调档：13（提示）与 14（卡内正文）两档，不开放任意字号。 */
enum class EmptyStateHintEmphasis { Caption, Body }

/** 解析后的两处墨色（标题 / 说明；图标默认跟说明同色）。判墨规则在 `pages/shell/EmptyStateInkSpec.kt`。 */
data class EmptyStateColors(
    val title: Color,
    val body: Color,
)

/** 组件几何常量：唯一来源，别在调用点再写字面量。 */
object EmptyStateSpec {
    val IconSize: Dp = 48.dp
    val IconTitleGap: Dp = 16.dp
    val TitleDescriptionGap: Dp = 8.dp
    val DescriptionActionGap: Dp = 20.dp
    val ContentPaddingHorizontal: Dp = 32.dp
    val ContentPaddingVertical: Dp = 48.dp
}

/**
 * 判墨的唯一实现是 [resolveEmptyStateColorsArgb]（`pages/shell/EmptyStateInkSpec.kt`，
 * 纯 Kotlin + JVM 单测）；这里只把两个 ARGB 包成 `Color`，不复制任何判据。
 */
@Composable
private fun emptyStateColors(ink: EmptyStateInk): EmptyStateColors {
    val dark = isSystemInDarkTheme()
    val argb = resolveEmptyStateColorsArgb(
        ink = ink,
        themeTitleArgb = QingyuTheme.primaryText(dark),
        themeBodyArgb = QingyuTheme.secondaryText(dark),
    )
    return EmptyStateColors(
        title = Color(argb.titleArgb),
        body = Color(argb.bodyArgb),
    )
}
