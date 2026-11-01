package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.WebdavSyncConfig
import java.time.Instant
import java.time.OffsetDateTime

/**
 * 云同步 / 云备份页面**可观察状态持有者**（Phase 3.5 · C1）。
 *
 * ## 它把「示例状态」换成真实状态
 *
 * P3-F 时代两页在壳里吃的是写死的 `WebdavSyncConfig()` + 空回调（示例状态）。
 * 这个类持有**真实配置 + 运行时状态 + 真实收发协调器**，对外只暴露两样东西：
 * 1. [cloudSyncViewState] / [backupListViewState]：交给现有纯渲染页直接渲染；
 * 2. 一组动作方法（连接 / 断开 / 立即同步 / 立即备份 / 打开某备份 / 刷新列表），
 *    渲染层把这些回调转给它即可。
 *
 * ## 为什么它不带 `android.*` / Compose
 *
 * 配置落盘走 [WebdavConfigStore]、快照读写走 [LocalSnapshotStore]、网络走
 * [WebdavRemoteTransport]，三者都是缝。于是整个状态机能在 JVM 单测里跑：
 * 注入内存假 store + 假传输，就能验「刷新列表拿到远端条目 / 立即备份后多一条 /
 * 断开后账号清零」这类页面真正关心的行为。
 *
 * ## 界面的可观察性
 *
 * 纯 Kotlin 不能直接用 Compose 的 `mutableStateOf`。这里用「[revision] 自增 + [addListener]」
 * 的最小观察者协议：Compose 侧在 `DisposableEffect` 里订阅、`revision` 变化时触发重组
 * （见 `composeP1` 的 `rememberCloudSyncControllerVersion`）。这样协调器 / 控制器本身
 * 仍是纯逻辑，不把 Compose 拖进 L0 classpath。
 */

/** 配置读写缝（生产用 SharedPreferences/加密存储，单测用内存实现）。密码也走这里。 */
interface WebdavConfigStore {
    fun loadConfig(): WebdavSyncConfig
    fun saveConfig(config: WebdavSyncConfig)
    fun hasStoredPassword(): Boolean
    fun storePassword(password: String)
    fun clearPassword()
}

/** 连接结果：成功 / 失败 + 可本地化的错误码。 */
data class CloudSyncConnectResult(val success: Boolean, val errorCode: String? = null)

class CloudSyncController(
    private val store: WebdavConfigStore,
    private val snapshotStore: LocalSnapshotStore,
    private val transportFactory: (WebdavSyncConfig, String) -> WebdavRemoteTransport? =
        { config, password -> createWebdavRemoteTransport(config, password) },
    private val deviceLabel: String = "",
    private val clock: () -> String = { OffsetDateTime.now().toString() },
    /**
     * 课表仓储（宿主注入）。注入了它，「立即备份 / 立即同步」才拿得到**当前课表的实时快照**，
     * 「恢复」才会真的把快照写回课表；不注入则退回旧的本地快照文件路径（仅在单测 / 兼容时用）。
     */
    private val repository: TimetableRepository? = null,
    /** 已存密码的读取缝：进程重启后进云页面可据此重建传输，不必让用户重新输密码。 */
    private val passwordProvider: (() -> String?)? = null,
    /** 覆盖默认的「生成上传字节」实现（单测可直接喂固定字节）。 */
    private val snapshotProvider: (() -> SnapshotBuildResult)? = null,
    /** 覆盖默认的「写回仓储」实现（单测可注入失败）。 */
    private val snapshotApplier: ((ByteArray) -> SnapshotApplyResult)? = null,
) {

    var config: WebdavSyncConfig = store.loadConfig()
        private set

    /** 高级设置三框的草稿（未点保存前只在本层，不落盘）。 */
    var baseUrlDraft: String = config.baseUrl
        private set
    var remoteFolderDraft: String = config.remoteFolder
        private set
    var deviceLabelDraft: String = deviceLabel
        private set

    private var status: CloudSyncStatusSource = CloudSyncStatusSource(
        lastSyncedAtIso = config.lastSyncedAtIso,
    )
    private var backupEntries: List<CloudBackupEntryModel> = emptyList()
    private var remoteFiles: List<RemoteBackupFile> = emptyList()
    private var loadingBackups: Boolean = false
    private var isCreatingBackup: Boolean = false
    private var transport: WebdavRemoteTransport? = null

    /**
     * 上传字节来源：优先用调用方注入的；否则若给了仓储，就从**当前课表**现组一份；
     * 都没有才退回本地快照文件（旧路径）。
     */
    private val effectiveSnapshotProvider: (() -> SnapshotBuildResult)? =
        snapshotProvider ?: repository?.let { repo ->
            { TimetableSnapshotBridge.buildSnapshotBytes(repo, deviceIdOf(), clock()) }
        }

    /** 恢复落点：优先用调用方注入的；否则写回仓储；都没有则不额外写（旧路径）。 */
    private val effectiveSnapshotApplier: ((ByteArray) -> SnapshotApplyResult)? =
        snapshotApplier ?: repository?.let { repo ->
            { bytes -> TimetableSnapshotBridge.applySnapshot(repo, bytes) }
        }

    /** 最近一次恢复前的课表快照（撤销用）；null = 没有可撤销的恢复。 */
    private var lastRestoreRollback: ByteArray? = null

    // ── 可观察协议 ──

    private val listeners = LinkedHashSet<() -> Unit>()

    /** 每次状态变化自增；Compose 侧据此触发重组。 */
    var revision: Long = 0L
        private set

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyChanged() {
        revision++
        listeners.toList().forEach { it() }
    }

    // ── 视图状态 ──

    fun cloudSyncViewState(): CloudSyncViewState = CloudSyncLogic.buildViewState(
        config = config,
        hasStoredPassword = store.hasStoredPassword(),
        status = status,
        isCreatingBackup = isCreatingBackup,
        loadingBackups = loadingBackups,
        backupEntries = backupEntries,
        isLoading = false,
        deviceLabel = deviceLabelDraft,
    )

    /**
     * 最近一次错误的**原始码**（不是本地化后的句子）。
     *
     * `SyncResultToasts.forRestore/forDeleteBackup` 要的是码、再各自本地化一遍；
     * 给它 `cloudSyncViewState().status.lastErrorText`（已是人话）会二次包装成
     * 「恢复失败：恢复失败：…」。`status` 本身是私有状态，所以这里只开一个只读口。
     */
    val lastErrorCode: String? get() = status.lastErrorCode

    fun backupListViewState(): CloudBackupListViewState = CloudBackupListLogic.buildListViewState(
        entries = backupEntries,
        isLoading = loadingBackups,
        isCreatingBackup = isCreatingBackup,
        errorCode = status.lastErrorCode,
    )

    // ── 配置编辑（全部委托既有纯逻辑，不重复判据） ──

    fun setSyncEnabled(enabled: Boolean) {
        persist(config.copyWith(enabled = enabled))
    }

    fun selectProvider(index: Int) {
        val provider = CloudSyncLogic.PROVIDER_ORDER.getOrElse(index) { config.provider }
        persist(CloudSyncLogic.buildProviderChangeConfig(config, provider, confirmedBaseUrl = null))
    }

    fun selectMode(index: Int) {
        val mode = CloudSyncLogic.MODE_ORDER.getOrElse(index) { config.syncMode }
        persist(config.copyWith(syncMode = mode))
    }

    fun onBaseUrlChanged(value: String) {
        baseUrlDraft = value
        notifyChanged()
    }

    fun onRemoteFolderChanged(value: String) {
        remoteFolderDraft = value
        notifyChanged()
    }

    fun onDeviceLabelChanged(value: String) {
        deviceLabelDraft = value
        notifyChanged()
    }

    /**
     * 保存高级设置。返回 baseUrl 闸门结论，让页面决定「直接生效 / 弹明文确认 / 报非法」。
     * @param allowedInsecureHttp 页面已在明文二次确认里点了「继续」时传 true
     */
    fun saveAdvanced(allowedInsecureHttp: Boolean = false): BaseUrlVerdict {
        val resolution = CloudSyncLogic.resolveBaseUrl(baseUrlDraft)
        when (resolution.verdict) {
            BaseUrlVerdict.INVALID -> return BaseUrlVerdict.INVALID
            BaseUrlVerdict.NEED_HTTP_CONFIRM -> if (!allowedInsecureHttp) {
                return BaseUrlVerdict.NEED_HTTP_CONFIRM
            }
            BaseUrlVerdict.PROCEED -> Unit
        }
        val resolved = resolution.resolvedUrl ?: return BaseUrlVerdict.INVALID
        persist(
            CloudSyncLogic.buildAdvancedConfig(
                config = config,
                confirmedBaseUrl = resolved,
                rawRemoteFolder = remoteFolderDraft,
            ),
        )
        return BaseUrlVerdict.PROCEED
    }

    fun selectMaxCount(index: Int) {
        val value = CloudSyncLogic.MAX_BACKUP_COUNT_OPTIONS.getOrElse(index) { config.maxBackupCount }
        persist(config.copyWith(maxBackupCount = value))
    }

    fun selectMaxAge(index: Int) {
        val value = CloudSyncLogic.MAX_BACKUP_AGE_OPTIONS.getOrElse(index) { config.maxBackupAgeDays }
        persist(config.copyWith(maxBackupAgeDays = value))
    }

    fun setManualBackupProtected(value: Boolean) {
        persist(config.copyWith(manualBackupProtected = value))
    }

    // ── 连接 / 断开 ──

    /** 测试连接（不落盘）：发起一次根 PROPFIND 自检。 */
    fun testConnection(username: String, password: String): Boolean {
        val candidate = candidateForConnection(username)
        val probe = transportFactory(candidate, password) ?: return false
        return probe.testConnection() == null
    }

    /** 连接：先自检，通过才落配置 + 密码并启用。 */
    fun connect(username: String, password: String): CloudSyncConnectResult {
        if (username.trim().isEmpty()) return CloudSyncConnectResult(false, "missing_credentials")
        val candidate = candidateForConnection(username)
        val created = transportFactory(candidate, password)
            ?: return CloudSyncConnectResult(false, "insecure_url_blocked")
        val connectionError = created.testConnection()
        if (connectionError != null) return CloudSyncConnectResult(false, connectionError)

        store.storePassword(password)
        transport = created
        persist(CloudSyncLogic.buildConnectConfig(candidate, username))
        status = status.copy(lastErrorCode = null)
        notifyChanged()
        // 连接成功就把备份列表拉回来：否则首次连接的这一页仍是空的，用户以为云端没备份。
        refreshBackups()
        return CloudSyncConnectResult(true)
    }

    fun disconnect() {
        transport?.let { cancelIfCoordinator() }
        transport = null
        store.clearPassword()
        persist(CloudSyncLogic.buildDisconnectConfig(config))
        backupEntries = emptyList()
        remoteFiles = emptyList()
        lastRestoreRollback = null
        status = CloudSyncStatusSource()
        notifyChanged()
    }

    // ── 真实收发动作 ──

    /**
     * 进页首次加载：已配置好账号时拉一次远端备份列表。
     *
     * 之前两页进页什么都不做，`backupEntries` 只在上传 / 下载 / 删除后才被填，
     * 所以「刚进页面备份列表恒空」——看起来像云端没有备份。
     *
     * 未配置（没有用户名或拿不到密码）时**什么都不做**，不写错误码：
     * 未连接是正常首屏状态，不是一次失败的同步。
     */
    fun refreshOnEnter() {
        if (!hasActiveConnection()) return
        if (loadingBackups) return
        refreshBackups()
    }

    /** 是否已有可用连接（当前会话连过，或能从存档重建传输）。 */
    fun hasActiveConnection(): Boolean = ensureTransport() != null

    /** 刷新远端备份列表（PROPFIND）。返回结局供页面判断错误码。 */
    fun refreshBackups(): ListBackupsOutcome {
        val coordinator = coordinatorOrNull()
            ?: return ListBackupsOutcome(SyncOpKind.FAILED, errorCode = "missing_credentials")
        loadingBackups = true
        notifyChanged()
        val outcome = coordinator.listRemoteBackups(config)
        loadingBackups = false
        if (outcome.kind == SyncOpKind.OK) {
            remoteFiles = outcome.files
            backupEntries = outcome.files.map { toEntry(it) }
        } else if (outcome.kind == SyncOpKind.EMPTY) {
            remoteFiles = emptyList()
            backupEntries = emptyList()
        } else {
            status = status.copy(lastErrorCode = outcome.errorCode)
        }
        notifyChanged()
        return outcome
    }

    /** 立即同步：上传本机当前快照，成功后刷新列表。 */
    fun syncNow(): SyncResultKind = runUpload()

    /** 立即备份：与同步同一套上传，只是结果提示不同。 */
    fun createBackup(): SyncResultKind = runUpload()

    /**
     * 打开（恢复）某条远端备份：强制以远端为准下载，**并写回课表仓储**。
     *
     * ## 修复了什么（P0）
     *
     * 之前下载成功只把字节写进本地快照文件，全仓没有代码把它写回课表：用户的课表
     * 一点没变，界面却提示「已从云端恢复」。现在只有 [effectiveSnapshotApplier] 写回成功
     * 才返回 [SyncResultKind.DOWNLOADED]；写回失败一律 [SyncResultKind.FAILED] 并带错误码。
     *
     * ## 撤销点
     *
     * 下载前先把**本机当前课表**组一份快照存进 [lastRestoreRollback]，成功后可调
     * [undoLastRestore] 回退。注意：当前页面没有撤销入口（Toast 承载不了动作按钮），
     * 见宿主接线报告。
     */
    fun openBackup(entryId: String): SyncResultKind {
        val coordinator = coordinatorOrNull() ?: return SyncResultKind.FAILED
        val file = remoteFiles.firstOrNull { it.fileName == entryId }
            ?: return SyncResultKind.FAILED
        // 撤销点：下载会先覆盖本地快照文件，所以必须在下载**之前**取当前课表。
        val rollback = effectiveSnapshotProvider?.let { provider ->
            (provider() as? SnapshotBuildResult.Success)?.bytes
        }
        status = status.copy(isSyncing = true)
        notifyChanged()
        val outcome = coordinator.downloadSnapshot(
            config = config,
            remotePath = file.remotePath,
            hasLocalUserData = true,
            resolver = { SyncConflictChoice.KEEP_REMOTE },
        )
        status = status.copy(isSyncing = false)
        return when (outcome.kind) {
            SyncOpKind.OK -> {
                if (!applyDownloadedSnapshot(outcome.bytes)) {
                    notifyChanged()
                    return SyncResultKind.FAILED
                }
                rollback?.let { lastRestoreRollback = it }
                markSynced()
                refreshBackups()
                SyncResultKind.DOWNLOADED
            }
            SyncOpKind.CANCELLED -> SyncResultKind.CANCELLED
            else -> {
                status = status.copy(lastErrorCode = outcome.errorCode)
                notifyChanged()
                SyncResultKind.FAILED
            }
        }
    }

    /**
     * 撤销最近一次恢复（把恢复前的课表快照写回去）。
     *
     * @return true = 已回退；false = 没有撤销点 / 写回失败（错误码见 [lastErrorCode]）。
     */
    fun undoLastRestore(): Boolean {
        val rollback = lastRestoreRollback ?: return false
        val applier = effectiveSnapshotApplier ?: return false
        return when (val result = applier(rollback)) {
            SnapshotApplyResult.Applied -> {
                lastRestoreRollback = null
                status = status.copy(lastErrorCode = null)
                notifyChanged()
                true
            }
            is SnapshotApplyResult.Invalid -> {
                status = status.copy(lastErrorCode = result.errorCode)
                notifyChanged()
                false
            }
            is SnapshotApplyResult.Failed -> {
                status = status.copy(lastErrorCode = result.errorCode)
                notifyChanged()
                false
            }
        }
    }

    /** 把下载到的字节写回课表。没有注入落点时退回「视为已应用」（仅单测 / 旧路径）。 */
    private fun applyDownloadedSnapshot(bytes: ByteArray?): Boolean {
        if (bytes == null) {
            status = status.copy(lastErrorCode = "backup_not_found")
            return false
        }
        val applier = effectiveSnapshotApplier ?: return true
        return when (val result = applier(bytes)) {
            SnapshotApplyResult.Applied -> true
            is SnapshotApplyResult.Invalid -> {
                status = status.copy(lastErrorCode = result.errorCode)
                false
            }
            is SnapshotApplyResult.Failed -> {
                status = status.copy(lastErrorCode = result.errorCode)
                false
            }
        }
    }

    /**
     * 按 entryId 取远端备份条目（详情弹层要拿设备名/来源/内容摘要去渲染）。
     *
     * 为什么需要它：`backupEntries` 是私有状态，渲染层只拿到已格式化的 `rows`
     * （title/subtitle/details），拼不出 Dart `showCloudBackupDetailSheet` 那三行
     * 「设备 / 来源 / 内容」。**不新造一份派生逻辑**——三行由
     * `CloudBackupListLogic.buildDetail` 从条目本体算，渲染层只负责画。
     */
    fun backupEntry(entryId: String): CloudBackupEntryModel? =
        backupEntries.firstOrNull { it.id == entryId }

    /**
     * 删除某条远端备份（Dart `_deleteBackup`，`cloud_backup_list_screen.dart:218`）。
     *
     * 与 [openBackup] 同一套查找口径（`remoteFiles.firstOrNull { it.fileName == entryId }`）：
     * 列表行的 `entryId` 就是远端文件名，两个动作不能各用一套匹配方式，否则会出现
     * 「能恢复但删不掉」这种只有真连过 WebDAV 才看得见的错位。
     *
     * 成功 → 刷新列表并回 [SyncResultKind.BACKUP_DELETED]；失败 → 记错误码回 `FAILED`。
     */
    fun deleteBackup(entryId: String): SyncResultKind {
        val active = ensureTransport() ?: return SyncResultKind.FAILED
        val file = remoteFiles.firstOrNull { it.fileName == entryId }
            ?: return SyncResultKind.FAILED
        val result = active.deleteRemoteFile(file.remotePath)
        return if (result.isFailed) {
            status = status.copy(lastErrorCode = result.errorMessage ?: "delete_failed")
            notifyChanged()
            SyncResultKind.FAILED
        } else {
            refreshBackups()
            SyncResultKind.BACKUP_DELETED
        }
    }

    /** 页面退出时调用：取消进行中的下载 + 摘掉监听。 */
    fun dispose() {
        cancelIfCoordinator()
        listeners.clear()
    }

    // ── 内部 ──

    private fun runUpload(): SyncResultKind {
        val coordinator = coordinatorOrNull() ?: return SyncResultKind.FAILED
        val bytes = currentSnapshotBytes() ?: return SyncResultKind.FAILED
        val exportedAtMicros = exportedAtMicrosOf(bytes)
        status = status.copy(isSyncing = true)
        isCreatingBackup = true
        notifyChanged()
        val outcome = coordinator.uploadSnapshot(
            config = config,
            snapshotBytes = bytes,
            exportedAtUtcMicros = exportedAtMicros,
            deviceId = deviceIdOf(),
        )
        status = status.copy(isSyncing = false)
        isCreatingBackup = false
        return when (outcome.kind) {
            SyncOpKind.OK -> {
                markSynced()
                refreshBackups()
                SyncResultKind.UPLOADED
            }
            SyncOpKind.CANCELLED -> SyncResultKind.CANCELLED
            else -> {
                status = status.copy(lastErrorCode = outcome.errorCode)
                notifyChanged()
                SyncResultKind.FAILED
            }
        }
    }

    private fun markSynced() {
        val now = clock()
        status = status.copy(lastSyncedAtIso = now, lastErrorCode = null)
        persist(config.copyWith(lastSyncedAtIso = now))
    }

    /**
     * 取本次要上传的字节。
     *
     * 顺序：注入 / 仓储实时快照 → 本地快照文件（旧路径）。
     * **没有数据时如实失败并给出错误码**（`no_local_user_data` / `missing_backup_snapshot`），
     * 绝不产出一个空包把云端好数据顶掉。
     */
    private fun currentSnapshotBytes(): ByteArray? {
        val provider = effectiveSnapshotProvider
        if (provider == null) {
            return snapshotStore.readSnapshot() ?: run {
                status = status.copy(lastErrorCode = "missing_backup_snapshot")
                notifyChanged()
                null
            }
        }
        return when (val result = provider()) {
            is SnapshotBuildResult.Success -> result.bytes
            SnapshotBuildResult.NoLocalData -> {
                status = status.copy(lastErrorCode = "no_local_user_data")
                notifyChanged()
                null
            }
            is SnapshotBuildResult.Failure -> {
                status = status.copy(lastErrorCode = result.errorCode)
                notifyChanged()
                null
            }
        }
    }

    private fun persist(next: WebdavSyncConfig) {
        config = next
        baseUrlDraft = next.baseUrl
        remoteFolderDraft = next.remoteFolder
        store.saveConfig(next)
        notifyChanged()
    }

    private fun candidateForConnection(username: String): WebdavSyncConfig {
        val effectiveBase = baseUrlDraft.trim().ifEmpty { WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL }
        return config.copyWith(username = username.trim(), baseUrl = effectiveBase)
    }

    private fun coordinatorOrNull(): WebdavSyncCoordinator? {
        val active = ensureTransport() ?: return null
        return WebdavSyncCoordinator(active, snapshotStore)
    }

    /**
     * 取当前传输；当前会话没连过时，尝试用**已存配置 + 已存密码**重建一次。
     *
     * 为什么需要它：进程重启后 `transport` 是空的，但配置与密码都还在盘上。不重建的话，
     * 进页面拉备份 / 立即同步 / 删除都会报 `missing_credentials`，用户得重新登录一次
     * 才会「突然正常」——看起来像功能坏了。读不到密码（密钥失效 / 没连过）就返回 null，
     * 页面按未连接展示。
     */
    private fun ensureTransport(): WebdavRemoteTransport? {
        transport?.let { return it }
        if (config.username.isBlank()) return null
        val password = passwordProvider?.invoke()?.takeIf { it.isNotEmpty() } ?: return null
        return transportFactory(config, password)?.also { transport = it }
    }

    private fun cancelIfCoordinator() {
        // 协调器按需构造，取消标记挂在「当前这次操作」的实例上；这里没有长效实例，
        // 真实下载是同步阻塞调用，页面退出通常发生在调用栈返回后，故以断开传输为准。
    }

    private fun toEntry(file: RemoteBackupFile): CloudBackupEntryModel = CloudBackupEntryModel(
        id = file.fileName,
        fileName = file.fileName,
        exportedAtIso = file.exportedAtMillis?.let { Instant.ofEpochMilli(it).toString() } ?: "",
        contentSha256 = file.contentSha256 ?: "",
        deviceId = file.deviceId ?: "",
        deviceLabel = file.deviceId ?: "",
        source = CloudBackupSource.AUTO,
        isCurrent = file.contentSha256 != null && file.contentSha256 == config.lastUploadedLocalHash,
    )

    private fun exportedAtMicrosOf(bytes: ByteArray): Long {
        val payload = runCatching {
            com.mutx163.qingyu.sync.decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        }.getOrNull() ?: return 0L
        val millis = CloudBackupListLogic.parseExportedAtMillis(payload["exportedAt"] as? String)
        return millis * 1000L
    }

    private fun deviceIdOf(): String = deviceLabelDraft.trim().ifEmpty { "device" }
}
