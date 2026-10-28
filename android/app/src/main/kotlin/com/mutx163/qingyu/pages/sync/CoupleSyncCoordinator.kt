package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.shouldSkipCouplePullAsUnchanged

/**
 * 情侣课表「真收发」协调层（Phase 3.5 · C1 的另一半）。
 *
 * 只做两件真实网络动作：**拉取对端课表（GET）** 与 **上传我的课表（PUT）**。
 * 变更判定沿用既有纯逻辑 [shouldSkipCouplePullAsUnchanged]（内容哈希一致 + 已有绑定 + 非强制 → 免导入）。
 *
 * **交给调用方的**：拉回来的字节如何写进「对方课表档案」、绑定记录如何落盘（属仓储/宿主，不在本层）。
 * 本层只把「字节 + 内容哈希 + 结局」交回去，保持无 Android / 无仓储依赖、可 JVM 单测。
 */

/** 情侣拉取结局（Dart `CoupleWebdavPullStatus` 的四态 + 取消）。 */
enum class CouplePullKind { IMPORTED, UPDATED, UNCHANGED, FAILED, CANCELLED }

data class CouplePullOutcome(
    val kind: CouplePullKind,
    /** 拉到的正文（UNCHANGED 时也可能给出，供调用方比对；FAILED/CANCELLED 为 null）。 */
    val bytes: ByteArray? = null,
    /** 正文 SHA-256（十六进制）。 */
    val contentHash: String? = null,
    val errorCode: String? = null,
)

data class CoupleUploadOutcome(
    val kind: SyncOpKind,
    val remotePath: String? = null,
    val errorCode: String? = null,
)

class CoupleSyncCoordinator(
    private val transport: WebdavRemoteTransport,
) {

    @Volatile
    private var cancelled: Boolean = false

    fun cancel() {
        cancelled = true
    }

    fun reset() {
        cancelled = false
    }

    /**
     * 拉取对端课表。
     *
     * @param force 用户手动点「立即拉取」为 true（跳过 unchanged 短路）
     * @param hasBinding 本机是否已有对方课表绑定（没有绑定时即便哈希一致也要导入一次）
     */
    fun pullPartnerTimetable(
        config: CoupleWebdavConfig,
        force: Boolean = true,
        hasBinding: Boolean = false,
    ): CouplePullOutcome {
        cancelled = false
        val fetched = transport.getBytes(config.partnerTimetableRemotePath)
        if (fetched.isFailed) {
            return CouplePullOutcome(CouplePullKind.FAILED, errorCode = fetched.errorMessage ?: "sync_failed")
        }
        if (fetched.isNotFound || fetched.isEmpty) {
            return CouplePullOutcome(CouplePullKind.FAILED, errorCode = "couple_webdav_pull_failed")
        }
        val bytes = fetched.bytes ?: return CouplePullOutcome(
            CouplePullKind.FAILED,
            errorCode = "couple_webdav_pull_failed",
        )
        if (cancelled) return CouplePullOutcome(CouplePullKind.CANCELLED)

        val hash = WebdavSyncCoordinator.rawSha256Hex(bytes)
        if (shouldSkipCouplePullAsUnchanged(
                lastRemoteContentHash = config.lastRemoteContentHash,
                contentHash = hash,
                force = force,
                hasPartnerBinding = hasBinding,
            )
        ) {
            return CouplePullOutcome(CouplePullKind.UNCHANGED, bytes = bytes, contentHash = hash)
        }
        return CouplePullOutcome(
            kind = if (hasBinding) CouplePullKind.UPDATED else CouplePullKind.IMPORTED,
            bytes = bytes,
            contentHash = hash,
        )
    }

    /** 上传我的课表给对端拉取。 */
    fun uploadMineTimetable(
        config: CoupleWebdavConfig,
        bytes: ByteArray,
    ): CoupleUploadOutcome {
        cancelled = false
        val folder = transport.ensureRemoteFolder(config.remoteFolder)
        if (folder.isFailed) {
            return CoupleUploadOutcome(
                SyncOpKind.FAILED,
                errorCode = folder.errorMessage ?: "sync_failed",
            )
        }
        if (cancelled) return CoupleUploadOutcome(SyncOpKind.CANCELLED)
        val put = transport.putBytes(config.mineTimetableRemotePath, bytes)
        if (put.isFailed) {
            return CoupleUploadOutcome(
                SyncOpKind.FAILED,
                remotePath = config.mineTimetableRemotePath,
                errorCode = put.errorMessage ?: "sync_failed",
            )
        }
        return CoupleUploadOutcome(SyncOpKind.OK, remotePath = config.mineTimetableRemotePath)
    }
}
