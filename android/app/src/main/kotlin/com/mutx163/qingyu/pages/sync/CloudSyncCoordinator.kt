package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.BackupIndexRecoveryAction
import com.mutx163.qingyu.sync.GetBytesResult
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.SyncConflictInfo
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.WebdavWriteResult
import com.mutx163.qingyu.sync.bytesEqual
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decideBackupIndexRecovery
import com.mutx163.qingyu.sync.decodeSnapshotObject
import com.mutx163.qingyu.sync.parseSnapshotMetaFields
import com.mutx163.qingyu.sync.resolveSyncConflictAutomatically
import com.mutx163.qingyu.sync.versionedSnapshotRemotePath
import com.mutx163.qingyu.sync.webdavPullHasSyncConflict
import java.security.MessageDigest

/**
 * 云同步「真收发」协调层（Phase 3.5 · C1；2026-11-02 起按 **Dart 协议**读写远端）。
 *
 * ## 远端布局（与 Flutter 版 `webdav_sync_service.dart` 逐字对齐，双向互通的格式合同）
 *
 * - `<folder>snapshot.meta.json` —— **当前快照指针**：`exportedAt/contentSha256/deviceId/
 *   appVersion?/snapshotPath`，`snapshotPath` 指向不可变的版本化正文；Dart 缺 meta 直接当
 *   「已是最新」，所以 meta 是唯一权威指针；
 * - `<folder>snapshot-<sha256>-<微秒>-<设备>.mikcb` —— 版本化正文，写在**根目录**
 *   （不是 history/）；
 * - `<folder>history/<yyyyMMdd-HHmmss本地>-<hash8>.mikcb` —— 历史备份（Dart 命名）；
 * - `<folder>history/index.json` —— 历史索引（version=1 + entries），缺失/损坏按
 *   Dart `decideWebdavBackupIndexRecovery` 口径恢复（重建自 listing）。
 *
 * ## 发布顺序（Dart `_publishSnapshotVersion` 原样）
 *
 * 取独占锁（服务器不支持锁→继续，锁被占→硬失败）→ PUT 版本化正文 → **读回校验** →
 * PUT meta → **再读 meta 校验**（contentSha256 与 snapshotPath 必须等于本次发布的）
 * → 解锁。读回校验保证「正文/meta 配对」不被并发写者拆散——服务器没有锁和 ETag 也成立。
 *
 * 数据面依赖 [WebdavRemoteTransport] 这个缝，单测注入内存假实现即可覆盖全路径。
 */

/** 一次同步动作的结局（不是 HTTP 细节，是页面要判的业务结局）。 */
enum class SyncOpKind {
    /** 成功且产生了变化（上传完成 / 下载并落盘）。 */
    OK,

    /** 远端目录为空（没有备份）。 */
    EMPTY,

    /** 远端与本地一致，无需动作。 */
    UNCHANGED,

    /** 内容冲突，等待调用方按 [SyncConflictChoice] 处置。 */
    CONFLICT,

    /** 用户中途退出（取消），未落脏数据。 */
    CANCELLED,

    /** 失败；[errorCode] 是可本地化的安全短码。 */
    FAILED,
}

/** 远端一条备份（来自 history/index.json 条目，或重建自 listing 的快照体解析）。 */
data class RemoteBackupFile(
    val fileName: String,
    val remotePath: String,
    val exportedAtMillis: Long? = null,
    val contentSha256: String? = null,
    val deviceId: String? = null,
    val exportedAtIso: String? = null,
    val deviceLabel: String = "",
    val appVersion: String? = null,
    /** 索引条目自带的「当前版本」标记；重建自 listing 时由 meta 哈希判定。 */
    val isCurrent: Boolean = false,
    /**
     * 备份来源。索引互通后来自 index.json（Flutter 写的真实来源）；
     * 重建自 listing 的条目只能给缺省 AUTO——文件名里没有来源信息。
     */
    val source: CloudBackupSource = CloudBackupSource.AUTO,
    val profileCount: Int? = null,
    val courseCount: Int? = null,
)

/** 列远端备份结果。 */
data class ListBackupsOutcome(
    val kind: SyncOpKind,
    val files: List<RemoteBackupFile> = emptyList(),
    val errorCode: String? = null,
)

/** 上传结果。 */
data class UploadSnapshotOutcome(
    val kind: SyncOpKind,
    val remotePath: String? = null,
    val contentSha256: String? = null,
    val errorCode: String? = null,
)

/** 下载结果（含冲突判定与是否已落盘）。 */
data class DownloadSnapshotOutcome(
    val kind: SyncOpKind,
    val bytes: ByteArray? = null,
    val remoteContentSha256: String? = null,
    val localContentSha256: String? = null,
    val conflict: SyncConflictInfo? = null,
    val resolvedChoice: SyncConflictChoice? = null,
    val applied: Boolean = false,
    val errorCode: String? = null,
)

/** `snapshot.meta.json` 的读取结果（Dart `WebdavRemoteMetaResult` 口径）。 */
sealed interface RemoteMetaFetch {
    /** meta 存在且可解析；[contentSha256] 为空串表示声明为空（Dart 同样当「无拉取工作」）。 */
    data class Ok(
        val exportedAtIso: String,
        val contentSha256: String,
        val deviceId: String,
        val snapshotPath: String?,
    ) : RemoteMetaFetch

    /** 404 / 空体：云端从未发布过 meta（Dart `isNotFound` → upToDate）。 */
    data object NotFound : RemoteMetaFetch

    /** 网络失败或 JSON/类型不合法（Dart `invalid_response`）。 */
    data class Failed(val errorCode: String) : RemoteMetaFetch
}

/** 历史索引装载结果（上传维护索引、删除备份共用）。 */
sealed interface BackupIndexLoad {
    data class Ok(val entries: List<CloudBackupEntryModel>) : BackupIndexLoad
    data class Failed(val errorCode: String) : BackupIndexLoad
}

/**
 * 本机快照读写接缝（生产用存储层实现，单测用内存假实现）。
 * 只读写「当前快照」这一份字节；多档案/任务写回归仓储（不在本层）。
 */
interface LocalSnapshotStore {
    fun readSnapshot(): ByteArray?
    fun writeSnapshot(bytes: ByteArray)
}

/**
 * 云同步收发协调器。
 *
 * @param transport 真实收发通道（生产由 [createWebdavRemoteTransport] 构造）。
 * @param localStore 本机快照读写（下载成功且无冲突时写这里）。
 * @param nowMillis 保留策略的「现在」（毫秒）；控制器把页面时钟传进来，单测注入固定值，
 *   生产缺省用系统时钟（Dart `DateTime.now()` 同位）。
 */
class WebdavSyncCoordinator(
    // 公开：恢复前差异预览只拿字节不落盘（`CloudSyncController.previewBackupRestore`），
    // 必须绕开 downloadSnapshot 的写本地副作用（2026-11-03）。
    val transport: WebdavRemoteTransport,
    private val localStore: LocalSnapshotStore,
    private val nowMillis: () -> Long = { System.currentTimeMillis() },
) {

    @Volatile
    private var cancelled: Boolean = false

    /** 用户中途退出页面时调用；当前操作在网络返回后、落盘前会看到它。 */
    fun cancel() {
        cancelled = true
    }

    /** 手动清取消标记（一般不用，操作开头会自动清）。 */
    fun reset() {
        cancelled = false
    }

    // ---------- 远端 meta（当前快照指针） ----------

    /** GET `snapshot.meta.json` 并按 Dart `getRemoteMetaResult` 口径归类。 */
    fun fetchRemoteMeta(config: WebdavSyncConfig): RemoteMetaFetch {
        val result = transport.getBytes(config.metaRemotePath)
        if (result.isFailed) {
            return RemoteMetaFetch.Failed(result.errorMessage ?: "sync_failed")
        }
        val bytes = result.bytes
        if (result.isNotFound || bytes == null || bytes.isEmpty()) {
            return RemoteMetaFetch.NotFound
        }
        val decoded = try {
            MiniJson.parse(String(bytes, Charsets.UTF_8))
        } catch (_: Exception) {
            null
        }
        if (decoded !is Map<*, *>) return RemoteMetaFetch.Failed("invalid_response")
        @Suppress("UNCHECKED_CAST")
        val fields = parseSnapshotMetaFields(decoded as Map<String, Any?>)
        if (!fields.isValid) {
            // Dart 侧 fromJson 抛 FormatException 被 getRemoteMetaResult catch → invalid_response。
            return RemoteMetaFetch.Failed("invalid_response")
        }
        return RemoteMetaFetch.Ok(
            exportedAtIso = fields.exportedAtIso ?: "",
            contentSha256 = fields.contentSha256 ?: "",
            deviceId = fields.deviceId ?: "",
            snapshotPath = fields.snapshotPath,
        )
    }

    // ---------- 列远端备份（index 优先，缺失/损坏走恢复） ----------

    fun listRemoteBackups(config: WebdavSyncConfig): ListBackupsOutcome {
        return when (val loaded = loadBackupIndex(config)) {
            is BackupIndexLoad.Failed -> ListBackupsOutcome(
                SyncOpKind.FAILED,
                errorCode = loaded.errorCode,
            )
            is BackupIndexLoad.Ok -> {
                if (loaded.entries.isEmpty()) {
                    ListBackupsOutcome(SyncOpKind.EMPTY)
                } else {
                    ListBackupsOutcome(
                        SyncOpKind.OK,
                        files = loaded.entries.map { toRemoteBackupFile(config, it) },
                    )
                }
            }
        }
    }

    /**
     * 装载历史索引（Dart `_loadRemoteBackupIndex` 原样口径）：
     * 1. index.json 可读且是合法结构 → 直接用；
     * 2. index 缺失/损坏 → 按 `decideBackupIndexRecovery` 决策：
     *    空远端 → 空；listing 也拿不到 → 失败（**瞬时错误绝不用空索引顶掉好索引**）；
     *    否则从 listing 重建——逐个下载历史文件解析快照体，坏体跳过（绝不删）。
     */
    fun loadBackupIndex(config: WebdavSyncConfig): BackupIndexLoad {
        val indexResult = transport.getBytes(config.historyIndexRemotePath)
        var readable = indexResult
        if (!indexResult.isFailed && !indexResult.isNotFound) {
            val bytes = indexResult.bytes
            val decoded = bytes?.let {
                try {
                    MiniJson.parse(String(it, Charsets.UTF_8))
                } catch (_: Exception) {
                    null
                }
            }
            if (decoded is Map<*, *> && decoded["entries"] is List<*>) {
                return BackupIndexLoad.Ok(CloudBackupIndexCodec.decodeIndex(String(bytes, Charsets.UTF_8)))
            }
            // 结构不合法：按 Dart `readableIndexResult = failed('sync_failed')` 进恢复决策。
            readable = GetBytesResult.failed("sync_failed")
        }

        val listing = transport.listHistoryBackupFiles(config.historyRemoteFolder)
        return when (decideBackupIndexRecovery(readable, listing)) {
            BackupIndexRecoveryAction.USE_INDEX -> BackupIndexLoad.Failed("sync_failed")
            BackupIndexRecoveryAction.EMPTY -> BackupIndexLoad.Ok(emptyList())
            BackupIndexRecoveryAction.FAILED -> BackupIndexLoad.Failed(
                listing.errorMessage ?: readable.errorMessage ?: "sync_failed",
            )
            BackupIndexRecoveryAction.REBUILD_FROM_LISTING ->
                rebuildIndexFromListing(config, listing.fileNames)
        }
    }

    /**
     * 从 listing 重建索引（Dart `_loadRemoteBackupIndex` 重建分支）：
     * 逐个下载 → 解析快照体 → `id = 文件名去 .mikcb`；单个体损坏跳过不外抛
     * （一个坏文件不许把全部历史藏掉）；旧命名（`snapshot-*`）与新命名同样可读。
     */
    private fun rebuildIndexFromListing(
        config: WebdavSyncConfig,
        fileNames: List<String>,
    ): BackupIndexLoad {
        val meta = fetchRemoteMeta(config)
        if (meta is RemoteMetaFetch.Failed) return BackupIndexLoad.Failed(meta.errorCode)
        val currentHash = (meta as? RemoteMetaFetch.Ok)?.contentSha256 ?: ""
        val entries = ArrayList<CloudBackupEntryModel>(fileNames.size)
        for (name in fileNames) {
            val backup = transport.getBytes(config.historyBackupRemotePath(name))
            if (backup.isFailed) {
                return BackupIndexLoad.Failed(backup.errorMessage ?: "sync_failed")
            }
            if (backup.isNotFound) continue
            val bytes = backup.bytes ?: continue
            val payload = try {
                decodeSnapshotObject(String(bytes, Charsets.UTF_8))
            } catch (_: Exception) {
                continue
            }
            val envelope = checkSnapshotEnvelopeAndChecksum(payload)
            if (!envelope.isValid) continue
            val exportedRaw = payload["exportedAt"] as? String
            entries.add(
                CloudBackupEntryModel(
                    id = name.removeSuffix(".mikcb"),
                    fileName = name,
                    exportedAtIso = exportedRaw ?: "",
                    contentSha256 = envelope.actualHash,
                    deviceId = payload["deviceId"] as? String ?: "",
                    deviceLabel = "",
                    isCurrent = envelope.actualHash == currentHash,
                    source = CloudBackupSource.AUTO,
                    profileCount = CloudBackupIndexCodec.countProfilesInSnapshot(payload),
                    courseCount = CloudBackupIndexCodec.countCoursesInSnapshot(payload),
                ),
            )
        }
        return BackupIndexLoad.Ok(entries)
    }

    /** 覆写 `history/index.json`（失败即失败，调用方决定是否外显）。 */
    fun saveBackupIndex(
        config: WebdavSyncConfig,
        entries: List<CloudBackupEntryModel>,
    ): WebdavWriteResult = transport.putBytes(
        config.historyIndexRemotePath,
        CloudBackupIndexCodec.encodeIndex(entries),
    )

    private fun toRemoteBackupFile(config: WebdavSyncConfig, entry: CloudBackupEntryModel): RemoteBackupFile {
        val millis = CloudBackupIndexCodec.entryMillis(entry)
        return RemoteBackupFile(
            fileName = entry.fileName,
            remotePath = config.historyBackupRemotePath(entry.fileName),
            exportedAtMillis = millis.takeIf { it > 0L },
            contentSha256 = entry.contentSha256.ifEmpty { null },
            deviceId = entry.deviceId.ifEmpty { null },
            exportedAtIso = entry.exportedAtIso,
            deviceLabel = entry.deviceLabel,
            appVersion = entry.appVersion,
            isCurrent = entry.isCurrent,
            source = entry.source,
            profileCount = entry.profileCount,
            courseCount = entry.courseCount,
        )
    }

    // ---------- 上传（发布正文 + meta + 历史与索引） ----------

    /**
     * 上传一份快照：按 Dart 协议发布（锁 → 正文 → 读回 → meta → 校验 → 解锁 → 历史 → 索引）。
     *
     * @param snapshotBytes 快照正文（UTF-8 JSON 字节）
     * @param exportedAtIso 导出时刻（快照信封里的 `exportedAt` 原串；meta 与历史命名都用它）
     * @param deviceId 设备标识（只用于文件名，会做字符清洗）
     * @param source 备份来源（手动允许重复哈希入索引；写进 index 供 Flutter 端识别）
     * @param appVersion App 版本（写进 meta 与索引；宿主注入，null 时不写键）
     */
    fun uploadSnapshot(
        config: WebdavSyncConfig,
        snapshotBytes: ByteArray,
        exportedAtIso: String,
        deviceId: String,
        source: CloudBackupSource = CloudBackupSource.AUTO,
        appVersion: String? = null,
    ): UploadSnapshotOutcome {
        cancelled = false
        val contentSha256 = snapshotContentHash(snapshotBytes) ?: return UploadSnapshotOutcome(
            SyncOpKind.FAILED,
            errorCode = "invalid_sync_snapshot_payload",
        )

        // 版本化正文写在**根目录**（Dart `_versionedSnapshotRemotePath`），不是 history/。
        val exportedAtMicros =
            CloudBackupListLogic.parseExportedAtMillis(exportedAtIso) * 1000L
        val versionedPath = versionedSnapshotRemotePath(
            normalizedRemoteFolder = config.normalizedRemoteFolder,
            contentSha256 = contentSha256,
            exportedAtUtcMicros = exportedAtMicros,
            deviceId = deviceId,
        )
        val metaBytes = CloudBackupIndexCodec.buildMetaBytes(
            exportedAtIso = exportedAtIso,
            contentSha256 = contentSha256,
            deviceId = deviceId,
            appVersion = appVersion,
            snapshotPath = versionedPath,
        )

        val folderResult = transport.ensureRemoteFolder(config.normalizedRemoteFolder)
        if (folderResult.isFailed) {
            return UploadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = folderResult.errorMessage ?: "sync_failed",
            )
        }
        if (cancelled) return UploadSnapshotOutcome(SyncOpKind.CANCELLED)

        // 锁被占是硬失败（Dart `_publishSnapshotVersion`：同步窗口内有人正在写，重试）；
        // 服务器不支持锁则 tokenless 继续——靠不可变正文 + 读回校验保证配对。
        val lock = transport.acquireWriteLock(config.normalizedRemoteFolder)
        if (lock.isFailed) {
            return UploadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = lock.errorMessage ?: "sync_failed",
            )
        }
        val lockToken = lock.lockToken

        try {
            val bodyResult = transport.putBytesConditional(versionedPath, snapshotBytes, lockToken = lockToken)
            if (bodyResult.isFailed) {
                return UploadSnapshotOutcome(
                    SyncOpKind.FAILED,
                    errorCode = bodyResult.errorMessage ?: "sync_failed",
                )
            }
            if (cancelled) return UploadSnapshotOutcome(SyncOpKind.CANCELLED)

            // 读回校验：服务器没锁/没 ETag 也不许半截正文上盘（Dart `_verifyRemoteBytes`）。
            val readBack = transport.getBytes(versionedPath)
            if (readBack.isFailed || readBack.isNotFound) {
                return UploadSnapshotOutcome(
                    SyncOpKind.FAILED,
                    remotePath = versionedPath,
                    contentSha256 = contentSha256,
                    errorCode = readBack.errorMessage ?: "sync_failed",
                )
            }
            val backBytes = readBack.bytes
            if (backBytes == null || !bytesEqual(backBytes, snapshotBytes)) {
                return UploadSnapshotOutcome(
                    SyncOpKind.FAILED,
                    remotePath = versionedPath,
                    contentSha256 = contentSha256,
                    errorCode = "sync_failed",
                )
            }

            val metaResult = transport.putBytesConditional(config.metaRemotePath, metaBytes, lockToken = lockToken)
            if (metaResult.isFailed) {
                return UploadSnapshotOutcome(
                    SyncOpKind.FAILED,
                    remotePath = versionedPath,
                    contentSha256 = contentSha256,
                    errorCode = metaResult.errorMessage ?: "sync_failed",
                )
            }

            // 发布后读回 meta：contentSha256 与 snapshotPath 必须是本次这份，
            // 否则说明并发写者在我们读回之前又覆盖了 meta（Dart 同款校验）。
            val publishedMeta = fetchRemoteMeta(config)
            val published = publishedMeta as? RemoteMetaFetch.Ok
            if (published == null ||
                published.contentSha256 != contentSha256 ||
                published.snapshotPath != versionedPath
            ) {
                return UploadSnapshotOutcome(
                    SyncOpKind.FAILED,
                    remotePath = versionedPath,
                    contentSha256 = contentSha256,
                    errorCode = "sync_failed",
                )
            }
        } finally {
            // 锁有服务端超时；解锁失败不掩盖发布结果（Dart finally 注释原样）。
            if (lockToken != null) {
                runCatching { transport.releaseWriteLock(config.normalizedRemoteFolder, lockToken) }
            }
        }

        if (cancelled) return UploadSnapshotOutcome(SyncOpKind.CANCELLED)

        // ── 历史与索引（Dart `_writeBackupHistory`）。
        // 失败按 Dart 口径整体报失败——正文与 meta 已发布（不可变正文有意保留），
        // 下一次同步可安全重试或由保留策略回收。
        return writeBackupHistory(config, snapshotBytes, contentSha256, exportedAtIso, deviceId, source, appVersion)
            .let { historyError ->
                if (historyError == null) {
                    UploadSnapshotOutcome(SyncOpKind.OK, remotePath = versionedPath, contentSha256 = contentSha256)
                } else {
                    UploadSnapshotOutcome(
                        SyncOpKind.FAILED,
                        remotePath = versionedPath,
                        contentSha256 = contentSha256,
                        errorCode = historyError,
                    )
                }
            }
    }

    /** 历史备份 + 索引维护；null = 成功，非 null = 失败短码（正文/meta 已发布不受影响）。 */
    private fun writeBackupHistory(
        config: WebdavSyncConfig,
        snapshotBytes: ByteArray,
        contentSha256: String,
        exportedAtIso: String,
        deviceId: String,
        source: CloudBackupSource,
        appVersion: String?,
    ): String? {
        val folderResult = transport.ensureRemoteFolder(config.historyRemoteFolder)
        if (folderResult.isFailed) {
            return folderResult.errorMessage ?: "sync_failed"
        }

        // Dart 命名：本地墙上时刻 yyyyMMdd-HHmmss + hash8（CloudBackupIndexService.buildBackupId）。
        val backupId = CloudBackupIndexCodec.buildBackupId(exportedAtIso, contentSha256)
        val fileName = CloudBackupIndexCodec.buildBackupFileName(backupId)
        val historyResult = transport.putBytes(config.historyBackupRemotePath(fileName), snapshotBytes)
        if (historyResult.isFailed) {
            return historyResult.errorMessage ?: "sync_failed"
        }

        val loaded = loadBackupIndex(config)
        val existingEntries = when (loaded) {
            is BackupIndexLoad.Failed -> return loaded.errorCode
            is BackupIndexLoad.Ok -> loaded.entries
        }

        val payload = runCatching {
            decodeSnapshotObject(String(snapshotBytes, Charsets.UTF_8))
        }.getOrNull() ?: return "invalid_sync_snapshot_payload"
        val entry = CloudBackupEntryModel(
            id = backupId,
            fileName = fileName,
            exportedAtIso = exportedAtIso,
            contentSha256 = contentSha256,
            deviceId = deviceId,
            deviceLabel = "",
            appVersion = appVersion,
            source = source,
            profileCount = CloudBackupIndexCodec.countProfilesInSnapshot(payload),
            courseCount = CloudBackupIndexCodec.countCoursesInSnapshot(payload),
        )
        val withNew = CloudBackupIndexCodec.addEntry(
            entries = existingEntries,
            entry = entry,
            currentContentSha256 = contentSha256,
            allowDuplicateHash = source == CloudBackupSource.MANUAL,
        )
        val removals = CloudBackupIndexCodec.planHistoryPrune(
            entries = withNew,
            config = config,
            nowMillis = nowMillis(),
            manualFileNames = emptySet(),
        )
        for (removed in removals) {
            // 索引已裁掉但远端删除失败 → 孤儿文件，下一轮 prune 再试（Dart 同口径：只记日志不中断）。
            runCatching { transport.deleteRemoteFile(config.historyBackupRemotePath(removed.fileName)) }
        }
        val saveResult = saveBackupIndex(config, withNew - removals.toSet())
        if (saveResult.isFailed) {
            return saveResult.errorMessage ?: "sync_failed"
        }
        return null
    }

    // ---------- 下载（GET）+ 冲突判定 ----------

    /**
     * 下载远端快照，校验信封/校验和，做冲突判定，无冲突且未取消时写本机。
     *
     * @param remotePath 要下载的远端路径（meta 指针解析出的版本化正文，或历史文件）
     * @param expectedRemoteHash meta 声明的内容哈希；非空且与正文重算值不符 →
     *   `sync_snapshot_meta_mismatch`（Dart `downloadAndApply` 的配对校验）
     * @param hasLocalUserData 本机快照是否含用户亲手沉淀的数据（冲突自动决策要用）
     * @param readLocalSnapshot 读「本机现在这份课表」的字节；默认读本机快照文件。
     *   控制器有仓储时应传入**实时快照**：进程在两次同步之间被杀时，快照文件可能是空的
     *   （上传从不写它），只按文件判会把「远端==本机」误判成首次分歧、弹出假冲突框。
     * @param resolver 冲突裁决（默认 LWW + 字典序平局判云端；后台拉取传 background 版）
     */
    fun downloadSnapshot(
        config: WebdavSyncConfig,
        remotePath: String = config.snapshotRemotePath,
        expectedRemoteHash: String? = null,
        hasLocalUserData: Boolean = false,
        readLocalSnapshot: () -> ByteArray? = localStore::readSnapshot,
        resolver: (SyncConflictInfo) -> SyncConflictChoice = ::resolveSyncConflictAutomatically,
    ): DownloadSnapshotOutcome {
        cancelled = false
        val fetched = transport.getBytes(remotePath)
        if (fetched.isFailed) {
            return DownloadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = fetched.errorMessage ?: "sync_failed",
            )
        }
        if (fetched.isNotFound || fetched.isEmpty) {
            return DownloadSnapshotOutcome(SyncOpKind.FAILED, errorCode = "backup_not_found")
        }
        val bytes = fetched.bytes ?: return DownloadSnapshotOutcome(
            SyncOpKind.FAILED,
            errorCode = "backup_not_found",
        )

        // 用户中途退出：网络已返回，但绝不把字节写进本机（不落脏数据）。
        if (cancelled) return DownloadSnapshotOutcome(SyncOpKind.CANCELLED)

        val remotePayload = try {
            decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        } catch (error: Exception) {
            return DownloadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = error.message ?: "invalid_sync_snapshot_payload",
            )
        }
        val envelope = checkSnapshotEnvelopeAndChecksum(remotePayload)
        if (!envelope.isValid) {
            return DownloadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = envelope.errorCode ?: "invalid_sync_snapshot_payload",
            )
        }
        if (!expectedRemoteHash.isNullOrEmpty() && envelope.actualHash != expectedRemoteHash) {
            // meta 与正文不配对：另一台设备刚发了新版本（Dart `sync_snapshot_meta_mismatch`）。
            return DownloadSnapshotOutcome(
                SyncOpKind.FAILED,
                bytes = bytes,
                remoteContentSha256 = envelope.actualHash,
                errorCode = "sync_snapshot_meta_mismatch",
            )
        }

        val remoteHash = envelope.actualHash
        val localBytes = readLocalSnapshot()
        val localHash = localBytes?.let { snapshotContentHash(it) }.orEmpty()

        val conflict = webdavPullHasSyncConflict(
            lastUploadedLocalHash = config.lastUploadedLocalHash,
            lastAppliedRemoteHash = config.lastAppliedRemoteHash,
            localContentSha256 = localHash,
            remoteContentSha256 = remoteHash,
        )
        if (conflict) {
            val info = buildConflictInfo(
                remotePayload = remotePayload,
                localBytes = localBytes,
                localHash = localHash,
                remoteHash = remoteHash,
                config = config,
                hasLocalUserData = hasLocalUserData,
            )
            val choice = resolver(info)
            if (choice == SyncConflictChoice.CANCEL) {
                return DownloadSnapshotOutcome(
                    SyncOpKind.CANCELLED,
                    bytes = bytes,
                    remoteContentSha256 = remoteHash,
                    localContentSha256 = localHash,
                    conflict = info,
                    resolvedChoice = choice,
                )
            }
            if (choice == SyncConflictChoice.KEEP_LOCAL) {
                // 保留本机：不覆盖、不落盘，把冲突信息交回页面弹选择。
                return DownloadSnapshotOutcome(
                    SyncOpKind.CONFLICT,
                    bytes = bytes,
                    remoteContentSha256 = remoteHash,
                    localContentSha256 = localHash,
                    conflict = info,
                    resolvedChoice = choice,
                )
            }
            // KEEP_REMOTE：继续走落盘。
        }

        if (cancelled) return DownloadSnapshotOutcome(SyncOpKind.CANCELLED)
        localStore.writeSnapshot(bytes)
        return DownloadSnapshotOutcome(
            SyncOpKind.OK,
            bytes = bytes,
            remoteContentSha256 = remoteHash,
            localContentSha256 = localHash,
            conflict = if (conflict) buildConflictInfo(
                remotePayload = remotePayload,
                localBytes = localBytes,
                localHash = localHash,
                remoteHash = remoteHash,
                config = config,
                hasLocalUserData = hasLocalUserData,
            ) else null,
            resolvedChoice = if (conflict) SyncConflictChoice.KEEP_REMOTE else null,
            applied = true,
        )
    }

    // ---------- 内部 ----------

    private fun buildConflictInfo(
        remotePayload: Map<String, Any?>,
        localBytes: ByteArray?,
        localHash: String,
        remoteHash: String,
        config: WebdavSyncConfig,
        hasLocalUserData: Boolean,
    ): SyncConflictInfo {
        val remoteExportedAt = CloudBackupListLogic.parseExportedAtMillis(
            remotePayload["exportedAt"] as? String,
        )
        val localPayload = localBytes?.let {
            runCatching { decodeSnapshotObject(String(it, Charsets.UTF_8)) }.getOrNull()
        }
        val localExportedAt = CloudBackupListLogic.parseExportedAtMillis(
            localPayload?.get("exportedAt") as? String,
        )
        val firstSyncDivergence =
            config.lastUploadedLocalHash == null &&
                config.lastAppliedRemoteHash == null &&
                localHash != remoteHash
        return SyncConflictInfo(
            localExportedAtMillis = localExportedAt,
            remoteExportedAtMillis = remoteExportedAt,
            localHash = localHash,
            remoteHash = remoteHash,
            isFirstSyncDivergence = firstSyncDivergence,
            localHasUserData = hasLocalUserData,
        )
    }

    companion object {
        /** 快照字节的内容一致性哈希；不是合法快照时返回 null。 */
        fun snapshotContentHash(bytes: ByteArray): String? = try {
            computeContentSha256(decodeSnapshotObject(String(bytes, Charsets.UTF_8)))
        } catch (_: Exception) {
            null
        }

        /** 原始字节 SHA-256（情侣课表这类非快照信封的正文用）。 */
        fun rawSha256Hex(bytes: ByteArray): String {
            val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
            return digest.joinToString("") { "%02x".format(it) }
        }
    }
}
