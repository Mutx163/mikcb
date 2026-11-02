package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.GetBytesResult
import com.mutx163.qingyu.sync.HistoryListResult
import com.mutx163.qingyu.sync.LockResult
import com.mutx163.qingyu.sync.WebdavHeadResult
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.WebdavWriteResult

/**
 * C1 协调层单测用的内存假实现（不参与 JUnit 运行，只被各 Test 类引用）。
 *
 * 这些假实现**只按产品语义行为**，不照抄实现：
 * - 目录 listing 只列某目录的直接子文件；
 * - PUT 覆盖同名、GET 缺失返回 notFound；
 * - 失败用安全短码（与 `WebdavFailures` 同口径）。
 */

/** 内存 WebDAV 传输：path → bytes。失败用可配置的短码注入。 */
class FakeRemoteTransport : WebdavRemoteTransport {
    val files = LinkedHashMap<String, ByteArray>()
    val createdFolders = LinkedHashSet<String>()

    /** 非空时直接返回，用于模拟断线 / 超时 / 目录不存在等。 */
    var listResultOverride: HistoryListResult? = null
    var getResultOverride: GetBytesResult? = null
    var putFailureCode: String? = null
    var ensureFailureCode: String? = null
    var connectionErrorCode: String? = null

    /** 在 GET / PUT 前回调（用于模拟「用户中途退出」）。 */
    var beforeGet: () -> Unit = {}
    var beforePut: () -> Unit = {}

    // ── 条件写 / 锁能力（协议互通第 1 段；默认值 = 今天的行为） ──

    /** 最近一次条件 PUT 携带的条件头与锁 token（缺省调用记录为空 map / null）。 */
    var lastConditionalPutHeaders: Map<String, String>? = null
        private set
    var lastConditionalPutLockToken: String? = null
        private set

    /** false = 服务器不支持 LOCK（`acquireWriteLock` 返回 unsupported，与旧行为一致）。 */
    var lockSupported: Boolean = false

    /** true = 模拟别的客户端正持锁（取锁硬失败）。 */
    var lockConflict: Boolean = false

    /** 当前被持有的锁 token；`releaseWriteLock` 后清空。 */
    var heldLockToken: String? = null
        private set

    override fun listHistoryBackupFiles(historyRemoteFolder: String): HistoryListResult {
        listResultOverride?.let { return it }
        val names = files.keys
            .filter { it.startsWith(historyRemoteFolder) }
            .filter { !it.removePrefix(historyRemoteFolder).contains('/') }
            .filter { it.endsWith(".mikcb") }
            .map { it.substringAfterLast('/') }
        return HistoryListResult.ok(names)
    }

    override fun getBytes(remotePath: String): GetBytesResult {
        beforeGet()
        getResultOverride?.let { return it }
        val bytes = files[remotePath] ?: return GetBytesResult.notFound()
        return GetBytesResult.ok(bytes)
    }

    override fun putBytes(remotePath: String, bytes: ByteArray): WebdavWriteResult {
        beforePut()
        putFailureCode?.let { return WebdavWriteResult.failed(it) }
        files[remotePath] = bytes
        return WebdavWriteResult.ok(201, null)
    }

    override fun putBytesConditional(
        remotePath: String,
        bytes: ByteArray,
        headers: Map<String, String>,
        lockToken: String?,
    ): WebdavWriteResult {
        lastConditionalPutHeaders = headers
        lastConditionalPutLockToken = lockToken
        return putBytes(remotePath, bytes)
    }

    override fun acquireWriteLock(remotePath: String): LockResult = when {
        !lockSupported -> LockResult.unsupported()
        lockConflict -> LockResult.failed("access_denied")
        else -> LockResult.acquired("opaquelocktoken:fake-${System.nanoTime()}").also {
            heldLockToken = it.lockToken
        }
    }

    override fun releaseWriteLock(remotePath: String, lockToken: String): WebdavWriteResult {
        if (heldLockToken == lockToken) {
            heldLockToken = null
            return WebdavWriteResult.ok(204, null)
        }
        return WebdavWriteResult.failed("conflict")
    }

    override fun getRemoteEtag(remotePath: String): String? = null

    override fun ensureRemoteFolder(remoteFolder: String): WebdavWriteResult {
        ensureFailureCode?.let { return WebdavWriteResult.failed(it) }
        createdFolders.add(remoteFolder)
        return WebdavWriteResult.ok(200, null)
    }

    override fun head(remotePath: String): WebdavHeadResult =
        if (files.containsKey(remotePath)) {
            WebdavHeadResult.present(200, files.getValue(remotePath).size.toLong(), null)
        } else {
            WebdavHeadResult.missing(404)
        }

    override fun testConnection(): String? = connectionErrorCode

    override fun deleteRemoteFile(remotePath: String): WebdavWriteResult {
        val existed = files.remove(remotePath) != null
        return if (existed) WebdavWriteResult.ok(204, null) else WebdavWriteResult.ok(404, null, notFound = true)
    }
}

/** 内存本机快照存储。 */
class FakeLocalSnapshotStore(initial: ByteArray? = null) : LocalSnapshotStore {
    var stored: ByteArray? = initial
    var writeCount: Int = 0
        private set

    override fun readSnapshot(): ByteArray? = stored

    override fun writeSnapshot(bytes: ByteArray) {
        stored = bytes
        writeCount++
    }
}

/** 内存配置存储。 */
class FakeConfigStore(
    var config: WebdavSyncConfig = WebdavSyncConfig(),
    var password: String? = null,
) : WebdavConfigStore {
    var savedCount: Int = 0
        private set

    override fun loadConfig(): WebdavSyncConfig = config
    override fun saveConfig(config: WebdavSyncConfig) {
        this.config = config
        savedCount++
    }

    override fun hasStoredPassword(): Boolean = password != null
    override fun storePassword(password: String) {
        this.password = password
    }

    override fun clearPassword() {
        password = null
    }
}

/** 构造一份**合法**的云同步快照 JSON（信封 version=2/type=sync，profiles/timeSchemes 是数组）。 */
fun buildSyncSnapshotJson(
    exportedAt: String = "2026-03-07T09:05:00.000",
    deviceId: String = "devA",
    profileId: String = "p1",
): String =
    """{"app":"mikcb","schemaVersion":2,"backupType":"sync",""" +
        """"exportedAt":"$exportedAt","deviceId":"$deviceId",""" +
        """"profiles":[{"id":"$profileId"}],"timeSchemes":[]}"""

fun buildSyncSnapshotBytes(
    exportedAt: String = "2026-03-07T09:05:00.000",
    deviceId: String = "devA",
    profileId: String = "p1",
): ByteArray = buildSyncSnapshotJson(exportedAt, deviceId, profileId).toByteArray(Charsets.UTF_8)

/** 构造一份情侣课表正文（不要求是快照信封，本层只做字节对比/哈希）。 */
fun buildCoupleBytes(content: String = "partner-timetable-v1"): ByteArray =
    content.toByteArray(Charsets.UTF_8)

/** 便捷：默认情侣配置（http 不可用，但本层不校验 scheme，只用路径拼接）。 */
fun defaultCoupleConfig(): CoupleWebdavConfig = CoupleWebdavConfig()
