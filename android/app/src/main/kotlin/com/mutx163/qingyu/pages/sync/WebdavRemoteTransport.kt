package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.GetBytesResult
import com.mutx163.qingyu.sync.HistoryListResult
import com.mutx163.qingyu.sync.LockResult
import com.mutx163.qingyu.sync.WebdavEndpoint
import com.mutx163.qingyu.sync.WebdavHeadResult
import com.mutx163.qingyu.sync.WebdavHttpTransport
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.WebdavWriteResult

/**
 * 页面协调层与真实 WebDAV 收发之间的**可注入接口（缝）**。
 *
 * 为什么要有它：`WebdavHttpTransport`（`main: sync/`，已交付 `c339330d`）直接持有
 * `HttpURLConnection`/裸 socket，页面协调层若直接依赖它，L0 的 JVM 单测就只能起一个
 * 真 HTTP 服务才有得测。把动作抽成接口后，单测注入一个内存假实现即可覆盖
 * 「列备份 / 上传 / 下载 / 冲突 / 断线 / 取消」全部路径，生产实现 [WebdavHttpRemoteTransport]
 * 只做一字不改的透传。
 *
 * **接口只放页面层真实用到的动作**，与传输层一一对应，不在这里新增任何语义
 * （路径拼接、失败分类、XML 解析全在 `sync/` 的纯逻辑里，本层不重复实现）。
 *
 * ## 条件写能力（2026-11-02 协议互通第 1 段）
 *
 * 云备份与 Flutter 版互通需要 Dart 已有的三样并发能力：`If-Match`/`If-None-Match`
 * 条件 PUT（Dart `webdav_sync_service.dart` `_publishSnapshotVersion`）、取独占写锁、
 * 释放写锁。传输层本体（`sync/WebdavHttpTransport`）早已具备全部三个（`putBytes` 的
 * `headers`/`lockToken` 参数与 `acquireWriteLock`/`releaseWriteLock`），缺的只是这个
 * 接口面。三个新方法都带**默认实现 = 今天的能力**：
 * - `putBytesConditional` 默认丢弃条件头、原样转调 [putBytes]；
 * - `acquireWriteLock` 默认返回「服务器不支持锁」（Dart `WebdavLockResult.unsupported`
 *   同一语义，调用方据此走无锁路径）；
 * - `releaseWriteLock` 只在拿到锁后才会被调用，默认失败值不可达。
 *
 * 这样新能力是**纯增量**：既有调用点（情侣同步走 [putBytes]）与既有测试假实现
 * 一个字都不用改，行为与今天完全一致——由 `WebdavRemoteTransportCapabilityTest` 钉住。
 */
interface WebdavRemoteTransport {
    /** PROPFIND depth=1 列历史备份目录里的文件名。 */
    fun listHistoryBackupFiles(historyRemoteFolder: String): HistoryListResult

    /** GET 一个远端文件（空体当缺失）。 */
    fun getBytes(remotePath: String): GetBytesResult

    /** PUT 一个远端文件。 */
    fun putBytes(remotePath: String, bytes: ByteArray): WebdavWriteResult

    /**
     * PUT 一个远端文件，可带条件头（`If-Match` / `If-None-Match` 等）与锁 token
     * （token 会包成 WebDAV `If: (<token>)` 头，Dart `putBytes` 同口径）。
     * 默认实现**忽略**全部条件、等价 [putBytes]——「锁能力关闭时行为与今天一致」。
     */
    fun putBytesConditional(
        remotePath: String,
        bytes: ByteArray,
        headers: Map<String, String> = emptyMap(),
        lockToken: String? = null,
    ): WebdavWriteResult = putBytes(remotePath, bytes)

    /** PROPFIND depth=0 取 ETag（拿不到返回 null）。 */
    fun getRemoteEtag(remotePath: String): String?

    /** 逐段 MKCOL 建目录（已存在视为成功）。 */
    fun ensureRemoteFolder(remoteFolder: String): WebdavWriteResult

    /** HEAD 探测文件是否存在 + 长度 + ETag。 */
    fun head(remotePath: String): WebdavHeadResult

    /** 对根做 PROPFIND depth=0 自检；null 表示可用。 */
    fun testConnection(): String?

    /** DELETE 一个远端文件（404 按幂等返回 notFound=true）。 */
    fun deleteRemoteFile(remotePath: String): WebdavWriteResult

    /**
     * 对目录取独占写锁（Dart `acquireWriteLock` 口径：405/501 与明确「不支持锁」的
     * 403 → [LockResult.unsupported]，其余失败是硬失败）。默认 = 不支持锁。
     */
    fun acquireWriteLock(remotePath: String): LockResult = LockResult.unsupported()

    /** 释放写锁（`Lock-Token: <token>`）。默认实现不可达（拿不到锁就没有 token）。 */
    fun releaseWriteLock(remotePath: String, lockToken: String): WebdavWriteResult =
        WebdavWriteResult.failed("sync_failed")
}

/**
 * 生产适配器：把 [WebdavRemoteTransport] 的每次调用透传给 [WebdavHttpTransport]。
 *
 * 超时/响应上限等参数已在构造 [WebdavHttpTransport] 时给定，这里不再另开一套。
 */
class WebdavHttpRemoteTransport(
    private val transport: WebdavHttpTransport,
) : WebdavRemoteTransport {

    override fun listHistoryBackupFiles(historyRemoteFolder: String): HistoryListResult =
        transport.listHistoryBackupFiles(historyRemoteFolder)

    override fun getBytes(remotePath: String): GetBytesResult =
        transport.getBytes(remotePath)

    override fun putBytes(remotePath: String, bytes: ByteArray): WebdavWriteResult =
        transport.putBytes(remotePath, bytes)

    override fun putBytesConditional(
        remotePath: String,
        bytes: ByteArray,
        headers: Map<String, String>,
        lockToken: String?,
    ): WebdavWriteResult = transport.putBytes(remotePath, bytes, headers = headers, lockToken = lockToken)

    override fun getRemoteEtag(remotePath: String): String? =
        transport.getRemoteEtag(remotePath)

    override fun ensureRemoteFolder(remoteFolder: String): WebdavWriteResult =
        transport.ensureRemoteFolder(remoteFolder)

    override fun head(remotePath: String): WebdavHeadResult =
        transport.head(remotePath)

    override fun testConnection(): String? =
        transport.testConnection()

    override fun deleteRemoteFile(remotePath: String): WebdavWriteResult =
        transport.deleteRemoteFile(remotePath)

    override fun acquireWriteLock(remotePath: String): LockResult =
        transport.acquireWriteLock(remotePath)

    override fun releaseWriteLock(remotePath: String, lockToken: String): WebdavWriteResult =
        transport.releaseWriteLock(remotePath, lockToken)
}

/**
 * 云同步端点构造：把配置 + 密码变成真实收发通道。
 *
 * @return null = 被 scheme 门禁拦下（`insecure_url_blocked`：http 且未显式放行，或协议非法）。
 * 调用方（壳 / 协调器）拿到 null 时按「地址不安全」提示，**不要**回落到任何默认地址。
 */
fun createWebdavRemoteTransport(
    config: WebdavSyncConfig,
    password: String,
    allowInsecureHttp: Boolean = false,
): WebdavRemoteTransport? {
    val endpoint = WebdavEndpoint.from(config, password, allowInsecureHttp) ?: return null
    return WebdavHttpRemoteTransport(WebdavHttpTransport(endpoint))
}

/** 情侣端点构造：http 一律拒绝（情侣页没有二次确认入口）。null = 地址不可用。 */
fun createCoupleRemoteTransport(
    config: CoupleWebdavConfig,
    password: String,
): WebdavRemoteTransport? {
    val endpoint = WebdavEndpoint.fromCouple(config, password) ?: return null
    return WebdavHttpRemoteTransport(WebdavHttpTransport(endpoint))
}
