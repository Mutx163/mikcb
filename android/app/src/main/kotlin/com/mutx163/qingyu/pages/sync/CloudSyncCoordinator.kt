package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.SyncConflictInfo
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.checkSnapshotEnvelopeAndChecksum
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decodeSnapshotObject
import com.mutx163.qingyu.sync.resolveSyncConflictAutomatically
import com.mutx163.qingyu.sync.versionedSnapshotRemotePath
import com.mutx163.qingyu.sync.webdavPullHasSyncConflict
import java.security.MessageDigest

/**
 * 云同步「真收发」协调层（Phase 3.5 · C1）。
 *
 * 这是把 P3-F 只做「状态机 + 解析」的模型层接上**真实网络收发**的那一层：
 * 列远端备份（PROPFIND）、上传（PUT）、下载（GET）、冲突判定、断线/超时失败码、
 * 中途退出取消，全部在这里完成。数据面依赖 [WebdavRemoteTransport] 这个缝，
 * 单测注入内存假实现即可覆盖全路径，不碰真机、不起 HTTP 服务。
 *
 * **刻意不放进来的东西**（交给别的层）：
 * - 密码 / 端点构造：由 [createWebdavRemoteTransport] 从配置 + 密码生成，密码存储归宿主；
 * - 配置落盘（SharedPreferences）、UI 文案与按钮态：归 `CloudSyncController` / 宿主；
 * - 快照 `applySnapshot`（把快照写回仓储各表）：这是仓储原子入口（台账 §9.4 ③ `task-14`），
 *   本层只负责把「校验通过、无冲突、未取消」的快照字节交给 [LocalSnapshotStore]。
 *
 * ## 取消语义（中途退出不落脏数据）
 * [cancel] 置位后，一次下载在「网络返回之后、写本地之前」会看到取消标记并直接返回
 * [SyncOpKind.CANCELLED]，**不写任何字节**；每次新操作开头清掉取消标记。
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

/** 远端一条备份文件（来自 PROPFIND 文件名，元信息尽力从版本化文件名解析）。 */
data class RemoteBackupFile(
    val fileName: String,
    val remotePath: String,
    val exportedAtMillis: Long? = null,
    val contentSha256: String? = null,
    val deviceId: String? = null,
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
 */
class WebdavSyncCoordinator(
    private val transport: WebdavRemoteTransport,
    private val localStore: LocalSnapshotStore,
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

    // ---------- 列远端备份（PROPFIND） ----------

    fun listRemoteBackups(config: WebdavSyncConfig): ListBackupsOutcome {
        val listing = transport.listHistoryBackupFiles(config.historyRemoteFolder)
        if (listing.isFailed) {
            return ListBackupsOutcome(SyncOpKind.FAILED, errorCode = listing.errorMessage ?: "sync_failed")
        }
        // 目录不存在（404）与空目录在产品语义上都是「还没有备份」。
        if (listing.isNotFound || listing.fileNames.isEmpty()) {
            return ListBackupsOutcome(SyncOpKind.EMPTY)
        }
        val files = listing.fileNames.map { name ->
            parseRemoteBackupFile(name, config.historyRemoteFolder)
        }
        return ListBackupsOutcome(SyncOpKind.OK, files = files)
    }

    // ---------- 上传（PUT） ----------

    /**
     * 上传一份快照：先建目录，再写版本化文件，最后更新「当前快照」指针。
     *
     * @param snapshotBytes 快照正文（UTF-8 JSON 字节）
     * @param exportedAtUtcMicros 导出时刻（微秒，来自快照信封）
     * @param deviceId 设备标识（只用于文件名，会做字符清洗）
     */
    fun uploadSnapshot(
        config: WebdavSyncConfig,
        snapshotBytes: ByteArray,
        exportedAtUtcMicros: Long,
        deviceId: String,
    ): UploadSnapshotOutcome {
        cancelled = false
        val contentSha256 = snapshotContentHash(snapshotBytes) ?: return UploadSnapshotOutcome(
            SyncOpKind.FAILED,
            errorCode = "invalid_sync_snapshot_payload",
        )

        val folderResult = transport.ensureRemoteFolder(config.historyRemoteFolder)
        if (folderResult.isFailed) {
            return UploadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = folderResult.errorMessage ?: "sync_failed",
            )
        }
        if (cancelled) return UploadSnapshotOutcome(SyncOpKind.CANCELLED)

        val versionedPath = versionedSnapshotRemotePath(
            normalizedRemoteFolder = config.historyRemoteFolder,
            contentSha256 = contentSha256,
            exportedAtUtcMicros = exportedAtUtcMicros,
            deviceId = deviceId,
        )
        val versionedResult = transport.putBytes(versionedPath, snapshotBytes)
        if (versionedResult.isFailed) {
            return UploadSnapshotOutcome(
                SyncOpKind.FAILED,
                errorCode = versionedResult.errorMessage ?: "sync_failed",
            )
        }
        if (cancelled) return UploadSnapshotOutcome(SyncOpKind.CANCELLED)

        // 「当前快照」指针：让其他设备知道最新快照是哪一份（失败即整体失败，不留半截）。
        val pointerResult = transport.putBytes(config.snapshotRemotePath, snapshotBytes)
        if (pointerResult.isFailed) {
            return UploadSnapshotOutcome(
                SyncOpKind.FAILED,
                remotePath = versionedPath,
                contentSha256 = contentSha256,
                errorCode = pointerResult.errorMessage ?: "sync_failed",
            )
        }
        return UploadSnapshotOutcome(
            SyncOpKind.OK,
            remotePath = versionedPath,
            contentSha256 = contentSha256,
        )
    }

    // ---------- 下载（GET）+ 冲突判定 ----------

    /**
     * 下载远端快照，校验信封/校验和，做冲突判定，无冲突且未取消时写本机。
     *
     * @param remotePath 要下载的远端路径（默认「当前快照」指针）
     * @param hasLocalUserData 本机快照是否含用户亲手沉淀的数据（冲突自动决策要用）
     * @param resolver 冲突裁决（默认 LWW + 字典序平局判云端；后台拉取传 background 版）
     */
    fun downloadSnapshot(
        config: WebdavSyncConfig,
        remotePath: String = config.snapshotRemotePath,
        hasLocalUserData: Boolean = false,
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

        val remoteHash = envelope.actualHash
        val localBytes = localStore.readSnapshot()
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
        private val VERSIONED_FILE_REGEX =
            Regex("""^snapshot-([0-9a-fA-F]+)-(\d+)-(.+)\.mikcb$""")

        /**
         * 从版本化文件名解析元信息（`snapshot-<sha256>-<micros>-<device>.mikcb`）。
         * 解析不出就给 null（仍是一条备份，只是没有结构化元信息）。
         */
        fun parseRemoteBackupFile(fileName: String, historyRemoteFolder: String): RemoteBackupFile {
            val match = VERSIONED_FILE_REGEX.find(fileName)
            val exportedAtMillis = match?.groupValues?.getOrNull(2)?.toLongOrNull()?.let { it / 1000L }
            return RemoteBackupFile(
                fileName = fileName,
                remotePath = "$historyRemoteFolder$fileName",
                exportedAtMillis = exportedAtMillis,
                contentSha256 = match?.groupValues?.getOrNull(1),
                deviceId = match?.groupValues?.getOrNull(3),
            )
        }

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
