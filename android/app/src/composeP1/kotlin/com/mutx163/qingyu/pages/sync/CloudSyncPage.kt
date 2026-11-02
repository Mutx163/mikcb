package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
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
import top.yukonga.miuix.kmp.icon.extended.Back
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
                                        Text(text = SyncStrings.saveAction.zh)
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
        title = SyncStrings.cloudSyncLoginSheetTitle.zh,
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = SyncStrings.cloudSyncLoginSheetSubtitle.zh,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(14.dp))
            TextField(
                value = username,
                onValueChange = { username = it },
                label = SyncStrings.cloudSyncUsernameLabel.zh,
                useLabelAsPlaceholder = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(10.dp))
            TextField(
                value = password,
                onValueChange = { password = it },
                label = SyncStrings.cloudSyncPasswordLabel.zh,
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
                    Text(text = SyncStrings.cloudSyncTestConnection.zh)
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
                    Text(text = SyncStrings.cloudSyncConfirmConnect.zh)
                }
            }
        }
    }
}
