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

    /**
     * 高级设置保存的 verdict → 页面提示（2026-11-05 云同步反馈修复①）。
     *
     * - INVALID → 「地址非法」错误提示（页面弹胶囊）；
     * - NEED_HTTP_CONFIRM → null：走明文二次确认框（不是 toast）；
     * - PROCEED → 「已保存」成功提示（2026-11-06 ARB 批：键 `cloudSyncSaved` 放闸补上；
     *   发布版 `_saveConfig` 本就静默，这里按 Chief 裁决比发布版多一步成功反馈）。
     *
     * 单测钉住三档映射：把这里的分支删掉（探针）→ [CloudSyncModelTest] 必红。
     */
    fun advancedSaveFeedback(verdict: BaseUrlVerdict): SyncToast? = when (verdict) {
        BaseUrlVerdict.INVALID -> SyncResultToasts.forBaseUrlInvalid()
        BaseUrlVerdict.NEED_HTTP_CONFIRM -> null
        BaseUrlVerdict.PROCEED -> SyncToast(message = SyncStrings.cloudSyncSaved.text, isError = false)
    }

    /**
     * 高级设置**落盘失败**的页面提示（2026-11-06 ARB 批）：`commitOrThrow` 的
     * IOException 等被 runCatching 兜住后不再静默——弹「保存失败」错误胶囊。
     * 文案**复用 ARB 既有通用键 `saveFailed`**（发布版全仓库的同一句），不新增重复键。
     *
     * 单测钉住键引用：把这里的 `saveFailed` 换掉（探针）→ [SyncResultToastsTest] 必红。
     */
    fun advancedSaveFailureFeedback(): SyncToast =
        SyncToast(message = SyncStrings.saveFailed.text, isError = true)

    /**
     * 连接成功的页面提示（A 类第 16 条，2026-11-05）：发布版连接成功后
     * `showAppToast`（cloud_sync_screen.dart:271-273），此前 Kotlin 侧连接成功只关弹层
     * 静默、`cloudSyncConnectSuccess` 键零消费。成功态（非 error）、无动作位。
     *
     * 消费点在页面（CloudSyncControllerPage）：壳层弹层负责调 `controller.connect`，
     * 页面观察 `account.connected` 的「未连接 → 已连接」翻转弹胶囊——页面不重复调
     * connect，也不经 ShellPageIndex 传回调（那是别的成员的文件）。
     *
     * 单测钉住键引用：把这里的 `cloudSyncConnectSuccess` 换掉（探针）→
     * [SyncResultToastsTest] 必红。
     */
    fun connectSuccessFeedback(): SyncToast =
        SyncToast(message = SyncStrings.cloudSyncConnectSuccess.text, isError = false)


    /** Dart `_maxBackupCountOptions` / `_maxBackupAgeOptions`。 */
    val MAX_BACKUP_COUNT_OPTIONS: List<Int> = listOf(5, 10, 15, 20, 30)
    val MAX_BACKUP_AGE_OPTIONS: List<Int> = listOf(7, 14, 30, 60, 90)

    /** 备份区预览条数上限（Dart `_backupEntries.take(3)`）。 */
    const val BACKUP_PREVIEW_LIMIT = 3

    /** Dart `_isAccountConnected`：用户名 trim 非空 **且** 本机存有密码。 */
    fun isAccountConnected(username: String, hasStoredPassword: Boolean): Boolean =
        username.trim().isNotEmpty() && hasStoredPassword

    // ── 升级后一次性提示：请重输网盘密码 ──

    /** 云同步一次性标记（`KeyValueStore` 契约键，落盘自动带 `flutter.` 前缀）。 */
    const val LEGACY_REPROMPT_MARK_CLOUD = "webdav_password_legacy_reprompt_v1"

    /** 情侣 WebDAV 一次性标记（与云同步分开，两条线互不影响）。 */
    const val LEGACY_REPROMPT_MARK_COUPLE = "couple_webdav_password_legacy_reprompt_v1"

    /** 旧插件 prefs 键名后缀（只做后缀匹配，不拼插件私有前缀）。 */
    const val LEGACY_KEY_SUFFIX_CLOUD = "webdav_sync_password"
    const val LEGACY_KEY_SUFFIX_COUPLE = "couple_webdav_password"

    /**
     * 是否应弹「升级后请重输网盘密码」：三条**同时**成立才提示。
     *
     * 1. 新版密文键里没有密码（`hasStoredPassword == false`）；
     * 2. 旧 Dart 插件 prefs 里确有对应旧键（`hasLegacyDartCredential == true`）；
     * 3. 一次性标记没写过（`alreadyPrompted == false`）。
     *
     * 纯函数：探测/读标记都在调用方，便于 JVM 真值表对拍。
     */
    fun shouldPromptLegacyPasswordReentry(
        hasStoredPassword: Boolean,
        hasLegacyDartCredential: Boolean,
        alreadyPrompted: Boolean,
    ): Boolean = !hasStoredPassword && hasLegacyDartCredential && !alreadyPrompted

    /**
     * 页面入口的一次性取数：探测旧键 + 读标记，判定为「该提示」时**立刻写标记**，
     * 返回本次是否应显示。写标记失败（`IOException` 等）仍返回 true——宁可下次重复，
     * 不能本次漏掉用户真正需要的提示。
     *
     * 探测/读/写都以函数注入，避免页面层把 Android 的
     * [com.mutx163.qingyu.platform.AndroidLegacyCredentialProbe] 类型带进 L0 classpath；
     * 也方便单测注入计数假实现，验证「有密码时不探测」「只探测一次」。
     */
    fun takeLegacyPasswordReentryPrompt(
        hasStoredPassword: Boolean,
        legacyKeySuffix: String,
        alreadyPrompted: () -> Boolean,
        hasLegacyDartCredential: (String) -> Boolean,
        markPrompted: () -> Unit,
    ): Boolean {
        // 新版已有密码：正常升级路径，不探测、不提示。
        if (hasStoredPassword) return false
        // 已提示过：先读标记再探测，第二次进入同一条线不再碰 prefs 键集合。
        val prompted = runCatching { alreadyPrompted() }.getOrDefault(false)
        if (!shouldPromptLegacyPasswordReentry(false, true, prompted)) return false
        val legacy = runCatching { hasLegacyDartCredential(legacyKeySuffix) }.getOrDefault(false)
        if (!shouldPromptLegacyPasswordReentry(false, legacy, false)) return false
        runCatching { markPrompted() }
        return true
    }

    fun providerLabel(provider: WebdavSyncProvider): String = when (provider) {
        WebdavSyncProvider.JIANGUOYUN -> SyncStrings.cloudSyncProviderJianguoyun.text
        WebdavSyncProvider.CUSTOM -> SyncStrings.cloudSyncProviderCustom.text
    }

    fun modeLabel(mode: WebdavSyncMode): String = when (mode) {
        WebdavSyncMode.AUTO -> SyncStrings.cloudSyncModeAuto.text
        WebdavSyncMode.MANUAL -> SyncStrings.cloudSyncModeManual.text
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
                SyncStrings.cloudSyncConflictFirstSyncTitle.text
            } else {
                SyncStrings.cloudSyncConflictTitle.text
            },
            message = if (isFirstSyncDivergence) {
                SyncStrings.cloudSyncConflictFirstSyncBody.text
            } else {
                SyncStrings.cloudSyncConflictBody.text
            },
            cancelLabel = SyncStrings.cancelAction.text,
            useRemoteLabel = SyncStrings.cloudSyncUseRemoteAction.text,
            keepLocalLabel = SyncStrings.cloudSyncKeepLocalAction.text,
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
                    SyncStrings.cloudSyncConnectAccount.text
                },
                subtitle = if (connected) providerLabel(config.provider) else SyncStrings.cloudSyncNotConnectedHint.text,
                username = config.username.trim(),
            ),
            status = statusView,
            accountSectionTitle = SyncStrings.cloudSyncAccountSectionTitle.text,
            connectActionLabel = SyncStrings.cloudSyncConnectAccount.text,
            disconnectActionLabel = SyncStrings.cloudSyncDisconnect.text,
            disconnectTitle = SyncStrings.cloudSyncDisconnectTitle.text,
            disconnectBody = SyncStrings.cloudSyncDisconnectBody.text,
            title = SyncStrings.cloudSyncTitle.text,
            introTitle = SyncStrings.cloudSyncIntroTitle.text,
            introSubtitle = SyncStrings.cloudSyncIntroSubtitle.text,
            helpTitle = SyncStrings.cloudSyncHelpTitle.text,
            helpBody = SyncStrings.cloudSyncHelpBody.text,
            showSyncSettings = connected,
            settingsSectionTitle = SyncStrings.cloudSyncSettingsSectionTitle.text,
            syncEnabledTitle = SyncStrings.cloudSyncEnabledTitle.text,
            syncEnabled = config.enabled,
            providerTitle = SyncStrings.cloudSyncProviderTitle.text,
            providerLabels = providerLabels(),
            providerIndex = providerIndexOf(config.provider),
            modeTitle = SyncStrings.cloudSyncModeTitle.text,
            modeLabels = modeLabels(),
            modeIndex = modeIndexOf(config.syncMode),
            advancedTitle = SyncStrings.cloudSyncAdvancedTitle.text,
            baseUrlLabel = SyncStrings.cloudSyncBaseUrlLabel.text,
            baseUrl = config.baseUrl,
            remoteFolderLabel = SyncStrings.cloudSyncRemoteFolderLabel.text,
            remoteFolder = config.remoteFolder,
            deviceLabelTitle = SyncStrings.cloudBackupDeviceLabelTitle.text,
            deviceLabelHint = SyncStrings.cloudBackupDeviceLabelHint.text,
            deviceLabel = deviceLabel,
            baseUrlInvalidMessage = SyncStrings.cloudSyncBaseUrlInvalid.text,
            httpConfirmTitle = SyncStrings.cloudSyncHttpConfirmTitle.text,
            httpConfirmMessage = SyncStrings.cloudSyncHttpConfirmMessage.text,
            httpConfirmProceedLabel = SyncStrings.cloudSyncHttpConfirmProceed.text,
            showStatus = connected,
            statusSectionTitle = SyncStrings.cloudSyncStatusTitle.text,
            lastSyncedLabel = SyncStrings.cloudSyncLastSyncedLabel.text,
            lastErrorLabel = SyncStrings.cloudSyncLastErrorLabel.text,
            syncingLabel = SyncStrings.cloudSyncSyncing.text,
            showSyncNow = showBusinessSections,
            syncNowButton = CloudSyncButtonView(
                label = SyncStrings.cloudSyncSyncNow.text,
                loading = status.isSyncing,
                enabled = !status.isSyncing && config.enabled,
            ),
            showBackups = showBusinessSections,
            backupSectionTitle = SyncStrings.cloudBackupSectionTitle.text,
            createBackupButton = CloudSyncButtonView(
                label = SyncStrings.cloudBackupCreateNow.text,
                loading = isCreatingBackup,
                // Dart: onPressed: _creatingBackup || _syncing ? null : _createManualBackup
                enabled = !isCreatingBackup && !status.isSyncing,
            ),
            loadingBackups = loadingBackups,
            backupRows = previewRows,
            hasMoreBackups = sorted.size > BACKUP_PREVIEW_LIMIT,
            viewAllLabel = SyncStrings.cloudBackupViewAll.text,
            emptyBackupText = SyncStrings.cloudBackupEmpty.text,
            showRetention = showBusinessSections,
            retentionSectionTitle = SyncStrings.cloudBackupRetentionTitle.text,
            maxCountTitle = SyncStrings.cloudBackupMaxCountTitle.text,
            maxCountSubtitle = SyncStrings.cloudBackupMaxCountSubtitle.text,
            maxCountOptionLabels = maxCountOptionLabels(),
            maxCountSelectedIndex = optionIndexOf(MAX_BACKUP_COUNT_OPTIONS, config.maxBackupCount),
            maxAgeTitle = SyncStrings.cloudBackupMaxAgeTitle.text,
            maxAgeSubtitle = SyncStrings.cloudBackupMaxAgeSubtitle.text,
            maxAgeOptionLabels = maxAgeOptionLabels(),
            maxAgeSelectedIndex = optionIndexOf(MAX_BACKUP_AGE_OPTIONS, config.maxBackupAgeDays),
            manualProtectedTitle = SyncStrings.cloudBackupManualProtectedTitle.text,
            manualBackupProtected = config.manualBackupProtected,
            // 恢复入口就在备份区里：业务区整段不出现时（未连接 / 同步关闭），撤销也不该出现。
            canUndoRestore = canUndoRestore && showBusinessSections,
            undoRestoreTitle = SyncStrings.cloudBackupUndoRestoreTitle.text,
            undoRestoreSummary = SyncStrings.cloudBackupUndoRestoreSummary.text,
            undoRestoreActionLabel = SyncStrings.themeUndo.text,
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
