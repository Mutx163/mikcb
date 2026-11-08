package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 壁纸弹层里**按发布版版式**画的那两块：操作块与每日壁纸入口。
 *
 * ## 为什么不是设置列表行
 *
 * 发布版（`lib/screens/settings/settings_home_backdrop_flow.dart`）在这两个宿主上是**两套版式**，
 * 且差异是刻意的：
 *
 * | 宿主 | 版式 | 出处 |
 * |---|---|---|
 * | 「课表页面」设置的壁纸卡 | 白卡里的行（`HyperosListTile` 族） | `:79-103` 的 `backdropRowsHaveCardBackground = true` |
 * | 「外观编辑」的壁纸弹层 | **整段无容器**：主按钮 + 次按钮 | 同处 `false` / `backdropRowHorizontalInset = 0` |
 *
 * 弹层那边若照设置页的行来画（白卡 + chevron 行），半屏弹窗就变成「一张缩小的设置列表」：
 * 主操作「选择图片」读不出是主操作，`背景图片` 那行还带着一颗点不动的箭头 —— 用户 2026-11-05
 * 报的「排版很奇怪」就是这件事。所以这里按发布版重画，**模型不动**
 * （[SettingsBackdropFlowPage] 仍服务两个宿主），文字全部取自模型节点，本文件不存第二份文案。
 *
 * ## 为什么这里没有「当前壁纸预览」（2026-11-07 三次修正）
 *
 * 前两版都在这块里画一张小预览：
 *
 * 1. 固定 96×56 横框 + 裁切 ⇒ 竖屏壁纸只剩中间一条，用户说「全是横向的」；
 * 2. 改成按真实宽高比（9:19.5 ⇒ 37×80）⇒ 变成一条细缝，旁边一大片空白，用户说「太丑了」。
 *
 * 结论：**预览不该是这一行的小配件**。当前壁纸本来就已经在「最近使用」条的第一张卡上
 * （带主题色描边），把那条卡放大到 78×150（≈ 手机屏比例）就是预览；这里只剩操作。
 * 文件名（`wallpaper_1759….jpg`）也一并不再显示 —— 它对「我用的是哪张」不构成答案。
 *
 * ## 尺寸
 *
 * | 位置 | 值 |
 * |---|---|
 * | 操作块上下留白 | 12 / 12 |
 * | 主按钮 | 40（满宽、主题色实心） |
 * | 主按钮 → 次按钮行 | 10 |
 * | 次按钮 | 40，等宽并排，间距 12 |
 *
 * 按钮一律是官方 [Button] / [TextButton]：主操作用 `buttonColorsPrimary()`，
 * 调整位置用 `buttonColors()`（`secondaryVariant`），清除图片用
 * `textButtonColors(textColor = error)` ——「危险色只染字」是本仓对 destructive 的唯一口径
 * （同 `TaskListPage` 的删除、`TimeSchemeManagementDialogs` 的删除）。不自绘任何形状 / 按压反馈。
 *
 * ## 文件丢失警示
 *
 * 发布版那块是「error 10% 底 + 圆角 12 的可点容器」（`:946-964`）。这里只保留**颜色语义**
 * （标题警示色 + 说明次要色），不做自绘容器（miuix 没有警示条控件，自绘底色板属于
 * 「不可用能力」）；它正下方就是同一个动作的「选择图片」按钮，点得到。
 * 目前宿主传的 `fileMissing` 恒为 false（`AppearanceEditorHost` 未算这一项），这一支是备用。
 */

/**
 * 第一页的操作块：文件丢失警示（备用）+ 满宽主按钮 + 调整位置 / 清除图片。
 *
 * @param pickLabel 「选择图片」按钮文案。
 * @param missingTitle 文件丢失警示的标题；null = 文件在（或不判断）。
 * @param missingSubtitle 警示的说明句。
 * @param adjustLabel 「调整位置」按钮文案；null = 没有壁纸（模型只在有壁纸时给这两行）。
 * @param clearLabel 「清除图片」按钮文案。
 */
@Composable
internal fun WallpaperImageBlock(
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
            .padding(top = 12.dp, bottom = 12.dp),
    ) {
        if (missingTitle != null) {
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
            Spacer(modifier = Modifier.height(10.dp))
        }
        // 主操作独占一行、满宽（`settings_home_backdrop_flow.dart:903-909`）。
        Button(
            onClick = onPick,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) {
            Text(text = pickLabel, maxLines = 1)
        }
        if (adjustLabel != null && clearLabel != null) {
            Spacer(modifier = Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 两颗次按钮等宽并排（`:912-935`）。文字不折行：405dp 屏上每颗约 105dp，
                // 四字文案在发布版里就是因为挤成一行才掉字的（`:900-902`）。
                Button(
                    onClick = onAdjust,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = adjustLabel, maxLines = 1)
                }
                // 清除是**破坏性**动作：底色与「调整位置」同档，只用危险色染字
                // （`textButtonColors(color = …)` 是底色位，传错就是「红底 + 灰字」）。
                TextButton(
                    text = clearLabel,
                    onClick = onClear,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.textButtonColors(
                        textColor = MiuixTheme.colorScheme.error,
                    ),
                )
            }
        }
    }
}

/**
 * 第一页「每日壁纸」入口的**兜底形态**：单独一行 `TextButton`（36 高）。
 *
 * 正常情况这一条根本不进列表：图库入口被提到「最近使用」的标题行右侧
 * （[RecentWallpaperBlock] 的 `trailingLabel`），省掉整块 58dp —— 半屏弹层里那 58dp
 * 正是「缩略条被切掉一半」的来源。只有**一条历史都没有**（首次进来、还没选过图）时
 * 「最近使用」整段不存在，图库入口才落回这里，避免入口凭空消失。
 *
 * 尺寸：36 高 + 6 / 12 留白 = 54（原满宽按钮块 58）。仍是官方 [TextButton]，
 * 只是从「实心次按钮」降到「链接档」——它是导航，不该和「选择图片」抢同一层的重量。
 *
 * @param entryLabel 图库入口按钮文案（模型 `backdrop.bing.entry` 行的 title）。
 */
@Composable
internal fun BingWallpaperBlock(
    entryLabel: String,
    onEntry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 6.dp, bottom = 12.dp),
    ) {
        TextButton(
            text = entryLabel,
            onClick = onEntry,
            modifier = Modifier.fillMaxWidth(),
            minHeight = 36.dp,
            colors = ButtonDefaults.textButtonColors(),
        )
    }
}
