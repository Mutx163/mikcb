package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.WebdavBaseUrlScheme
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.WebdavSyncMode
import com.mutx163.qingyu.sync.WebdavSyncProvider
import com.mutx163.qingyu.sync.inspectWebdavBaseUrlScheme
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId

/**
 * 云同步页的纯逻辑（源：`lib/screens/cloud_sync_screen.dart`）。
 *
 * 这里承载三类判据，渲染层一律不再自己算：
 * 1. **分段显隐**：未连接 → 只留引导与账号区；已连接但同步关掉 → 设置区还在，
 *    同步按钮 / 备份区 / 保留策略区整段不出现（Dart `if (_config.enabled)`）；
 * 2. **按钮状态机**：`loading` 与 `enabled` 分开表达（Dart 里是 `loading:` +
 *    `onPressed: 条件 ? null : 动作` 两个入参），同步中与备份中互相禁用；
 * 3. **baseUrl 三级闸门**：空 → 坚果云默认 https；http → 需要明文二次确认；
 *    其余 → 非法。三个入口（高级设置保存、提供商切换、测连接）共用同一份判据。
 */

/** baseUrl 闸门判定（Dart `_confirmBaseUrl` 的四个出口收敛成三个）。 */
enum class BaseUrlVerdict {
    /** 可直接使用（含空串回落默认地址）。 */
    PROCEED,

    /** 明文 http：动作前必须弹一次风险确认。 */
    NEED_HTTP_CONFIRM,

    /** 协议非法：提示错误、动作中止。 */
    INVALID,
}

data class BaseUrlResolution(
    val verdict: BaseUrlVerdict,
    val resolvedUrl: String?,
)

/** 协调器状态里本页要展示的三项（`WebdavSyncStatus` 的展示侧子集）。 */
data class CloudSyncStatusSource(
    val lastSyncedAtIso: String? = null,
    val isSyncing: Boolean = false,
    val lastErrorCode: String? = null,
)

data class CloudSyncStatusView(
    /** "-" 表示从未同步过（Dart `_formatDateTime(null)`）。 */
    val lastSyncedAtText: String,
    val isSyncing: Boolean,
    /** null = 没有错误行。 */
    val lastErrorText: String?,
)

data class CloudSyncAccountView(
    val connected: Boolean,
    /** 已连接：`已连接：{email}`；未连接：`连接坚果云`。 */
    val title: String,
    /** 已连接：提供商名；未连接：未连接说明。 */
    val subtitle: String,
    val username: String,
)

data class CloudSyncButtonView(
    val label: String,
    val loading: Boolean,
    val enabled: Boolean,
)

/** 同步冲突弹框（Dart `_resolveConflict` 的标题/正文/三个动作）。 */
data class SyncConflictDialogView(
    val title: String,
    val message: String,
    val cancelLabel: String,
    val useRemoteLabel: String,
    val keepLocalLabel: String,
)

/**
 * 云同步页整页 viewState。
 *
 * 文案字段也一并在模型层算好：渲染层只摆位置，不拼字符串、不判业务条件。
 */
data class CloudSyncViewState(
    val isLoading: Boolean,
    val account: CloudSyncAccountView,
    val status: CloudSyncStatusView,
    // 账号区
    val accountSectionTitle: String,
    val connectActionLabel: String,
    val disconnectActionLabel: String,
    val disconnectTitle: String,
    val disconnectBody: String,
    // 引导 / 帮助
    val title: String,
    val introTitle: String,
    val introSubtitle: String,
    val helpTitle: String,
    val helpBody: String,
    // 设置区
    val showSyncSettings: Boolean,
    val settingsSectionTitle: String,
    val syncEnabledTitle: String,
    val syncEnabled: Boolean,
    val providerTitle: String,
    val providerLabels: List<String>,
    val providerIndex: Int,
    val modeTitle: String,
    val modeLabels: List<String>,
    val modeIndex: Int,
    // 高级设置
    val advancedTitle: String,
    val baseUrlLabel: String,
    val baseUrl: String,
    val remoteFolderLabel: String,
    val remoteFolder: String,
    val deviceLabelTitle: String,
    val deviceLabelHint: String,
    val deviceLabel: String,
    val baseUrlInvalidMessage: String,
    val httpConfirmTitle: String,
    val httpConfirmMessage: String,
    val httpConfirmProceedLabel: String,
    // 状态区
    val showStatus: Boolean,
    val statusSectionTitle: String,
    val lastSyncedLabel: String,
    val lastErrorLabel: String,
    val syncingLabel: String,
    // 立即同步
    val showSyncNow: Boolean,
    val syncNowButton: CloudSyncButtonView,
    // 备份区
    val showBackups: Boolean,
    val backupSectionTitle: String,
    val createBackupButton: CloudSyncButtonView,
    val loadingBackups: Boolean,
    val backupRows: List<CloudBackupRowView>,
    val hasMoreBackups: Boolean,
    val viewAllLabel: String,
    val emptyBackupText: String,
    // 保留策略
    val showRetention: Boolean,
    val retentionSectionTitle: String,
    val maxCountTitle: String,
    val maxCountSubtitle: String,
    val maxCountOptionLabels: List<String>,
    val maxCountSelectedIndex: Int,
    val maxAgeTitle: String,
    val maxAgeSubtitle: String,
    val maxAgeOptionLabels: List<String>,
    val maxAgeSelectedIndex: Int,
    val manualProtectedTitle: String,
    val manualBackupProtected: Boolean,
    // 撤销上一次恢复（仅当确有可撤销的恢复、且备份区可见时才出现）
    val canUndoRestore: Boolean = false,
    val undoRestoreTitle: String = "",
    val undoRestoreSummary: String = "",
    val undoRestoreActionLabel: String = "",
)

object CloudSyncLogic {

    /** Dart `_maxBackupCountOptions` / `_maxBackupAgeOptions`。 */
    val MAX_BACKUP_COUNT_OPTIONS: List<Int> = listOf(5, 10, 15, 20, 30)
    val MAX_BACKUP_AGE_OPTIONS: List<Int> = listOf(7, 14, 30, 60, 90)

    /** 备份区预览条数上限（Dart `_backupEntries.take(3)`）。 */
    const val BACKUP_PREVIEW_LIMIT = 3

    /** Dart `_isAccountConnected`：用户名 trim 非空 **且** 本机存有密码。 */
    fun isAccountConnected(username: String, hasStoredPassword: Boolean): Boolean =
        username.trim().isNotEmpty() && hasStoredPassword

    fun providerLabel(provider: WebdavSyncProvider): String = when (provider) {
        WebdavSyncProvider.JIANGUOYUN -> SyncStrings.cloudSyncProviderJianguoyun.zh
        WebdavSyncProvider.CUSTOM -> SyncStrings.cloudSyncProviderCustom.zh
    }

    fun modeLabel(mode: WebdavSyncMode): String = when (mode) {
        WebdavSyncMode.AUTO -> SyncStrings.cloudSyncModeAuto.zh
        WebdavSyncMode.MANUAL -> SyncStrings.cloudSyncModeManual.zh
    }

    /**
     * 选项顺序钉死为 Dart 页面里的书写顺序（不是枚举声明顺序）。
     *
     * 枚举 `WebdavSyncMode` 声明是 MANUAL→AUTO（Phase 2 沿用 Dart 值顺序），
     * 而屏上「自动同步 / 手动同步」是 AUTO 在前；下标必须按**展示顺序**算，
     * 否则下拉会显示错的那一项。
     */
    val PROVIDER_ORDER: List<WebdavSyncProvider> =
        listOf(WebdavSyncProvider.JIANGUOYUN, WebdavSyncProvider.CUSTOM)

    val MODE_ORDER: List<WebdavSyncMode> = listOf(WebdavSyncMode.AUTO, WebdavSyncMode.MANUAL)

    fun providerLabels(): List<String> = PROVIDER_ORDER.map { providerLabel(it) }

    fun modeLabels(): List<String> = MODE_ORDER.map { modeLabel(it) }

    fun providerIndexOf(provider: WebdavSyncProvider): Int =
        PROVIDER_ORDER.indexOf(provider).coerceAtLeast(0)

    fun modeIndexOf(mode: WebdavSyncMode): Int = MODE_ORDER.indexOf(mode).coerceAtLeast(0)

    fun maxCountOptionLabels(): List<String> =
        MAX_BACKUP_COUNT_OPTIONS.map { SyncStrings.cloudBackupMaxCountOption.filled("count", it.toString()) }

    fun maxAgeOptionLabels(): List<String> =
        MAX_BACKUP_AGE_OPTIONS.map { SyncStrings.cloudBackupMaxAgeOption.filled("days", it.toString()) }

    /** `yyyy-MM-dd HH:mm`；null → "-"（Dart `_formatDateTime`）。 */
    fun formatDateTimeOrDash(iso: String?, zone: ZoneId = ZoneId.systemDefault()): String {
        val millis = parseIsoMillis(iso, zone) ?: return "-"
        return CloudBackupListLogic.formatBackupDateTime(millis, zone)
    }

    fun buildStatusView(
        status: CloudSyncStatusSource,
        zone: ZoneId = ZoneId.systemDefault(),
    ): CloudSyncStatusView = CloudSyncStatusView(
        lastSyncedAtText = formatDateTimeOrDash(status.lastSyncedAtIso, zone),
        isSyncing = status.isSyncing,
        lastErrorText = status.lastErrorCode?.let { SyncStrings.localizeSyncError(it) },
    )

    /**
     * baseUrl 闸门（Dart `_confirmBaseUrl`）。
     *
     * 空串先回落坚果云默认 https 地址，再按 scheme 分级：https 放行、http 需二次确认、
     * 其余非法。返回值里的 [BaseUrlResolution.resolvedUrl] 就是确认后可直接落盘/发请求的地址。
     */
    fun resolveBaseUrl(raw: String): BaseUrlResolution {
        val trimmed = raw.trim()
        val resolved = trimmed.ifEmpty { WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL }
        return when (inspectWebdavBaseUrlScheme(resolved)) {
            WebdavBaseUrlScheme.HTTPS -> BaseUrlResolution(BaseUrlVerdict.PROCEED, resolved)
            WebdavBaseUrlScheme.INSECURE_HTTP -> BaseUrlResolution(BaseUrlVerdict.NEED_HTTP_CONFIRM, resolved)
            WebdavBaseUrlScheme.INVALID -> BaseUrlResolution(BaseUrlVerdict.INVALID, null)
        }
    }

    /** 远程目录为空回落默认值，否则保留输入（Dart `_saveAdvancedFields` 的 trim 口径）。 */
    fun resolveRemoteFolder(raw: String): String =
        raw.trim().ifEmpty { WebdavSyncConfig.DEFAULT_REMOTE_FOLDER }

    /** 连接成功后落盘的配置：写入用户名并启用同步（Dart `_openConnectSheet`）。 */
    fun buildConnectConfig(config: WebdavSyncConfig, username: String): WebdavSyncConfig =
        config.copyWith(username = username.trim(), enabled = true)

    /**
     * 断开账号（Dart `_disconnectAccount`）：清用户名、关开关、清两个哈希与上次同步时间。
     *
     * 顺序上 Dart 先落配置再尽力删凭据，所以这里只表达「配置怎么变」——
     * 凭据删除失败不影响「已断开」的语义。
     */
    fun buildDisconnectConfig(config: WebdavSyncConfig): WebdavSyncConfig = config.copyWith(
        username = "",
        enabled = false,
        clearLastAppliedRemoteHash = true,
        clearLastUploadedLocalHash = true,
        clearLastSyncedAt = true,
    )

    /**
     * 切提供商（Dart `_applyProviderSelection`）。
     *
     * 切回坚果云强制默认 https 地址、不需要确认；切到自定义沿用调用方已确认过的地址。
     */
    fun buildProviderChangeConfig(
        config: WebdavSyncConfig,
        provider: WebdavSyncProvider,
        confirmedBaseUrl: String?,
    ): WebdavSyncConfig = if (provider == WebdavSyncProvider.JIANGUOYUN) {
        config.copyWith(
            provider = provider,
            baseUrl = WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL,
        )
    } else {
        config.copyWith(
            provider = provider,
            baseUrl = confirmedBaseUrl ?: config.baseUrl,
        )
    }

    /** 高级设置保存（Dart `_saveAdvancedFields`）。 */
    fun buildAdvancedConfig(
        config: WebdavSyncConfig,
        confirmedBaseUrl: String,
        rawRemoteFolder: String,
    ): WebdavSyncConfig = config.copyWith(
        baseUrl = confirmedBaseUrl,
        remoteFolder = resolveRemoteFolder(rawRemoteFolder),
    )

    /** 同步冲突弹框；首次同步分歧换解释性文案（Dart `_resolveConflict`）。 */
    fun conflictDialog(isFirstSyncDivergence: Boolean): SyncConflictDialogView =
        SyncConflictDialogView(
            title = if (isFirstSyncDivergence) {
                SyncStrings.cloudSyncConflictFirstSyncTitle.zh
            } else {
                SyncStrings.cloudSyncConflictTitle.zh
            },
            message = if (isFirstSyncDivergence) {
                SyncStrings.cloudSyncConflictFirstSyncBody.zh
            } else {
                SyncStrings.cloudSyncConflictBody.zh
            },
            cancelLabel = SyncStrings.cancelAction.zh,
            useRemoteLabel = SyncStrings.cloudSyncUseRemoteAction.zh,
            keepLocalLabel = SyncStrings.cloudSyncKeepLocalAction.zh,
        )

    /** 备份区预览（前 [BACKUP_PREVIEW_LIMIT] 条，倒序由 [CloudBackupListLogic] 保证）。 */
    fun backupPreviewRows(
        entries: List<CloudBackupEntryModel>,
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<CloudBackupRowView> =
        CloudBackupListLogic.sortByExportedAtDesc(entries, zone)
            .take(BACKUP_PREVIEW_LIMIT)
            .map { CloudBackupListLogic.buildRow(it, zone) }

    fun optionIndexOf(options: List<Int>, value: Int): Int =
        options.indexOf(value).takeIf { it >= 0 } ?: 0

    /**
     * 整页 viewState。
     *
     * @param backupEntries 全量备份条目（未排序也可，这里会按导出时间倒序再取前 3 条）。
     * @param isLoading 首屏配置读取中。
     */
    @Suppress("LongParameterList")
    fun buildViewState(
        config: WebdavSyncConfig,
        hasStoredPassword: Boolean,
        status: CloudSyncStatusSource,
        isCreatingBackup: Boolean,
        loadingBackups: Boolean,
        backupEntries: List<CloudBackupEntryModel>,
        isLoading: Boolean,
        deviceLabel: String,
        zone: ZoneId = ZoneId.systemDefault(),
        canUndoRestore: Boolean = false,
    ): CloudSyncViewState {
        val connected = isAccountConnected(config.username, hasStoredPassword)
        val statusView = buildStatusView(status, zone)
        val sorted = CloudBackupListLogic.sortByExportedAtDesc(backupEntries, zone)
        val previewRows = sorted.take(BACKUP_PREVIEW_LIMIT).map { CloudBackupListLogic.buildRow(it, zone) }

        // 未连接时整段业务区都不出现；已连接但同步关掉时，设置区仍在（可以重新打开）。
        val showBusinessSections = connected && config.enabled

        return CloudSyncViewState(
            isLoading = isLoading,
            account = CloudSyncAccountView(
                connected = connected,
                title = if (connected) {
                    SyncStrings.cloudSyncConnectedAs.filled("email", config.username.trim())
                } else {
                    SyncStrings.cloudSyncConnectAccount.zh
                },
                subtitle = if (connected) providerLabel(config.provider) else SyncStrings.cloudSyncNotConnectedHint.zh,
                username = config.username.trim(),
            ),
            status = statusView,
            accountSectionTitle = SyncStrings.cloudSyncAccountSectionTitle.zh,
            connectActionLabel = SyncStrings.cloudSyncConnectAccount.zh,
            disconnectActionLabel = SyncStrings.cloudSyncDisconnect.zh,
            disconnectTitle = SyncStrings.cloudSyncDisconnectTitle.zh,
            disconnectBody = SyncStrings.cloudSyncDisconnectBody.zh,
            title = SyncStrings.cloudSyncTitle.zh,
            introTitle = SyncStrings.cloudSyncIntroTitle.zh,
            introSubtitle = SyncStrings.cloudSyncIntroSubtitle.zh,
            helpTitle = SyncStrings.cloudSyncHelpTitle.zh,
            helpBody = SyncStrings.cloudSyncHelpBody.zh,
            showSyncSettings = connected,
            settingsSectionTitle = SyncStrings.cloudSyncSettingsSectionTitle.zh,
            syncEnabledTitle = SyncStrings.cloudSyncEnabledTitle.zh,
            syncEnabled = config.enabled,
            providerTitle = SyncStrings.cloudSyncProviderTitle.zh,
            providerLabels = providerLabels(),
            providerIndex = providerIndexOf(config.provider),
            modeTitle = SyncStrings.cloudSyncModeTitle.zh,
            modeLabels = modeLabels(),
            modeIndex = modeIndexOf(config.syncMode),
            advancedTitle = SyncStrings.cloudSyncAdvancedTitle.zh,
            baseUrlLabel = SyncStrings.cloudSyncBaseUrlLabel.zh,
            baseUrl = config.baseUrl,
            remoteFolderLabel = SyncStrings.cloudSyncRemoteFolderLabel.zh,
            remoteFolder = config.remoteFolder,
            deviceLabelTitle = SyncStrings.cloudBackupDeviceLabelTitle.zh,
            deviceLabelHint = SyncStrings.cloudBackupDeviceLabelHint.zh,
            deviceLabel = deviceLabel,
            baseUrlInvalidMessage = SyncStrings.cloudSyncBaseUrlInvalid.zh,
            httpConfirmTitle = SyncStrings.cloudSyncHttpConfirmTitle.zh,
            httpConfirmMessage = SyncStrings.cloudSyncHttpConfirmMessage.zh,
            httpConfirmProceedLabel = SyncStrings.cloudSyncHttpConfirmProceed.zh,
            showStatus = connected,
            statusSectionTitle = SyncStrings.cloudSyncStatusTitle.zh,
            lastSyncedLabel = SyncStrings.cloudSyncLastSyncedLabel.zh,
            lastErrorLabel = SyncStrings.cloudSyncLastErrorLabel.zh,
            syncingLabel = SyncStrings.cloudSyncSyncing.zh,
            showSyncNow = showBusinessSections,
            syncNowButton = CloudSyncButtonView(
                label = SyncStrings.cloudSyncSyncNow.zh,
                loading = status.isSyncing,
                enabled = !status.isSyncing && config.enabled,
            ),
            showBackups = showBusinessSections,
            backupSectionTitle = SyncStrings.cloudBackupSectionTitle.zh,
            createBackupButton = CloudSyncButtonView(
                label = SyncStrings.cloudBackupCreateNow.zh,
                loading = isCreatingBackup,
                // Dart: onPressed: _creatingBackup || _syncing ? null : _createManualBackup
                enabled = !isCreatingBackup && !status.isSyncing,
            ),
            loadingBackups = loadingBackups,
            backupRows = previewRows,
            hasMoreBackups = sorted.size > BACKUP_PREVIEW_LIMIT,
            viewAllLabel = SyncStrings.cloudBackupViewAll.zh,
            emptyBackupText = SyncStrings.cloudBackupEmpty.zh,
            showRetention = showBusinessSections,
            retentionSectionTitle = SyncStrings.cloudBackupRetentionTitle.zh,
            maxCountTitle = SyncStrings.cloudBackupMaxCountTitle.zh,
            maxCountSubtitle = SyncStrings.cloudBackupMaxCountSubtitle.zh,
            maxCountOptionLabels = maxCountOptionLabels(),
            maxCountSelectedIndex = optionIndexOf(MAX_BACKUP_COUNT_OPTIONS, config.maxBackupCount),
            maxAgeTitle = SyncStrings.cloudBackupMaxAgeTitle.zh,
            maxAgeSubtitle = SyncStrings.cloudBackupMaxAgeSubtitle.zh,
            maxAgeOptionLabels = maxAgeOptionLabels(),
            maxAgeSelectedIndex = optionIndexOf(MAX_BACKUP_AGE_OPTIONS, config.maxBackupAgeDays),
            manualProtectedTitle = SyncStrings.cloudBackupManualProtectedTitle.zh,
            manualBackupProtected = config.manualBackupProtected,
            // 恢复入口就在备份区里：业务区整段不出现时（未连接 / 同步关闭），撤销也不该出现。
            canUndoRestore = canUndoRestore && showBusinessSections,
            undoRestoreTitle = SyncStrings.cloudBackupUndoRestoreTitle.zh,
            undoRestoreSummary = SyncStrings.cloudBackupUndoRestoreSummary.zh,
            undoRestoreActionLabel = SyncStrings.themeUndo.zh,
        )
    }

    private fun parseIsoMillis(raw: String?, zone: ZoneId): Long? {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return null
        runCatching { return OffsetDateTime.parse(text).toInstant().toEpochMilli() }
        runCatching {
            return LocalDateTime.parse(text).atZone(zone).toInstant().toEpochMilli()
        }
        return runCatching { Instant.parse(text).toEpochMilli() }.getOrNull()
    }
}
