package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.SyncConflictInfo
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.decodeSnapshotObject
import com.mutx163.qingyu.sync.resolveManualPullConflictChoice
import com.mutx163.qingyu.sync.resolveRemoteSnapshotPath
import java.time.Instant
import java.time.OffsetDateTime
import java.util.concurrent.CopyOnWriteArrayList

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

/** 连接结果：成功 / 失败 + 可本地化的错误码。 */
data class CloudSyncConnectResult(val success: Boolean, val errorCode: String? = null)

class CloudSyncController(
    private val store: WebdavConfigStore,
    private val snapshotStore: LocalSnapshotStore,
    private val transportFactory: (WebdavSyncConfig, String) -> WebdavRemoteTransport? =
        { config, password -> createWebdavRemoteTransport(config, password) },
    private val deviceLabel: String = "",
    /**
     * 设备名落盘缝（宿主注入 `configStore.writeDeviceLabel`）。
     *
     * 2026-11-10 用户报「设备名叫 Compose 壳」时查实：改名以前只写进 [deviceLabelDraft]，
     * 从未落盘 ⇒ 下次进页面读回来还是空。这里必须落盘，才能读到用户起的名字。
     */
    private val persistDeviceLabel: ((String) -> Unit)? = null,
    private val clock: () -> String = { OffsetDateTime.now().toString() },
    /**
     * 课表仓储（宿主注入）。注入了它，「立即备份 / 立即同步」才拿得到**当前课表的实时快照**，
     * 「恢复」才会真的把快照写回课表；不注入则退回旧的本地快照文件路径（仅在单测 / 兼容时用）。
     */
    private val repository: TimetableRepository? = null,
    /**
     * 宏进快照的读取缝（P3）：非空时上传的字节带 `warehouse.macros`。
     * 类型只到 `List<Map<String, Any?>>`——sync 模块不能反向 import warehouse
     * （否则 `-Module pages/sync` 的 L0 编不过）；编解码由 warehouse 侧提供。
     */
    private val warehouseMacrosProvider: (() -> List<Map<String, Any?>>)? = null,
    /** 宏出快照的落库缝（P3）：恢复成功后把 `warehouse.macros` 原始列表交给 warehouse 域。 */
    private val warehouseMacrosApplier: ((Any?) -> Unit)? = null,
    /** 已存密码的读取缝：进程重启后进云页面可据此重建传输，不必让用户重新输密码。 */
    private val passwordProvider: (() -> String?)? = null,
    /** 覆盖默认的「生成上传字节」实现（单测可直接喂固定字节）。 */
    private val snapshotProvider: (() -> SnapshotBuildResult)? = null,
    /** 覆盖默认的「写回仓储」实现（单测可注入失败）。 */
    private val snapshotApplier: ((ByteArray) -> SnapshotApplyResult)? = null,
    /**
     * App 版本号（写进 snapshot.meta.json 与 history/index.json 的 appVersion 字段，
     * Flutter 端备份详情会显示）。宿主注入；null/空时不写键（Dart 条件写入同口径）。
     */
    private val appVersion: String? = null,
    /**
     * 撤销点索引。默认进程级共享（[CloudSyncUndoStore.shared]）：f.cloudSync 与
     * f.backupList 各自 new 控制器，但撤销点必须是同一份——在备份列表页恢复、
     * 进云同步页仍要能看到撤销入口。单测注入独立实例做隔离。
     */
    private val undoStore: CloudSyncUndoStore = CloudSyncUndoStore.shared,
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
     * 已下载待确认应用的远端快照（[prepareRestore] 与 [confirmPreparedRestore] 之间的
     * 一次性交接）。预览阶段零副作用：不写本机快照文件、不写课表仓储，用户取消即弃。
     * prepare 在 IO 线程写、confirm 在 IO 线程读、discard 在主线程清，单引用用 volatile 兜底。
     */
    @Volatile
    private var pendingRestore: PendingRemoteSnapshot? = null

    /** 一次恢复准备的缓存体：预览时下载并校验过的字节，确认时原样应用。 */
    private class PendingRemoteSnapshot(
        val bytes: ByteArray,
        val contentSha256: String,
    )

    /**
     * 「立即同步」先拉后推时发现的**待裁决冲突**（远端比基线新、本地也有改动）。
     *
     * 非空时页面应弹「选边」框；用户三选一经 [resolveSyncConflict] 消费后清空。
     * 置位到消费之间**绝不**动远端与本机数据——这正是「不静默覆盖」的落点。
     * syncNow 在 IO 线程写、主线程读，单引用读写用 volatile 兜底。
     */
    @Volatile
    var pendingSyncConflict: SyncConflictInfo? = null
        private set

    /**
     * 本会话里「立即备份」（手动）成功写出的远端文件名。
     *
     * 来源不落在版本化文件名里，目录列出来的条目缺省都是 AUTO；保留策略的
     * 「手动备份保护」与列表的「来源」展示只能对**本会话亲手备份的那几条**如实，
     * 会话外/别的设备的手动备份无从知晓（彻底解法要 index 互通，另案）。
     */
    private val manualBackupFileNames = LinkedHashSet<String>()

    /**
     * 上传字节来源：优先用调用方注入的；否则若给了仓储，就从**当前课表**现组一份；
     * 都没有才退回本地快照文件（旧路径）。
     */
    private val effectiveSnapshotProvider: (() -> SnapshotBuildResult)? =
        snapshotProvider ?: repository?.let { repo ->
            {
                TimetableSnapshotBridge.buildSnapshotBytes(
                    repo,
                    deviceIdOf(),
                    clock(),
                    warehouseMacrosProvider?.invoke() ?: emptyList(),
                )
            }
        }

    /** 恢复落点：优先用调用方注入的；否则写回仓储；都没有则不额外写（旧路径）。 */
    private val effectiveSnapshotApplier: ((ByteArray) -> SnapshotApplyResult)? =
        snapshotApplier ?: repository?.let { repo ->
            { bytes ->
                TimetableSnapshotBridge.applySnapshot(
                    repo,
                    bytes,
                    warehouseMacrosApplier,
                )
            }
        }

    /**
     * 是否有可撤销的恢复（撤销点在 [undoStore] 里，两页共享，见构造参数说明）。
     *
     * 只有**真正写回成功**的那次恢复才会留下撤销点；恢复失败、本机原本没有数据、
     * 断开连接、已经撤销过，都是 false。页面据此决定撤销入口是否出现。
     * 没有写回落点（[effectiveSnapshotApplier] 为空）时也不给入口：点了必然失败。
     */
    val canUndoLastRestore: Boolean
        get() = undoStore.peek() != null && effectiveSnapshotApplier != null

    // ── 可观察协议 ──

    /**
     * 监听器列表用 [CopyOnWriteArrayList] 而不是 `LinkedHashSet` + 锁。
     *
     * 为什么必须换：连接 / 测试连接挪到 IO 线程后，[notifyChanged] 会在 IO 线程迭代
     * 监听器，而 add / remove 发生在主线程（Compose 进入 / 离开组合时订阅退订）。
     * `LinkedHashSet` 的 `toList()` 与并发写不互斥，会直接 `ConcurrentModificationException`。
     * 为什么不加锁：锁方案要求**持锁期间回调监听器**，回调里写 Compose 状态会触发重组，
     * 等于把重组路径拖进临界区，有死锁风险；写时复制对这里的「读多写少」（监听器一页
     * 一两个、增删只在进出页面时发生）是零成本，且迭代永远安全，调用方无需关心线程。
     */
    private val listeners = CopyOnWriteArrayList<() -> Unit>()

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
        canUndoRestore = canUndoLastRestore,
    )

    /**
     * 新版密文键里是否存有密码（只读口）。
     *
     * 页面层判「升级后是否需要重输密码」用：`cloudSyncViewState()` 内部读过一次，
     * 但那是快照、且被渲染字段包着，宿主/页面拿不到原始布尔值。
     */
    fun hasStoredPassword(): Boolean = store.hasStoredPassword()

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
        canUndoRestore = canUndoLastRestore,
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
        // 只改草稿不落盘 = 下次进页面又读回占位名（用户报的「为什么叫 Compose 壳」根因之一）。
        persistDeviceLabel?.invoke(value.trim())
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

    /**
     * 测试连接（不落盘）：发起一次根 PROPFIND 自检。
     * 失败码同时写进 [lastErrorCode] 并广播，页面（含连接弹层）据此给出可见提示。
     */
    fun testConnection(username: String, password: String): Boolean {
        val candidate = candidateForConnection(username)
        val created = transportFactory(candidate, password)
        if (created == null) {
            recordConnectFailure("insecure_url_blocked")
            return false
        }
        val connectionError = created.testConnection()
        if (connectionError != null) {
            recordConnectFailure(connectionError)
            return false
        }
        return true
    }

    /** 连接：先自检，通过才落配置 + 密码并启用。 */
    fun connect(username: String, password: String): CloudSyncConnectResult {
        if (username.trim().isEmpty()) return connectFailure("missing_credentials")
        val candidate = candidateForConnection(username)
        val created = transportFactory(candidate, password)
            ?: return connectFailure("insecure_url_blocked")
        val connectionError = created.testConnection()
        if (connectionError != null) return connectFailure(connectionError)

        store.storePassword(password)
        transport = created
        persist(CloudSyncLogic.buildConnectConfig(candidate, username))
        status = status.copy(lastErrorCode = null)
        notifyChanged()
        // 连接成功就把备份列表拉回来：否则首次连接的这一页仍是空的，用户以为云端没备份。
        refreshBackups()
        return CloudSyncConnectResult(true)
    }

    /**
     * 连接 / 测试失败的统一出口：错误码写进 [status] 并 `notifyChanged()`。
     *
     * 为什么走 status 而不是另开回调：页面的错误显示（`lastErrorText`）与各失败动作
     * （刷新 / 恢复 / 删除）本来就都落在 `status.lastErrorCode` 这一条通道上，
     * 连接失败没有理由特殊化。弹层是否关闭由页面按返回值判断——失败时返回
     * `success = false`，弹层留着让用户改完重试。
     */
    private fun connectFailure(errorCode: String): CloudSyncConnectResult {
        recordConnectFailure(errorCode)
        return CloudSyncConnectResult(false, errorCode)
    }

    private fun recordConnectFailure(errorCode: String) {
        status = status.copy(lastErrorCode = errorCode)
        notifyChanged()
    }

    /** 落错误码到 `status.lastErrorCode` 并返回 FAILED（页面经 `for*` 本地化）。 */
    private fun failWithCode(errorCode: String): SyncResultKind {
        recordConnectFailure(errorCode)
        return SyncResultKind.FAILED
    }

    fun disconnect() {
        transport?.let { cancelIfCoordinator() }
        transport = null
        store.clearPassword()
        persist(CloudSyncLogic.buildDisconnectConfig(config))
        backupEntries = emptyList()
        remoteFiles = emptyList()
        undoStore.clear()
        pendingRestore = null
        manualBackupFileNames.clear()
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
        val coordinator = coordinatorOrNull() ?: run {
            // 2026-11-06 第五轮复核④：未连接的早退也清旧错误码——onRetryRefresh 可达时
            // （比如密码被清后错误条还挂着）点重试走到这里，status 里残留的上次失败码
            // 会变成死提示。未配置是正常首屏状态（本方法 KDoc 口径），不写新错误码、
            // 也不留旧错误码。
            status = status.copy(lastErrorCode = null)
            notifyChanged()
            return ListBackupsOutcome(SyncOpKind.FAILED, errorCode = "missing_credentials")
        }
        loadingBackups = true
        notifyChanged()
        val outcome = coordinator.listRemoteBackups(config)
        loadingBackups = false
        if (outcome.kind == SyncOpKind.OK) {
            remoteFiles = outcome.files
            backupEntries = outcome.files.map { toEntry(it) }
            // 2026-11-06 第三轮返工①-2：成功即清上次错误码——否则刷新成功后仍显示
            // 陈旧错误 + 死重试提示（错误条挂着，点重试其实已经没事了）。
            if (status.lastErrorCode != null) {
                status = status.copy(lastErrorCode = null)
            }
        } else if (outcome.kind == SyncOpKind.EMPTY) {
            remoteFiles = emptyList()
            backupEntries = emptyList()
            // 同上：云端空也是「刷新成功」——同样清掉陈旧错误。
            if (status.lastErrorCode != null) {
                status = status.copy(lastErrorCode = null)
            }
        } else {
            status = status.copy(lastErrorCode = outcome.errorCode)
        }
        notifyChanged()
        return outcome
    }

    /**
     * 立即同步：**先拉后推**（Dart `syncNow` = `downloadAndApply` → `uploadSnapshot`）。
     *
     * ## 为什么不能只 PUT
     *
     * 之前 `syncNow()` 就是 `runUpload()`：不比对远端直接覆盖。两台设备都改过之后，
     * 后按同步的那台会**静默顶掉**先同步那台的数据，冲突判定（`webdavPullHasSyncConflict`）
     * 因为基线从来没落盘而恒不触发。现在：
     * 1. 远端缺失 / 远端仍是基线 → 直接推本地（远端没别人的新数据可丢）；
     * 2. 本机没改、远端新了 → 以云端为准拉下来（与 Dart 口径一致）；
     * 3. 两边都改过 → **挂起冲突**等用户选边（[resolveSyncConflict]），绝不静默覆盖。
     */
    fun syncNow(): SyncResultKind {
        val coordinator = coordinatorOrNull() ?: return failWithCode("missing_credentials")
        return when (val pull = runPullPhase(coordinator)) {
            is PullPhase.Downloaded -> SyncResultKind.DOWNLOADED
            is PullPhase.Failed -> {
                status = status.copy(lastErrorCode = pull.errorCode)
                notifyChanged()
                SyncResultKind.FAILED
            }
            is PullPhase.Conflict -> {
                pendingSyncConflict = pull.info
                SyncResultKind.CANCELLED
            }
            PullPhase.ProceedToUpload -> runUpload(CloudBackupSource.AUTO)
        }
    }

    /**
     * 消费 [pendingSyncConflict]：按用户选边继续这次同步。
     *
     * - 保留本机 → 强制上传本地（Dart `keepLocal` → `uploadSnapshot`）；
     * - 使用云端 → 拉取并应用远端（返回 [SyncResultKind.DOWNLOADED]）；
     * - 取消 → 什么都不动。
     *
     * 没有待裁决冲突时返回 [SyncResultKind.CANCELLED]（幂等，页面重复调用无害）。
     */
    fun resolveSyncConflict(choice: SyncConflictChoice): SyncResultKind {
        pendingSyncConflict ?: return SyncResultKind.CANCELLED
        pendingSyncConflict = null
        return when (choice) {
            SyncConflictChoice.KEEP_LOCAL -> runUpload(CloudBackupSource.AUTO, force = true)
            SyncConflictChoice.KEEP_REMOTE -> downloadApplyAndMark(
                resolver = { SyncConflictChoice.KEEP_REMOTE },
            )
            SyncConflictChoice.CANCEL -> SyncResultKind.CANCELLED
        }
    }

    /** 立即备份：与同步同一套上传，来源记为手动（保留策略要保护它）。 */
    fun createBackup(): SyncResultKind = runUpload(CloudBackupSource.MANUAL)

    /**
     * 打开（恢复）某条远端备份的**单步入口**：等于 [prepareRestore] + [confirmPreparedRestore]
     * 两步合成，语义与拆出的两步完全一致（同一份代码，无第二实现）。
     *
     * 既有单测锚定这个入口；页面走两步——确认框里要先给差异概要，应用必须等用户确认。
     *
     * ## 修复了什么（P0）
     *
     * 之前下载成功只把字节写进本地快照文件，全仓没有代码把它写回课表：用户的课表
     * 一点没变，界面却提示「已从云端恢复」。现在只有 [effectiveSnapshotApplier] 写回成功
     * 才返回 [SyncResultKind.DOWNLOADED]；写回失败一律 [SyncResultKind.FAILED] 并带错误码。
     */
    fun openBackup(entryId: String): SyncResultKind = when (prepareRestore(entryId)) {
        is RestorePrepareOutcome.Ready -> confirmPreparedRestore()
        is RestorePrepareOutcome.Failed -> SyncResultKind.FAILED
        RestorePrepareOutcome.NotFound -> SyncResultKind.FAILED
        RestorePrepareOutcome.Missing -> SyncResultKind.FAILED
    }

    /**
     * 恢复第一步（预览）：下载远端快照、校验信封、与当前本机算差异概要。
     *
     * **零副作用**：不写本机快照文件、不写课表仓储（预览字节缓存在 [pendingRestore]，
     * 用户取消即弃）。概要供确认框展示——恢复是整份覆盖，用户确认前必须看到影响面。
     * 失败时错误码写进 [lastErrorCode]，页面按「恢复失败」提示。
     */
    fun prepareRestore(entryId: String): RestorePrepareOutcome {
        val coordinator = coordinatorOrNull() ?: return RestorePrepareOutcome.Missing
        val file = remoteFiles.firstOrNull { it.fileName == entryId }
            ?: return RestorePrepareOutcome.NotFound
        status = status.copy(isSyncing = true)
        notifyChanged()
        val fetch = coordinator.fetchSnapshotBytes(file.remotePath)
        status = status.copy(isSyncing = false)
        return when (fetch) {
            is WebdavSyncCoordinator.SnapshotBytesFetch.Ok -> {
                pendingRestore = PendingRemoteSnapshot(
                    bytes = fetch.bytes,
                    contentSha256 = fetch.contentSha256,
                )
                notifyChanged()
                RestorePrepareOutcome.Ready(
                    RestoreDiffLogic.summarize(fetch.payload, currentLocalPayload()),
                )
            }
            is WebdavSyncCoordinator.SnapshotBytesFetch.Failed -> {
                status = status.copy(lastErrorCode = fetch.errorCode)
                notifyChanged()
                RestorePrepareOutcome.Failed(fetch.errorCode)
            }
        }
    }

    /** 用户在确认框点了取消 / 关闭：丢弃预览缓存（幂等；不碰网络与任何存储）。 */
    fun discardPreparedRestore() {
        pendingRestore = null
    }

    /**
     * 恢复第二步（应用）：把 [prepareRestore] 缓存的字节写回课表仓储。
     *
     * 与单步恢复的 OK 分支同一条路：先抓撤销点（当前课表），本机快照文件换成远端
     * 这份（镜像下载落盘行为），再写回仓储；失败不留撤销点、错误码见 [lastErrorCode]。
     * 没有待应用的缓存（没 prepare 过 / 已确认过 / 已丢弃）直接 FAILED。
     *
     * @return [SyncResultKind.DOWNLOADED] = 已写回成功
     */
    fun confirmPreparedRestore(): SyncResultKind {
        val pending = pendingRestore ?: return SyncResultKind.FAILED
        // 撤销点 / 旧本地快照必须在**写回之前**取（原子回滚的补偿依据）。
        val rollback = effectiveSnapshotProvider?.let { provider ->
            (provider() as? SnapshotBuildResult.Success)?.bytes
        }
        val previousLocal = readLocalSnapshotQuietly()
        pendingRestore = null
        // 顺序对齐 205 恢复：**先**把本机快照文件换成远端这份（镜像 downloadSnapshot 的落盘
        // 行为），**再**写回仓储课表，最后原子收口（撤销点 + 基线钉）。若在「被杀」点抛错：
        // 快照没写成功→课表也不动（test ②）；快照已写、课表没写回→重启重试补齐（test ①）。
        snapshotStore.writeSnapshot(pending.bytes)
        if (!applyDownloadedSnapshot(pending.bytes)) {
            // 课表写回失败：本机快照已被换成远端，必须还原，避免「本地快照=远端」的假象。
            restoreLocalSnapshotQuietly(previousLocal, rollback)
            notifyChanged()
            return SyncResultKind.FAILED
        }
        // 原子收口：本机快照已写在上面（localSnapshotAlreadyWritten=true），这里只补撤销点 +
        // 基线钉（config）。任一步失败在内部按相反顺序回滚课表与本机快照并写 lastErrorCode
        //（backup_restore_commit_failed / backup_restore_rollback_failed），不向上抛。
        val committed = commitRestoredSnapshot(
            remoteBytes = pending.bytes,
            remoteContentSha256 = pending.contentSha256,
            rollbackBytes = rollback,
            previousLocalSnapshot = previousLocal,
            undoPoint = rollback?.let {
                CloudRestoreUndoPoint(beforeBytes = it, afterBytes = pending.bytes)
            },
            resetUndo = true,
            localSnapshotAlreadyWritten = true,
        )
        if (!committed) {
            return SyncResultKind.FAILED
        }
        refreshBackups()
        return SyncResultKind.DOWNLOADED
    }

    /** 当前课表的快照 payload（差异概要的本机侧）；没有数据 / 解析失败给 null（按空表比对）。 */
    private fun currentLocalPayload(): Map<String, Any?>? {
        val bytes = (effectiveSnapshotProvider?.invoke() as? SnapshotBuildResult.Success)?.bytes
            ?: return null
        return runCatching {
            decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        }.getOrNull()
    }

    /**
     * 撤销最近一次恢复。
     *
     * ## 只回退「仍是恢复后值」的条目（2026-11-02）
     *
     * 之前是把恢复前抓的整份快照写回：恢复后用户又改的课会一起消失。现在撤销前先
     * 组一份当前课表，交 [CloudRestoreUndoPlanner] 按 id 三向比对（恢复前 / 恢复时 /
     * 现在）：恢复带入且未被动的条目撤掉、恢复覆盖且未被动的条目还原、用户改过或
     * 新建的条目原样保留。
     *
     * 三份现场拿不齐（旧路径没有快照提供者、或某份解析失败）时保守回落
     * 「整份写回恢复前快照」，与按 id 比对出现前的行为一致。
     *
     * 成功会 `notifyChanged()`：两份 viewState 的 `canUndoRestore` 随之变 false，
     * 页面上的撤销卡片立即消失；失败会留下撤销点并写 [lastErrorCode]，让用户能重试。
     *
     * @return true = 已回退（含「无可回退变更」的空撤销）；false = 没有撤销点 / 写回失败
     *   （错误码见 [lastErrorCode]）。
     */
    fun undoLastRestore(): Boolean {
        val point = undoStore.peek() ?: return false
        val applier = effectiveSnapshotApplier ?: return false
        val currentBytes = (effectiveSnapshotProvider?.invoke() as? SnapshotBuildResult.Success)?.bytes
        val targetBytes = CloudRestoreUndoPlanner.buildUndoBytes(
            point = point,
            currentBytes = currentBytes,
            exportedAtIso = clock(),
        )
        if (targetBytes == null) {
            // 没有任何需要回退的变更（恢复没改过数据，或改动已被用户全部改过）：
            // 消费掉撤销点即可，不必为「什么都没改」再写一次整份课表。
            undoStore.clear()
            status = status.copy(lastErrorCode = null)
            notifyChanged()
            return true
        }
        return when (val result = applier(targetBytes)) {
            SnapshotApplyResult.Applied -> {
                undoStore.clear()
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

    /**
     * 恢复类操作的**三件套原子收口**（2026-11-03）：
     * 「本机快照文件 → 撤销点 → 基线钉（config）」要么全写，要么一个都不写。
     *
     * 旧实现是三步裸调用：`writeSnapshot` 抛错（磁盘满 / 权限）时课表已经被写回，
     * 撤销点还没设、基线没钉，本机快照也没换——正是任务里说的半写状态。这里任意
     * 一步失败就按相反顺序补偿：恢复旧本地快照文件 → 清撤销点（不留指向错误状态的
     * 撤销点）→ 用恢复前字节把课表写回去 → 最后如实报错误码。补偿自己失败时
     * 报 `backup_restore_rollback_failed`，至少让用户知道「课表现在是恢复后的，
     * 但同步基线没动」。
     *
     * @param undoPoint 非空 = 同时重设撤销点；[resetUndo] 为真且 [undoPoint] 为空 =
     *   清掉旧撤销点（旧点指向更早状态，留着会撤错东西）。
     * @return 成功 true；失败 false 且 [status] 已带错误码。
     */
    private fun commitRestoredSnapshot(
        remoteBytes: ByteArray,
        remoteContentSha256: String?,
        rollbackBytes: ByteArray?,
        previousLocalSnapshot: ByteArray?,
        undoPoint: CloudRestoreUndoPoint?,
        resetUndo: Boolean,
        /**
         * 协调器 `downloadSnapshot` 成功时已经把本地快照文件写成同一份字节；
         * 下载路径传 true 少一次整包重写（大包时省一份瞬时分配）。
         */
        localSnapshotAlreadyWritten: Boolean = false,
    ): Boolean {
        val statusBefore = status
        return try {
            if (!localSnapshotAlreadyWritten) snapshotStore.writeSnapshot(remoteBytes)
            if (undoPoint != null) {
                undoStore.set(undoPoint)
            } else if (resetUndo) {
                undoStore.clear()
            }
            markSynced(remoteContentSha256)
            true
        } catch (_: Exception) {
            undoStore.clear()
            // 旧本地快照：优先原件；从来没有（首次恢复）就写回恢复前字节，
            // 让「本机快照」与「已回滚的课表」仍然对得上，下一轮不会误判同源。
            val localBytes = previousLocalSnapshot ?: rollbackBytes
            val localRestored = localBytes == null ||
                runCatching { snapshotStore.writeSnapshot(localBytes) }.isSuccess
            val applier = effectiveSnapshotApplier
            val snapshotRestored = when {
                applier == null -> true
                rollbackBytes == null -> false
                else -> applier(rollbackBytes) == SnapshotApplyResult.Applied
            }
            status = statusBefore.copy(
                isSyncing = false,
                lastErrorCode = if (localRestored && snapshotRestored) {
                    "backup_restore_commit_failed"
                } else {
                    "backup_restore_rollback_failed"
                },
            )
            notifyChanged()
            false
        }
    }

    private fun readLocalSnapshotQuietly(): ByteArray? =
        runCatching { snapshotStore.readSnapshot() }.getOrNull()

    /**
     * 冲突判定用的「本机现在这份课表」。
     *
     * 有仓储 / 注入快照时用**实时快照**：上传路径从不写本机快照文件，若进程在
     * 「云端已写好、基线还没钉」之间被杀，重启后文件仍是空的，只按文件判会把
     * 「远端 == 本机」当成首次分歧，弹出假「选边」框。
     * 实时快照明确为空（没有用户数据）时返回 null，不能回落旧文件——旧文件正是
     * 可能已经与实际课表脱节的那一份。
     */
    private fun readLocalSnapshotForConflict(): ByteArray? {
        val provider = effectiveSnapshotProvider ?: return readLocalSnapshotQuietly()
        return (provider() as? SnapshotBuildResult.Success)?.bytes
    }

    /** 下载/应用失败时把协调器已经覆盖过的本地快照文件还原，避免「本地快照说同步了」。 */
    private fun restoreLocalSnapshotQuietly(previous: ByteArray?, fallback: ByteArray?) {
        val target = previous ?: fallback ?: return
        runCatching { snapshotStore.writeSnapshot(target) }
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

    /** 删除某条远端备份（Dart `deleteBackup`：索引查条目 → 当前版本拒绝 → 删文件 → 维护索引）。
     *
     * 条目从 `history/index.json` 查（读不到走恢复重建）；文件与索引都认识它才动得起来，
     * 不认识的远端文件永远不会被这条路删掉。当前版本闸门是两道：索引的 `isCurrent`，
     * 以及本机上传基线（`lastUploadedLocalHash`）——它是其他设备「最新一份」的参照。
     */
    fun deleteBackup(entryId: String): SyncResultKind {
        // Dart `deleteBackup`：`buildConnectionParams == null` → `missing_credentials`，
        // 索引里查不到条目 → `backup_not_found`（都不是泛化的「同步失败」）。
        val coordinator = coordinatorOrNull() ?: return failWithCode("missing_credentials")
        val entries = when (val loaded = coordinator.loadBackupIndex(config)) {
            is BackupIndexLoad.Failed -> {
                status = status.copy(lastErrorCode = loaded.errorCode)
                notifyChanged()
                return SyncResultKind.FAILED
            }
            is BackupIndexLoad.Ok -> loaded.entries
        }
        // UI 行 id 用的是文件名；索引 id 用的是 backupId，两个都能定位到同一条。
        val entry = entries.firstOrNull { it.fileName == entryId || it.id == entryId }
            ?: return failWithCode("backup_not_found")
        if (entry.isCurrent || entry.contentSha256 == config.lastUploadedLocalHash) {
            status = status.copy(lastErrorCode = "cannot_delete_current_backup")
            notifyChanged()
            return SyncResultKind.FAILED
        }
        val active = ensureTransport() ?: return failWithCode("missing_credentials")
        val result = active.deleteRemoteFile(config.historyBackupRemotePath(entry.fileName))
        if (result.isFailed) {
            status = status.copy(lastErrorCode = result.errorMessage ?: "delete_failed")
            notifyChanged()
            return SyncResultKind.FAILED
        }
        // 索引同步摘掉这条：失败的顺序与 Dart 一致（文件先删，索引保存失败按失败报，
        // 文件已删不回滚——孤儿索引条目下次重建自 listing 会自然消失）。
        val saveResult = coordinator.saveBackupIndex(
            config,
            CloudBackupIndexCodec.removeEntry(entries, entry.id),
        )
        if (saveResult.isFailed) {
            status = status.copy(lastErrorCode = saveResult.errorMessage ?: "delete_failed")
            notifyChanged()
            return SyncResultKind.FAILED
        }
        refreshBackups()
        return SyncResultKind.BACKUP_DELETED
    }

    /** 页面退出时调用：取消进行中的下载 + 摘掉监听。 */
    fun dispose() {
        cancelIfCoordinator()
        listeners.clear()
    }

    // ── 内部 ──

    private fun runUpload(source: CloudBackupSource, force: Boolean = false): SyncResultKind {
        val coordinator = coordinatorOrNull() ?: return failWithCode("missing_credentials")
        val bytes = currentSnapshotBytes() ?: return SyncResultKind.FAILED
        // 自动上传前先按 Dart `decideWebdavAutoUpload` 的优先级判「远近一致」：
        // 一致就返回 UP_TO_DATE，不再发布新版本化正文、不写历史文件——否则每次自动
        // 同步都会堆一份一模一样的备份（手动备份与冲突选「保留本机」走 force，不跳过）。
        if (!force && source == CloudBackupSource.AUTO) {
            val meta = coordinator.fetchRemoteMeta(config)
            if (meta is RemoteMetaFetch.Ok) {
                val remoteHash = meta.contentSha256.trim()
                if (remoteHash.isNotEmpty() &&
                    remoteHash == WebdavSyncCoordinator.snapshotContentHash(bytes)
                ) {
                    status = status.copy(isSyncing = false, lastErrorCode = null)
                    notifyChanged()
                    return SyncResultKind.UP_TO_DATE
                }
            }
        }
        val exportedAtIso = exportedAtIsoOf(bytes)
        status = status.copy(isSyncing = true)
        isCreatingBackup = true
        notifyChanged()
        // 上传按 Dart 协议在协调器里一次完成：锁 → 正文（读回校验）→ meta（发布校验）
        // → 历史文件 → index 维护（含保留策略执行）。成功即远端布局与 Flutter 版互通。
        val outcome = coordinator.uploadSnapshot(
            config = config,
            snapshotBytes = bytes,
            exportedAtIso = exportedAtIso,
            deviceId = deviceIdOf(),
            source = source,
            appVersion = appVersion,
        )
        status = status.copy(isSyncing = false)
        isCreatingBackup = false
        return when (outcome.kind) {
            SyncOpKind.OK -> {
                // 上传成功 = 本机就是最新一份：把「上传基线」落到盘上。此前只写
                // lastSyncedAtIso，`lastUploadedLocalHash` 恒 null ⇒ 列表「当前版本」
                // 永不出现、删除闸门恒放行、冲突判定恒误报（本条修的就是它）。
                markSynced(outcome.contentSha256)
                // 手动来源只在内存里记文件名（index 互通后条目来源已如实落盘）。
                outcome.remotePath
                    ?.substringAfterLast('/')
                    ?.takeIf { source == CloudBackupSource.MANUAL }
                    ?.let { manualBackupFileNames.add(it) }
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

    /**
     * 同步成功收口：写上次同步时间 + 把两个基线钉到 [contentHash]。
     *
     * @param contentHash 本次同步后「本机与远端共同」的内容哈希（上传成功 = 上传字节、
     *   拉取/恢复成功 = 远端字节）。null 时不改基线（仅旧路径兼容；正常成功路径必有值）。
     */
    private fun markSynced(contentHash: String? = null) {
        val now = clock()
        status = status.copy(lastSyncedAtIso = now, lastErrorCode = null)
        persist(
            config.copyWith(
                lastSyncedAtIso = now,
                lastUploadedLocalHash = contentHash,
                lastAppliedRemoteHash = contentHash,
            ),
        )
    }

    /** [syncNow] 拉取阶段的三种出口（上传 / 已应用远端 / 等用户选边）。 */
    private sealed interface PullPhase {
        /** 远端没有新数据（缺失 / 就是基线），可以放心推本地。 */
        data object ProceedToUpload : PullPhase

        /** 已拉取并应用远端，本地现在就是云端那份，无需再推。 */
        data object Downloaded : PullPhase

        /** 拉取本身失败（网络 / 负载非法）。 */
        data class Failed(val errorCode: String) : PullPhase

        /** 两边都改过：挂起冲突等用户选边，本轮绝不动任何一端。 */
        data class Conflict(val info: SyncConflictInfo) : PullPhase
    }

    /**
     * 拉取阶段：读 `snapshot.meta.json` 指针 → 与基线比对 → 需要时交给协调器拉取。
     *
     * 顺序与判定对齐 Dart `downloadAndApply`：meta 缺失/内容哈希等于 `lastAppliedRemoteHash`
     * = 云端没有新东西，直接返回去推本地；meta 声明的哈希与正文重算值不符报
     * `sync_snapshot_meta_mismatch`，绝不把配不上对的正文写进本机。
     *
     * 旧格式兼容：云端没有 meta（本壳旧版写的，只有 `snapshot.mikcb` 指针）时按旧路径
     * 判定——正文缺失 → 推本地；存在 → 信封校验后按基线/冲突走（见 [legacyPullPhase]）。
     */
    private fun runPullPhase(coordinator: WebdavSyncCoordinator): PullPhase {
        ensureTransport() ?: return PullPhase.Failed("missing_credentials")
        return when (val meta = coordinator.fetchRemoteMeta(config)) {
            is RemoteMetaFetch.Failed -> PullPhase.Failed(meta.errorCode)
            RemoteMetaFetch.NotFound -> legacyPullPhase(coordinator) ?: PullPhase.ProceedToUpload
            is RemoteMetaFetch.Ok -> {
                if (meta.contentSha256.isEmpty()) return PullPhase.ProceedToUpload
                pullAndApplyRemote(
                    coordinator,
                    meta,
                    hasLocalUserData = localHasUserDataNow(),
                    // Dart `resolveManualPullConflictChoice`：本机是空壳时不弹「选边」，
                    // 直接以云端为准；有本地用户数据才挂起等用户选。
                    resolver = { info ->
                        resolveManualPullConflictChoice(info.localHasUserData)
                            ?: SyncConflictChoice.CANCEL
                    },
                ) ?: PullPhase.ProceedToUpload
            }
        }
    }

    /**
     * 旧格式云端（没有 meta）的拉取判定：GET legacy 指针 `snapshot.mikcb` →
     * 缺失 = 云端没数据（去推本地）；存在 = 信封校验 → 基线比对 → 冲突走协调器。
     * null 返回值 = 云端没有新数据，可以推本地。
     */
    private fun legacyPullPhase(coordinator: WebdavSyncCoordinator): PullPhase? {
        val active = ensureTransport() ?: return PullPhase.Failed("missing_credentials")
        val fetched = active.getBytes(config.snapshotRemotePath)
        if (fetched.isFailed) {
            return PullPhase.Failed(fetched.errorMessage ?: "sync_failed")
        }
        val bytes = fetched.bytes
        if (fetched.isNotFound || fetched.isEmpty || bytes == null) {
            return null
        }
        val remotePayload = try {
            decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        } catch (error: Exception) {
            return PullPhase.Failed(error.message ?: "invalid_sync_snapshot_payload")
        }
        val envelope = checkSnapshotEnvelopeAndChecksum(remotePayload)
        if (!envelope.isValid) {
            return PullPhase.Failed(envelope.errorCode ?: "invalid_sync_snapshot_payload")
        }
        if (envelope.actualHash == config.lastAppliedRemoteHash) {
            return null
        }
        // 远端比基线新：让协调器做冲突判定。空壳本机直接以云端为准；有本地
        // 用户数据才挂起（CANCEL）等页面弹「选边」框（Dart 手动拉取同口径）。
        val rollback = effectiveSnapshotProvider?.let { provider ->
            (provider() as? SnapshotBuildResult.Success)?.bytes
        }
        val previousLocal = readLocalSnapshotQuietly()
        status = status.copy(isSyncing = true)
        notifyChanged()
        val outcome = coordinator.downloadSnapshot(
            config = config,
            hasLocalUserData = localHasUserDataNow(),
            readLocalSnapshot = ::readLocalSnapshotForConflict,
            resolver = { info ->
                resolveManualPullConflictChoice(info.localHasUserData)
                    ?: SyncConflictChoice.CANCEL
            },
        )
        status = status.copy(isSyncing = false)
        return when (outcome.kind) {
            SyncOpKind.OK -> {
                val downloaded = outcome.bytes
                if (!applyDownloadedSnapshot(downloaded)) {
                    restoreLocalSnapshotQuietly(previousLocal, rollback)
                    PullPhase.Failed(status.lastErrorCode ?: "sync_failed")
                } else if (downloaded == null) {
                    restoreLocalSnapshotQuietly(previousLocal, rollback)
                    PullPhase.Failed("sync_snapshot_missing")
                } else if (
                    !commitRestoredSnapshot(
                        remoteBytes = downloaded,
                        remoteContentSha256 = outcome.remoteContentSha256,
                        rollbackBytes = rollback,
                        previousLocalSnapshot = previousLocal,
                        undoPoint = null,
                        resetUndo = false,
                        localSnapshotAlreadyWritten = true,
                    )
                ) {
                    PullPhase.Failed(status.lastErrorCode ?: "backup_restore_commit_failed")
                } else {
                    PullPhase.Downloaded
                }
            }
            SyncOpKind.CANCELLED -> outcome.conflict?.let { PullPhase.Conflict(it) }
                ?: PullPhase.Failed("sync_failed")
            else -> PullPhase.Failed(outcome.errorCode ?: "sync_failed")
        }
    }

    /**
     * 按 meta 声明拉取并应用远端（立即同步的「云端较新」分支与「使用云端」选边共用）。
     * 正文路径取 meta 的 `snapshotPath`（经穿越校验）；非法路径报
     * `sync_snapshot_path_invalid`（Dart 同码）。
     * @return null = meta 声明哈希等于当前基线（云端没有新数据，调用方自行推进）
     */
    private fun pullAndApplyRemote(
        coordinator: WebdavSyncCoordinator,
        meta: RemoteMetaFetch.Ok,
        hasLocalUserData: Boolean,
        resolver: (SyncConflictInfo) -> SyncConflictChoice,
    ): PullPhase? {
        if (meta.contentSha256 == config.lastAppliedRemoteHash) return null
        val snapshotPath = resolveRemoteSnapshotPath(
            normalizedRemoteFolder = config.normalizedRemoteFolder,
            snapshotRemotePath = config.snapshotRemotePath,
            rawPath = meta.snapshotPath,
        ) ?: return PullPhase.Failed("sync_snapshot_path_invalid")
        // 协调器会先覆盖本机快照文件；失败时用这两份还原（见 commitRestoredSnapshot）。
        val rollback = effectiveSnapshotProvider?.let { provider ->
            (provider() as? SnapshotBuildResult.Success)?.bytes
        }
        val previousLocal = readLocalSnapshotQuietly()
        status = status.copy(isSyncing = true)
        notifyChanged()
        val outcome = coordinator.downloadSnapshot(
            config = config,
            remotePath = snapshotPath,
            expectedRemoteHash = meta.contentSha256,
            hasLocalUserData = hasLocalUserData,
            readLocalSnapshot = ::readLocalSnapshotForConflict,
            resolver = resolver,
        )
        status = status.copy(isSyncing = false)
        return when (outcome.kind) {
            SyncOpKind.OK -> {
                val downloaded = outcome.bytes
                if (!applyDownloadedSnapshot(downloaded)) {
                    restoreLocalSnapshotQuietly(previousLocal, rollback)
                    PullPhase.Failed(status.lastErrorCode ?: "sync_failed")
                } else if (downloaded == null) {
                    restoreLocalSnapshotQuietly(previousLocal, rollback)
                    PullPhase.Failed("sync_snapshot_missing")
                } else if (
                    !commitRestoredSnapshot(
                        remoteBytes = downloaded,
                        remoteContentSha256 = outcome.remoteContentSha256,
                        rollbackBytes = rollback,
                        previousLocalSnapshot = previousLocal,
                        undoPoint = null,
                        resetUndo = false,
                        localSnapshotAlreadyWritten = true,
                    )
                ) {
                    // 普通同步不重设撤销点，但「本机快照 + 基线钉」仍须同进同退。
                    PullPhase.Failed(status.lastErrorCode ?: "backup_restore_commit_failed")
                } else {
                    PullPhase.Downloaded
                }
            }
            SyncOpKind.CANCELLED -> outcome.conflict?.let { PullPhase.Conflict(it) }
                ?: PullPhase.Failed("sync_failed")
            else -> PullPhase.Failed(outcome.errorCode ?: "sync_failed")
        }
    }

    /** 以云端为准拉取并应用（用户选了「使用云端」），成功后写基线。 */
    private fun downloadApplyAndMark(
        resolver: (SyncConflictInfo) -> SyncConflictChoice,
    ): SyncResultKind {
        val coordinator = coordinatorOrNull() ?: return SyncResultKind.FAILED
        val meta = coordinator.fetchRemoteMeta(config)
        return when (meta) {
            is RemoteMetaFetch.Failed -> {
                status = status.copy(lastErrorCode = meta.errorCode)
                notifyChanged()
                SyncResultKind.FAILED
            }
            RemoteMetaFetch.NotFound -> {
                // 旧格式云端：直接按 legacy 指针拉（无 meta 配对校验可做）。
                when (val phase = legacyPullPhase(coordinator)) {
                    is PullPhase.Downloaded -> SyncResultKind.DOWNLOADED
                    is PullPhase.Failed -> {
                        status = status.copy(lastErrorCode = phase.errorCode)
                        notifyChanged()
                        SyncResultKind.FAILED
                    }
                    else -> SyncResultKind.CANCELLED
                }
            }
            is RemoteMetaFetch.Ok -> when (
                val phase = pullAndApplyRemote(
                    coordinator,
                    meta,
                    hasLocalUserData = localHasUserDataNow(),
                    resolver = resolver,
                )
            ) {
                PullPhase.Downloaded -> SyncResultKind.DOWNLOADED
                is PullPhase.Failed -> {
                    status = status.copy(lastErrorCode = phase.errorCode)
                    notifyChanged()
                    SyncResultKind.FAILED
                }
                else -> SyncResultKind.CANCELLED
            }
        }
    }

    /**
     * 本机是否含用户亲手沉淀的课表数据（冲突预决策用；Dart
     * `AppSyncSnapshot.hasUserAuthoredData`）。空壳本机遇到云端有数据时不弹「选边」框，
     * 直接以云端为准（Dart `resolveManualPullConflictChoice`）。
     *
     * 没有仓储（单测 / 旧的本地快照文件路径）时保守返回 true：宁可多弹一次「选边」，
     * 也不在看不见数据时静默把本机覆盖成云端。
     */
    private fun localHasUserDataNow(): Boolean {
        val repo = repository ?: return true
        return TimetableSnapshotBridge.localHasUserAuthoredData(repo)
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
        // 先落盘再改内存（2026-11-03）：旧顺序在 `saveConfig` 抛错时会让内存里的
        // `config` 领先于磁盘，下一次启动读回的是旧值而界面显示新值——又是半写状态。
        store.saveConfig(next)
        config = next
        baseUrlDraft = next.baseUrl
        remoteFolderDraft = next.remoteFolder
        notifyChanged()
    }

    private fun candidateForConnection(username: String): WebdavSyncConfig {
        val effectiveBase = baseUrlDraft.trim().ifEmpty { WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL }
        return config.copyWith(username = username.trim(), baseUrl = effectiveBase)
    }

    private fun coordinatorOrNull(): WebdavSyncCoordinator? {
        val active = ensureTransport() ?: return null
        return WebdavSyncCoordinator(
            transport = active,
            localStore = snapshotStore,
            nowMillis = { CloudBackupListLogic.parseExportedAtMillis(clock()) },
        )
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
        exportedAtIso = file.exportedAtIso
            ?: file.exportedAtMillis?.let { Instant.ofEpochMilli(it).toString() }
            ?: "",
        contentSha256 = file.contentSha256 ?: "",
        deviceId = file.deviceId ?: "",
        deviceLabel = file.deviceLabel.ifBlank { file.deviceId ?: "" },
        appVersion = file.appVersion,
        // 索引条目自带 isCurrent（Flutter 端写的也算数）；本机基线命中同样算当前版本。
        isCurrent = file.isCurrent ||
            (file.contentSha256 != null && file.contentSha256 == config.lastUploadedLocalHash),
        // 来源不再硬编码 AUTO：index 互通后条目来源已如实落盘（Flutter 写的 MANUAL 也认）；
        // 本会话手动备份的那几条由内存记录兜底（重建自 listing 的条目没有来源信息）。
        source = if (file.fileName in manualBackupFileNames) {
            CloudBackupSource.MANUAL
        } else {
            file.source
        },
        profileCount = file.profileCount,
        courseCount = file.courseCount,
    )

    /** 快照信封里的 `exportedAt` 原串（meta/历史命名都用它）；缺失回落当前时刻。 */
    private fun exportedAtIsoOf(bytes: ByteArray): String {
        val payload = runCatching {
            com.mutx163.qingyu.sync.decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        }.getOrNull()
        return (payload?.get("exportedAt") as? String)?.takeIf { it.isNotBlank() } ?: clock()
    }

    private fun deviceIdOf(): String = deviceLabelDraft.trim().ifEmpty { "device" }
}
