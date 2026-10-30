package com.mutx163.qingyu.pages.live

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuShapes
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「后台保活」子屏 · Compose 渲染层（P3-J 缺口补口 A3）。
 *
 * 对应 Flutter `lib/screens/live_settings_subpages.dart:1573-1880` 的
 * `LiveKeepAliveSettingsScreen`（含 `_LiveKeepAliveServiceTile`）：
 *
 * - 单组白卡（Dart `:1616-1617` 明说「单组页面不再拉分组标签」）；
 * - 第 1 行：开关「从最近任务中隐藏应用」（ARB `hideFromRecentsTitle`）；
 * - 第 2 行：无障碍保活服务行——已开启绿勾 / 未开启橙色图标；**未开启才**出「去开启」按钮；
 *   **已开启整行不可点**（Dart `:1871-1873` 的注释：行本身用绿勾表达状态即可）；
 * - 点「去开启」先弹确认说明（敏感权限：不读屏、不代点），确认后才跳系统设置；
 * - 可选勿扰权限行（[showDoNotDisturbAccessRow]）——Dart 里这一行在显示设置屏（`:665`），
 *   不在本屏，所以这里默认关闭，只有宿主显式打开才渲染。
 *
 * 本层不碰平台：探测无障碍服务 / 跳系统设置 / 落库开关都由宿主（shell 接线层）回调注入。
 * 文案一律取 [LiveKeepAliveStrings]（与 `lib/l10n/app_zh.arb` 逐字一致）。
 */
@Composable
fun LiveKeepAliveSettingsPage(
    state: LiveKeepAliveState,
    onHideFromRecentsChange: (Boolean) -> Unit,
    onOpenAccessibilitySettings: () -> Unit,
    onBack: () -> Unit,
    showDoNotDisturbAccessRow: Boolean = false,
    onOpenDoNotDisturbAccessSettings: () -> Unit = {},
) {
    val dark = isSystemInDarkTheme()
    // 确认弹窗是纯屏上交互状态，不需要宿主参与。
    var confirmVisible by remember { mutableStateOf(false) }

    // 顶栏折叠行为由 QingyuPageScaffold 统一给（Dart `live_settings_subpages.dart:1611-1614`
    // 用 HyperosSubpage，`collapsibleLargeTitle` 默认 true ⇒ 可折叠大标题）。
    // 滚动容器走官方配方的 QingyuPageList：Dart 的 HyperosListView 是
    // SingleChildScrollView + Column，官方 demo 侧一律是 LazyColumn + 滚动三件套，
    // 「样式从 demo」⇒ 这里换成惰性列表（末端轻震 + 过度滚动 + 右侧滚动条）。
    QingyuPageScaffold(
        title = LiveKeepAliveStrings.liveKeepAliveTitle.zh,
        onBack = onBack,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = QingyuShapes.SECTION_GAP.dp),
        ) {
            // Dart `:1616-1617` 明说「单组页面不再拉分组标签」⇒ 整页只有这一张设置组卡。
            item(key = "keep-alive") {
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(
                            horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                            vertical = QingyuShapes.SECTION_GAP.dp,
                        ),
                    cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                    // 包 Preference 行时**不传** insideMargin：官方 `*Preference` 自带 16dp。
                    insideMargin = PaddingValues(0.dp),
                ) {
                    SwitchPreference(
                        checked = state.hideFromRecents,
                        onCheckedChange = onHideFromRecentsChange,
                        title = LiveKeepAliveStrings.hideFromRecentsTitle.zh,
                    )

                    HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))

                    LiveKeepAliveServiceRow(
                        enabled = state.accessibilityEnabled,
                        onOpenSettings = { confirmVisible = true },
                    )

                    if (showDoNotDisturbAccessRow) {
                        HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
                        LiveDoNotDisturbAccessRow(
                            checked = state.doNotDisturbAccessChecked,
                            granted = state.doNotDisturbAccessGranted,
                            onClick = onOpenDoNotDisturbAccessSettings,
                        )
                    }
                }
            }
        }
    }

    LiveKeepAliveConfirmDialog(
        show = confirmVisible,
        onDismiss = { confirmVisible = false },
        onConfirm = {
            confirmVisible = false
            onOpenAccessibilitySettings()
        },
    )
}

/**
 * 宿主接线用的状态化重载：内部持有 [LiveKeepAliveState]，把平台动作收成四个回调。
 *
 * - [onPersistHideFromRecents]：落库「从最近任务中隐藏应用」，**返回是否落库成功**；
 *   失败时开关保持原值（Dart 成功后 `_draft = provider.settings`、失败不动 `_draft`），
 *   失败提示（ARB `saveFailed`）由宿主负责（Dart 侧是 `showAppToast`，属宿主级能力）；
 * - [onProbeAccessibilityEnabled]：读无障碍保活服务是否已开启；
 * - [onProbeDoNotDisturbAccessGranted]：读勿扰模式访问权限是否已授予；
 * - [refreshToken]：宿主在 `ON_RESUME`（从系统设置页返回）时自增，触发按 Dart
 *   `_refresh(retryIfDisabled = true)` 口径重探（3 次 × 450ms，读到 true 立即停）。
 */
@Composable
fun LiveKeepAliveSettingsPage(
    initialState: LiveKeepAliveState = LiveKeepAliveState(),
    onBack: () -> Unit,
    onPersistHideFromRecents: (Boolean) -> Boolean = { true },
    onProbeAccessibilityEnabled: () -> Boolean = { false },
    onProbeDoNotDisturbAccessGranted: () -> Boolean = { false },
    onOpenAccessibilitySettings: () -> Unit = {},
    onOpenDoNotDisturbAccessSettings: () -> Unit = {},
    showDoNotDisturbAccessRow: Boolean = false,
    refreshToken: Int = 0,
) {
    var state by remember { mutableStateOf(initialState) }

    LaunchedEffect(refreshToken) {
        val probes = mutableListOf(onProbeAccessibilityEnabled())
        val plan = LiveKeepAliveModel.buildRefreshPlan(
            accessibilityEnabled = probes.first(),
            retryIfDisabled = true,
        )
        var attempt = 0
        while (!probes.last() && attempt < plan.retryAttempts) {
            attempt++
            delay(plan.retryDelayMillis)
            probes += onProbeAccessibilityEnabled()
        }
        val outcome = LiveKeepAliveModel.resolveRefreshOutcome(probes, retryIfDisabled = true)
        state = state.withAccessibilityProbe(outcome.enabled)

        if (showDoNotDisturbAccessRow) {
            // Dart `_DoNotDisturbAccessTileState._refresh()` 没有重试，单读一次。
            state = state.withDoNotDisturbProbe(onProbeDoNotDisturbAccessGranted())
        }
    }

    LiveKeepAliveSettingsPage(
        state = state,
        onHideFromRecentsChange = { value ->
            val saved = onPersistHideFromRecents(value)
            // 存失败时开关保持原值：Dart 侧 `_draft` 只在成功后跟随 provider.settings。
            state = state.copy(
                hideFromRecents = LiveKeepAliveModel.resolveHideFromRecentsAfterSave(
                    current = state.hideFromRecents,
                    requested = value,
                    saved = saved,
                ),
            )
        },
        onOpenAccessibilitySettings = onOpenAccessibilitySettings,
        onBack = onBack,
        showDoNotDisturbAccessRow = showDoNotDisturbAccessRow,
        onOpenDoNotDisturbAccessSettings = onOpenDoNotDisturbAccessSettings,
    )
}

/**
 * 无障碍保活服务行（Dart `_LiveKeepAliveServiceTile`）。
 *
 * 没有官方 `*Preference` 对位件：行尾要挂按钮、行首要挂彩色图标徽标，所以手写一行，
 * 内边距取 [QingyuShapes] 的行刻度（与官方 Preference 自带的 16dp 对齐）。
 */
@Composable
private fun LiveKeepAliveServiceRow(
    enabled: Boolean,
    onOpenSettings: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val clickable = LiveKeepAliveModel.isServiceRowClickable(enabled)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = clickable, onClick = onOpenSettings)
            .padding(
                horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
            )
            .heightIn(min = QingyuShapes.LIST_ROW_MIN_HEIGHT.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LiveKeepAliveIconBadge(
            // Dart 图标集无对位件：已开启用官方 Ok（绿勾），未开启用 Settings（去设置里开）。
            icon = if (enabled) MiuixIcons.Ok else MiuixIcons.Settings,
            accent = Color(
                toneColor(
                    LiveKeepAliveModel.resolveServiceTone(enabled),
                ),
            ),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = LiveKeepAliveStrings.keepAliveServiceTitle.zh,
            modifier = Modifier.weight(1f),
            style = MiuixTheme.textStyles.body2,
            fontWeight = FontWeight.Medium,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        // 已开启时隐藏「去开启」：按钮唯一用途是开启，开着再引去确认弹窗是噪声。
        if (LiveKeepAliveModel.shouldShowEnableButton(enabled)) {
            Spacer(modifier = Modifier.width(8.dp))
            TextButton(
                text = LiveKeepAliveStrings.goEnableAction.zh,
                onClick = onOpenSettings,
            )
        }
    }
}

/**
 * 勿扰模式访问权限行（Dart `_DoNotDisturbAccessTile`）。
 *
 * 只在选了免打扰档时才有意义，所以默认不渲染（见 [LiveKeepAliveSettingsPage] 的
 * [showDoNotDisturbAccessRow]）。未探到状态前不猜：显示中性色 + 「建议检查」。
 */
@Composable
private fun LiveDoNotDisturbAccessRow(
    checked: Boolean,
    granted: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val status = LiveKeepAliveModel.resolveDoNotDisturbStatus(checked = checked, granted = granted)
    val grantedVisual = status == LivePermissionStatus.GRANTED

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(
                horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp,
                vertical = QingyuShapes.ROW_PADDING_VERTICAL.dp,
            )
            .heightIn(min = QingyuShapes.LIST_ROW_MIN_HEIGHT.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LiveKeepAliveIconBadge(
            icon = if (grantedVisual) MiuixIcons.Ok else MiuixIcons.Info,
            accent = Color(toneColor(LiveKeepAliveModel.resolveTone(status))),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = LiveKeepAliveStrings.guideStatusDoNotDisturbAccess.zh,
                style = MiuixTheme.textStyles.body2,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = LiveKeepAliveStrings.guideStatusDoNotDisturbAccessHint.zh,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = LiveKeepAliveStrings.statusLabel(status),
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/**
 * 开启前确认弹窗（Dart `_openSettings` 里的 `showHyperosConfirmDialog`）。
 *
 * 无障碍保活属敏感权限：跳系统设置前先说明用途与边界（不读屏、不代点），
 * 用户确认后再进入，降低误开与投诉风险。取消 / 点外部 / 返回键都**不放行**
 * （[LiveKeepAliveModel.shouldProceedToSettings] 对 `null` 与 `false` 一律返回 false）。
 */
@Composable
private fun LiveKeepAliveConfirmDialog(
    show: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = LiveKeepAliveStrings.keepAliveConfirmTitle.zh,
        summary = LiveKeepAliveStrings.keepAliveConfirmBody.zh,
        onDismissRequest = onDismiss,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = LiveKeepAliveStrings.cancelAction.zh,
                onClick = onDismiss,
            )
            Button(
                modifier = Modifier.weight(1f),
                onClick = onConfirm,
            ) {
                Text(LiveKeepAliveStrings.keepAliveConfirmGoAction.zh)
            }
        }
    }
}

/** 图标徽标（Dart `HyperosIconBadge`）：36dp / 圆角 12 / 主色 12% 底 + 主色图标。 */
@Composable
private fun LiveKeepAliveIconBadge(icon: ImageVector, accent: Color) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(accent.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = accent,
            modifier = Modifier.size(18.dp),
        )
    }
}

/** 语义色调 -> 彩豆色（Dart `HyperosIconColors.green/orange/blue`）。 */
private fun toneColor(tone: LiveStatusTone): Int = when (tone) {
    LiveStatusTone.NEUTRAL -> QingyuIconColors.BLUE
    LiveStatusTone.POSITIVE -> QingyuIconColors.GREEN
    LiveStatusTone.CAUTION -> QingyuIconColors.ORANGE
}
