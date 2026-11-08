package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.preference.WindowDropdownPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 云同步页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/cloud_sync_screen.dart`：
 * 引导条 → 云账号 → 同步设置（开关 / 提供商 / 方式）→ 高级设置（三个输入框）
 * → 同步状态 → 立即同步 → 备份版本（预览 3 条）→ 备份保留策略 → 帮助条。
 *
 * 分段显隐、按钮 loading/enabled、下拉选项下标、所有文案都在模型层
 * [CloudSyncLogic.buildViewState] 里算好；这里只摆位置、转通道回调。
 */
@Composable
fun CloudSyncPage(
    viewState: CloudSyncViewState,
    onBack: () -> Unit,
    onConnect: () -> Unit,
    onDisconnect: () -> Unit,
    onToggleEnabled: (Boolean) -> Unit,
    onProviderSelected: (index: Int) -> Unit,
    onModeSelected: (index: Int) -> Unit,
    onBaseUrlChange: (String) -> Unit,
    onRemoteFolderChange: (String) -> Unit,
    onDeviceLabelChange: (String) -> Unit,
    onSaveAdvanced: () -> Unit,
    onSyncNow: () -> Unit,
    onCreateBackup: () -> Unit,
    onOpenBackup: (entryId: String) -> Unit,
    onViewAllBackups: () -> Unit,
    onUndoRestore: () -> Unit,
    onMaxCountSelected: (index: Int) -> Unit,
    onMaxAgeSelected: (index: Int) -> Unit,
    onManualProtectedChange: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(title = viewState.title, onBack = onBack, smallTopBar = true) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {

            if (viewState.isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                return@Column
            }

            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                horizontalPadding = 16.dp,
                contentPadding = PaddingValues(top = 4.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // ── 1. 引导条 ──
                item(key = "intro") {
                    HintCard(
                        title = viewState.introTitle,
                        body = viewState.introSubtitle,
                        dark = dark,
                    )
                }

                // ── 2. 云账号 ──
                item(key = "account") {
                    SectionBlock(title = viewState.accountSectionTitle) {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 6.dp, vertical = 4.dp),
                        ) {
                            if (viewState.account.connected) {
                                Column(modifier = Modifier.fillMaxWidth()) {
                                    BasicRow(
                                        title = viewState.account.title,
                                        summary = viewState.account.subtitle,
                                        dark = dark,
                                    )
                                    TextButton(
                                        text = viewState.disconnectActionLabel,
                                        onClick = onDisconnect,
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                }
                            } else {
                                ArrowPreference(
                                    title = viewState.connectActionLabel,
                                    summary = viewState.account.subtitle,
                                    onClick = onConnect,
                                )
                            }
                        }
                    }
                }

                // ── 3. 同步设置（未连接时整段不出现） ──
                if (viewState.showSyncSettings) {
                    item(key = "settings") {
                        SectionBlock(title = viewState.settingsSectionTitle) {
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(0.dp),
                            ) {
                                SwitchPreference(
                                    checked = viewState.syncEnabled,
                                    onCheckedChange = onToggleEnabled,
                                    title = viewState.syncEnabledTitle,
                                )
                                WindowDropdownPreference(
                                    items = viewState.providerLabels,
                                    selectedIndex = viewState.providerIndex,
                                    title = viewState.providerTitle,
                                    onSelectedIndexChange = onProviderSelected,
                                )
                                WindowDropdownPreference(
                                    items = viewState.modeLabels,
                                    selectedIndex = viewState.modeIndex,
                                    title = viewState.modeTitle,
                                    onSelectedIndexChange = onModeSelected,
                                )
                            }
                        }
                    }

                    // ── 4. 高级设置（地址 / 目录 / 设备名） ──
                    item(key = "advanced") {
                        SectionBlock(title = viewState.advancedTitle) {
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                            ) {
                                Column(modifier = Modifier.fillMaxWidth()) {
                                    var baseUrl by remember(viewState.baseUrl) { mutableStateOf(viewState.baseUrl) }
                                    TextField(
                                        value = baseUrl,
                                        onValueChange = {
                                            baseUrl = it
                                            onBaseUrlChange(it)
                                        },
                                        label = viewState.baseUrlLabel,
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                    Spacer(modifier = Modifier.height(10.dp))
                                    var remoteFolder by remember(viewState.remoteFolder) {
                                        mutableStateOf(viewState.remoteFolder)
                                    }
                                    TextField(
                                        value = remoteFolder,
                                        onValueChange = {
                                            remoteFolder = it
                                            onRemoteFolderChange(it)
                                        },
                                        label = viewState.remoteFolderLabel,
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                    Spacer(modifier = Modifier.height(10.dp))
                                    var deviceLabel by remember(viewState.deviceLabel) {
                                        mutableStateOf(viewState.deviceLabel)
                                    }
                                    TextField(
                                        value = deviceLabel,
                                        onValueChange = {
                                            deviceLabel = it
                                            onDeviceLabelChange(it)
                                        },
                                        label = viewState.deviceLabelTitle,
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                    Text(
                                        text = viewState.deviceLabelHint,
                                        style = MiuixTheme.textStyles.footnote1,
                                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                        modifier = Modifier.padding(top = 6.dp),
                                    )
                                    Spacer(modifier = Modifier.height(10.dp))
                                    Button(
                                        onClick = onSaveAdvanced,
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Text(text = SyncStrings.saveAction.text)
                                    }
                                }
                            }
                        }
                    }

                    // ── 5. 同步状态 ──
                    if (viewState.showStatus) {
                        item(key = "status") {
                            SectionBlock(title = viewState.statusSectionTitle) {
                                QingyuCard(
                                    modifier = Modifier.fillMaxWidth(),
                                    insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                                ) {
                                    InfoLine(
                                        label = viewState.lastSyncedLabel,
                                        value = viewState.status.lastSyncedAtText,
                                        dark = dark,
                                    )
                                    if (viewState.status.isSyncing) {
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(
                                                text = viewState.syncingLabel,
                                                style = MiuixTheme.textStyles.body2,
                                                color = Color(QingyuTheme.primaryText(dark)),
                                            )
                                        }
                                    }
                                    viewState.status.lastErrorText?.let { error ->
                                        Spacer(modifier = Modifier.height(8.dp))
                                        InfoLine(
                                            label = viewState.lastErrorLabel,
                                            value = error,
                                            dark = dark,
                                            valueColor = Color(QingyuTheme.error(dark)),
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // ── 6. 立即同步 ──
                    if (viewState.showSyncNow) {
                        item(key = "sync_now") {
                            LoadingButton(
                                label = viewState.syncNowButton.label,
                                loading = viewState.syncNowButton.loading,
                                enabled = viewState.syncNowButton.enabled,
                                onClick = onSyncNow,
                            )
                        }
                    }

                    // ── 7. 备份版本（预览 3 条） ──
                    if (viewState.showBackups) {
                        item(key = "backups_header") {
                            SectionHeader(title = viewState.backupSectionTitle, dark = dark)
                        }
                        // 撤销入口：只有确实存在可撤销的恢复时才出现（恢复失败 / 已撤销后消失）。
                        if (viewState.canUndoRestore) {
                            item(key = "backups_undo") {
                                CloudRestoreUndoCard(
                                    title = viewState.undoRestoreTitle,
                                    summary = viewState.undoRestoreSummary,
                                    actionLabel = viewState.undoRestoreActionLabel,
                                    onUndo = onUndoRestore,
                                    modifier = Modifier.padding(horizontal = 4.dp),
                                )
                            }
                        }
                        item(key = "backups_create") {
                            LoadingButton(
                                label = viewState.createBackupButton.label,
                                loading = viewState.createBackupButton.loading,
                                enabled = viewState.createBackupButton.enabled,
                                onClick = onCreateBackup,
                            )
                        }
                        if (viewState.loadingBackups) {
                            item(key = "backups_loading") {
                                QingyuCard(
                                    modifier = Modifier.fillMaxWidth(),
                                    insideMargin = PaddingValues(vertical = 16.dp),
                                ) {
                                    Box(
                                        modifier = Modifier.fillMaxWidth(),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        CircularProgressIndicator()
                                    }
                                }
                            }
                        } else if (viewState.backupRows.isEmpty()) {
                            item(key = "backups_empty") {
                                QingyuCard(
                                    modifier = Modifier.fillMaxWidth(),
                                    insideMargin = PaddingValues(horizontal = 6.dp, vertical = 4.dp),
                                ) {
                                    BasicRow(
                                        title = viewState.emptyBackupText,
                                        summary = null,
                                        dark = dark,
                                        enabled = false,
                                    )
                                }
                            }
                        } else {
                            items(viewState.backupRows, key = { "backup_${it.entryId}" }) { row ->
                                QingyuCard(
                                    modifier = Modifier.fillMaxWidth(),
                                    insideMargin = PaddingValues(horizontal = 6.dp, vertical = 2.dp),
                                    onClick = { onOpenBackup(row.entryId) },
                                ) {
                                    BackupPreviewRow(row = row, dark = dark)
                                }
                            }
                            if (viewState.hasMoreBackups) {
                                item(key = "backups_view_all") {
                                    QingyuCard(
                                        modifier = Modifier.fillMaxWidth(),
                                        insideMargin = PaddingValues(0.dp),
                                    ) {
                                        ArrowPreference(
                                            title = viewState.viewAllLabel,
                                            onClick = onViewAllBackups,
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // ── 8. 备份保留策略 ──
                    if (viewState.showRetention) {
                        item(key = "retention") {
                            SectionBlock(title = viewState.retentionSectionTitle) {
                                QingyuCard(
                                    modifier = Modifier.fillMaxWidth(),
                                    insideMargin = PaddingValues(0.dp),
                                ) {
                                    WindowDropdownPreference(
                                        items = viewState.maxCountOptionLabels,
                                        selectedIndex = viewState.maxCountSelectedIndex,
                                        title = viewState.maxCountTitle,
                                        summary = viewState.maxCountSubtitle,
                                        onSelectedIndexChange = onMaxCountSelected,
                                    )
                                    WindowDropdownPreference(
                                        items = viewState.maxAgeOptionLabels,
                                        selectedIndex = viewState.maxAgeSelectedIndex,
                                        title = viewState.maxAgeTitle,
                                        summary = viewState.maxAgeSubtitle,
                                        onSelectedIndexChange = onMaxAgeSelected,
                                    )
                                    SwitchPreference(
                                        checked = viewState.manualBackupProtected,
                                        onCheckedChange = onManualProtectedChange,
                                        title = viewState.manualProtectedTitle,
                                    )
                                }
                            }
                        }
                    }
                }

                // ── 9. 帮助条 ──
                item(key = "help") {
                    HintCard(
                        title = viewState.helpTitle,
                        body = viewState.helpBody,
                        dark = dark,
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionBlock(title: String, content: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(title = title, dark = isSystemInDarkTheme())
        Spacer(modifier = Modifier.height(6.dp))
        content()
    }
}

@Composable
private fun SectionHeader(title: String, dark: Boolean) {
    QingyuSectionTitle(title)
}

/** 带图标的信息条（Flutter `HyperosHintBanner`）。 */
@Composable
private fun HintCard(title: String, body: String, dark: Boolean) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = MiuixIcons.Info,
                contentDescription = null,
                tint = Color(QingyuTheme.primary(dark = dark)),
                modifier = Modifier.size(18.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = body,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}

/** 纯展示行（Flutter `_CloudSyncInfoRow` / 无动作的 `HyperosNavTile`）。 */
@Composable
private fun BasicRow(
    title: String,
    summary: String?,
    dark: Boolean,
    enabled: Boolean = true,
) {
    val titleColor = if (enabled) {
        Color(QingyuTheme.primaryText(dark))
    } else {
        Color(QingyuTheme.secondaryText(dark))
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = titleColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        summary?.let {
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = it,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** 标签 + 取值两列（Flutter `_CloudSyncInfoRow`，左 72dp 标签）。 */
@Composable
private fun InfoLine(
    label: String,
    value: String,
    dark: Boolean,
    valueColor: Color? = null,
) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Box(modifier = Modifier.width(72.dp)) {
            Text(
                text = label,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Text(
            text = value,
            style = MiuixTheme.textStyles.body2,
            color = valueColor ?: Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.weight(1f),
        )
    }
}

/** 备份预览行：标题 + 副标题 + （当前）徽标 + 右箭头。 */
@Composable
private fun BackupPreviewRow(row: CloudBackupRowView, dark: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.title,
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = row.subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        row.details?.let { badge ->
            Text(
                text = badge,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.primary(dark = dark)),
            )
        }
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(16.dp),
        )
    }
}

/** 主行动按钮：loading 时左侧转圈，禁用时不可点（Flutter `HyperosButton`）。 */
@Composable
private fun LoadingButton(
    label: String,
    loading: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
    ) {
        if (loading) {
            CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
            Spacer(modifier = Modifier.width(8.dp))
        }
        Text(text = label)
    }
}

/**
 * 连接坚果云弹层（Dart `_WebdavConnectSheet`）。
 *
 * 官方底部弹层 [QingyuSheet]：带遮罩，点空白 / 返回键经 [onCancel] 关闭；
 * 标题行由套件的 `title` 给，不再自绘。
 *
 * 两个动作：先「测试连接」（次要，`buttonColors()`），再「确认连接」（主操作，
 * `buttonColorsPrimary()`）把账号密码交给宿主落盘。Dart 只有这两枚等宽按钮，
 * 没有第三枚「取消」——关闭靠下滑 / 返回键。
 * 用户名/密码是本弹层内的临时输入，属 UI 态；校验与 toast 由宿主经回调处理。
 *
 * @param show 是否显示。宿主当前以 `showConnect` 决定是否组合本组件，所以默认 `true`；
 *   Task 8b 接真实显隐时改为透传宿主状态。
 */
@Composable
fun WebdavConnectSheet(
    initialUsername: String,
    testing: Boolean,
    connecting: Boolean,
    onTestConnection: (username: String, password: String) -> Unit,
    onConfirm: (username: String, password: String) -> Unit,
    onCancel: () -> Unit,
    show: Boolean = true,
) {
    val dark = isSystemInDarkTheme()
    var username by remember(initialUsername) { mutableStateOf(initialUsername) }
    var password by remember { mutableStateOf("") }

    QingyuSheet(
        show = show,
        title = SyncStrings.cloudSyncLoginSheetTitle.text,
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = SyncStrings.cloudSyncLoginSheetSubtitle.text,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(14.dp))
            TextField(
                value = username,
                onValueChange = { username = it },
                label = SyncStrings.cloudSyncUsernameLabel.text,
                useLabelAsPlaceholder = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(10.dp))
            TextField(
                value = password,
                onValueChange = { password = it },
                label = SyncStrings.cloudSyncPasswordLabel.text,
                useLabelAsPlaceholder = true,
                // 对应 Dart `obscureText: true`
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                // 次要：先测连接（不落盘）。
                Button(
                    onClick = { onTestConnection(username.trim(), password) },
                    enabled = !testing && !connecting,
                    colors = ButtonDefaults.buttonColors(),
                    modifier = Modifier.weight(1f),
                ) {
                    if (testing) {
                        CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(6.dp))
                    }
                    Text(text = SyncStrings.cloudSyncTestConnection.text)
                }
                // 主色：确认连接并落盘。
                Button(
                    onClick = { onConfirm(username.trim(), password) },
                    enabled = !connecting,
                    colors = ButtonDefaults.buttonColorsPrimary(),
                    modifier = Modifier.weight(1f),
                ) {
                    if (connecting) {
                        CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(6.dp))
                    }
                    Text(text = SyncStrings.cloudSyncConfirmConnect.text)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 4 档：已连接有备份 / 未连接 / 首次加载 / 同步失败（列表留着缓存）；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 未连接 —— 同步设置 / 状态 / 备份 / 保留策略四段整段消失，只剩引导条与账号卡；
//   · 首次加载 —— 整页被居中进度圈顶掉（`isLoading` 早退分支）；
//   · 同步失败 —— 状态区出错误行，但备份区照常画，最容易只改了其中一处；
//   · 暗色 / 大字号 —— 页面取色走 isSystemInDarkTheme()，只有 QingyuPageTheme 会把
//     LocalConfiguration 的 uiMode 一起改写；行内文案的折行点只在字放大后才暴露。
//
// 固定写法：主题一律 QingyuPageTheme(isDark = …)、字号走 textScale 参数
//（@Preview(fontScale = …) 绕过了应用的 appTextScale 口径）；宽度按 400dp（本仓折行实测口径）。
//
// 数据一律走 `CloudSyncLogic.buildViewState`，不手工拼 viewState：
// 页面只吃模型层算好的显隐与文案，手工拼等于绕过被测代码。
// `WebdavSyncConfig` 用全限定名，避免给页面文件新增业务 import（本批只允许加预览用 import）。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用配置：`connected = true` 时填一个示例账号（账号非空 + 有密码才算已连接）。 */
private fun previewCloudSyncConfig(connected: Boolean): com.mutx163.qingyu.sync.WebdavSyncConfig =
    com.mutx163.qingyu.sync.WebdavSyncConfig(
        enabled = connected,
        username = if (connected) "zhangsan@example.com" else "",
    )

/** 预览用三份备份：当前版本 + 两台设备的旧备份，全用中文实义值。 */
private fun previewCloudSyncBackupEntries(): List<CloudBackupEntryModel> = listOf(
    CloudBackupEntryModel(
        id = "backup-current",
        fileName = "history/2026-11-08T09-12.mikcb",
        exportedAtIso = "2026-11-08T09:12:00",
        contentSha256 = "a1b2c3d4",
        deviceId = "device-demo-1",
        deviceLabel = "示例手机",
        appVersion = "1.0.0",
        isCurrent = true,
        source = CloudBackupSource.MANUAL,
        profileCount = 3,
        courseCount = 42,
    ),
    CloudBackupEntryModel(
        id = "backup-2",
        fileName = "history/2026-11-07T21-40.mikcb",
        exportedAtIso = "2026-11-07T21:40:00",
        contentSha256 = "e5f6a7b8",
        deviceId = "device-demo-2",
        deviceLabel = "示例平板",
        appVersion = "1.0.0",
        isCurrent = false,
        source = CloudBackupSource.AUTO,
        profileCount = 2,
        courseCount = 36,
    ),
    CloudBackupEntryModel(
        id = "backup-3",
        fileName = "history/2026-11-06T07-05.mikcb",
        exportedAtIso = "2026-11-06T07:05:00",
        contentSha256 = "c9d0e1f2",
        deviceId = "device-demo-1",
        deviceLabel = "示例手机",
        appVersion = "0.9.8",
        isCurrent = false,
        source = CloudBackupSource.AUTO,
        profileCount = 2,
        courseCount = 30,
    ),
)

/** 一档预览：模型层输入；[name] 只用来给预览命名，不参与渲染。 */
private data class PreviewCloudSyncState(
    val name: String,
    val config: com.mutx163.qingyu.sync.WebdavSyncConfig,
    val hasStoredPassword: Boolean,
    val status: CloudSyncStatusSource,
    val isLoading: Boolean = false,
    val loadingBackups: Boolean = false,
    val isCreatingBackup: Boolean = false,
    val backupEntries: List<CloudBackupEntryModel> = emptyList(),
    val deviceLabel: String = "示例手机",
)

private val previewCloudSyncStates: List<PreviewCloudSyncState> = listOf(
    PreviewCloudSyncState(
        name = "已连接有备份",
        config = previewCloudSyncConfig(connected = true),
        hasStoredPassword = true,
        status = CloudSyncStatusSource(lastSyncedAtIso = "2026-11-08T09:12:00"),
        backupEntries = previewCloudSyncBackupEntries(),
    ),
    PreviewCloudSyncState(
        name = "未连接",
        config = previewCloudSyncConfig(connected = false),
        hasStoredPassword = false,
        status = CloudSyncStatusSource(),
    ),
    PreviewCloudSyncState(
        name = "首次加载",
        config = previewCloudSyncConfig(connected = true),
        hasStoredPassword = true,
        status = CloudSyncStatusSource(),
        isLoading = true,
    ),
    PreviewCloudSyncState(
        name = "同步失败",
        config = previewCloudSyncConfig(connected = true),
        hasStoredPassword = true,
        status = CloudSyncStatusSource(
            lastSyncedAtIso = "2026-11-07T21:40:00",
            lastErrorCode = "network_error",
        ),
        backupEntries = previewCloudSyncBackupEntries(),
    ),
)

private fun previewCloudSyncState(name: String): PreviewCloudSyncState =
    previewCloudSyncStates.first { it.name == name }

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewCloudSyncPage(
    state: PreviewCloudSyncState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        CloudSyncPage(
            viewState = CloudSyncLogic.buildViewState(
                config = state.config,
                hasStoredPassword = state.hasStoredPassword,
                status = state.status,
                isCreatingBackup = state.isCreatingBackup,
                loadingBackups = state.loadingBackups,
                backupEntries = state.backupEntries,
                isLoading = state.isLoading,
                deviceLabel = state.deviceLabel,
            ),
            onBack = {},
            onConnect = {},
            onDisconnect = {},
            onToggleEnabled = {},
            onProviderSelected = {},
            onModeSelected = {},
            onBaseUrlChange = {},
            onRemoteFolderChange = {},
            onDeviceLabelChange = {},
            onSaveAdvanced = {},
            onSyncNow = {},
            onCreateBackup = {},
            onOpenBackup = {},
            onViewAllBackups = {},
            onUndoRestore = {},
            onMaxCountSelected = {},
            onMaxAgeSelected = {},
            onManualProtectedChange = {},
        )
    }
}

// ── 单档：四态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 已连接有备份", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewConnected() {
    PreviewCloudSyncPage(previewCloudSyncState("已连接有备份"))
}

@Suppress("unused")
@Preview(name = "2 未连接", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewDisconnected() {
    PreviewCloudSyncPage(previewCloudSyncState("未连接"))
}

@Suppress("unused")
@Preview(name = "3 首次加载", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewLoading() {
    PreviewCloudSyncPage(previewCloudSyncState("首次加载"))
}

@Suppress("unused")
@Preview(name = "4 同步失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewSyncFailed() {
    PreviewCloudSyncPage(previewCloudSyncState("同步失败"))
}

// ── 单档：外观两档（以「已连接有备份」为基准）───────────────────────────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewDark() {
    PreviewCloudSyncPage(previewCloudSyncState("已连接有备份"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewLargeText() {
    PreviewCloudSyncPage(previewCloudSyncState("已连接有备份"), textScale = 1.3f)
}

// ── 总览：四态并排，一屏看完 ────────────────────────────────────────────────

/**
 * 一屏总览：四种状态横向并排，用来一眼比结构差异（哪一段出现 / 消失）。
 *
 * 4 × 400dp + 3 × 16dp 间距 = 1648dp，所以画布给 1700dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~6 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·四态并排", showBackground = true, widthDp = 1700, heightDp = 900)
@Composable
private fun CloudSyncPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (state in previewCloudSyncStates) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewCloudSyncPage(state)
            }
        }
    }
}
