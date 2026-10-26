package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 关于页「版本更新」状态卡 · Compose 渲染层（Phase 3）。
 *
 * 判据在 main 源集、已有测试（[resolveAboutUpdateCardState] /
 * [resolveAboutUpdatePrimaryAction]），这里只负责**按判据画**：
 * 三态各画一张卡、主按钮去向由判据给。
 *
 * 这样分的意义：Dart 侧 2026-10-19 那个 bug（「已是最新」下面挂着能点的「立即下载」）
 * 是**状态与动作不一致**，属于判据问题而不是画法问题——把判据抽出来单测，
 * 比在界面里靠肉眼核对靠谱。
 *
 * ## 组件
 *
 * 官方 Miuix Card / Text / CircularProgressIndicator，不自绘。
 */
@Composable
fun AboutUpdateStatusCard(
    state: AboutUpdateCardState,
    primaryAction: AboutUpdatePrimaryAction,
    onPrimaryAction: () -> Unit,
    latestVersionText: String?,
    releaseVersionText: String?,
    onOpenReleasePage: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme

    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            when (state) {
                AboutUpdateCardState.CHECK_FAILED -> {
                    // 与「已是最新」分开画：失败不能长得像成功（Dart :832-835 的注释）。
                    Text(
                        text = AboutUpdateStrings.checkFailedTitle,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.onSurface,
                    )
                    Text(
                        text = AboutUpdateStrings.checkFailedHint,
                        fontSize = 12.sp,
                        lineHeight = 18.sp,
                        color = colors.onSurfaceVariantSummary,
                    )
                    ActionRow(
                        label = AboutUpdateStrings.retryAction,
                        emphasized = false,
                        onClick = onPrimaryAction,
                    )
                }

                AboutUpdateCardState.ALREADY_LATEST -> {
                    Text(
                        text = AboutUpdateStrings.alreadyLatestHeadline,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.onSurface,
                    )
                    latestVersionText?.takeIf { it.isNotEmpty() }?.let { version ->
                        VersionLine(
                            label = AboutUpdateStrings.currentVersionLabel,
                            version = version,
                        )
                    }
                    // 已是最新：**没有**主按钮。给个去 release 页的弱入口就够，
                    // 免得又出现「已是最新 + 立即下载」这种自相矛盾的卡。
                    ActionRow(
                        label = AboutUpdateStrings.viewReleaseAction,
                        emphasized = false,
                        onClick = onOpenReleasePage,
                    )
                }

                AboutUpdateCardState.UPDATE_AVAILABLE -> {
                    Text(
                        text = AboutUpdateStrings.updateAvailableHeadline,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = colors.onSurface,
                    )
                    releaseVersionText?.takeIf { it.isNotEmpty() }?.let { version ->
                        VersionLine(
                            label = AboutUpdateStrings.latestVersionLabel,
                            version = version,
                        )
                    }
                    ActionRow(
                        label = actionLabel(primaryAction),
                        emphasized = true,
                        onClick = onPrimaryAction,
                    )
                }
            }
        }
    }
}

/** 正在检查更新时的占位卡（Dart `_buildUpdateCheckingView`）。 */
@Composable
fun AboutUpdateCheckingCard() {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            CircularProgressIndicator()
            Text(
                text = AboutUpdateStrings.checkingTitle,
                fontSize = 14.sp,
                color = colors.onSurfaceVariantSummary,
            )
        }
    }
}

/** 主按钮文案由**去向**决定，不另写一套状态判断（避免两处判据漂移）。 */
private fun actionLabel(action: AboutUpdatePrimaryAction): String = when (action) {
    AboutUpdatePrimaryAction.OPEN_RELEASE_PAGE -> AboutUpdateStrings.viewReleaseAction
    AboutUpdatePrimaryAction.DOWNLOAD_IN_APP -> AboutUpdateStrings.downloadNowAction
    AboutUpdatePrimaryAction.OPEN_DOWNLOAD_LINK -> AboutUpdateStrings.openDownloadPageAction
}

/** 版本行：ARB 里 `当前版本` / `最新版本` 是**标签**，版本号另画。 */
@Composable
private fun VersionLine(label: String, version: String) {
    val colors = MiuixTheme.colorScheme
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = label,
            fontSize = 12.sp,
            color = colors.onSurfaceVariantSummary,
        )
        Text(
            text = version,
            fontSize = 12.sp,
            color = colors.onSurface,
        )
    }
}

@Composable
private fun ActionRow(
    label: String,
    emphasized: Boolean,
    onClick: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = label,
        fontSize = 14.sp,
        fontWeight = if (emphasized) FontWeight.SemiBold else FontWeight.Normal,
        color = if (emphasized) colors.primary else colors.onSurfaceVariantSummary,
        modifier = Modifier.clickable { onClick() },
    )
}
