package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 壁纸弹层里**按发布版版式**画的那两块：选图块与每日壁纸块。
 *
 * ## 为什么不是设置列表行
 *
 * 发布版（`lib/screens/settings/settings_home_backdrop_flow.dart`）在这两个宿主上是**两套版式**，
 * 且差异是刻意的：
 *
 * | 宿主 | 版式 | 出处 |
 * |---|---|---|
 * | 「课表页面」设置的壁纸卡 | 白卡里的行（`HyperosListTile` 族） | `:79-103` 的 `backdropRowsHaveCardBackground = true` |
 * | 「外观编辑」的壁纸弹层 | **整段无容器**：标题 + 说明 + 主按钮 + 次按钮 | 同处 `false` / `backdropRowHorizontalInset = 0` |
 *
 * 弹层那边若照设置页的行来画（白卡 + chevron 行），半屏弹窗就变成「一张缩小的设置列表」：
 * 主操作「选择图片」读不出是主操作，`背景图片` 那行还带着一颗点不动的箭头 —— 用户 2026-11-05
 * 报的「排版很奇怪」就是这件事。所以这里按发布版重画两块，**模型不动**（[SettingsBackdropFlowPage]
 * 仍服务两个宿主），文字全部取自模型节点，本文件不存第二份文案。
 *
 * ## 尺寸来源（逐条对拍发布版）
 *
 * | 位置 | 值 | Dart |
 * |---|---|---|
 * | 选图块上下留白 | 14 / 14 | `:884-885` |
 * | 标题字号 | 17sp（`headline1`） | `:889` `HyperosTypography.listTitle` |
 * | 标题 → 文件名 | 4 | `:890` |
 * | 文件名字号 | 13sp（`body2`）+ 次要色 | `:891` `listDetail` |
 * | 文件名 → 主按钮 | 12 | `:896` |
 * | 主按钮 → 两颗次按钮 | 12 | `:911` |
 * | 两颗次按钮之间 | 12 | `:926` |
 * | 每日壁纸块上下留白 | 4 / 14 | `:488` |
 * | 图库按钮 → 开关行 | 4 | `:500` |
 *
 * 按钮一律是官方 [Button]：主操作用 `buttonColorsPrimary()`（实心主题色），次操作用
 * `buttonColors()`（`secondaryVariant`，与 `RecentWallpaperConfirmBar` 的「取消」同一档）。
 * 不自绘任何形状 / 按压反馈。
 *
 * ## 文件丢失警示
 *
 * 发布版那块是「error 10% 底 + 圆角 12 的可点容器」（`:946-964`）。这里只保留**颜色语义**
 * （标题警示色 + 说明次要色），不做自绘容器（miuix 没有警示条控件，自绘底色板属于
 * 「不可用能力」）；它正下方就是同一个动作的「选择图片」按钮，点得到。
 * 目前宿主传的 `fileMissing` 恒为 false（`AppearanceEditorHost` 未算这一项），这一支是备用。
 */

/**
 * 第一页「选图」块：标题 + 文件名（+ 文件丢失警示）+ 主按钮 + 两颗次按钮。
 *
 * @param title 标题（模型 `backdrop.image` 行的 title，DB 文案「背景图片」）。
 * @param subtitle 文件名，没选图时是「未选择」。
 * @param missingTitle 文件丢失警示的标题；null = 文件在（或不判断）。
 * @param missingSubtitle 警示的说明句。
 * @param pickLabel 「选择图片」按钮文案。
 * @param adjustLabel 「调整位置」按钮文案；null = 没有壁纸（模型只在有壁纸时给这三行）。
 * @param clearLabel 「清除图片」按钮文案。
 */
@Composable
internal fun WallpaperImageBlock(
    title: String,
    subtitle: String,
    pickLabel: String,
    onPick: () -> Unit,
    modifier: Modifier = Modifier,
    missingTitle: String? = null,
    missingSubtitle: String? = null,
    adjustLabel: String? = null,
    clearLabel: String? = null,
    onAdjust: () -> Unit = {},
    onClear: () -> Unit = {},
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 14.dp, bottom = 14.dp),
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.headline1,
            color = MiuixTheme.colorScheme.onBackground,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = subtitle,
            style = MiuixTheme.textStyles.body2,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        )
        if (missingTitle != null) {
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = missingTitle,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.error,
            )
            if (missingSubtitle != null) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = missingSubtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                )
            }
        }
        Spacer(modifier = Modifier.height(12.dp))
        // 主操作独占一行、满宽（`settings_home_backdrop_flow.dart:903-909`）。
        Button(
            onClick = onPick,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) {
            Text(text = pickLabel, maxLines = 1)
        }
        if (adjustLabel != null && clearLabel != null) {
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 两颗次按钮等宽并排（`:912-935`）。文字不折行：405dp 屏上每颗约 105dp，
                // 四字文案在发布版里就是因为挤成一行才掉字的（`:900-902`）。
                WallpaperSecondaryButton(label = adjustLabel, onClick = onAdjust)
                WallpaperSecondaryButton(label = clearLabel, onClick = onClear)
            }
        }
    }
}

/** 每日壁纸块里那颗满宽次按钮 / 选图块的两颗次按钮（同一档样式）。 */
@Composable
private fun RowScope.WallpaperSecondaryButton(
    label: String,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        modifier = Modifier.weight(1f),
        colors = ButtonDefaults.buttonColors(),
    ) {
        Text(text = label, maxLines = 1)
    }
}

/**
 * 第一页「每日壁纸」块：满宽次按钮 + 「每天自动更换」开关行。
 *
 * 发布版这两件是**无容器的两根**（`:487-528`）：按钮是 `HyperosButton(secondary)`，
 * 开关是 `HyperosSwitchTile(backgroundColor: Colors.transparent)` —— 弹层上再来一块白卡
 * 会读成「屏内嵌屏」。开关行仍走 [SettingsNodeView]（官方 `SwitchPreference`），
 * 只是外面不再套卡。
 *
 * @param entryLabel 图库入口按钮文案（模型 `backdrop.bing.entry` 行的 title）。
 * @param switchNode 「每天自动更换」那一行（模型 `backdrop.bing.autoApply`）；null = 模型没给。
 */
@Composable
internal fun BingWallpaperBlock(
    entryLabel: String,
    onEntry: () -> Unit,
    onAction: (action: SettingsAction, target: String?, rowId: String) -> Unit,
    switchNode: SettingsNode?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 4.dp, bottom = 14.dp),
    ) {
        Button(
            onClick = onEntry,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(),
        ) {
            Text(text = entryLabel, maxLines = 1)
        }
        if (switchNode != null) {
            Spacer(modifier = Modifier.height(4.dp))
            SettingsNodeView(node = switchNode, onAction = onAction)
        }
    }
}
