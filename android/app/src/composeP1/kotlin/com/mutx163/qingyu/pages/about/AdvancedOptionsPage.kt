package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.infra.AppUpdateCheckResult
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.AppUpdateDownloadSource
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 高级选项页 · Compose 渲染层（1:1 复刻 `lib/screens/about_screen.dart` 的 `_AdvancedOptionsScreen`，
 * `:1722-2289`）。
 *
 * 分组与 Dart 一致：
 * 1. 弹窗提醒开关；
 * 2. 下载渠道（蒲公英 / GitHub / GitCode）；
 * 3. 下载安装包方式（应用内 / 系统下载管理器）；
 * 4. 检测测试版本开关；
 * 5. 镜像（**仅 GitHub 渠道 + 国内镜像来源时出现**）：预设单选 + 测速推荐 + 自定义地址；
 * 6. 测试与诊断：打开日志页。
 *
 * 本文件只画；设置读写与探测由宿主经回调注入，全部屏上文案取自 [AboutUpdatePageStrings]。
 */
@Composable
fun AdvancedOptionsPage(
    onBack: () -> Unit,
    settings: AppUpdateSettings = AppUpdateSettings(),
    result: AppUpdateCheckResult? = null,
    probeStates: Map<MirrorPreset, DownloadProbeResult> = emptyMap(),
    probing: Boolean = false,
    onPromptEnabledChange: (Boolean) -> Unit = {},
    onIncludePrereleaseChange: (Boolean) -> Unit = {},
    onDownloadChannelChange: (AppUpdateDownloadChannel) -> Unit = {},
    onUseSystemDownloaderChange: (Boolean) -> Unit = {},
    onMirrorPresetChange: (MirrorPreset) -> Unit = {},
    onProbeMirrors: () -> Unit = {},
    /**
     * 自定义镜像地址提交（Dart `_editMirrorUrlPrefix`，`about_screen.dart:2259-2288`）。
     *
     * 弹窗在本页（渲染层），落盘在宿主：宿主收原始文本，自己归一化 + 写设置 + 决定提示。
     * 空串 = 清空自定义地址（回落默认镜像）。
     */
    onMirrorPrefixSubmit: (String) -> Unit = {},
    onOpenDiagnostics: () -> Unit = {},
) {
    val recommended = resolveRecommendedMirrorPreset(probeStates)
    val channel = settings.downloadChannel
    val customPrefix = settings.mirrorUrlPrefix

    // 镜像地址编辑弹窗（Dart 用 `showAppTextInputDialog`，这里用官方 OverlayDialog + TextField）。
    var editingMirror by remember { mutableStateOf(false) }
    var mirrorDraft by remember { mutableStateOf("") }
    var mirrorError by remember { mutableStateOf<String?>(null) }

    fun openMirrorEditor() {
        mirrorDraft = settings.mirrorUrlPrefix
        mirrorError = null
        editingMirror = true
    }

    fun submitMirror() {
        val raw = mirrorDraft.trim()
        // Dart 侧只在「用到」时才归一化，非法值会被静默当成自定义前缀；
        // 这里在入口就拦住（ARB 已有 `aboutMirrorPrefixInvalid` 这条文案），
        // 空串仍然允许——它表示「清掉自定义地址，回默认镜像」。
        if (raw.isNotEmpty() && normalizeMirrorUrlPrefix(raw) == null) {
            mirrorError = AboutUpdatePageStrings.mirrorPrefixInvalid
            return
        }
        editingMirror = false
        onMirrorPrefixSubmit(raw)
    }

    QingyuPageScaffold(title = AboutUpdatePageStrings.advancedOptionsTitle, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(QingyuPageCardMargin),
        ) {
            // 1. 弹窗提醒
            item(key = "prompt") {
                GroupCard {
                    ToggleRow(
                        title = AboutUpdatePageStrings.updatePromptTitle,
                        subtitle = AboutUpdatePageStrings.updatePromptSubtitle,
                        checked = settings.promptEnabled,
                        onChange = onPromptEnabledChange,
                        showDivider = false,
                    )
                }
            }

            // 2. 下载渠道
            item(key = "channel-title") { QingyuSectionTitle(AboutUpdatePageStrings.downloadChannelSectionTitle) }
            item(key = "channel-group") {
                GroupCard {
                    val channels = AppUpdateDownloadChannel.entries
                    channels.forEachIndexed { index, item ->
                        ChoiceRow(
                            title = AboutUpdatePageStrings.channelLabel(item),
                            subtitle = AboutUpdatePageStrings.channelDescription(item),
                            selected = channel == item,
                            onClick = { onDownloadChannelChange(item) },
                            showDivider = index < channels.lastIndex,
                        )
                    }
                }
            }

            // 3. 下载安装包方式
            item(key = "method-title") { QingyuSectionTitle(AboutUpdatePageStrings.downloadPackageMethodTitle) }
            item(key = "method-group") {
                GroupCard {
                    ChoiceRow(
                        title = AboutUpdatePageStrings.inAppDownloadTitle,
                        subtitle = AboutUpdatePageStrings.inAppDownloadSubtitle,
                        selected = !settings.useSystemDownloader,
                        onClick = { onUseSystemDownloaderChange(false) },
                        showDivider = true,
                    )
                    ChoiceRow(
                        title = AboutUpdatePageStrings.systemDownloaderTitle,
                        subtitle = AboutUpdatePageStrings.systemDownloaderChoiceSubtitle,
                        selected = settings.useSystemDownloader,
                        onClick = { onUseSystemDownloaderChange(true) },
                        showDivider = false,
                    )
                }
            }

            // 4. 检测测试版本
            item(key = "prerelease") {
                GroupCard {
                    ToggleRow(
                        title = AboutUpdatePageStrings.checkPrereleaseTitle,
                        subtitle = AboutUpdatePageStrings.checkPrereleaseSubtitle,
                        checked = settings.includePrerelease,
                        onChange = onIncludePrereleaseChange,
                        showDivider = false,
                    )
                }
            }

            // 5. 镜像（GitHub + 国内镜像时才出现，Dart `:1829-1839`）
            if (channel == AppUpdateDownloadChannel.GITHUB && settings.downloadSource == AppUpdateDownloadSource.MIRROR) {
                item(key = "mirror-title") { QingyuSectionTitle(AboutUpdatePageStrings.mirrorSectionTitle) }
                item(key = "mirror-presets") {
                    GroupCard {
                        val presets = MirrorPreset.entries
                        presets.forEachIndexed { index, preset ->
                            val probe = probeStates[preset]
                            val isRecommended = recommended == preset && probe?.isSuccess == true
                            val subtitle = when {
                                preset == MirrorPreset.CUSTOM && customPrefix.trim().isEmpty() ->
                                    AboutUpdatePageStrings.fillCustomMirrorFirst
                                else -> resolveMirrorUrlPrefix(preset, customPrefix)
                            }
                            ChoiceRow(
                                title = if (isRecommended) {
                                    "${AboutUpdatePageStrings.presetLabel(preset)} · ${AboutUpdatePageStrings.recommended}"
                                } else {
                                    AboutUpdatePageStrings.presetLabel(preset)
                                },
                                subtitle = subtitle,
                                selected = settings.mirrorPreset == preset,
                                onClick = { onMirrorPresetChange(preset) },
                                showDivider = index < presets.lastIndex,
                                trailing = probe?.let { result -> { ProbeChip(result) } },
                            )
                        }
                    }
                }
                item(key = "mirror-actions") {
                    GroupCard {
                        ArrowRow(
                            title = if (probing) {
                                AboutUpdatePageStrings.probingMirrors
                            } else {
                                AboutUpdatePageStrings.probeMirrorsAction
                            },
                            enabled = !probing,
                            onClick = onProbeMirrors,
                        )
                        HorizontalDivider(Modifier.padding(start = 16.dp))
                        ArrowRow(
                            title = if (settings.mirrorPreset == MirrorPreset.CUSTOM) {
                                AboutUpdatePageStrings.editCustomMirrorAction
                            } else {
                                AboutUpdatePageStrings.setCustomMirrorAction
                            },
                            onClick = { openMirrorEditor() },
                        )
                    }
                }
            }

            // 6. 测试与诊断
            item(key = "diag-title") { QingyuSectionTitle(AboutUpdatePageStrings.diagnosticsTitle) }
            item(key = "diag-group") {
                GroupCard {
                    ArrowRow(
                        title = AboutUpdatePageStrings.viewPhoneLogsAction,
                        onClick = onOpenDiagnostics,
                    )
                }
            }
        }
    }

    // 镜像地址输入弹窗（Dart `showAppTextInputDialog`，`:2259-2272`）。
    OverlayDialog(
        show = editingMirror,
        title = AboutUpdatePageStrings.setMirrorSourceTitle,
        onDismissRequest = { editingMirror = false },
        // 内容自己带 8dp（TextField 的视觉轴线）；框架侧给 8 ⇒ 单边合计仍是 16，
        // 不是官方默认 24 + 8 = 32。
        insideMargin = DpSize(8.dp, 16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            TextField(
                value = mirrorDraft,
                onValueChange = {
                    mirrorDraft = it
                    mirrorError = null
                },
                label = AboutUpdatePageStrings.mirrorPrefixLabel,
                useLabelAsPlaceholder = true,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                text = mirrorError ?: AboutUpdatePageStrings.mirrorPresetCustomDescription,
                style = MiuixTheme.textStyles.footnote1,
                color = if (mirrorError != null) {
                    MiuixTheme.colorScheme.error
                } else {
                    MiuixTheme.colorScheme.onSurfaceVariantSummary
                },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    onClick = { editingMirror = false },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = AboutUpdatePageStrings.cancelAction)
                }
                Button(
                    onClick = { submitMirror() },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = AboutUpdatePageStrings.confirmAction)
                }
            }
        }
    }
}

/** 一组设置行共用一张卡（官方「一整张 Card 里多个 Preference」的写法；行自带 16dp 内边距）。 */
@Composable
private fun GroupCard(content: @Composable ColumnScope.() -> Unit) {
    QingyuCard(modifier = Modifier.fillMaxWidth()) { content() }
}

@Composable
private fun ToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
    showDivider: Boolean,
) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onChange(!checked) }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = colors.onSurface,
            )
            if (subtitle.isNotEmpty()) {
                Text(
                    text = subtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                )
            }
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
    if (showDivider) HorizontalDivider(Modifier.padding(start = 16.dp))
}

@Composable
private fun ChoiceRow(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
    showDivider: Boolean,
    trailing: (@Composable () -> Unit)? = null,
) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body1
                    .shiftWeight(if (selected) QingyuWeightDelta.SEMIBOLD else QingyuWeightDelta.MEDIUM),
                color = if (selected) colors.primary else colors.onSurface,
            )
            if (subtitle.isNotEmpty()) {
                Text(
                    text = subtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = colors.onSurfaceVariantSummary,
                )
            }
        }
        trailing?.invoke()
        if (selected) {
            Spacer(Modifier.width(8.dp))
            Icon(imageVector = MiuixIcons.Ok, contentDescription = null, tint = colors.primary)
        }
    }
    if (showDivider) HorizontalDivider(Modifier.padding(start = 16.dp))
}

@Composable
private fun ArrowRow(title: String, onClick: () -> Unit, enabled: Boolean = true) {
    val colors = MiuixTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled) { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = if (enabled) colors.onSurface else colors.onSurfaceVariantSummary,
            modifier = Modifier.weight(1f),
        )
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = colors.onSurfaceVariantSummary,
        )
    }
}

/** 镜像测速结果小胶囊：成功显示耗时（ms），失败显示「失败」（Dart `_buildMirrorProbeStatusChip`）。 */
@Composable
private fun ProbeChip(result: DownloadProbeResult) {
    val colors = MiuixTheme.colorScheme
    val label = if (result.isSuccess) "${result.elapsedMillis}ms" else AboutUpdatePageStrings.mirrorProbeFailedLabel
    val fg = if (result.isSuccess) colors.primary else colors.error
    Text(
        text = label,
        style = MiuixTheme.textStyles.footnote2,
        color = fg,
        modifier = Modifier
            .background(colors.secondaryContainer, RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 2.dp),
    )
}
